#' Compare publication trends across topics
#'
#' Compares how often a set of *comparison* topics co-occur with a *reference*
#' topic over time. For each year and each comparison term, the number of records
#' matching the reference combined with that term is expressed as a percentage of
#' the records matching the reference alone. This reveals which sub-topics are
#' growing or shrinking within a literature.
#'
#' @param reference_query Character scalar. The reference topic that anchors the
#'   comparison (for example `"language learning"`).
#' @param comparison_terms Character vector of topics to compare against the
#'   reference (for example `c("effect size", "Bayesian")`). Each is combined
#'   with the reference using a logical AND. A term repeated in the vector is
#'   counted once, with a warning.
#' @param years Integer vector of publication years to span (for example
#'   `2015:2020`).
#' @param field Optional 'Scopus' field tag applied to every component of every
#'   query (see [scopus_plan()]).
#' @param view Either `"STANDARD"` or `"COMPLETE"`.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble of class `scopus_comparison` with the columns `query` (the
#'   full query used), `query_type` (`"reference"` or `"comparison"`),
#'   `abridged_query` (the topic label for plotting), `year`, `n` (records that
#'   year, as a double so very large counts are exact), `reference_n` (reference
#'   records that year, likewise a double), `comparison_percentage`
#'   (`100 * n / reference_n`, or `NA` when `reference_n` is 0) and
#'   `average_comparison_percentage` (the same ratio computed on period totals,
#'   over the years where both counts are available). Comparison rows are sorted
#'   by descending average percentage.
#' @section API access:
#' This performs one count request per term per year, plus one per year for the
#' reference topic, so it requires a valid API key and internet access. The
#' *API access* section of [scopus_count()] gives the details. A modest number
#' of terms and years keeps the call within quota.
#' @seealso [plot_scopus_comparison()] to visualise the result.
#' @examplesIf scopusflow::scopus_has_key()
#' cmp <- scopus_compare_topics(
#'   reference_query = "deep learning",
#'   comparison_terms = c("computer vision", "drug discovery"),
#'   years = 2018:2022,
#'   field = "TITLE-ABS-KEY"
#' )
#' cmp
#' @examples
#' # The shape of the return value, built offline so it runs without a key.
#' years <- 2018:2022
#' ref_n <- c(4200, 5600, 7100, 8600, 10200)
#' counts <- list(`computer vision` = c(1500, 2000, 2500, 3000, 3600),
#'                `drug discovery`  = c(180, 260, 370, 500, 660))
#' cmp <- tibble::tibble(
#'   query = "TITLE-ABS-KEY(deep learning)",
#'   query_type = c(rep("reference", length(years)),
#'                  rep("comparison", length(counts) * length(years))),
#'   abridged_query = c(rep("deep learning", length(years)),
#'                      rep(names(counts), each = length(years))),
#'   year = rep(years, length(counts) + 1),
#'   n = c(ref_n, unlist(counts, use.names = FALSE)),
#'   reference_n = rep(ref_n, length(counts) + 1),
#'   comparison_percentage = 100 * c(ref_n, unlist(counts, use.names = FALSE)) /
#'     rep(ref_n, length(counts) + 1),
#'   average_comparison_percentage = c(rep(100, length(years)),
#'                                     rep(c(35.3, 5.4), each = length(years)))
#' )
#' class(cmp) <- c("scopus_comparison", class(cmp))
#' cmp
#' @export
scopus_compare_topics <- function(reference_query,
                                  comparison_terms,
                                  years,
                                  field = NULL,
                                  view = c("STANDARD", "COMPLETE"),
                                  api_key = NULL,
                                  inst_token = NULL,
                                  verbose = FALSE) {
  view <- rlang::arg_match(view)
  scopus_check_query(reference_query)
  if (!is.character(comparison_terms) || length(comparison_terms) == 0L ||
      anyNA(comparison_terms) || !all(nzchar(trimws(comparison_terms)))) {
    rlang::abort(
      "`comparison_terms` must be a non-empty character vector of non-empty terms.",
      class = c("scopus_error_bad_input", "scopus_error")
    )
  }
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  scopus_check_flag(verbose, "verbose")
  if (is.null(years)) {
    rlang::abort("`years` must be supplied.", class = c("scopus_error_bad_input", "scopus_error"))
  }
  years <- sort(unique(years))

  # A repeated term would spend a second full set of count requests against the
  # weekly quota and come back as a second identical block, which the plot then
  # draws as overlapping lines under one legend entry.
  repeated <- unique(comparison_terms[duplicated(comparison_terms)])
  if (length(repeated) > 0L) {
    cli::cli_warn(
      "Counting {length(repeated)} repeated comparison term{?s} once: {.val {repeated}}.",
      class = "scopus_warning_duplicate_terms"
    )
    comparison_terms <- unique(comparison_terms)
  }

  ref_wrapped <- scopus_wrap_field(reference_query, field)

  count_for <- function(query, year) {
    scopus_total_results(scopus_search_page(
      query = query, start = 0L, count = 1L, view = view,
      date = as.character(year), api_key = api_key, inst_token = inst_token
    ))
  }

  # Reference counts by year (denominator). Counts are doubles so that a missing
  # total arrives as NA, where a type error would stop the comparison.
  if (verbose) cli::cli_inform("Counting reference query across {length(years)} year{?s}.")
  ref_n <- vapply(years, function(y) count_for(ref_wrapped, y), numeric(1))
  names(ref_n) <- as.character(years)

  rows <- list()
  rows[[1]] <- scopus_comparison_block(
    query = ref_wrapped, query_type = "reference",
    abridged = reference_query, years = years, n = ref_n, ref_n = ref_n
  )

  for (term in comparison_terms) {
    if (verbose) cli::cli_inform("Counting comparison term {.val {term}}.")
    term_wrapped <- scopus_wrap_field(term, field)
    cmp_query <- paste(ref_wrapped, "AND", term_wrapped)
    cmp_n <- vapply(years, function(y) count_for(cmp_query, y), numeric(1))
    rows[[length(rows) + 1L]] <- scopus_comparison_block(
      query = cmp_query, query_type = "comparison",
      abridged = term, years = years, n = cmp_n, ref_n = ref_n
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL

  # Sort comparison terms by descending average percentage; reference first.
  ord <- order(
    out$query_type != "reference",
    -out$average_comparison_percentage,
    out$abridged_query,
    out$year
  )
  out <- out[ord, ]
  rownames(out) <- NULL
  tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_comparison")
}

# Build the per-year rows for one query, computing percentages safely. A year
# whose reference count is zero (or whose count is unavailable) yields NA for
# that year, and the average rests on the years that are available.
scopus_comparison_block <- function(query, query_type, abridged, years, n, ref_n) {
  pct <- ifelse(is.na(ref_n) | ref_n == 0, NA_real_, 100 * n / ref_n)
  # Both totals are taken over the same years. Summing the numerator over years
  # the denominator drops would inflate the average above every per-year share
  # in the same tibble, and that average also orders the topics in the plot.
  ok <- !is.na(n) & !is.na(ref_n)
  total_n <- sum(n[ok])
  total_ref <- sum(ref_n[ok])
  avg <- if (!any(ok) || total_ref == 0) NA_real_ else 100 * total_n / total_ref
  data.frame(
    query = query,
    query_type = query_type,
    abridged_query = abridged,
    year = as.integer(years),
    # Doubles, as scopus_total_results(), scopus_trend() and
    # scopus_intersections() all carry their counts: a broad query can report
    # billions of matches, which a 32-bit integer would turn into NA while
    # leaving the percentage beside it populated.
    n = as.numeric(n),
    reference_n = as.numeric(ref_n),
    comparison_percentage = as.numeric(pct),
    average_comparison_percentage = as.numeric(avg),
    stringsAsFactors = FALSE
  )
}

#' @export
print.scopus_comparison <- function(x, ...) {
  scopus_print_line(
    "{.cls scopus_comparison} ({length(unique(x$abridged_query))} topic{?s})"
  )
  NextMethod()
  invisible(x)
}
