# Each HTTP status maps to a specific typed condition.
status_cases <- list(
  list(code = 400L, class = "scopus_error_bad_request"),
  list(code = 401L, class = "scopus_error_unauthorized"),
  list(code = 403L, class = "scopus_error_forbidden"),
  list(code = 404L, class = "scopus_error_not_found"),
  list(code = 413L, class = "scopus_error_payload_too_large"),
  list(code = 414L, class = "scopus_error_uri_too_long")
)

for (case in status_cases) {
  test_that(sprintf("HTTP %d maps to %s", case$code, case$class), {
    local_scopus_test_env()
    httr2::local_mocked_responses(function(req) {
      mock_json_response(list(`service-error` = list()), status = case$code)
    })
    expect_error(scopus_count("x"), class = case$class)
    expect_error(scopus_count("x"), class = "scopus_error")
  })
}

# Note: httr2's local_mocked_responses() intentionally bypasses req_retry(), so
# the full retry-then-succeed loop cannot be exercised offline. We instead unit
# test the retry decision logic directly.
test_that("transient statuses are classified for retry", {
  is_transient <- scopusflow:::scopus_is_transient
  for (s in c(429L, 500L, 502L, 503L, 504L)) {
    expect_true(is_transient(httr2::response(s)), info = paste("status", s))
  }
  for (s in c(200L, 400L, 401L, 403L, 404L, 413L, 414L)) {
    expect_false(is_transient(httr2::response(s)), info = paste("status", s))
  }
})

# Elsevier answers both throttling and a spent weekly quota with HTTP 429, and
# marks the second with X-ELS-Status "QUOTA_EXCEEDED - Quota Exceeded" and the
# reset time in X-RateLimit-Reset (its API key settings page).
quota_exceeded_headers <- function(status = "QUOTA_EXCEEDED - Quota Exceeded") {
  list(
    `X-ELS-Status` = status,
    `X-RateLimit-Limit` = "20000",
    `X-RateLimit-Remaining` = "0",
    `X-RateLimit-Reset` = "1700000000"  # 2023-11-14 22:13:20 UTC
  )
}

test_that("a 429 marked QUOTA_EXCEEDED is not transient, and a plain 429 still is", {
  is_transient <- scopusflow:::scopus_is_transient
  exceeded <- scopusflow:::scopus_quota_exceeded
  spent <- httr2::response(429L, headers = quota_exceeded_headers())
  expect_true(exceeded(spent))
  expect_false(is_transient(spent))
  # The header is matched on its prefix, whatever its case.
  lower <- httr2::response(429L, headers = quota_exceeded_headers("quota_exceeded"))
  expect_true(exceeded(lower))
  expect_false(is_transient(lower))
  # Throttling, or a 429 without the header, keeps the old behaviour.
  throttled <- httr2::response(429L, headers = list(`X-ELS-Status` = "OK"))
  expect_false(exceeded(throttled))
  expect_true(is_transient(throttled))
  expect_true(is_transient(httr2::response(429L)))
  # The header means nothing on another status.
  expect_false(exceeded(httr2::response(200L, headers = quota_exceeded_headers())))
})

test_that("a spent quota raises scopus_error_quota_exceeded naming the reset", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(), status = 429L, headers = quota_exceeded_headers())
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_quota_exceeded")
  # A subclass of the rate-limit condition, so existing handlers still catch it.
  expect_s3_class(cnd, "scopus_error_rate_limit")
  expect_s3_class(cnd, "scopus_error")
  expect_match(conditionMessage(cnd), "weekly quota is used up", fixed = TRUE)
  expect_match(conditionMessage(cnd), "2023-11-14 22:13:20 UTC", fixed = TRUE)
  expect_equal(cnd$status, 429L)
  expect_match(cnd$quota$status, "^QUOTA_EXCEEDED")
})

test_that("a spent quota without a reset header says the time is unknown", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(), status = 429L,
                       headers = list(`X-ELS-Status` = "QUOTA_EXCEEDED - Quota Exceeded"))
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_quota_exceeded")
  expect_match(conditionMessage(cnd), "did not say when", fixed = TRUE)
  expect_no_match(conditionMessage(cnd), "NA UTC", fixed = TRUE)
})

test_that("the 403 message names entitlement, not the quota", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(), status = 403L))
  msg <- tryCatch(scopus_count("x"), scopus_error_forbidden = conditionMessage)
  expect_match(msg, "not entitled to this resource or view", fixed = TRUE)
  expect_match(msg, "institutional token", fixed = TRUE)
  expect_no_match(msg, "quota", ignore.case = TRUE)
})

test_that("Retry-After drives the back-off wait", {
  retry_after <- scopusflow:::scopus_retry_after
  expect_equal(retry_after(httr2::response(429L, headers = list(`Retry-After` = "12"))), 12)
  expect_true(is.na(retry_after(httr2::response(429L))))
})

# An IMF-fixdate (RFC 9110, section 5.6.7) written without the locale, since
# format(x, "%a %b") gives German day and month names under a German locale.
imf_fixdate <- function(time) {
  lt <- as.POSIXlt(time, tz = "UTC")
  sprintf(
    "%s, %02d %s %04d %02d:%02d:%02d GMT",
    c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")[lt$wday + 1L],
    lt$mday, month.abb[lt$mon + 1L], lt$year + 1900L,
    lt$hour, lt$min, as.integer(lt$sec)
  )
}

