test_that("scopus_plan builds a single-cell plan by default", {
  p <- scopus_plan("language learning")
  expect_s3_class(p, "scopus_plan")
  expect_true(is_scopus_plan(p))
  expect_equal(nrow(p), 1L)
  expect_equal(p$query, "language learning")
  expect_true(is.na(p$date))
})

test_that("field tags wrap the query", {
  p <- scopus_plan("learning", field = "TITLE-ABS-KEY")
  expect_equal(p$query, "TITLE-ABS-KEY(learning)")
})

test_that("field tags are normalised and validated", {
  expect_equal(scopus_plan("x", field = "title")$query, "TITLE(x)")
  expect_error(scopus_plan("x", field = "bad field"), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", field = ""), class = "scopus_error_bad_input")
})

test_that("year range collapses to a date string for partition none", {
  p <- scopus_plan("x", years = 2015:2020)
  expect_equal(p$date, "2015-2020")
  p1 <- scopus_plan("x", years = 2019)
  expect_equal(p1$date, "2019")
})

test_that("partition by year produces one cell per year", {
  p <- scopus_plan("x", years = c(2020, 2018, 2018, 2019), partition = "year")
  expect_equal(nrow(p), 3L)
  expect_equal(p$year, c(2018L, 2019L, 2020L))
  expect_equal(p$date, c("2018", "2019", "2020"))
})

test_that("partition by year requires years", {
  expect_error(scopus_plan("x", partition = "year"), class = "scopus_error_bad_input")
})

test_that("invalid inputs are rejected", {
  expect_error(scopus_plan(""), class = "scopus_error_bad_input")
  expect_error(scopus_plan(c("a", "b")), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", years = c(2010, 2010.5)), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", years = 1500), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", page_size = 0), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", page_size = 201), class = "scopus_error_bad_input")
  expect_error(scopus_plan("x", view = "FULL"))
})

test_that("page_size defaults to the most quota-efficient page per view", {
  expect_equal(scopus_plan("x")$page_size[1], 200L)            # STANDARD
  expect_equal(scopus_plan("x", view = "COMPLETE")$page_size[1], 25L)
})

test_that("page_size is bounded by the view's API limit", {
  expect_equal(scopus_plan("x", page_size = 200)$page_size[1], 200L)
  expect_error(scopus_plan("x", view = "COMPLETE", page_size = 26),
               class = "scopus_error_bad_input")
  expect_equal(scopus_plan("x", view = "COMPLETE", page_size = 25)$page_size[1], 25L)
})

test_that("a query the API cannot run as written is refused before any request", {
  local_scopus_test_env()
  sent <- 0L
  httr2::local_mocked_responses(function(req) {
    sent <<- sent + 1L
    mock_search_results(list(), total = 0)
  })
  # Pasted from the web interface's refinement panel, which the Search API
  # ignores, so the search would run unfiltered.
  refined <- 'x AND (LIMIT-TO (DOCTYPE, "ar"))'
  # The refusal is the offline check's own, not some other input error.
  refused <- function(expr, problem) {
    err <- expect_error(expr, class = "scopus_error_bad_input")
    expect_identical(err$problem, problem)
  }
  refused(scopus_plan(refined), "refinement")
  refused(scopus_count(refined), "refinement")
  refused(scopus_fetch(refined), "refinement")
  refused(scopus_trend(refined, years = 2020), "refinement")
  refused(scopus_compare_topics(refined, "y", years = 2020), "refinement")
  refused(scopus_compare_topics("x", refined, years = 2020), "refinement")
  refused(scopus_intersections(c(a = "x", b = refined)), "refinement")
  # A tagged query wrapped in another tag, which the API rejects with HTTP 400.
  refused(scopus_plan("TITLE(x)", field = "TITLE-ABS-KEY"), "double_field")
  refused(scopus_count("TITLE(x)", field = "title-abs-key"), "double_field")
  refused(
    scopus_compare_topics("x", c("y", "TITLE(z)"), years = 2020, field = "ABS"),
    "double_field"
  )
  refused(scopus_plan("(a OR b", field = "TITLE"), "unbalanced")
  expect_identical(sent, 0L)
})

test_that("a tagged concept is checked as written, without the field", {
  local_scopus_test_env()
  sent <- 0L
  httr2::local_mocked_responses(function(req) {
    sent <<- sent + 1L
    mock_search_results(list(), total = 3)
  })
  out <- scopus_intersections(
    c(a = "graphene", b = 'TITLE-ABS-KEY ( "working memory" )'),
    field = "TITLE-ABS-KEY"
  )
  expect_identical(
    out$query,
    c("TITLE-ABS-KEY(graphene)", 'TITLE-ABS-KEY ( "working memory" )')
  )
  expect_identical(sent, 2L)
})

test_that("INDEXTERMS() warns and the plan is still built", {
  expect_warning(
    p <- scopus_plan("INDEXTERMS(memory)"),
    class = "scopus_warning_query_syntax"
  )
  expect_identical(p$query, "INDEXTERMS(memory)")
})

test_that("plan prints without error", {
  expect_output(print(scopus_plan("x", years = 2018:2019, partition = "year")), "cell")
})
