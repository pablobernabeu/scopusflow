# Live integration tests. These are skipped on CRAN and only run when a real
# key is configured and the user has opted in via NOT_CRAN. They make genuine
# network requests and consume quota.
test_that("a live count succeeds when explicitly enabled", {
  skip_on_cran()
  skip_if_offline()
  skip_if(Sys.getenv("SCOPUS_API_KEY") == "", "SCOPUS_API_KEY not set")
  skip_if(Sys.getenv("NOT_CRAN") != "true", "NOT_CRAN not enabled")

  withr::local_options(scopusflow.api_key = NULL) # use the real env var
  n <- scopus_count("TITLE-ABS-KEY(bibliometrics)", years = 2020)
  expect_true(is.numeric(n))
  expect_gte(n, 0L)
})
