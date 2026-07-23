#' Convert records to a bibliometrix-compatible data frame
#'
#' Re-maps a [scopus_records] tibble to the tagged column layout used by the
#' \pkg{bibliometrix} package (and the wider ISI/Web of Science convention), so
#' results can flow into downstream science-mapping workflows.
#'
#' @param x A [scopus_records] tibble.
#' @return A data frame (classed `bibliometrixDB`) with the standard tag columns
#'   `AU` (authors), `TI` (title), `SO` (source or publication), `DI` (DOI), `PY`
#'   (publication year), `TC` (times cited), `UT` (record id) and `DB`
#'   (`"SCOPUS"`). Character tag fields are upper-cased to match the bibliometrix
#'   convention.
#' @details
#' This produces the *shape* bibliometrix expects from the core descriptive
#' fields. It reconstructs only what the 'Scopus' Search API returns, so richer
#' fields that some bibliometrix analyses use, such as full author affiliations
#' or cited references, are left out. To obtain those, export a full 'Scopus'
#' CSV or BibTeX file from the web interface and read it with
#' `bibliometrix::convert2df()`.
#' @examples
#' # On the bundled corpus of real articles, which stands in for a retrieval
#' # of your own because 'Scopus' records may not be redistributed.
#' m <- as_bibliometrix(example_records)
#' head(m[, c("AU", "TI", "PY", "SO", "TC", "DB")])
#' @export
as_bibliometrix <- function(x) {
  if (!is_scopus_records(x)) {
    rlang::abort(
      "`x` must be a `scopus_records` object.",
      class = "scopus_error_bad_input"
    )
  }
  up <- function(v) toupper(as.character(v))
  out <- data.frame(
    AU = up(x$authors),
    TI = up(x$title),
    SO = up(x$publication),
    DI = x$doi,
    PY = x$year,
    TC = x$citations,
    UT = x$scopus_id,
    DB = "SCOPUS",
    stringsAsFactors = FALSE
  )
  class(out) <- c("bibliometrixDB", "data.frame")
  out
}
