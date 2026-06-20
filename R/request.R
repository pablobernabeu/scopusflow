# HTTP layer ----------------------------------------------------------------
#
# scopusflow talks to the Elsevier Scopus Search API directly through httr2
# rather than through rscopus. This gives request-level control over
# pagination, quota headers and retry with back-off, and, importantly, it makes
# offline testing possible through httr2::local_mocked_responses().

scopus_base_url <- function() {
  getOption("scopusflow.base_url", "https://api.elsevier.com/content/search/scopus")
}

scopus_user_agent <- function() {
  paste0("scopusflow/", utils::packageVersion("scopusflow"),
         " (https://github.com/pablobernabeu/scopusflow)")
}

# Build (but do not perform) a Scopus search request.
#
# `params` is a named list of query parameters (query, count, start, view, ...).
scopus_request <- function(params,
                           api_key = NULL,
                           inst_token = NULL,
                           call = rlang::caller_env()) {
  key <- scopus_key(api_key, call = call)
  token <- scopus_inst_token(inst_token)

  req <- httr2::request(scopus_base_url())
  req <- httr2::req_user_agent(req, scopus_user_agent())
  req <- httr2::req_headers(
    req,
    `X-ELS-APIKey` = key,
    Accept = "application/json",
    .redact = "X-ELS-APIKey"
  )
  if (!is.null(token)) {
    req <- httr2::req_headers(req, `X-ELS-Insttoken` = token, .redact = "X-ELS-Insttoken")
  }
  # Drop absent parameters (NULL or empty string) so they are omitted from the
  # query string rather than sent as a bare, possibly malformed, parameter.
  absent <- vapply(params, function(v) {
    is.null(v) || (length(v) == 1L && !is.na(v) && identical(as.character(v), ""))
  }, logical(1))
  params <- params[!absent]
  req <- httr2::req_url_query(req, !!!params)
  req
}

# Perform a request, retrying transient failures, and return the httr2 response.
#
# Non-2xx responses are turned into typed scopusflow conditions. Retry/back-off
# parameters are read from options so tests can disable sleeping.
scopus_perform <- function(req, call = rlang::caller_env()) {
  max_tries <- getOption("scopusflow.max_tries", 3L)
  backoff <- getOption("scopusflow.retry_backoff", NULL)

  req <- httr2::req_retry(
    req,
    max_tries = max_tries,
    is_transient = scopus_is_transient,
    backoff = backoff,
    after = function(resp) scopus_retry_after(resp)
  )

  # Let httr2 classify HTTP errors (so retry works), then re-raise them as
  # typed scopusflow conditions carrying the status and parsed quota.
  tryCatch(
    httr2::req_perform(req),
    httr2_http = function(cnd) {
      resp <- cnd$resp
      scopus_abort_status(httr2::resp_status(resp), resp = resp, call = call)
    },
    httr2_failure = function(cnd) scopus_abort_offline(parent = cnd, call = call)
  )
}

# Which responses should be retried: rate limiting (429) and transient 5xx.
scopus_is_transient <- function(resp) {
  httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
}

# Number of seconds to wait before a retry, honouring Retry-After if present.
# The header may be a number of seconds or an HTTP date (RFC 7231); both forms
# are supported.
scopus_retry_after <- function(resp) {
  ra <- httr2::resp_header(resp, "Retry-After")
  if (is.null(ra)) {
    return(NA_real_)
  }
  secs <- suppressWarnings(as.numeric(ra))
  if (!is.na(secs)) {
    return(secs)
  }
  when <- suppressWarnings(
    as.POSIXct(ra, format = "%a, %d %b %Y %H:%M:%S", tz = "GMT")
  )
  if (is.na(when)) {
    return(NA_real_)
  }
  max(0, as.numeric(difftime(when, Sys.time(), units = "secs")))
}

