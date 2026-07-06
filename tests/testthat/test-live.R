# Live integration tests. These are skipped on CRAN and only run when a real key
# is configured and the user has opted in via NOT_CRAN. They make genuine network
# requests and consume a small amount of quota (about two requests).
#
# Their job is the one thing the offline mocks cannot do: confirm the package
# still works against the live, evolving 'Scopus' API, so that a renamed field or
# a changed envelope is caught early rather than by a user's bug report.

skip_live <- function() {
  skip_on_cran()
  skip_if_offline()
  skip_if(Sys.getenv("SCOPUS_API_KEY") == "", "SCOPUS_API_KEY not set")
  skip_if(Sys.getenv("NOT_CRAN") != "true", "NOT_CRAN not enabled")
}

test_that("a live count succeeds", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL) # use the real env var
  n <- scopus_count("TITLE-ABS-KEY(bibliometrics)", years = 2020)
  expect_true(is.numeric(n))
  expect_gte(n, 0)
})

test_that("a live fetch returns the documented, populated schema", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  recs <- scopus_fetch(
    "TITLE-ABS-KEY(bibliometrics)",
    years = 2020, max_results = 5
  )
  expect_s3_class(recs, "scopus_records")
  expect_equal(names(recs), scopusflow:::scopus_records_columns())
  expect_gt(nrow(recs), 0)

  # The schema must be genuinely populated, not all-NA: that is what catches the
  # API renaming prism:doi, dc:identifier, dc:title or prism:coverDate.
  expect_true(any(!is.na(recs$scopus_id)) || any(!is.na(recs$doi)))
  expect_true(any(!is.na(recs$title)))
  expect_true(any(!is.na(recs$year)))
})

test_that("a live response carries quota headers", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  recs <- scopus_fetch("TITLE-ABS-KEY(bibliometrics)", years = 2020, max_results = 1)
  quota <- attr(recs, "quota")
  expect_type(quota, "list")
  expect_true(all(c("limit", "remaining", "reset") %in% names(quota)))
})

test_that("a live abstract retrieval returns metadata", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  ab <- scopus_abstract("10.1103/PhysRevLett.116.061102")
  expect_s3_class(ab, "scopus_abstracts")
  expect_equal(nrow(ab), 1L)
  expect_false(is.na(ab$title))
})

test_that("a live trend returns annual counts", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  tr <- scopus_trend("TITLE-ABS-KEY(graphene)", years = 2018:2019)
  expect_s3_class(tr, "scopus_trend")
  expect_equal(nrow(tr), 2L)
  expect_true(all(tr$n >= 0))
})

test_that("a live COMPLETE-view fetch adds the authkeywords column", {
  # Same request cost as the STANDARD-view live fetch test above; the more
  # expensive per-document Abstract Retrieval path (references/keywords via
  # scopus_abstract()/scopus_corpus()) is deliberately not exercised by a
  # recurring live test here, since this file runs on an unattended schedule
  # and that path draws on its own, smaller, per-document quota. It has been
  # verified directly against a live key during development instead (see
  # dev/design-notes.md).
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  recs <- scopus_fetch("TITLE-ABS-KEY(bibliometrics)", years = 2020, max_results = 1, view = "COMPLETE")
  expect_true("authkeywords" %in% names(recs))
})
