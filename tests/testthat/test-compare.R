# Mock that returns deterministic counts: the reference matches 10 per year
# (but 0 in 2018, to exercise the zero-denominator path), term "t1" matches 5
# and term "t2" matches 2.
compare_mock <- function() {
  function(req) {
    q <- httr2::url_parse(req$url)$query
    query <- q$query
    year <- q$date
    total <- if (!grepl("AND", query, fixed = TRUE)) {
      if (identical(year, "2018")) 0L else 10L
    } else if (grepl("t1", query, fixed = TRUE)) {
      5L
    } else {
      2L
    }
    mock_search_results(list(), total = total)
  }
}

test_that("comparison computes per-year and average percentages", {
  local_scopus_test_env()
  httr2::local_mocked_responses(compare_mock())
  cmp <- scopus_compare_topics("ref", c("t1", "t2"), years = 2015:2020)
  expect_s3_class(cmp, "scopus_comparison")

  t1 <- cmp[cmp$abridged_query == "t1", ]
  # 5 / 10 = 50% in non-2018 years.
  expect_equal(unique(t1$comparison_percentage[t1$year != 2018]), 50)
  expect_equal(unique(t1$average_comparison_percentage), 60)

  t2 <- cmp[cmp$abridged_query == "t2", ]
  expect_equal(unique(t2$average_comparison_percentage), 24)
})

test_that("zero reference count yields NA, not NaN/Inf", {
  local_scopus_test_env()
  httr2::local_mocked_responses(compare_mock())
  cmp <- scopus_compare_topics("ref", "t1", years = 2017:2019)
  na_year <- cmp[cmp$abridged_query == "t1" & cmp$year == 2018, ]
  expect_true(is.na(na_year$comparison_percentage))
  expect_false(any(is.nan(cmp$comparison_percentage)))
  expect_false(any(is.infinite(cmp$comparison_percentage)))
})

test_that("the average rests on the years where both counts are available", {
  # A year whose reference total came back NA must not contribute its
  # comparison count to the numerator while contributing nothing to the
  # denominator: that inflates the average past every per-year share in the
  # same tibble, and the average also orders the topics in the plot.
  blk <- scopus_comparison_block(
    query = "q", query_type = "comparison", abridged = "a",
    years = 2018:2020, n = c(100, 500, 300), ref_n = c(1000, NA, 2000)
  )
  expect_equal(blk$comparison_percentage, c(10, NA, 15))
  # 400 over 3000, not 900 over 3000.
  expect_equal(unique(blk$average_comparison_percentage), 400 / 30)
  expect_true(is.na(blk$reference_n[2]))
})

test_that("the average is NA when no year has both counts", {
  blk <- scopus_comparison_block(
    query = "q", query_type = "comparison", abridged = "a",
    years = 2018:2019, n = c(100, 200), ref_n = c(NA_real_, NA_real_)
  )
  expect_true(all(is.na(blk$average_comparison_percentage)))
})

test_that("comparison counts are doubles, so billion-scale totals survive", {
  # Narrowing to a 32-bit integer here turned a broad query's counts into NA
  # while leaving its percentage populated, contradicting scopus_trend() and
  # scopus_intersections(), which both carry counts as doubles.
  blk <- scopus_comparison_block(
    query = "q", query_type = "comparison", abridged = "a",
    years = 2020, n = 3e9, ref_n = 3e9
  )
  expect_type(blk$n, "double")
  expect_type(blk$reference_n, "double")
  expect_equal(blk$n, 3e9)
  expect_equal(blk$reference_n, 3e9)
})

test_that("comparison rows are ordered by descending average", {
  local_scopus_test_env()
  httr2::local_mocked_responses(compare_mock())
  cmp <- scopus_compare_topics("ref", c("t2", "t1"), years = 2015:2016)
  comp <- cmp[cmp$query_type == "comparison", ]
  # t1 (avg 60) should appear before t2 (avg 24).
  expect_equal(unique(comp$abridged_query), c("t1", "t2"))
})

test_that("the reference baseline is included at 100%", {
  local_scopus_test_env()
  httr2::local_mocked_responses(compare_mock())
  cmp <- scopus_compare_topics("ref", "t1", years = 2015:2016)
  ref <- cmp[cmp$query_type == "reference", ]
  expect_true(all(ref$comparison_percentage == 100))
})

test_that("invalid inputs are rejected before any request", {
  local_scopus_test_env()
  expect_error(scopus_compare_topics("ref", character(0), 2015:2016),
               class = "scopus_error_bad_input")
  expect_error(scopus_compare_topics("ref", "t1", years = NULL),
               class = "scopus_error_bad_input")
  expect_error(scopus_compare_topics("", "t1", years = 2015),
               class = "scopus_error_bad_input")
})

test_that("a repeated comparison term is counted once and warned about", {
  local_scopus_test_env()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    compare_mock()(req)
  })
  cmp <- NULL
  expect_warning(
    cmp <- scopus_compare_topics("ref", c("t1", "t2", "t1"), years = 2019:2020),
    class = "scopus_warning_duplicate_terms"
  )
  # One count request per distinct term per year, plus the reference.
  expect_equal(calls, (2L + 1L) * 2L)
  expect_equal(sort(unique(cmp$abridged_query)), c("ref", "t1", "t2"))
  expect_equal(nrow(cmp), 6L)
  expect_equal(sum(cmp$abridged_query == "t1"), 2L)
})
