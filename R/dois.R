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
      rlang::abort(
        "`file` must be `NULL` or a single non-empty path.",
        class = "scopus_error_bad_input"
      )
    }
    utils::write.csv(data.frame(doi = dois), file = file, row.names = FALSE)
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
#' @param old,new [scopus_records] objects or character vectors of DOIs,
#'   representing the earlier (`old`) and later (`new`) retrievals.
#' @return A tibble of class `scopus_doi_diff` with columns `doi` and `status`,
#'   where `status` is an ordered factor with levels `"added"` (in `new` only),
#'   `"removed"` (in `old` only) and `"unchanged"` (in both). Rows are sorted by
#'   status then DOI, and printing shows the counts in each category.
#' @seealso [scopus_extract_dois()]
#' @examples
#' # A baseline retrieval and the same search re-run a year later, both taken
#' # from the bundled corpus of real articles: the second pull has gained the
#' # 2024 records and lost the first one to re-indexing.
#' baseline <- example_records[example_records$year <= 2023, ]
#' later <- example_records[-1, ]
#' scopus_diff_dois(old = baseline, new = later)
#' @export
scopus_diff_dois <- function(old, new) {
  old_dois <- scopus_clean_dois(scopus_as_doi_vector(old))
  new_dois <- scopus_clean_dois(scopus_as_doi_vector(new))
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
  out <- out[order(out$status, out$doi), , drop = FALSE]
  tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_doi_diff")
}

#' @export
print.scopus_doi_diff <- function(x, ...) {
  counts <- table(factor(x$status, levels = c("added", "removed", "unchanged")))
  cli::cli_text(
    "{.cls scopus_doi_diff} {counts[['added']]} added, ",
    "{counts[['removed']]} removed, {counts[['unchanged']]} unchanged"
  )
  print(tibble::as_tibble(x), ...)
  invisible(x)
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
  rlang::abort(
    "`x` must be a `scopus_records` object or a character vector of DOIs.",
    class = "scopus_error_bad_input"
  )
}

# Trim whitespace, strip resolver prefixes, drop NA/empty. The resolver host and
# the `doi:` label are removed separately so that a space after either (as in
# "DOI: 10.1/x", common when DOIs are copied from a citation) does not survive.
scopus_clean_dois <- function(dois) {
  dois <- dois[!is.na(dois)]
  dois <- trimws(dois)
  dois <- sub("^\\s*(https?://)?(www\\.)?(dx\\.)?doi\\.org/", "", dois, ignore.case = TRUE)
  dois <- sub("^\\s*doi:\\s*", "", dois, ignore.case = TRUE)
  dois <- trimws(dois)
  dois[nzchar(dois)]
}
