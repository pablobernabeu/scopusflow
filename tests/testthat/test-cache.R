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
  expect_identical(attr(recs, "view"), "STANDARD")

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
  # authkeywords column and the manifest, while a newly fetched cell has both.
  # That older cell also predates the COMPLETE author list, so it is fetched
  # again, where it used to be bound in as it stood.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  old_cell <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/old"))))
  saveRDS(old_cell, file.path(cache, "cell-001-2019.rds"))

  entries <- list(list(`prism:doi` = "10.1/new", authkeywords = "graphene"))
  httr2::local_mocked_responses(function(req) mock_search_results(entries, total = 1L))
  plan <- scopus_plan("x", years = 2019:2020, partition = "year", view = "COMPLETE")

  expect_warning(
    recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_equal(nrow(recs), 2L)
  expect_equal(recs$authkeywords, c("graphene", "graphene"))

  # Sets whose columns differ still bind, the missing column filled with NA.
  mixed <- scopus_combine(old_cell, recs)
  expect_true(is.na(mixed$authkeywords[mixed$doi == "10.1/old"]))
  expect_equal(mixed$authkeywords[mixed$doi == "10.1/new"], c("graphene", "graphene"))
})

test_that("a COMPLETE checkpoint from before the author list was read is refetched once", {
  # Such a checkpoint holds first authors under COMPLETE, the defect the author
  # list fixes, and serving it would carry the defect into every resumed
  # harvest. Its manifest lacks records_schema, or it has no manifest at all.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  fx <- complete_authors_fixture()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_search_results(list(fx$entry), total = 1L)
  })
  plan <- scopus_plan("x", years = 2020, view = "COMPLETE")
  scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  file <- list.files(cache, pattern = "^cell-", full.names = TRUE)

  # What 0.4.0 wrote for the same cell: the first author alone, and a manifest
  # without the schema.
  old <- readRDS(file)
  old$authors <- "Cong L."
  meta <- attr(old, "cache_meta")
  meta$records_schema <- NULL
  attr(old, "cache_meta") <- meta
  saveRDS(old, file)

  expect_warning(
    recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE),
    "before COMPLETE-view records carried the author list", fixed = TRUE,
    class = "scopus_warning_cache_mismatch"
  )
  expect_equal(calls, 2L)
  expect_identical(recs$authors, fx$expected_authors)

  # The checkpoint written in its place is served from then on.
  expect_no_warning(again <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE))
  expect_equal(calls, 2L)
  expect_identical(again$authors, fx$expected_authors)

  # A checkpoint without a manifest, as releases before 0.4.0 wrote, is
  # refetched too.
  bare <- readRDS(file)
  attr(bare, "cache_meta") <- NULL
  saveRDS(bare, file)
  expect_warning(scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE),
                 class = "scopus_warning_cache_mismatch")
  expect_equal(calls, 3L)
})

test_that("a STANDARD checkpoint from before the schema was recorded is still served", {
  # dc:creator was always the right reading of a STANDARD record, so these
  # checkpoints cost no quota.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 2L)(req)
  })
  plan <- scopus_plan("x", years = 2020)
  scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  file <- list.files(cache, pattern = "^cell-", full.names = TRUE)
  old <- readRDS(file)
  meta <- attr(old, "cache_meta")
  meta$records_schema <- NULL
  attr(old, "cache_meta") <- meta
  attr(old, "view") <- NULL
  saveRDS(old, file)

  expect_no_warning(recs <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE))
  expect_equal(calls, 1L)
  expect_equal(nrow(recs), 2L)
  # The records predate the view attribute, and the manifest, checked against
  # the cell, still names the view they were fetched under.
  expect_identical(attr(recs, "view"), "STANDARD")
})

test_that("a retrieval records the view it was fetched under", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 2L))
  expect_identical(attr(scopus_fetch("x"), "view"), "STANDARD")
  expect_identical(attr(scopus_fetch("x", view = "COMPLETE"), "view"), "COMPLETE")
  plan <- scopus_plan("x", years = 2019:2020, partition = "year", view = "COMPLETE")
  expect_identical(attr(scopus_fetch_plan(plan), "view"), "COMPLETE")

  httr2::local_mocked_responses(mock_cursor_corpus(total = 2L))
  expect_identical(attr(scopus_fetch("x", cursor = TRUE), "view"), "STANDARD")
})

test_that("a combined set keeps its view only where every part records the same one", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 1L))
  standard <- scopus_fetch("x")
  complete <- scopus_fetch("x", view = "COMPLETE")
  expect_identical(attr(scopus_combine(standard, standard, dedupe = TRUE), "view"),
                   "STANDARD")
  expect_null(attr(scopus_combine(standard, complete), "view"))
  # A part that records no view leaves the whole without one, as a part that
  # cannot be dated leaves it undated.
  unrecorded <- standard
  attr(unrecorded, "view") <- NULL
  expect_null(attr(scopus_combine(standard, unrecorded), "view"))
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