test_that("Retry-After accepts the HTTP-date form", {
  retry_after <- scopusflow:::scopus_retry_after
  future <- imf_fixdate(Sys.time() + 100)
  secs <- retry_after(httr2::response(429L, headers = list(`Retry-After` = future)))
  expect_true(secs > 0 && secs <= 100)
  past <- "Wed, 21 Oct 2015 07:28:00 GMT"
  expect_equal(retry_after(httr2::response(429L, headers = list(`Retry-After` = past))), 0)
})

test_that("the HTTP-date parser reads the RFC form exactly and refuses others", {
  parse <- scopusflow:::scopus_parse_http_date
  expect_equal(
    parse("Wed, 21 Oct 2037 07:28:00 GMT"),
    as.POSIXct("2037-10-21 07:28:00", tz = "UTC")
  )
  # Surrounding white space is ignored, on either side.
  expect_equal(
    parse(" Wed, 21 Oct 2037 07:28:00 GMT "),
    as.POSIXct("2037-10-21 07:28:00", tz = "UTC")
  )
  expect_true(is.na(parse("Wednesday, 21-Oct-37 07:28:00 GMT")))
  expect_true(is.na(parse("Wed, 21 Okt 2037 07:28:00 GMT")))
  expect_true(is.na(parse("Wed, 31 Feb 2037 07:28:00 GMT")))
  expect_true(is.na(parse("soon")))
})

test_that("Retry-After dates parse whatever the time locale", {
  # The parser used as.POSIXct() with %b, which reads month names in the
  # session's LC_TIME, so an English date was NA under German or French.
  old <- Sys.getlocale("LC_TIME")
  german <- ""
  for (candidate in c("German_Germany.1252", "de_DE.UTF-8", "de_DE")) {
    german <- suppressWarnings(Sys.setlocale("LC_TIME", candidate))
    if (nzchar(german)) break
  }
  Sys.setlocale("LC_TIME", old)
  skip_if(!nzchar(german), "No German time locale on this machine.")
  withr::local_locale(c(LC_TIME = german))

  date <- "Wed, 21 Oct 2037 07:28:00 GMT"
  expect_equal(
    scopusflow:::scopus_parse_http_date(date),
    as.POSIXct("2037-10-21 07:28:00", tz = "UTC")
  )
  secs <- scopusflow:::scopus_retry_after(
    httr2::response(429L, headers = list(`Retry-After` = date))
  )
  expect_false(is.na(secs))
  expect_gt(secs, 0)
})

test_that("persistent 429 surfaces a rate-limit condition", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(), status = 429L, headers = list(`Retry-After` = "0"))
  })
  expect_error(scopus_count("x"), class = "scopus_error_rate_limit")
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_false(inherits(cnd, "scopus_error_quota_exceeded"))
})

test_that("5xx maps to a server condition (after retries)", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(), status = 503L))
  expect_error(scopus_count("x"), class = "scopus_error_server")
})

test_that("a transport failure becomes an offline condition", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    rlang::abort("simulated transport failure", class = "httr2_failure")
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_offline")
  expect_false(inherits(cnd, "scopus_error_timeout"))
  expect_match(conditionMessage(cnd), "may be offline", fixed = TRUE)
})

test_that("a timeout is reported as a timeout, not as being offline", {
  local_scopus_test_env()
  withr::local_options(scopusflow.timeout = 5)
  # The parent httr2 attaches when curl gives up on a stalled transfer.
  timeout <- structure(
    class = c("curl_error_operation_timedout", "curl_error", "error", "condition"),
    list(
      message = "Timeout was reached [api.elsevier.com]: Operation timed out after 5001 milliseconds",
      call = NULL
    )
  )
  httr2::local_mocked_responses(function(req) {
    rlang::abort("Failed to perform HTTP request.", class = "httr2_failure", parent = timeout)
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_timeout")
  # Still an offline condition, so handlers written for that keep working.
  expect_s3_class(cnd, "scopus_error_offline")
  expect_match(conditionMessage(cnd), "did not respond within 5 seconds", fixed = TRUE)
  expect_match(conditionMessage(cnd), "scopusflow.timeout", fixed = TRUE)
  expect_no_match(conditionMessage(cnd), "offline", fixed = TRUE)

  # A parent of another class is recognised by curl's message.
  plain <- simpleError("Timeout was reached: Resolving timed out after 5000 milliseconds")
  httr2::local_mocked_responses(function(req) {
    rlang::abort("Failed to perform HTTP request.", class = "httr2_failure", parent = plain)
  })
  expect_error(scopus_count("x"), class = "scopus_error_timeout")
})

test_that("a malformed body is reported", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(unexpected = TRUE)))
  expect_error(scopus_count("x"), class = "scopus_error_malformed")
})

test_that("the condition carries the HTTP status and parsed quota", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(), status = 403L,
                       headers = list(`X-RateLimit-Remaining` = "0"))
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_equal(cnd$status, 403L)
  expect_equal(cnd$quota$remaining, 0)
})
