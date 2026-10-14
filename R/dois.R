#' Extract, clean and optionally export DOIs
#'
#' Pulls Digital Object Identifiers from a [scopus_records] object (or a bare
#' character vector), normalises them and removes missing values. The resulting
#' list can be imported into a reference manager such as Zotero to assemble a
#' bibliography.
#'
#' @param x A [scopus_records] tibble, or a character vector of DOIs.
#' @param dedupe Logical, dropping duplicate DOIs by default.
#' @param file Optional path at which to write the DOIs as a single-column CSV.
#'   A file is written only when this argument is supplied, and only to the exact
#'   path given, so the package always leaves the working directory untouched
#'   unless asked. Parent directories are assumed to exist already.
#' @return A character vector of cleaned DOIs, returned invisibly when `file` is
#'   written.
#' @details
#' Normalisation trims surrounding whitespace and strips common resolver
#' prefixes (`https://doi.org/`, `http://dx.doi.org/`, `doi:`) so that the same
#' article is counted once even when its DOI is formatted differently in two
#' records. Because DOIs are case-insensitive, comparison and deduplication
#' ignore case, while the output keeps the original casing.
#' @seealso [scopus_diff_dois()] to compare two retrievals.
#' @examples
#' # The bundled corpus of real articles stands in for a harvest of your own,
#' # since 'Scopus' records may not be redistributed.
#' dois <- scopus_extract_dois(example_records)
#' length(dois)
#' head(dois, 3)
#'
#' # Eleven of its 138 records arrived without a DOI, as records do, and so
#' # drop out of the list.
#' sum(is.na(example_records$doi))
#'
#' # The same cleaning applies to a bare vector, so a resolver prefix or a
#' # difference in case does not make one article look like two.
#' scopus_extract_dois(c("https://doi.org/10.1/A", "doi: 10.1/a", "10.2/B"))
#'
#' # Write to a temporary file (never the working directory).
#' path <- tempfile(fileext = ".csv")
#' scopus_extract_dois(example_records, file = path)
#' @export
scopus_extract_dois <- function(x, dedupe = TRUE, file = NULL) {
  dois <- scopus_as_doi_vector(x)
  dois <- scopus_clean_dois(dois)
  if (isTRUE(dedupe)) {
    dois <- dois[!duplicated(tolower(dois))]
  }
  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
      scopus_abort_bad_input(
        "`file` must be `NULL` or a single non-empty path."
      )
    }
    scopus_write_csv(data.frame(doi = dois), file)
    return(invisible(dois))
  }
  dois
}

#' Compare two DOI retrievals
#'
#' Identifies which DOIs were added, removed or unchanged between an earlier and
#' a later retrieval. This supports change tracking: re-running a search later
#' and seeing exactly what is new.
#'
#' A record without a DOI cannot be compared this way, and 'Scopus' gives no
#' DOI to a share of what it indexes, more of it in the arts and humanities and
#' among books and proceedings (Gorraiz et al., 2016). Such records are left out
#' of the rows and counted in the attributes `n_old_without_doi` and
#' `n_new_without_doi` and on the printed line. [scopus_diff_records()]
#' compares the records themselves, matching on the 'Scopus' identifier.
#'
#' @param old,new [scopus_records] objects or character vectors of DOIs,
#'   representing the earlier (`old`) and later (`new`) retrievals.
#' @return A tibble of class `scopus_doi_diff` with columns `doi` and `status`,
#'   where `status` is a factor with levels `"added"` (in `new` only),
#'   `"removed"` (in `old` only) and `"unchanged"` (in both). Rows are sorted by
#'   status then DOI, in byte order, so the order is the same under every
#'   locale and in the Python twin. The integer attributes `n_old_without_doi`
#'   and `n_new_without_doi` count the records (or vector elements) on each
#'   side that had no DOI and so were not compared. Printing shows the counts
#'   in each category, and those records where there are any.
#' @references
#' Gorraiz, J., Melero-Fuentes, D., Gumpenberger, C., & Valderrama-Zurián,
#' J.-C. (2016). Availability of digital object identifiers (DOIs) in Web of
#' Science and Scopus. *Journal of Informetrics*, *10*(1), 98–109.
#' \doi{10.1016/j.joi.2015.11.008}
#' @seealso [scopus_extract_dois()], [scopus_diff_records()]
#' @examples
#' # A baseline retrieval and the same search re-run a year later, both taken
#' # from the bundled corpus of real articles: the second pull has gained the
#' # 2024 records and lost the first one to re-indexing. Eleven records in each
#' # pull carry no DOI, and the printed line says so.
#' baseline <- example_records[example_records$year <= 2023, ]
#' later <- example_records[-1, ]
#' scopus_diff_dois(old = baseline, new = later)
#' @export
scopus_diff_dois <- function(old, new) {
  old_dois <- scopus_tidy_dois(scopus_as_doi_vector(old))
  new_dois <- scopus_tidy_dois(scopus_as_doi_vector(new))
  n_old_without <- sum(is.na(old_dois))
  n_new_without <- sum(is.na(new_dois))
  old_dois <- old_dois[!is.na(old_dois)]
  new_dois <- new_dois[!is.na(new_dois)]
  old_dois <- old_dois[!duplicated(tolower(old_dois))]
  new_dois <- new_dois[!duplicated(tolower(new_dois))]

  old_key <- tolower(old_dois)
  new_key <- tolower(new_dois)

  added <- new_dois[!new_key %in% old_key]
  removed <- old_dois[!old_key %in% new_key]
  unchanged <- new_dois[new_key %in% old_key]

  status <- factor(
    c(rep("added", length(added)),
      rep("removed", length(removed)),
      rep("unchanged", length(unchanged))),
    levels = c("added", "removed", "unchanged")
  )
  out <- tibble::tibble(doi = c(added, removed, unchanged), status = status)
  # Byte order, as the Python twin sorts. The default method follows the
  # locale's collation, under which an English locale puts "10.1016/j.cell"
  # before "10.1016/S0140".
  out <- out[order(out$status, out$doi, method = "radix"), , drop = FALSE]
  out <- tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_doi_diff")
  attr(out, "n_old_without_doi") <- n_old_without
  attr(out, "n_new_without_doi") <- n_new_without
  out
}

