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

test_that("Retry-After drives the back-off wait", {
  retry_after <- scopusflow:::scopus_retry_after
  expect_equal(retry_after(httr2::response(429L, headers = list(`Retry-After` = "12"))), 12)
  expect_true(is.na(retry_after(httr2::response(429L))))
})

test_that("Retry-After accepts the HTTP-date form", {
  retry_after <- scopusflow:::scopus_retry_after
  future <- format(Sys.time() + 100, "%a, %d %b %Y %H:%M:%S", tz = "GMT")
  secs <- retry_after(httr2::response(429L, headers = list(`Retry-After` = future)))
  expect_true(secs > 0 && secs <= 100)
  past <- "Wed, 21 Oct 2015 07:28:00 GMT"
  expect_equal(retry_after(httr2::response(429L, headers = list(`Retry-After` = past))), 0)
})

test_that("persistent 429 surfaces a rate-limit condition", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(), status = 429L, headers = list(`Retry-After` = "0"))
  })
  expect_error(scopus_count("x"), class = "scopus_error_rate_limit")
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
  expect_error(scopus_count("x"), class = "scopus_error_offline")
})

test_that("a malformed body is reported", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(unexpected = TRUE)))
  expect_error(scopus_count("x"), class = "scopus_error_malformed")
})

test_that("a body that is not JSON at all is reported, with the parse error", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 200L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw("<not json>")
    )
  })
  cnd <- tryCatch(scopus_count("x"), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_malformed")
  expect_false(is.null(cnd$parent))
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

test_that("bad input raises a condition of the scopus_error family", {
  # The README, the help pages and the app's handlers all promise that every
  # scopus_error_* condition inherits from scopus_error, so a caller can catch
  # the family in one place.
  expect_error(scopus_count(""), class = "scopus_error")
  expect_error(scopus_plan("x", partition = "year"), class = "scopus_error")
  expect_error(scopus_quota(1), class = "scopus_error")
  expect_error(as_bibtex(1), class = "scopus_error")
  cnd <- tryCatch(scopus_count(""), scopus_error = function(e) e)
  expect_s3_class(cnd, "scopus_error_bad_input")
})
