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

test_that("a checkpoint from a different plan is refetched, not served", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 1L)(req)
  })

  plan_a <- scopus_plan("graphene", years = 2020)
  scopus_fetch_plan(plan_a, cache_dir = cache, resume = TRUE)
  first_calls <- calls

  # A different plan pointed at the same cache_dir must not be served plan A's
  # records: the mismatching checkpoint is a cache miss, refetched and
  # overwritten.
  plan_b <- scopus_plan("perovskite", years = 2020)
  expect_warning(
    recs <- scopus_fetch_plan(plan_b, cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_gt(calls, first_calls)
  expect_true(all(recs$query == plan_b$query[1]))

  # The overwritten checkpoint then serves plan B from cache.
  calls_after <- calls
  scopus_fetch_plan(plan_b, cache_dir = cache, resume = TRUE)
  expect_equal(calls, calls_after)
})

test_that("a year-partitioned plan does not serve another year's checkpoint", {
  # Every cell of a year-partitioned plan carries the same wrapped query, the
  # year travelling separately as the `date` parameter, so keying checkpoints on
  # the cell index alone let two plans over overlapping year spans hand each
  # other the wrong years, silently.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(function(req) {
    date <- httr2::url_parse(req$url)$query$date
    mock_search_results(
      list(list(`prism:doi` = paste0("10.1/", date), `dc:title` = date)),
      total = 1L
    )
  })

  scopus_fetch_plan(scopus_plan("x", years = 2015:2016, partition = "year"),
                    cache_dir = cache, resume = TRUE)
  recs <- scopus_fetch_plan(scopus_plan("x", years = 2016:2017, partition = "year"),
                            cache_dir = cache, resume = TRUE)
  expect_equal(recs$title, c("2016", "2017"))

  # The 2016 cell is shared between the two plans, but it sits at a different
  # position in each, so each keeps its own checkpoint.
  expect_setequal(
    list.files(cache, pattern = "^cell-"),
    c("cell-001-2015.rds", "cell-002-2016.rds", "cell-001-2016.rds",
      "cell-002-2017.rds")
  )
})

test_that("a checkpoint truncated by max_results is not served to a wider request", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(mock_corpus(total = 40L))
  plan <- scopus_plan("x", years = 2020, partition = "year")

  expect_equal(nrow(scopus_fetch_plan(plan, max_results = 5, cache_dir = cache,
                                      resume = TRUE)), 5L)
  expect_warning(
    recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_equal(nrow(recs), 40L)

  # A narrower request is served from the wider checkpoint, trimmed to its own
  # cap, and costs nothing.
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 40L)(req)
  })
  expect_equal(nrow(scopus_fetch_plan(plan, max_results = 5, cache_dir = cache,
                                      resume = TRUE)), 5L)
  expect_equal(calls, 0L)
})

test_that("a checkpoint holding more than the request is served trimmed to the cap", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 5L)(req)
  })
  plan <- scopus_plan("x", years = 2020, partition = "year")

  expect_equal(nrow(scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)), 5L)
  after_first <- calls

  recs <- scopus_fetch_plan(plan, max_results = 2, cache_dir = cache, resume = TRUE)
  expect_equal(calls, after_first)   # served from cache, no new requests
  expect_equal(nrow(recs), 2L)
  # Provenance survives the trim.
  expect_s3_class(attr(recs, "retrieved_at"), "POSIXct")

  # The checkpoint on disk keeps all five rows for a later, wider request.
  expect_equal(nrow(scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)), 5L)
  expect_equal(calls, after_first)
})

test_that("a zero-row checkpoint is not served to a different query", {
  # An empty cell has no query column values, so the record-column guard passes
  # it vacuously; the manifest's own copy of the query has to reject the
  # mismatch.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 0L)(req)
  })

  recs_a <- scopus_fetch_plan(scopus_plan("graphene", years = 2020),
                              cache_dir = cache, resume = TRUE)
  expect_equal(nrow(recs_a), 0L)
  first_calls <- calls

  expect_warning(
    recs_b <- scopus_fetch_plan(scopus_plan("perovskite", years = 2020),
                                cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_gt(calls, first_calls)
  expect_equal(nrow(recs_b), 0L)

  # The overwritten checkpoint then serves its own query from cache.
  calls_after <- calls
  scopus_fetch_plan(scopus_plan("perovskite", years = 2020),
                    cache_dir = cache, resume = TRUE)
  expect_equal(calls, calls_after)
})