#' Parse 'Scopus' quota and rate-limit headers
#'
#' Elsevier returns the caller's weekly quota and short-term rate-limit status in
#' response headers. `scopus_quota()` extracts them into a tidy list so a
#' workflow can pause, schedule or report on the remaining allowance.
#'
#' @param resp An [httr2::response] object, typically captured during a request.
#' @return A list with elements `limit`, `remaining`, `reset` (a `POSIXct` time
#'   at which the rate-limit window resets, or `NA`), `status` and `retry_after`
#'   (seconds, or `NA`). A missing header yields `NA`.
#' @details
#' The relevant headers are `X-RateLimit-Limit`, `X-RateLimit-Remaining`,
#' `X-RateLimit-Reset` (epoch seconds), `X-ELS-Status` and `Retry-After`. When
#' the API raises a quota or rate-limit error, the parsed quota is also attached
#' to the resulting condition, where it is available as `cnd$quota`.
#' @examples
#' # Build a fake response to show the shape of the output (no network used).
#' resp <- httr2::response(
#'   status_code = 200,
#'   headers = list(
#'     `X-RateLimit-Limit` = "20000",
#'     `X-RateLimit-Remaining` = "19987",
#'     `X-RateLimit-Reset` = "1700000000"
#'   )
#' )
#' scopus_quota(resp)
#' @export
scopus_quota <- function(resp) {
  if (!inherits(resp, "httr2_response")) {
    rlang::abort(
      "`resp` must be an httr2 response object.",
      class = "scopus_error_bad_input"
    )
  }
  get_num <- function(name) {
    val <- httr2::resp_header(resp, name)
    if (is.null(val)) NA_real_ else suppressWarnings(as.numeric(val))
  }
  reset_raw <- get_num("X-RateLimit-Reset")
  reset <- if (is.na(reset_raw)) {
    as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  } else {
    as.POSIXct(reset_raw, origin = "1970-01-01", tz = "UTC")
  }
  list(
    limit = get_num("X-RateLimit-Limit"),
    remaining = get_num("X-RateLimit-Remaining"),
    reset = reset,
    status = httr2::resp_header(resp, "X-ELS-Status") %||% NA_character_,
    retry_after = scopus_retry_after(resp)
  )
}

# Perform one search page and return the parsed `search-results` list.
scopus_search_page <- function(query,
                               start = 0L,
                               count = 25L,
                               view = "STANDARD",
                               date = NULL,
                               field = NULL,
                               cursor = NULL,
                               api_key = NULL,
                               inst_token = NULL,
                               call = rlang::caller_env()) {
  # Offset and cursor paging are mutually exclusive: with a cursor, `start` is
  # omitted and the API returns the next cursor in the response.
  params <- list(
    query = query,
    start = if (is.null(cursor)) format(as.integer(start), scientific = FALSE) else NULL,
    count = format(as.integer(count), scientific = FALSE),
    view = view,
    date = date,
    field = field,
    cursor = cursor
  )
  req <- scopus_request(params, api_key = api_key, inst_token = inst_token, call = call)
  resp <- scopus_perform(req, call = call)
  # Parse with jsonlite directly (rather than httr2::resp_body_json, which only
  # suggests jsonlite) so the dependency is explicit and the structure is stable.
  body <- tryCatch(
    jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE),
    error = function(e) {
      rlang::abort(
        "The 'Scopus' API response was not valid JSON.",
        class = c("scopus_error_malformed", "scopus_error"),
        parent = e, call = call
      )
    }
  )
  results <- body[["search-results"]]
  if (is.null(results)) {
    rlang::abort(
      "The 'Scopus' API response did not contain a `search-results` element.",
      class = c("scopus_error_malformed", "scopus_error")
    )
  }
  attr(results, "quota") <- scopus_quota(resp)
  results
}

# Total number of results reported for the most recent page. Returned as a
# double so that very large totals (Scopus can report billions for broad
# queries) survive without integer overflow to NA.
scopus_total_results <- function(results) {
  total <- results[["opensearch:totalResults"]]
  if (is.null(total)) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(total))
}
