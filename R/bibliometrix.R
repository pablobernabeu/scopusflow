#' Convert records to a bibliometrix-compatible data frame
#'
#' Re-maps a [scopus_records] tibble to the tagged column layout used by the
#' \pkg{bibliometrix} package (and the wider ISI/Web of Science convention), so
#' results can flow into downstream science-mapping workflows.
#'
#' @param x A [scopus_records] tibble.
#' @return A data frame (classed `bibliometrixDB`) with the standard tag columns
#'   `AU` (authors), `TI` (title), `SO` (source/publication), `DI` (DOI), `PY`
#'   (publication year), `TC` (times cited), `UT` (record id) and `DB`
#'   (`"SCOPUS"`). Character tag fields are upper-cased, matching bibliometrix
#'   conventions.
#' @details
#' This produces the *shape* bibliometrix expects from its core descriptive
#' fields; it does not reconstruct fields the 'Scopus' Search API does not
#' return (such as full author affiliations or cited references), which some
#' bibliometrix analyses require. For those, export a full 'Scopus' CSV/BibTeX
#' from the web interface and use `bibliometrix::convert2df()`.
#' @examples
#' recs <- scopus_records(list(entry = list(
#'   list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
#'        `dc:title` = "A study", `dc:creator` = "Doe J.",
#'        `prism:publicationName` = "Journal", `prism:coverDate` = "2020-01-01",
#'        `citedby-count` = "3")
#' )))
#' as_bibliometrix(recs)
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