test_that("a plan carries its per-cell accounting onto the result", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 2L))
  plan <- scopus_plan("x", years = 2018:2020, partition = "year")
  recs <- scopus_fetch_plan(plan)

  cells <- attr(recs, "cell_totals")
  expect_s3_class(cells, "tbl_df")
  expect_equal(cells$cell, 1:3)
  expect_equal(cells$date, as.character(2018:2020))
  expect_equal(cells$n_records, rep(2L, 3))
  expect_equal(cells$reported_total, rep(2, 3))
  expect_equal(attr(recs, "total_results"), 6)
  expect_equal(attr(recs, "paging"), "offset")
})

test_that("a resumed harvest keeps each cell's total, time and version", {
  # The checkpoint holds the cell's attributes, so a resumed harvest is dated
  # and its completeness stated as if it had run at once. The Python twin
  # restores the same three from its checkpoint manifests.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_corpus(total = 2L)(req)
  })
  plan <- scopus_plan("x", years = 2019:2020, partition = "year")
  first <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  after_first <- calls

  resumed <- scopus_fetch_plan(plan, cache_dir = cache, resume = TRUE)
  expect_equal(calls, after_first)
  expect_equal(attr(resumed, "cell_totals")$reported_total, c(2, 2))
  expect_equal(attr(resumed, "total_results"), 4)
  expect_equal(attr(resumed, "retrieved_at"), attr(first, "retrieved_at"))
  expect_identical(attr(resumed, "scopusflow_version"),
                   attr(first, "scopusflow_version"))
})

test_that("an overall total is claimed only when every cell reported one", {
  local_scopus_test_env()
  # The second cell's response omits the total, as a non-conforming or partial
  # response can; summing the rest would understate the search.
  httr2::local_mocked_responses(function(req) {
    q <- httr2::url_parse(req$url)$query
    if (identical(q$date, "2019")) {
      return(mock_json_response(list(`search-results` = list(entry = mock_entries(2L)))))
    }
    mock_corpus(total = 2L)(req)
  })
  recs <- scopus_fetch_plan(scopus_plan("x", years = 2018:2019, partition = "year"))
  totals <- attr(recs, "cell_totals")$reported_total
  expect_equal(totals[1], 2)
  expect_true(is.na(totals[2]))
  expect_true(is.na(attr(recs, "total_results")))
})

test_that("a cell shorter than the API reported warns", {
  local_scopus_test_env()
  # Ten records are claimed and two are served, which is what a truncated or
  # refused download looks like from the inside: the first page is short and
  # the next is empty, while the reported total stays at ten.
  page <- 0L
  httr2::local_mocked_responses(function(req) {
    page <<- page + 1L
    entries <- if (page == 1L) mock_entries(2L) else list(list(error = "Result set was empty"))
    mock_search_results(entries, total = 10L)
  })
  expect_warning(
    scopus_fetch_plan(scopus_plan("x", years = 2019L)),
    "Cell 1 retrieved 2 record(s), but the Scopus API reports 10 for this query",
    fixed = TRUE,
    class = "scopus_warning_shortfall"
  )

  # A cell stopped by max_results is short by request, not by failure.
  page <- 0L
  expect_no_warning(
    scopus_fetch_plan(scopus_plan("x", years = 2019L), max_results = 2)
  )
})

test_that("an offset-paged plan cell stops at the ceiling and the warning names cursor = TRUE", {
  # The cell is already a single year, so advice to partition by year would
  # send the caller round in a circle.
  local_scopus_test_env()
  withr::local_options(scopusflow.hard_cap = 400L)
  httr2::local_mocked_responses(mock_paged_corpus(total = 1000L))
  plan <- scopus_plan("x", years = 2021L, partition = "year")

  capped <- expect_warning(
    shortfall <- expect_warning(
      recs <- scopus_fetch_plan(plan),
      class = "scopus_warning_shortfall"
    ),
    class = "scopus_warning_capped"
  )
  expect_equal(nrow(recs), 400L)
  expect_identical(attr(recs, "paging"), "offset")
  expect_match(conditionMessage(capped),
               "Use scopus_fetch_plan(plan, cursor = TRUE) to retrieve the whole cell.",
               fixed = TRUE)
  expect_false(grepl("partition", conditionMessage(capped), fixed = TRUE))
  # The shortfall wording is shared with the Python twin and stays as it was.
  expect_match(conditionMessage(shortfall),
               "Cell 1 retrieved 400 record(s), but the Scopus API reports 1000",
               fixed = TRUE)

  # scopus_fetch() keeps its own advice, since a single query can be split.
  outside <- expect_warning(scopus_fetch("x"), class = "scopus_warning_capped")
  expect_match(conditionMessage(outside), "Use scopus_fetch(cursor = TRUE)", fixed = TRUE)
})

