test_that("scopus_fetch_plan executes every cell and re-numbers entries", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 2L))
  plan <- scopus_plan("x", years = 2018:2020, partition = "year")
  recs <- scopus_fetch_plan(plan)
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 6L)          # 2 per year x 3 years
  expect_equal(recs$entry_number, 1:6)
  expect_s3_class(attr(recs, "plan"), "scopus_plan")
})

test_that("caching writes per-cell files and resume avoids re-fetching", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 1L)(req)
  })
  plan <- scopus_plan("x", years = 2019:2020, partition = "year")

  scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  first_calls <- calls
  expect_true(length(list.files(cache, pattern = "cell-")) == 2L)

  # Second run should serve both cells from cache (no new requests).
  recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  expect_equal(calls, first_calls)
  expect_equal(nrow(recs), 2L)
})

test_that("scopus_fetch_plan validates its inputs", {
  local_scopus_test_env()
  expect_error(scopus_fetch_plan(list()), class = "scopus_error_bad_input")
})

test_that("scopus_fetch_plan(view = 'COMPLETE') carries authkeywords through", {
  local_scopus_test_env()
  entries <- list(list(`prism:doi` = "10.1/a", authkeywords = "graphene | supercapacitor"))
  httr2::local_mocked_responses(function(req) mock_search_results(entries, total = 1L))
  plan <- scopus_plan("x", years = 2020, view = "COMPLETE")
  recs <- scopus_fetch_plan(plan)
  expect_true("authkeywords" %in% names(recs))
  expect_equal(recs$authkeywords, "graphene | supercapacitor")
})

test_that("resuming a cache written without authkeywords does not error", {
  # Simulates upgrading scopusflow mid-harvest: an older cached cell lacks the
  # authkeywords column entirely, while a newly fetched cell has it.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  old_cell <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/old"))))
  saveRDS(old_cell, file.path(cache, "cell-001.rds"))

  entries <- list(list(`prism:doi` = "10.1/new", authkeywords = "graphene"))
  httr2::local_mocked_responses(function(req) mock_search_results(entries, total = 1L))
  plan <- scopus_plan("x", years = 2019:2020, partition = "year", view = "COMPLETE")

  recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  expect_equal(nrow(recs), 2L)
  expect_true("authkeywords" %in% names(recs))
  expect_true(is.na(recs$authkeywords[recs$doi == "10.1/old"]))
  expect_equal(recs$authkeywords[recs$doi == "10.1/new"], "graphene")
})

test_that("the managed cache directory is under R_user_dir and clearable", {
  # Redirect the managed cache into a temporary location for the test.
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  expect_match(scopus_cache_dir(), "scopusflow", fixed = TRUE)
  dir <- scopus_cache_dir(create = TRUE)
  writeLines("x", file.path(dir, "marker.txt"))
  expect_true(file.exists(file.path(dir, "marker.txt")))
  scopus_cache_clear()
  expect_false(dir.exists(dir))
})
