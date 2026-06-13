#' Extract, clean and optionally export DOIs
#'
#' Pulls Digital Object Identifiers from a [scopus_records] object (or a bare
#' character vector), normalises them and removes missing values. The resulting
#' list can be imported into a reference manager such as Zotero to assemble a
#' bibliography.
#'
#' @param x A [scopus_records] tibble, or a character vector of DOIs.
#' @param dedupe Logical; drop duplicate DOIs (default `TRUE`).
#' @param file Optional path to write the DOIs to as a single-column CSV. The
#'   file is written **only** when this is supplied, and only to the exact path
#'   given - the package never writes implicitly. Parent directories are not
#'   created.
#' @return A character vector of cleaned DOIs (invisibly when `file` is written).
#' @details
#' Normalisation trims surrounding whitespace and strips common resolver
#' prefixes (`https://doi.org/`, `http://dx.doi.org/`, `doi:`) so that the same
#' article is not counted twice because of formatting differences. Comparison and
#' deduplication are case-insensitive (DOIs are case-insensitive), but the
#' original casing is preserved in the output.
#' @seealso [scopus_diff_dois()] to compare two retrievals.
#' @examples
#' recs <- scopus_records(list(entry = list(
#'   list(`prism:doi` = "10.1/AAA"),
#'   list(`prism:doi` = "https://doi.org/10.1/aaa"),
#'   list(`prism:doi` = NULL)
#' )))
#' scopus_extract_dois(recs)
#'
#' # Write to a temporary file (never the working directory).
#' path <- tempfile(fileext = ".csv")
#' scopus_extract_dois(recs, file = path)
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
#' @return A tibble with columns `doi` and `status`, where `status` is one of
#'   `"added"` (in `new` only), `"removed"` (in `old` only) or `"unchanged"` (in
#'   both), sorted by status then DOI.
#' @seealso [scopus_extract_dois()]
#' @examples
#' old <- c("10.1/a", "10.1/b")
#' new <- c("10.1/b", "10.1/c")
#' scopus_diff_dois(old, new)
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

  out <- tibble::tibble(
    doi = c(added, removed, unchanged),
    status = c(
      rep("added", length(added)),
      rep("removed", length(removed)),
      rep("unchanged", length(unchanged))
    )
  )
  out[order(out$status, out$doi), ]
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

# Trim whitespace, strip resolver prefixes, drop NA/empty.
scopus_clean_dois <- function(dois) {
  dois <- dois[!is.na(dois)]
  dois <- trimws(dois)
  dois <- sub("^(https?://(dx\\.)?doi\\.org/|doi:)", "", dois, ignore.case = TRUE)
  dois[nzchar(dois)]
}