test_that("cursor = TRUE retrieves a plan cell above the offset ceiling whole", {
  local_scopus_test_env()
  withr::local_options(scopusflow.hard_cap = 400L)
  httr2::local_mocked_responses(mock_paged_corpus(total = 1000L))
  plan <- scopus_plan("x", years = 2021L, partition = "year")

  recs <- expect_no_warning(scopus_fetch_plan(plan, cursor = TRUE))
  expect_equal(nrow(recs), 1000L)
  expect_equal(recs$entry_number, 1:1000)
  expect_identical(attr(recs, "paging"), "cursor")
  expect_equal(attr(recs, "cell_totals")$n_records, 1000L)
  expect_equal(attr(recs, "total_results"), 1000)
})

test_that("a checkpoint answers only the paging mode it was fetched under", {
  # The two modes return different records for a cell above the ceiling, and
  # a different order below it, and the search record states the mode.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  corpus <- mock_paged_corpus(total = 3L)
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    corpus(req)
  })
  plan <- scopus_plan("x", years = 2020L, partition = "year")

  scopus_fetch_plan(plan, cache_dir = cache)
  expect_equal(calls, 1L)
  switched <- expect_warning(
    recs <- scopus_fetch_plan(plan, cache_dir = cache, cursor = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_equal(calls, 2L)
  expect_identical(attr(recs, "paging"), "cursor")
  # This plan wrote the checkpoint, under the other mode, so the warning says
  # so and gives no advice about cache directories, which a caller following
  # the capped warning's advice would otherwise read in every cell.
  expect_match(conditionMessage(switched),
               "was fetched under offset paging, not the cursor paging asked for",
               fixed = TRUE)
  expect_false(grepl("cache_dir", conditionMessage(switched), fixed = TRUE))

  # The checkpoint written in its place serves cursor requests from then on,
  # and is a miss for an offset request in turn.
  resumed <- expect_no_warning(scopus_fetch_plan(plan, cache_dir = cache, cursor = TRUE))
  expect_equal(calls, 2L)
  expect_identical(attr(resumed, "paging"), "cursor")
  back <- expect_warning(scopus_fetch_plan(plan, cache_dir = cache),
                         class = "scopus_warning_cache_mismatch")
  expect_equal(calls, 3L)
  expect_match(conditionMessage(back),
               "was fetched under cursor paging, not the offset paging asked for",
               fixed = TRUE)

  # Another plan's checkpoint in the other mode is still another plan's.
  other <- scopus_plan("y", years = 2020L, partition = "year")
  foreign <- expect_warning(scopus_fetch_plan(other, cache_dir = cache, cursor = TRUE),
                            class = "scopus_warning_cache_mismatch")
  expect_equal(calls, 4L)
  expect_match(conditionMessage(foreign), "Give each plan its own cache_dir.",
               fixed = TRUE)
})

test_that("a checkpoint that records no paging mode counts as offset-paged", {
  # scopus_fetch_plan() paged by offset alone until it gained `cursor`, so a
  # manifest written before then, or a checkpoint without one, describes an
  # offset-paged cell.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  corpus <- mock_paged_corpus(total = 2L)
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    corpus(req)
  })
  plan <- scopus_plan("x", years = 2020L, partition = "year")
  scopus_fetch_plan(plan, cache_dir = cache)
  file <- list.files(cache, pattern = "^cell-", full.names = TRUE)
  expect_identical(attr(readRDS(file), "cache_meta")$paging, "offset")

  for (strip in c("paging", "manifest")) {
    old <- readRDS(file)
    if (strip == "paging") {
      meta <- attr(old, "cache_meta")
      meta$paging <- NULL
      attr(old, "cache_meta") <- meta
    } else {
      attr(old, "cache_meta") <- NULL
    }
    saveRDS(old, file)
    before <- calls
    expect_no_warning(scopus_fetch_plan(plan, cache_dir = cache))
    expect_equal(calls, before)
    switched <- expect_warning(scopus_fetch_plan(plan, cache_dir = cache, cursor = TRUE),
                               class = "scopus_warning_cache_mismatch")
    expect_equal(calls, before + 1L)
    expect_match(conditionMessage(switched), "was fetched under offset paging",
                 fixed = TRUE)
    # Back to an offset checkpoint for the next round.
    expect_warning(scopus_fetch_plan(plan, cache_dir = cache),
                   class = "scopus_warning_cache_mismatch")
  }
})

test_that("scopus_fetch_plan() takes cursor as TRUE or FALSE", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) stop("no request was expected"))
  plan <- scopus_plan("x", years = 2020L)
  for (bad in list(NA, "yes", c(TRUE, FALSE), 1, NULL)) {
    expect_error(scopus_fetch_plan(plan, cursor = bad), class = "scopus_error_bad_input")
  }
})