#' @export
print.scopus_doi_diff <- function(x, ...) {
  counts <- table(factor(x$status, levels = c("added", "removed", "unchanged")))
  untracked <- scopus_not_compared(
    attr(x, "n_old_without_doi"), attr(x, "n_new_without_doi"), "without a DOI"
  )
  scopus_print_line(
    "{.cls scopus_doi_diff} {counts[['added']]} added, ",
    "{counts[['removed']]} removed, {counts[['unchanged']]} unchanged{untracked}"
  )
  print(tibble::as_tibble(x), ...)
  invisible(x)
}

# The clause a diff's printed line ends with when records on either side could
# not be compared, such as ", 2 earlier and 1 later records without a DOI not
# compared", or "" when every record was compared. A diff built before the
# counts were recorded carries none and gets "".
scopus_not_compared <- function(n_old, n_new, lacking) {
  n_old <- if (is.null(n_old)) 0L else n_old
  n_new <- if (is.null(n_new)) 0L else n_new
  sides <- c(if (n_old > 0L) paste(n_old, "earlier"),
             if (n_new > 0L) paste(n_new, "later"))
  if (length(sides) == 0L) return("")
  noun <- if (n_old + n_new == 1L) "record" else "records"
  paste0(", ", paste(sides, collapse = " and "), " ", noun, " ", lacking,
         " not compared")
}

# Coerce accepted inputs to a character vector of DOIs.
scopus_as_doi_vector <- function(x) {
  if (is_scopus_records(x)) {
    return(x$doi)
  }
  if (is.data.frame(x) && "doi" %in% names(x)) {
    return(x$doi)
  }
  if (is.character(x)) {
    return(x)
  }
  scopus_abort_bad_input(
    "`x` must be a `scopus_records` object or a character vector of DOIs."
  )
}

# Trim whitespace, strip resolver prefixes, drop NA/empty.
scopus_clean_dois <- function(dois) {
  dois <- scopus_tidy_dois(dois)
  dois[!is.na(dois)]
}

# The cleaning of scopus_clean_dois(), one value per element, with NA for a DOI
# that is missing or empty once cleaned, so that the result lines up with the
# records (scopus_combine() keys each record on it). The resolver host and the
# `doi:` label are removed separately so that a space after either (as in
# "DOI: 10.1/x", common when DOIs are copied from a citation) does not survive.
scopus_tidy_dois <- function(dois) {
  dois <- trimws(as.character(dois))
  dois <- sub("^\\s*(https?://)?(www\\.)?(dx\\.)?doi\\.org/", "", dois, ignore.case = TRUE)
  dois <- sub("^\\s*doi:\\s*", "", dois, ignore.case = TRUE)
  dois <- trimws(dois)
  dois[!is.na(dois) & !nzchar(dois)] <- NA_character_
  dois
}
