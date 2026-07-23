#' Summarise a set of 'Scopus' records
#'
#' Gives a compact overview of a [scopus_records] object, reporting how many
#' records it holds, the span of publication years they cover, how many distinct
#' sources and Digital Object Identifiers appear among them and how widely they
#' have been cited. It is a convenient way to take stock of a retrieval before
#' any closer analysis.
#'
#' @param object A [scopus_records] tibble.
#' @param ... Ignored, present for compatibility with the [summary()] generic.
#' @return A list of class `scopus_records_summary`, with elements `n_records`,
#'   `years` (the earliest and latest year present, each `NA` when no year is
#'   known), `n_sources`, `n_with_doi`, `total_citations`, `median_citations`,
#'   `top_cited` (the title of the most-cited record) and `top_source` (the most
#'   frequent source title). Printing it produces a short readable report.
#' @examples
#' # The bundled corpus of real articles stands in for a retrieval of your
#' # own, since 'Scopus' records may not be redistributed.
#' summary(example_records)
#' @export
summary.scopus_records <- function(object, ...) {
  years <- object$year[!is.na(object$year)]
  year_range <- if (length(years) == 0L) c(NA_integer_, NA_integer_) else {
    c(min(years), max(years))
  }
  citations <- object$citations[!is.na(object$citations)]
  sources <- object$publication[!is.na(object$publication)]

  structure(
    list(
      n_records = nrow(object),
      years = year_range,
      n_sources = length(unique(sources)),
      n_with_doi = sum(!is.na(object$doi)),
      total_citations = if (length(citations) == 0L) NA_integer_ else sum(citations),
      median_citations = if (length(citations) == 0L) NA_real_ else stats::median(citations),
      top_cited = if (length(citations) == 0L) NA_character_ else {
        object$title[which.max(object$citations)]
      },
      top_source = if (length(sources) == 0L) NA_character_ else {
        names(sort(table(sources), decreasing = TRUE))[1]
      }
    ),
    class = "scopus_records_summary"
  )
}

#' @export
print.scopus_records_summary <- function(x, ...) {
  year_text <- if (anyNA(x$years)) {
    "no publication years recorded"
  } else if (x$years[1] == x$years[2]) {
    sprintf("from %d", x$years[1])
  } else {
    sprintf("from %d to %d", x$years[1], x$years[2])
  }
  cli::cli_text("{.cls scopus_records} summary")
  cli::cli_text("{x$n_records} record{?s}, {year_text}.")
  cli::cli_text(
    "{x$n_sources} source{?s}, {x$n_with_doi} with a DOI."
  )
  if (!is.na(x$total_citations)) {
    cli::cli_text(
      "Cited {x$total_citations} time{?s} in total, median {x$median_citations} per record."
    )
  }
  if (!is.na(x$top_source)) {
    cli::cli_text("Most frequent source: {x$top_source}.")
  }
  if (!is.na(x$top_cited)) {
    cli::cli_text("Most cited: {.emph {x$top_cited}}.")
  }
  invisible(x)
}
