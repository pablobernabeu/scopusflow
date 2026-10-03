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
#'
#' `AU` holds every author only for a retrieval made with
#' `view = "COMPLETE"`. Under `STANDARD` the API sends the first author alone,
#' so each document would look single-authored to the collaboration measures
#' and co-authorship networks bibliometrix builds from `AU`. Converting a set
#' retrieved under `STANDARD` therefore raises a warning of class
#' `scopus_warning_first_author_only`, once per session (see
#' [scopus_records()]).
#' @examples
#' # On the bundled corpus of real articles, which stands in for a retrieval
#' # of your own because 'Scopus' records may not be redistributed.
#' m <- as_bibliometrix(example_records)
#' head(m[, c("AU", "TI", "PY", "SO", "TC", "DB")])
#' @export
as_bibliometrix <- function(x) {
  if (!is_scopus_records(x)) {
    scopus_abort_bad_input(
      "`x` must be a `scopus_records` object."
    )
  }
  scopus_warn_first_author_only(x)
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