test_that("a cap that never bit leaves the checkpoint usable for any request", {
  # The cell held fewer records than its cap, so nothing was truncated and a
  # later uncapped request must not spend quota refetching it.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 3L)(req)
  })
  plan <- scopus_plan("x", years = 2020, partition = "year")

  scopus_fetch_plan(plan, max_results = 25, cache_dir = cache, resume = TRUE)
  after_first <- calls
  expect_equal(nrow(scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)), 3L)
  expect_equal(calls, after_first)
})

test_that("a checkpoint from a different view or page size is refetched", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(mock_corpus(total = 1L))

  scopus_fetch_plan(scopus_plan("x", years = 2020, partition = "year"),
                    cache_dir = cache, resume = TRUE)
  expect_warning(
    scopus_fetch_plan(
      scopus_plan("x", years = 2020, partition = "year", page_size = 10),
      cache_dir = cache, resume = TRUE
    ),
    class = "scopus_warning_cache_mismatch"
  )
})

test_that("a half-written checkpoint is refetched rather than aborting the run", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(mock_corpus(total = 2L))
  plan <- scopus_plan("x", years = 2020, partition = "year")
  scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)

  # What an interrupted or killed run leaves behind.
  file <- list.files(cache, pattern = "^cell-", full.names = TRUE)
  bytes <- readBin(file, "raw", file.size(file))
  writeBin(bytes[seq_len(length(bytes) %/% 2L)], file)

  expect_warning(
    recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_unreadable"
  )
  expect_equal(nrow(recs), 2L)

  # The damaged checkpoint has been replaced, so the next resume is clean.
  expect_silent(scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE))
})

test_that("a checkpoint is written whole or not at all", {
  # The temp file the atomic write uses must not be left behind, and must never
  # be mistaken for a checkpoint.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(mock_corpus(total = 1L))
  scopus_fetch_plan(scopus_plan("x", years = 2019:2020, partition = "year"),
                    cache_dir = cache, resume = TRUE)
  expect_setequal(list.files(cache), c("cell-001-2019.rds", "cell-002-2020.rds"))
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
  saveRDS(old_cell, file.path(cache, "cell-001-2019.rds"))

  entries <- list(list(`prism:doi` = "10.1/new", authkeywords = "graphene"))
  httr2::local_mocked_responses(function(req) mock_search_results(entries, total = 1L))
  plan <- scopus_plan("x", years = 2019:2020, partition = "year", view = "COMPLETE")

  recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  expect_equal(nrow(recs), 2L)
  expect_true("authkeywords" %in% names(recs))
  expect_true(is.na(recs$authkeywords[recs$doi == "10.1/old"]))
  expect_equal(recs$authkeywords[recs$doi == "10.1/new"], "graphene")
})

test_that("a combined harvest is dated by its oldest cell", {
  # A resumed harvest can span days, so the combined set is only as fresh as
  # the earliest cell that went into it.
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 1L))
  plan <- scopus_plan("x", years = 2019:2020, partition = "year")

  cells <- lapply(1:2, function(i) scopus_fetch("x"))
  attr(cells[[1]], "retrieved_at") <- as.POSIXct("2024-01-02 03:04:05", tz = "UTC")
  attr(cells[[2]], "retrieved_at") <- as.POSIXct("2024-06-07 08:09:10", tz = "UTC")
  attr(cells[[1]], "scopusflow_version") <- "0.1.0"
  attr(cells[[2]], "scopusflow_version") <- "0.3.0"

  bound <- scopusflow:::scopus_bind_records(cells)
  expect_equal(attr(bound, "retrieved_at"),
               as.POSIXct("2024-01-02 03:04:05", tz = "UTC"))
  expect_equal(attr(bound, "scopusflow_version"), c("0.1.0", "0.3.0"))

  # A cell that cannot be dated, as a checkpoint written before these
  # attributes existed cannot, must leave the whole set undated rather than
  # letting it claim a time later than one of its own cells.
  attr(cells[[1]], "retrieved_at") <- NULL
  attr(cells[[1]], "scopusflow_version") <- NULL
  partial <- scopusflow:::scopus_bind_records(cells)
  expect_null(attr(partial, "retrieved_at"))
  expect_null(attr(partial, "scopusflow_version"))

  # And an ordinary run carries a single, current stamp through the plan.
  recs <- scopus_fetch_plan(plan)
  expect_s3_class(attr(recs, "retrieved_at"), "POSIXct")
  expect_equal(attr(recs, "scopusflow_version"),
               as.character(utils::packageVersion("scopusflow")))
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
