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
#'   shown by `print()`. The time the counts were taken is attached as the
#'   `retrieved_at` attribute (a `POSIXct`), as a harvest records its own.
#'   'Scopus' goes on indexing a year's publications after the year has begun,
#'   so a count for the year of retrieval is a count so far, and
#'   [plot_scopus_trend()] says so from this time.
#' @section API access:
#' This performs one count request per year, so it requires a valid API key and
#' internet access; see the *API access* section of [scopus_count()].
#' @seealso [plot_scopus_trend()], [scopus_compare_topics()]
#' @examplesIf scopusflow::scopus_has_key()
#' tr <- scopus_trend('"graphene supercapacitor"', years = 2015:2024,
#'                    field = "TITLE-ABS-KEY")
#' tr
#' @examples
#' # The offline companion, which needs no key. 'Scopus' records may not be
#' # redistributed, so the package bundles a corpus of real articles instead.
#' # It is a complete harvest of OpenAlex's exact-phrase search for the same
#' # phrase, so tallying its rows by year gives the yearly counts of that
#' # search. A 'Scopus' count of the phrase would differ.
#' by_year <- table(example_records$year)
#' tr <- tibble::tibble(
#'   query = 'TITLE-ABS-KEY("graphene supercapacitor")',
#'   year = as.integer(names(by_year)),
#'   n = as.numeric(by_year)
#' )
#' class(tr) <- c("scopus_trend", class(tr))
#' tr
#' @export
scopus_trend <- function(query,
                         years,
                         field = NULL,
                         view = c("STANDARD", "COMPLETE"),
                         api_key = NULL,
                         inst_token = NULL,
                         verbose = FALSE) {
  view <- scopus_match_arg(view, c("STANDARD", "COMPLETE"))
  field <- scopus_check_field(field)
  scopus_check_query(query, field)
  years <- scopus_check_years(years)
  if (is.null(years)) {
    scopus_abort_bad_input("`years` must be supplied.")
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

  # Taken when the counting finished, as a harvest is dated when its records
  # are in. The incomplete-year note on the figure is read from this time,
  # never from the clock of the session that draws it.
  stamp <- Sys.time()

  if (anyNA(n)) {
    missing_years <- years[is.na(n)]
    n_missing <- length(missing_years)
    cli::cli_warn(
      "No count returned for {n_missing} year{?s} ({.val {missing_years}}); recorded as {.val NA}."
    )
  }

  out <- tibble::new_tibble(
    list(query = rep(wrapped, length(years)), year = as.integer(years), n = n),
    nrow = length(years), class = "scopus_trend"
  )
  attr(out, "retrieved_at") <- stamp
  out
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
#'   Author strings holding several names separated by `"; "` are split, so each
#'   contributor is counted once per record. Only a `view = "COMPLETE"`
#'   retrieval holds several names, since `STANDARD` records carry the first
#'   author alone (see [scopus_records()]). A tally by author of a set retrieved
#'   under `STANDARD` therefore counts first authorships, and says so with a
#'   warning of class `scopus_warning_first_author_only`, once per session.
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
#' # first authors. A harvest retrieved with view = "COMPLETE" lists every
#' # author, and the tally splits them.
#' scopus_top(example_records, by = "author", n = 5)
#' @export
scopus_top <- function(x, by = c("source", "author"), n = 10L) {
  if (!is_scopus_records(x)) {
    scopus_abort_bad_input(
      "`x` must be a `scopus_records` object."
    )
  }
  by <- scopus_match_arg(by, c("source", "author"))
  if (!is.numeric(n) || length(n) != 1L || !is.finite(n) || n < 1L ||
      n != floor(n)) {
    scopus_abort_bad_input(
      "`n` must be a single positive whole number."
    )
  }
  if (identical(by, "author")) {
    scopus_warn_first_author_only(x)
  }

  values <- switch(
    by,
    source = x$publication[!is.na(x$publication)],
    author = unlist(strsplit(x$authors[!is.na(x$authors)], "; ", fixed = TRUE),
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

# Annual record counts within a held set (used by autoplot.scopus_records).
# Every year the set's searches covered is counted, a year without records as
# zero, so an empty year shows as a zero bar. A year no cell searched is not
# added. The counts used to run from the first year in the records to the
# last, which drew a zero bar for each year that a plan such as c(2015, 2020)
# never searched. Without a plan, or with one that sent no year limit, the
# span of the records' own years stands in. A year that holds records keeps
# its row in every case, and a set in which no record has a year gives no
# rows. The Python twin's year_counts() follows the same rule, held to the
# shared fixture tests/testthat/fixtures/trend-years.json.
scopus_year_counts <- function(x) {
  years <- as.integer(x$year[!is.na(x$year)])
  if (length(years) == 0L) {
    return(tibble::tibble(year = integer(), n = integer()))
  }
  searched <- scopus_searched_years(x)
  span <- if (length(searched) == 0L) seq(min(years), max(years)) else searched
  span <- sort(unique(c(as.integer(span), years)))
  # table() over the factor counts every level. tabulate() would size its
  # result by the highest level present and drop trailing years without
  # records, which a plan's span can now end on.
  counts <- as.integer(table(factor(years, levels = span)))
  tibble::tibble(year = span, n = counts)
}

# The years a record set's searches covered, read from its plan's cells as the
# search record reads them (scopus_report_years()). That is each year cell's
# year, or every year of the range a single cell sent. A harvest stopped before
# its last cell searched only the cells it ran. Only the Python twin stops one,
# so the branch is dormant here, kept so that the twins count the same years
# from the same attributes. Empty without a plan, or with one that sent no
# year limit.
scopus_searched_years <- function(x) {
  plan <- attr(x, "plan")
  if (!is_scopus_plan(plan)) {
    return(integer())
  }
  stoppage <- scopus_report_stop(x, plan)
  cells <- scopus_report_cells(x, plan, joined = stoppage$joined)
  scopus_report_covered(cells[!(cells$cell %in% stoppage$not_run), , drop = FALSE])
}

# The note a record-count figure carries when the years it plots reach the
# year its counts were retrieved in. 'Scopus' is updated daily, so a count for
# the year of retrieval, or for a later year that an article in press already
# carries, was a count so far. A final point that drops is easily read as a
# decline. The year and the date are read in UTC from the recorded retrieval
# time, as the search record reads it. The clock of the session drawing the
# figure is never read, since it says nothing about when the counts were
# taken. NULL when nothing records the time or no plotted year reaches it. The
# Python twin words the note identically.
scopus_incomplete_note <- function(years, retrieved_at) {
  if (is.null(retrieved_at) || length(retrieved_at) == 0L) {
    return(NULL)
  }
  stamp <- min(as.POSIXct(retrieved_at))
  if (is.na(stamp)) {
    return(NULL)
  }
  year <- as.integer(format(stamp, "%Y", tz = "UTC"))
  late <- sort(unique(as.integer(years[!is.na(years) & years >= year])))
  if (length(late) == 0L) {
    return(NULL)
  }
  day <- format(stamp, "%Y-%m-%d", tz = "UTC")
  if (length(late) == 1L) {
    sprintf("%d was incomplete when retrieved on %s.", late, day)
  } else {
    sprintf("%d and later years were incomplete when retrieved on %s.", late[1L], day)
  }
}
