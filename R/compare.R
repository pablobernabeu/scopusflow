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
#'   with the reference using a logical AND.
#' @param years Integer vector of publication years to span (for example
#'   `2015:2020`).
#' @param field Optional 'Scopus' field tag applied to every component of every
#'   query (see [scopus_plan()]).
#' @param view Either `"STANDARD"` or `"COMPLETE"`.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical; report progress when `TRUE`.
#' @return A tibble of class `scopus_comparison` with columns: `query` (the full
#'   query used), `query_type` (`"reference"` or `"comparison"`), `abridged_query`
#'   (the topic label for plotting), `year`, `n` (records that year),
#'   `reference_n` (reference records that year), `comparison_percentage`
#'   (`100 * n / reference_n`, or `NA` when `reference_n` is 0) and
#'   `average_comparison_percentage` (the same ratio computed on period totals).
#'   Comparison rows are sorted by descending average percentage.
#' @section API access:
#' Performs one count request per term per year and so requires a valid API key
#' and internet access; see the *API access* section of [scopus_count()]. Use a
#' modest number of terms and years to stay within quota.
#' @seealso [plot_scopus_comparison()] to visualise the result.
#' @examplesIf scopusflow::scopus_has_key()
#' cmp <- scopus_compare_topics(
#'   reference_query = "language learning",
#'   comparison_terms = c("effect size", "Bayesian"),
#'   years = 2015:2020,
#'   field = "TITLE-ABS-KEY"
#' )
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
      class = "scopus_error_bad_input"
    )
  }
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  if (is.null(years)) {
    rlang::abort("`years` must be supplied.", class = "scopus_error_bad_input")
  }
  years <- sort(unique(years))

  ref_wrapped <- scopus_wrap_field(reference_query, field)

  count_for <- function(query, year) {
    scopus_total_results(scopus_search_page(
      query = query, start = 0L, count = 1L, view = view,
      date = as.character(year), api_key = api_key, inst_token = inst_token
    ))
  }

  # Reference counts by year (denominator).
  if (verbose) cli::cli_inform("Counting reference query across {length(years)} year{?s}.")
  ref_n <- vapply(years, function(y) count_for(ref_wrapped, y), integer(1))
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
    cmp_n <- vapply(years, function(y) count_for(cmp_query, y), integer(1))
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

# Build the per-year rows for one query, computing percentages safely.
scopus_comparison_block <- function(query, query_type, abridged, years, n, ref_n) {
  pct <- ifelse(ref_n == 0, NA_real_, 100 * n / ref_n)
  total_n <- sum(n)
  total_ref <- sum(ref_n)
  avg <- if (total_ref == 0) NA_real_ else 100 * total_n / total_ref
  data.frame(
    query = query,
    query_type = query_type,
    abridged_query = abridged,
    year = as.integer(years),
    n = as.integer(n),
    reference_n = as.integer(ref_n),
    comparison_percentage = as.numeric(pct),
    average_comparison_percentage = as.numeric(avg),
    stringsAsFactors = FALSE
  )
}

#' @export
print.scopus_comparison <- function(x, ...) {
  cli::cli_text("{.cls scopus_comparison} ({length(unique(x$abridged_query))} topic{?s})")
  NextMethod()
  invisible(x)
}
