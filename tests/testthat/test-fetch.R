test_that("scopus_count returns the reported total with quota attached", {
  local_scopus_test_env()
  httr2::local_mocked_responses(
    mock_corpus(total = 137L, headers = list(`X-RateLimit-Remaining` = "99"))
  )
  n <- scopus_count("anything")
  expect_equal(as.numeric(n), 137)
  expect_equal(attr(n, "quota")$remaining, 99)
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

test_that("a huge total still triggers the cap warning (no integer overflow)", {
  local_scopus_test_env()
  withr::local_options(scopusflow.hard_cap = 6L)
  # Far beyond the 32-bit integer ceiling.
  httr2::local_mocked_responses(function(req) {
    mock_search_results(mock_entries(2L), total = 3000000000)
  })
  expect_warning(
    recs <- scopus_fetch("anything", page_size = 2L),
    class = "scopus_warning_capped"
  )
  expect_equal(attr(recs, "total_results"), 3e9)
})

test_that("fetching stops when the server serves fewer records than its total", {
  local_scopus_test_env()
  served <- 5L
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    q <- httr2::url_parse(req$url)$query
    start <- as.integer(if (is.null(q$start)) 0L else q$start)
    count <- as.integer(if (is.null(q$count)) 25L else q$count)
    n <- max(0L, min(count, served - start))
    entries <- if (n > 0L) mock_entries(n, offset = start) else {
      list(list(error = "Result set was empty"))
    }
    # Report a total far larger than what is actually served.
    mock_search_results(entries, total = 100L)
  })
  recs <- scopus_fetch("anything", page_size = 2L)
  expect_equal(nrow(recs), 5L)
  expect_lte(calls, 4L)  # 3 full pages then a short page; no run to the ceiling
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

test_that("cursor pagination retrieves the whole set without a 5000 cap", {
  local_scopus_test_env()
  withr::local_options(scopusflow.hard_cap = 6L) # would bite offset paging, not cursor
  httr2::local_mocked_responses(mock_cursor_corpus(total = 450L))
  recs <- scopus_fetch("anything", cursor = TRUE, page_size = 200L)
  expect_equal(nrow(recs), 450L)
  expect_equal(recs$entry_number, 1:450)
  expect_equal(attr(recs, "total_results"), 450)
})

test_that("cursor pagination reaches beyond 5000 records", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_cursor_corpus(total = 12000L))
  recs <- scopus_fetch("anything", cursor = TRUE, page_size = 200L, max_results = 7000L)
  expect_equal(nrow(recs), 7000L)
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
