# These tests pin the shape of the request scopusflow sends, so that an
# accidental change to a parameter name, the path or the auth header is caught
# even though the rest of the suite only ever sees mocked responses.

test_that("the outbound request matches the 'Scopus' Search API contract", {
  withr::local_options(scopusflow.api_key = "secret-key")
  req <- scopusflow:::scopus_request(list(
    query = "TITLE-ABS-KEY(x)", count = "25", start = "0",
    view = "STANDARD", date = "2020", field = NULL
  ))
  u <- httr2::url_parse(req$url)

  expect_match(u$path, "content/search/scopus")
  expect_equal(u$query$query, "TITLE-ABS-KEY(x)")
  expect_equal(u$query$count, "25")
  expect_equal(u$query$start, "0")
  expect_equal(u$query$view, "STANDARD")
  expect_equal(u$query$date, "2020")
  expect_false("field" %in% names(u$query)) # NULL params are dropped

  expect_true("X-ELS-APIKey" %in% names(req$headers))
  expect_equal(req$headers[["Accept"]], "application/json")
})

test_that("an institutional token is sent only when configured", {
  withr::local_options(scopusflow.api_key = "k", scopusflow.inst_token = NULL)
  withr::local_envvar(SCOPUS_INST_TOKEN = "")
  req <- scopusflow:::scopus_request(list(query = "x"))
  expect_false("X-ELS-Insttoken" %in% names(req$headers))

  withr::local_options(scopusflow.inst_token = "tok")
  req2 <- scopusflow:::scopus_request(list(query = "x"))
  expect_true("X-ELS-Insttoken" %in% names(req2$headers))
})

test_that("every request carries a transfer timeout", {
  # curl's own default is no timeout at all, so a connection that opens and
  # then stalls hangs the session outright: no response ever arrives for the
  # retry policy to classify as transient.
  withr::local_options(scopusflow.api_key = "k")
  expect_equal(scopusflow:::scopus_request(list(query = "x"))$options$timeout_ms, 60000)
  expect_equal(
    scopusflow:::scopus_abstract_request("10.1/x", by = "doi")$options$timeout_ms,
    60000
  )

  withr::local_options(scopusflow.timeout = 5)
  expect_equal(scopusflow:::scopus_request(list(query = "x"))$options$timeout_ms, 5000)
})

test_that("the retry policy retries transport failures", {
  # httr2 1.0.4 stopped retrying a timeout or a reset connection unless
  # retry_on_failure = TRUE, so one such failure aborted a whole harvest.
  # local_mocked_responses() bypasses req_retry(), so the policy is read off
  # the request.
  withr::local_options(scopusflow.api_key = "k", scopusflow.max_tries = 3L)
  req <- scopusflow:::scopus_req_retry(scopusflow:::scopus_request(list(query = "x")))
  expect_true(req$policies$retry_on_failure)
  expect_equal(req$policies$retry_max_tries, 3L)
  expect_true(is.function(req$policies$retry_is_transient))
  expect_true(is.function(req$policies$retry_after))

  abstract <- scopusflow:::scopus_req_retry(
    scopusflow:::scopus_abstract_request("10.1/x", by = "doi")
  )
  expect_true(abstract$policies$retry_on_failure)
})

test_that("empty-string parameters are omitted from the query", {
  withr::local_options(scopusflow.api_key = "k")
  req <- scopusflow:::scopus_request(list(query = "x", view = "", date = NULL))
  u <- httr2::url_parse(req$url)
  expect_equal(u$query$query, "x")
  expect_false("view" %in% names(u$query))
  expect_false("date" %in% names(u$query))
})
