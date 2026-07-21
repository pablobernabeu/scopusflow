#' Count 'Scopus' results for a query
#'
#' Retrieves only the total number of records matching a query, without
#' downloading them. This is the inexpensive way to size a retrieval before
#' committing quota. The count can guide how to partition a [scopus_plan()], or
#' simply report how large a topic is.
#'
#' @param query Character scalar. The base search expression.
#' @param years Optional integer vector of publication years to restrict to.
#' @param field Optional 'Scopus' field tag to wrap the query in (see
#'   [scopus_plan()]).
#' @param view Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` adds an
#'   `authkeywords` column to [scopus_fetch()]/[scopus_fetch_plan()] output (see
#'   [scopus_records()]) at no extra cost beyond `COMPLETE`'s own smaller page
#'   size, which already means more requests, and so more quota, for the same
#'   number of records.
#' @param api_key,inst_token Optional credentials, resolved by default from
#'   options or environment variables (see [scopus_has_key()]).
#' @return A single number giving the total number of matching records, or `NA`
#'   when the API reports no total. It is returned as a double so that very large
#'   totals are represented exactly rather than overflowing, with the parsed
#'   quota (see [scopus_quota()]) attached as the `quota` attribute so a workflow
#'   can pace itself off a count.
#' @section API access:
#' This function performs a network request and therefore requires a valid API
#' key and internet access. When no key is configured it raises a
#' `scopus_error_no_key` condition, and other failures raise typed `scopus_error`
#' subclasses such as `scopus_error_rate_limit`. A [tryCatch()] around the call
#' lets a workflow handle these gracefully.
#' @examplesIf scopusflow::scopus_has_key()
#' scopus_count("CRISPR", years = 2015:2020, field = "TITLE-ABS-KEY")
#' @examples
#' # The shape of the return value, built offline so it runs without a key.
#' # The quota attribute is parsed from real response headers by scopus_quota(),
#' # so it cannot drift from what a live call attaches.
#' resp <- httr2::response(
#'   status_code = 200,
#'   headers = list(
#'     `X-RateLimit-Limit` = "20000",
#'     `X-RateLimit-Remaining` = "19987",
#'     `X-RateLimit-Reset` = "1700000000"
#'   )
#' )
#' n <- 12483
#' attr(n, "quota") <- scopus_quota(resp)
#' n
#' @export
scopus_count <- function(query,
                         years = NULL,
                         field = NULL,
                         view = c("STANDARD", "COMPLETE"),
                         api_key = NULL,
                         inst_token = NULL) {
  view <- rlang::arg_match(view)
  scopus_check_query(query)
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)

  wrapped <- scopus_wrap_field(query, field)
  date <- if (is.null(years)) NULL else scopus_year_range(years)

  results <- scopus_search_page(
    query = wrapped,
    start = 0L,
    count = 1L,
    view = view,
    date = date,
    api_key = api_key,
    inst_token = inst_token
  )
  total <- scopus_total_results(results)
  attr(total, "quota") <- attr(results, "quota")
  total
}
