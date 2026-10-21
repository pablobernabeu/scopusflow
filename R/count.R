#' Count 'Scopus' results for a query
#'
#' Retrieves only the total number of records matching a query, without
#' downloading them. This is the inexpensive way to size a retrieval before
#' committing quota. The count can guide how to partition a [scopus_plan()], or
#' simply report how large a topic is.
#'
#' @param query Character scalar. The base search expression, checked offline
#'   before any request (see the *Query checks* section of [scopus_plan()]).
#' @param years Optional integer vector of publication years. [scopus_count()],
#'   [scopus_fetch()] and [scopus_intersections()] send one inclusive range from
#'   the earliest year to the latest, as a [scopus_plan()] with
#'   `partition = "none"` does, so `c(2015, 2020)` covers every year from 2015
#'   to 2020. [scopus_trend()], [scopus_compare_topics()] and a plan with
#'   `partition = "year"` take each listed year. An empty vector places no year
#'   restriction, as `NULL` does, where the years form a range, and is refused
#'   where each year is counted.
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
#'   totals are represented exactly, with no risk of overflow, and the parsed
#'   quota (see [scopus_quota()]) attached as the `quota` attribute so a workflow
#'   can pace itself off a count.
#' @section API access:
#' This function performs a network request and therefore requires a valid API
#' key and internet access. Every error it raises inherits from `scopus_error`,
#' so a [tryCatch()] around the call lets a workflow handle these gracefully.
#' When no key is configured, it raises `scopus_error_no_key`, and an invalid
#' argument raises `scopus_error_bad_input` before any request. A request the
#' API refuses raises the subclass for its HTTP status:
#' `scopus_error_bad_request` (400), `scopus_error_unauthorized` (401, a key
#' the API does not accept), `scopus_error_forbidden` (403),
#' `scopus_error_not_found` (404),
#' `scopus_error_payload_too_large` (413), `scopus_error_uri_too_long` (414),
#' `scopus_error_rate_limit` (429) or `scopus_error_server` (any other status),
#' with the status in `cnd$status` and the parsed quota (see [scopus_quota()])
#' in `cnd$quota`. A response that is not the JSON the API documents raises
#' `scopus_error_malformed`, and a host that cannot be reached raises
#' `scopus_error_offline`. Throttling (HTTP 429) and the server errors 500, 502,
#' 503 and 504 are retried with back-off first, and so are transport failures
#' such as a timeout or a reset connection. A spent weekly quota, which Elsevier
#' also answers with HTTP 429, is not retried: it raises
#' `scopus_error_quota_exceeded`, a subclass of `scopus_error_rate_limit` whose
#' message gives the reset time. When the last attempt at a request times out
#' after `getOption("scopusflow.timeout", 60)` seconds, the error is
#' `scopus_error_timeout`, a subclass of `scopus_error_offline`.
#' @examplesIf scopusflow::scopus_has_key()
#' scopus_count('"graphene supercapacitor"', years = 2015:2024,
#'              field = "TITLE-ABS-KEY")
#' @examples
#' # The offline companion, which needs no key: one number with the parsed
#' # quota attached. The bundled corpus of real articles is a complete harvest
#' # of OpenAlex's exact-phrase search for the same phrase, so its row count is
#' # the total of that search. A 'Scopus' count of the phrase would differ. The
#' # quota attribute is parsed from real response headers by scopus_quota(), so
#' # it cannot drift from what a live call attaches.
#' resp <- httr2::response(
#'   status_code = 200,
#'   headers = list(
#'     `X-RateLimit-Limit` = "20000",
#'     `X-RateLimit-Remaining` = "19987",
#'     `X-RateLimit-Reset` = "1700000000"
#'   )
#' )
#' n <- nrow(example_records)
#' attr(n, "quota") <- scopus_quota(resp)
#' n
#' @export
scopus_count <- function(query,
                         years = NULL,
                         field = NULL,
                         view = c("STANDARD", "COMPLETE"),
                         api_key = NULL,
                         inst_token = NULL) {
  view <- scopus_match_arg(view, c("STANDARD", "COMPLETE"))
  field <- scopus_check_field(field)
  scopus_check_query(query, field)
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
