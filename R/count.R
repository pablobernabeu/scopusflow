#' Count 'Scopus' results for a query
#'
#' Retrieves only the total number of records matching a query, without
#' downloading them. This is the cheap way to size a retrieval before committing
#' quota: feed the count into [scopus_plan()] partitioning decisions or simply
#' report how large a topic is.
#'
#' @param query Character scalar. The base search expression.
#' @param years Optional integer vector of publication years to restrict to.
#' @param field Optional 'Scopus' field tag to wrap the query in (see
#'   [scopus_plan()]).
#' @param view Either `"STANDARD"` or `"COMPLETE"`.
#' @param api_key,inst_token Optional credentials; by default resolved from
#'   options or environment variables (see [scopus_has_key()]).
#' @return A single integer: the total number of matching records, or `NA` if the
#'   API did not report a total.
#' @section API access:
#' This function performs a network request and therefore requires a valid API
#' key and internet access. When no key is configured it raises a
#' `scopus_error_no_key` condition; other failures raise typed `scopus_error`
#' subclasses (for example `scopus_error_rate_limit`). Wrap calls in
#' [tryCatch()] to handle these gracefully.
#' @examplesIf scopusflow::scopus_has_key()
#' scopus_count("CRISPR", years = 2015:2020, field = "TITLE-ABS-KEY")
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
  scopus_total_results(results)
}
