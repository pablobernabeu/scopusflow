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
