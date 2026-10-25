# HTTP layer ----------------------------------------------------------------
#
# scopusflow talks to the Elsevier Scopus Search API directly through httr2
# and never through rscopus. This gives request-level control over
# pagination, quota headers and retry with back-off, and, importantly, it makes
# offline testing possible through httr2::local_mocked_responses().

# scopusflow.base_url is an internal endpoint override, not meant for users.
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
  # query string, never sent as a bare, possibly malformed, parameter.
  absent <- vapply(params, function(v) {
    is.null(v) || (length(v) == 1L && !is.na(v) && identical(as.character(v), ""))
  }, logical(1))
  params <- params[!absent]
  req <- httr2::req_url_query(req, !!!params)
  scopus_req_timeout(req)
}

# curl's default transfer timeout is infinite, so a connection that opens and
# then stalls hangs the session outright: no response ever arrives for
# scopus_is_transient() to classify, so the retry in scopus_perform() never
# fires either. Worst under run_app(), where the harvest runs in a background
# process whose only recovery is the Cancel button. 60 seconds per request is
# generous against Elsevier's observed latencies, including a COMPLETE-view
# page; the option is there for a slower link or a tighter budget.
scopus_req_timeout <- function(req) {
  seconds <- suppressWarnings(as.numeric(getOption("scopusflow.timeout", 60)))
  if (length(seconds) != 1L || is.na(seconds) || seconds <= 0) {
    return(req)
  }
  httr2::req_timeout(req, seconds)
}

# Perform a request, retrying transient failures, and return the httr2 response.
#
# Non-2xx responses are turned into typed scopusflow conditions. Retry/back-off
# parameters are read from the options ?scopus_count documents, which tests also
# set to disable sleeping.
scopus_perform <- function(req, call = rlang::caller_env()) {
  req <- scopus_req_retry(req)

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

# The retry policy every request is performed under, built apart from
# scopus_perform() so a test can read it off the request: httr2's mocks bypass
# req_retry(), so the retry loop itself cannot run offline.
#
# retry_on_failure = TRUE retries a transport failure (a timeout, a reset
# connection) as well as a transient status. httr2 did so by default until
# 1.0.4, which made it opt-in, and from then on one such failure aborted a whole
# harvest. Every request here is an idempotent GET, so a retry is safe. The
# argument does not exist before httr2 1.0.4, hence the floor in DESCRIPTION.
#
# A single try (scopusflow.max_tries = 1) attaches no policy at all. httr2 reads
# max_tries = 1 as "do not retry" only from 1.1.0, while 1.0.4 to 1.0.7, which
# that floor admits, reject it as an invalid argument. A request without a
# policy is performed once under every httr2, which is what a single try means.
scopus_req_retry <- function(req) {
  max_tries <- getOption("scopusflow.max_tries", 3L)
  if (is.numeric(max_tries) && identical(as.numeric(max_tries), 1)) {
    return(req)
  }
  httr2::req_retry(
    req,
    max_tries = max_tries,
    retry_on_failure = TRUE,
    is_transient = scopus_is_transient,
    backoff = getOption("scopusflow.retry_backoff", NULL),
    after = function(resp) scopus_retry_after(resp)
  )
}

# Which responses should be retried: throttling (429) and transient 5xx. A 429
# that reports a spent weekly quota is not retried, since the quota resets only
# days later and every retry would be refused in the same way.
scopus_is_transient <- function(resp) {
  status <- httr2::resp_status(resp)
  status %in% c(500L, 502L, 503L, 504L) ||
    (status == 429L && !scopus_quota_exceeded(resp))
}

# Whether a response reports the key's weekly quota as spent. Elsevier answers
# both throttling and a spent quota with HTTP 429, and marks the second with
# X-ELS-Status "QUOTA_EXCEEDED - Quota Exceeded" (its API key settings page).
# The header is matched on its prefix, ignoring case, so a change to the text
# after it does not matter. A 429 without the header counts as throttling, as
# every 429 did before.
scopus_quota_exceeded <- function(resp) {
  if (!isTRUE(httr2::resp_status(resp) == 429L)) {
    return(FALSE)
  }
  status <- httr2::resp_header(resp, "X-ELS-Status")
  length(status) == 1L && startsWith(toupper(trimws(status)), "QUOTA_EXCEEDED")
}

# Number of seconds to wait before a retry, honouring Retry-After if present.
# The header may be a number of seconds or an HTTP date; both forms are
# supported.
scopus_retry_after <- function(resp) {
  ra <- httr2::resp_header(resp, "Retry-After")
  if (is.null(ra)) {
    return(NA_real_)
  }
  secs <- suppressWarnings(as.numeric(ra))
  if (!is.na(secs)) {
    return(secs)
  }
  when <- scopus_parse_http_date(ra)
  if (is.na(when)) {
    return(NA_real_)
  }
  max(0, as.numeric(difftime(when, Sys.time(), units = "secs")))
}

# Parse an HTTP date in the IMF-fixdate form RFC 9110 (section 5.6.7) requires
# senders to use, "Wed, 21 Oct 2037 07:28:00 GMT", into a UTC POSIXct, or NA.
# The month is looked up in a fixed English table. as.POSIXct() with %b reads
# month names in the session's LC_TIME, so it returned NA for every such date
# under a German or French locale. The two obsolete forms the RFC asks
# recipients to accept as well are left unparsed: Retry-After then falls back
# to the back-off schedule, as it does without the header.
scopus_parse_http_date <- function(x) {
  na <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  # Trimmed once, before matching: regmatches() must extract from the same
  # string regexec() matched, or a leading space shifts every field.
  x <- trimws(x)
  parts <- regmatches(x, regexec(
    "^[A-Za-z]{3}, ([0-9]{1,2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$",
    x
  ))[[1]]
  if (length(parts) != 7L) {
    return(na)
  }
  months <- c("jan", "feb", "mar", "apr", "may", "jun",
              "jul", "aug", "sep", "oct", "nov", "dec")
  month <- match(tolower(parts[3]), months)
  if (is.na(month)) {
    return(na)
  }
  n <- as.integer(parts[-(1:3)])
  # ISOdatetime() gives NA for an impossible date such as 31 February.
  ISOdatetime(n[1], month, as.integer(parts[2]), n[2], n[3], n[4], tz = "UTC")
}

#' Parse 'Scopus' quota and rate-limit headers
#'
#' Elsevier returns the caller's weekly quota and short-term rate-limit status in
#' response headers. `scopus_quota()` extracts them into a tidy list so a
#' workflow can pause, schedule or report on the remaining allowance.
#'
#' @param resp An [httr2::response] object, typically captured during a request.
#' @return A list with elements `limit`, `remaining`, `reset`, `status` and
#'   `retry_after` (seconds, or `NA`). `reset` is the `POSIXct` time, in UTC,
#'   at which the key's quota resets, read from `X-RateLimit-Reset` (epoch
#'   seconds, per Elsevier's API key settings page), or `NA`. A missing header
#'   yields `NA`.
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
    scopus_abort_bad_input(
      "`resp` must be an httr2 response object."
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
    cursor = cursor
  )
  req <- scopus_request(params, api_key = api_key, inst_token = inst_token, call = call)
  resp <- scopus_perform(req, call = call)
  # Parse with jsonlite directly, since httr2::resp_body_json only suggests
  # jsonlite, so the dependency is explicit and the structure is stable.
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
