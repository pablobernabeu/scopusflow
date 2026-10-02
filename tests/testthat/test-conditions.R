# Every input error belongs to the scopus_error family, as R/conditions.R, the
# README and the vignettes promise, so `tryCatch(scopus_error = ...)` sees it.
# Each call below fails its validation before any request could be made; the
# mock turns a stray request into a test failure.

expect_bad_input <- function(expr) {
  cnd <- tryCatch(expr, error = identity)
  expect_s3_class(cnd, "scopus_error_bad_input")
  expect_s3_class(cnd, "scopus_error")
  invisible(cnd)
}

test_that("the package's own validators raise scopus_error", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    stop("No request should be made for invalid input.")
  })
  expect_bad_input(scopus_count(""))
  expect_bad_input(scopus_count("   "))
  expect_bad_input(scopus_count("x", years = 1500))
  expect_bad_input(scopus_count("x", years = 2020.5))
  expect_bad_input(scopus_count("x", field = "TITLE ABS"))
  expect_bad_input(scopus_plan("x", partition = "year"))
  expect_bad_input(scopus_fetch("x", max_results = 0))
  expect_bad_input(scopus_fetch_plan(list()))
  expect_bad_input(scopus_query(""))
  expect_bad_input(scopus_top(data.frame()))
  expect_bad_input(scopus_top(example_records, n = 0))
  expect_bad_input(as_bibtex(data.frame()))
  expect_bad_input(read_scopus_records(""))
  expect_bad_input(scopus_abstract("x", include = "figures"))
  expect_bad_input(scopus_search_report("not a record set"))
})

test_that("an invalid choice among fixed values raises scopus_error_bad_input", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    stop("No request should be made for invalid input.")
  })
  # These went through rlang::arg_match(), whose bare rlang_error sat outside
  # both classes.
  expect_bad_input(scopus_plan("x", partition = "month"))
  expect_bad_input(scopus_plan("x", view = "BOGUS"))
  expect_bad_input(scopus_count("x", view = "BOGUS"))
  expect_bad_input(scopus_fetch("x", view = "BOGUS"))
  expect_bad_input(scopus_trend("x", years = 2020:2021, view = "BOGUS"))
  expect_bad_input(scopus_compare_topics("x", "y", years = 2020, view = "BOGUS"))
  expect_bad_input(scopus_intersections(c(a = "x", b = "y"), view = "BOGUS"))
  expect_bad_input(scopus_top(example_records, by = "doi"))
  expect_bad_input(scopus_abstract("x", by = "eid"))
  expect_bad_input(scopus_corpus(example_records, by = "eid"))
  expect_bad_input(scopus_corpus(example_records, view = "META"))
  expect_bad_input(scopus_query("a", "b", .op = "XOR"))
  report <- scopus_search_report(example_records)
  expect_bad_input(format(report, style = "html"))
})

test_that("a re-raised choice error keeps rlang's message and argument name", {
  cnd <- expect_bad_input(scopus_plan("x", partition = "month"))
  msg <- conditionMessage(cnd)
  expect_match(msg, "`partition` must be one of", fixed = TRUE)
  expect_match(msg, "\"month\"", fixed = TRUE)
  # The error is reported against the user's call, not the internal helper.
  expect_identical(cnd$call[[1]], quote(scopus_plan))
  # A non-character value is refused under the same classes.
  expect_bad_input(scopus_count("x", view = 1))
})

test_that("scopus_match_arg returns the chosen value and the default's first", {
  f <- function(mode = c("fast", "slow")) scopus_match_arg(mode, c("fast", "slow"))
  expect_identical(f(), "fast")
  expect_identical(f("slow"), "slow")
  cnd <- expect_bad_input(f("medium"))
  expect_match(conditionMessage(cnd), "`mode` must be one of", fixed = TRUE)
  # An error raised while evaluating the argument is the caller's own, not an
  # invalid choice, and keeps its class.
  cnd <- tryCatch(f(rlang::abort("upstream", class = "upstream_error")),
                  error = identity)
  expect_s3_class(cnd, "upstream_error")
  expect_false(inherits(cnd, "scopus_error"))
})

test_that("a scopus_error handler now sees input errors", {
  out <- tryCatch(scopus_count("x", years = 1500),
                  scopus_error = function(e) "caught as scopus_error",
                  error = function(e) "fell through to error")
  expect_identical(out, "caught as scopus_error")
})
