test_that("scopus_has_key reflects configuration", {
  withr::local_options(scopusflow.api_key = NULL)
  withr::local_envvar(SCOPUS_API_KEY = "")
  expect_false(scopus_has_key())

  withr::local_options(scopusflow.api_key = "abc")
  expect_true(scopus_has_key())
})

test_that("missing key raises a typed condition without network", {
  withr::local_options(scopusflow.api_key = NULL)
  withr::local_envvar(SCOPUS_API_KEY = "")
  expect_error(scopus_count("x"), class = "scopus_error_no_key")
  expect_error(scopus_fetch("x"), class = "scopus_error_no_key")
})

test_that("an explicit api_key argument wins", {
  withr::local_options(scopusflow.api_key = NULL)
  withr::local_envvar(SCOPUS_API_KEY = "")
  httr2::local_mocked_responses(mock_corpus(total = 1L))
  withr::local_options(scopusflow.max_tries = 1L)
  expect_equal(scopus_count("x", api_key = "explicit"), 1L)
})

test_that("the key is never exposed in the request dump", {
  withr::local_options(scopusflow.api_key = "super-secret-key")
  req <- scopusflow:::scopus_request(list(query = "x"))
  dump <- paste(utils::capture.output(print(req)), collapse = "\n")
  expect_false(grepl("super-secret-key", dump))
})
