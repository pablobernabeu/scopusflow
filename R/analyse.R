#' Annual publication counts for a query
#'
#' Counts how many records match a query in each year, giving the size of a
#' literature over time. It is the single-query companion to
#' [scopus_compare_topics()]: where the comparison shows topics as a share of a
#' reference, this shows the absolute count.
#'
#' @inheritParams scopus_count
#' @param years Integer vector of publication years to count over, for example
#'   `2010:2020`.
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble of class `scopus_trend` with columns `query` (the
#'   field-wrapped query), `year` (integer) and `n` (the count that year, as a
#'   double so very large counts are exact). A year whose response omits a total
#'   is recorded as `NA` (with a warning) and contributes nothing to the total
#'   shown by `print()`.
#' @section API access:
#' This performs one count request per year, so it requires a valid API key and
#' internet access; see the *API access* section of [scopus_count()].
#' @seealso [plot_scopus_trend()], [scopus_compare_topics()],
#'   [scopus_year_counts()] for the same table tallied from records in hand
#' @examplesIf scopusflow::scopus_has_key()
#' tr <- scopus_trend("graphene supercapacitor", years = 2015:2024,
#'                    field = "TITLE-ABS-KEY")
#' tr
#' @examples
#' # The offline companion, which needs no key. 'Scopus' records may not be
#' # redistributed, so the package bundles a corpus of real articles instead;
#' # it is a complete harvest of its own query, so tallying its rows by year
#' # reproduces the yearly counts that query returns.
#' scopus_year_counts(example_records,
#'                    query = "TITLE-ABS-KEY(graphene supercapacitor)")
#' @export
scopus_trend <- function(query,
                         years,
                         field = NULL,
                         view = c("STANDARD", "COMPLETE"),
                         api_key = NULL,
                         inst_token = NULL,
                         verbose = FALSE) {
  view <- rlang::arg_match(view)
  scopus_check_query(query)
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  scopus_check_flag(verbose, "verbose")
  if (is.null(years)) {
    rlang::abort("`years` must be supplied.", class = c("scopus_error_bad_input", "scopus_error"))
  }
  years <- sort(unique(years))
  wrapped <- scopus_wrap_field(query, field)

  if (verbose) cli::cli_inform("Counting across {length(years)} year{?s}.")
  n <- vapply(years, function(y) {
    scopus_total_results(scopus_search_page(
      query = wrapped, start = 0L, count = 1L, view = view,
      date = as.character(y), api_key = api_key, inst_token = inst_token
    ))
  }, numeric(1))

  if (anyNA(n)) {
    missing_years <- years[is.na(n)]
    n_missing <- length(missing_years)
    cli::cli_warn(
      "No count returned for {n_missing} year{?s} ({.val {missing_years}}); recorded as {.val NA}."
    )
  }

  tibble::new_tibble(
    list(query = rep(wrapped, length(years)), year = as.integer(years), n = n),
    nrow = length(years), class = "scopus_trend"
  )
}

#' @export
print.scopus_trend <- function(x, ...) {
  total <- sum(x$n, na.rm = TRUE)
  scopus_print_line(
    "{.cls scopus_trend} ({nrow(x)} year{?s}, {format(total, big.mark = ',')} records)"
  )
  NextMethod()
  invisible(x)
}

#' Most frequent values in a record set
#'
#' Tallies the most common sources or authors across a [scopus_records] object.
#' It works on records already in memory, so it makes no network request.
#'
#' @param x A [scopus_records] tibble.
#' @param by What to tally: `"source"` (the publication titles) or `"author"`.
#'   Author strings holding several names are split on the semicolon, with or
#'   without a following space, so each contributor is counted once per record.
#' @param n The number of rows to return (the top `n`).
#' @return A tibble of class `scopus_top` with columns `value` and `n`, sorted by
#'   descending count, with ties broken by `value` in byte order so the result is
#'   reproducible across platforms and locales. Exactly `n` rows are returned
#'   (fewer if there are fewer distinct values), so values tied at the cut-off
#'   rank may be dropped. The `by` choice is stored in the `by` attribute.
#' @seealso [plot_scopus_top()], [summary.scopus_records()]
#' @examples
#' # The bundled corpus of real articles stands in for a harvest of your own,
#' # since 'Scopus' records may not be redistributed.
#' scopus_top(example_records, by = "source")
#'
#' # That corpus names one author per article, so the author tally counts
#' # first authors; a live harvest lists every author and splits them.
#' scopus_top(example_records, by = "author", n = 5)
#' @export
scopus_top <- function(x, by = c("source", "author"), n = 10L) {
  if (!is_scopus_records(x)) {
    rlang::abort(
      "`x` must be a `scopus_records` object.",
      class = c("scopus_error_bad_input", "scopus_error")
    )
  }
  by <- rlang::arg_match(by)
  if (!is.numeric(n) || length(n) != 1L || !is.finite(n) || n < 1L ||
      n != floor(n)) {
    rlang::abort(
      "`n` must be a single positive whole number.",
      class = c("scopus_error_bad_input", "scopus_error")
    )
  }

  values <- switch(
    by,
    source = x$publication[!is.na(x$publication)],
    # Split on the bare semicolon, not "; ": the Python twin joins author names
    # without the space, and a set written there is read back here.
    author = unlist(strsplit(x$authors[!is.na(x$authors)], ";", fixed = TRUE),
                    use.names = FALSE)
  )
  values <- trimws(values)
  values <- values[nzchar(values)]

  if (length(values) == 0L) {
    out <- tibble::tibble(value = character(), n = integer())
  } else {
    tab <- table(values)
    out <- tibble::tibble(value = names(tab), n = as.integer(tab))
    # Order by descending count, breaking ties by value in C-locale byte order
    # (method = "radix") so the truncated top-n is identical on every platform.
    out <- out[order(-out$n, out$value, method = "radix"), , drop = FALSE]
    # `n` stays a double here. The validator above accepts any finite whole
    # number, so as.integer() would turn anything past 2^31 into NA and leave
    # head() raising an untyped base error about its own argument. head()
    # accepts a double without complaint, and a cut above nrow() is a no-op.
    out <- utils::head(out, n)
  }
  structure(
    tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_top"),
    by = by
  )
}

# Annual record counts over the whole span a held set covers, gap years
# included as zero (used by autoplot.scopus_records, where a missing bar would
# otherwise close the gap and shorten the axis). scopus_year_counts() reports
# the years present, as scopus_trend() and the Python twin do.
scopus_year_span <- function(x) {
  years <- x$year[!is.na(x$year)]
  if (length(years) == 0L) {
    return(tibble::tibble(year = integer(), n = integer()))
  }
  span <- seq(min(years), max(years))
  counts <- tabulate(factor(years, levels = span))
  tibble::tibble(year = as.integer(span), n = as.integer(counts))
}

#' Tally the records of a harvest by year
#'
#' Counts the records of a set already in hand by publication year, in the
#' shape [scopus_trend()] returns. A complete harvest holds its own annual
#' counts, so this gives the trend of that query without spending a request.
#'
#' @param x A [scopus_records] object.
#' @param query Optional string naming the query the records answer, recorded
#'   in the `query` column. Records do not carry the query they came from, so
#'   it is `NA` unless supplied.
#' @return A tibble of class `scopus_trend` with the columns `query`, `year`
#'   (integer) and `n` (the count that year, as a double, matching
#'   [scopus_trend()]). Records with no year are dropped, and a year no record
#'   falls in is absent rather than zero, since a harvest says nothing about a
#'   year it does not cover.
#' @seealso [scopus_trend()] for the same table counted through the API, and
#'   [plot_scopus_trend()] to draw either.
#' @examples
#' # The bundled corpus of real articles is a complete harvest of its own
#' # query, so its rows per year are the publications per year that query
#' # returns.
#' scopus_year_counts(example_records,
#'                    query = "TITLE-ABS-KEY(graphene supercapacitor)")
#' @export
scopus_year_counts <- function(x, query = NA_character_) {
  if (!is_scopus_records(x)) {
    rlang::abort("`x` must be a `scopus_records` object.",
                 class = c("scopus_error_bad_input", "scopus_error"))
  }
  if (!is.character(query) || length(query) != 1L) {
    rlang::abort("`query` must be a single string, or `NA`.",
                 class = c("scopus_error_bad_input", "scopus_error"))
  }
  counts <- table(x$year[!is.na(x$year)])
  tibble::new_tibble(
    list(
      query = rep(as.character(query), length(counts)),
      year = as.integer(names(counts)),
      n = as.numeric(counts)
    ),
    nrow = length(counts), class = "scopus_trend"
  )
}
