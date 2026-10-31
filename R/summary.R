#' Summarise a set of 'Scopus' records
#'
#' Gives a compact overview of a [scopus_records] object, reporting how many
#' records it holds, the span of publication years they cover, how many distinct
#' sources appear among them, how many records carry a Digital Object Identifier
#' and how widely they have been cited. It is a convenient way to take stock of
#' a retrieval before any closer analysis.
#'
#' @param object A [scopus_records] tibble.
#' @param ... Ignored, present for compatibility with the [summary()] generic.
#' @return A list of class `scopus_records_summary`, with elements `n_records`,
#'   `years` (the earliest and latest year present, each `NA` when no year is
#'   known), `n_sources` (the number of distinct source titles), `n_with_doi`
#'   (the number of records carrying a DOI, so that a DOI held by two records
#'   counts twice), `total_citations`, `median_citations`,
#'   `top_cited` (the title of the most-cited record), `top_source` (the most
#'   frequent source title) and `doc_types`. `doc_types` counts the records of
#'   each document-type code, most frequent first, for a set retrieved with
#'   `fields = "extended"` (see [scopus_records()]), and is `NULL` for a set
#'   without the `doc_type` column. Printing it produces a short readable
#'   report, which for such a set also says how many records 'Scopus' labels
#'   errata (`er`) or retracted (`tb`). The counts report the labels 'Scopus'
#'   assigns, which do not screen a set for retractions. The *Extended fields*
#'   section of [scopus_records()] explains why, and what to check a set
#'   against.
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
      },
      doc_types = if ("doc_type" %in% names(object)) {
        scopus_tally_doc_types(object$doc_type)
      }
    ),
    class = "scopus_records_summary"
  )
}

# How many records carry each document-type code, as a named integer vector,
# most frequent first. Ties are ordered by code in byte order, so the order
# does not depend on the locale. A record with no code is left out.
scopus_tally_doc_types <- function(codes) {
  codes <- codes[!is.na(codes)]
  if (length(codes) == 0L) {
    return(stats::setNames(integer(), character()))
  }
  counts <- table(codes)
  n <- as.integer(counts)
  values <- names(counts)
  ord <- order(-n, values, method = "radix")
  stats::setNames(n[ord], values[ord])
}

# The sentence summary() prints about the two labels a screening step acts on.
# The counts are of what 'Scopus' labels, and the wording says so.
scopus_label_counts <- function(doc_types) {
  n_er <- if ("er" %in% names(doc_types)) doc_types[["er"]] else 0L
  n_tb <- if ("tb" %in% names(doc_types)) doc_types[["tb"]] else 0L
  errata <- if (n_er == 1L) {
    "1 record an erratum (er)"
  } else {
    sprintf("%d records errata (er)", n_er)
  }
  sprintf("Scopus labels %s and %d retracted (tb).", errata, n_tb)
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
  scopus_print_line("{.cls scopus_records} summary")
  scopus_print_line("{x$n_records} record{?s}, {year_text}.")
  scopus_print_line(
    "{x$n_sources} source{?s}, {x$n_with_doi} with a DOI."
  )
  if (!is.na(x$total_citations)) {
    scopus_print_line(
      "Cited {x$total_citations} time{?s} in total, median {x$median_citations} per record."
    )
  }
  if (length(x$doc_types) > 0L) {
    # Joined here, since cli would put a comma before the last "and".
    types <- sprintf("%d %s", x$doc_types, names(x$doc_types))
    if (length(types) > 1L) {
      types <- paste(paste(types[-length(types)], collapse = ", "),
                     types[length(types)], sep = " and ")
    }
    scopus_print_line("Document types: {types}.")
    labels <- scopus_label_counts(x$doc_types)
    scopus_print_line("{labels}")
  }
  if (!is.na(x$top_source)) {
    scopus_print_line("Most frequent source: {x$top_source}.")
  }
  if (!is.na(x$top_cited)) {
    scopus_print_line("Most cited: {.emph {x$top_cited}}.")
  }
  invisible(x)
}
