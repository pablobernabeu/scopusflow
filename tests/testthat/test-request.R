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

test_that("empty-string parameters are omitted from the query", {
  withr::local_options(scopusflow.api_key = "k")
  req <- scopusflow:::scopus_request(list(query = "x", view = "", date = NULL))
  u <- httr2::url_parse(req$url)
  expect_equal(u$query$query, "x")
  expect_false("view" %in% names(u$query))
  expect_false("date" %in% names(u$query))
})
