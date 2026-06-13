test_that("scopus_count returns the reported total", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 137L))
  expect_equal(scopus_count("anything"), 137L)
})

test_that("scopus_fetch paginates and binds once", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 7L))
  recs <- scopus_fetch("anything", page_size = 2L)
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 7L)
  expect_equal(recs$entry_number, 1:7)
  expect_false(anyDuplicated(recs$doi) > 0)
  expect_equal(attr(recs, "total_results"), 7L)
})

test_that("max_results limits retrieval", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 100L))
  recs <- scopus_fetch("anything", max_results = 10L, page_size = 4L)
  expect_equal(nrow(recs), 10L)
})

test_that("retrieval is capped at the API ceiling with a warning", {
  local_scopus_test_env()
  withr::local_options(scopusflow.hard_cap = 6L)
  httr2::local_mocked_responses(mock_corpus(total = 20L))
  expect_warning(
    recs <- scopus_fetch("anything", page_size = 2L),
    class = "scopus_warning_capped"
  )
  expect_equal(nrow(recs), 6L)
})

test_that("an empty corpus yields zero rows", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 0L))
  recs <- scopus_fetch("anything")
  expect_equal(nrow(recs), 0L)
})

test_that("quota is attached to fetched records", {
  local_scopus_test_env()
  httr2::local_mocked_responses(
    mock_corpus(total = 3L, headers = list(`X-RateLimit-Remaining` = "42"))
  )
  recs <- scopus_fetch("anything", page_size = 2L)
  expect_equal(attr(recs, "quota")$remaining, 42)
})

test_that("invalid max_results and page_size are rejected without network", {
  local_scopus_test_env()
  expect_error(scopus_fetch("x", max_results = 0), class = "scopus_error_bad_input")
  expect_error(scopus_fetch("x", max_results = 2.5), class = "scopus_error_bad_input")
  expect_error(scopus_fetch("x", page_size = 201), class = "scopus_error_bad_input")
  expect_error(scopus_fetch("x", view = "COMPLETE", page_size = 26),
               class = "scopus_error_bad_input")
})

test_that("a single request suffices when the page covers all results", {
  local_scopus_test_env()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 150L)(req)
  })
  # STANDARD view defaults to a 200-record page, so 150 results need one request.
  recs <- scopus_fetch("anything")
  expect_equal(nrow(recs), 150L)
  expect_equal(calls, 1L)
})
