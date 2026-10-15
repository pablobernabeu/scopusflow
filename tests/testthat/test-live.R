# Live integration tests. These are skipped on CRAN and run only when a real key
# is configured and SCOPUSFLOW_LIVE_TESTS is set to "true". They make genuine
# network requests and consume a small amount of quota: about seven 'Scopus'
# Search requests and one Abstract Retrieval request, the latter drawing on its
# own weekly quota, which is the smaller of the two.
#
# The opt-in is a variable of the package's own. devtools::test(),
# testthat::test_local() and devtools::check() set NOT_CRAN themselves, so an
# opt-in through NOT_CRAN spent live quota on every local run by anyone who
# keeps the key in ~/.Renviron, as ?scopus_has_key recommends. It is checked
# before the key and the connection, so an ordinary run neither reads the key
# nor probes the network. .github/workflows/live-api-check.yaml sets it.
#
# Their job is the one thing the offline mocks cannot do: confirm the package
# still works against the live, evolving 'Scopus' API, so that a renamed field or
# a changed envelope is caught early rather than by a user's bug report.

skip_live <- function() {
  skip_on_cran()
  skip_if(!identical(Sys.getenv("SCOPUSFLOW_LIVE_TESTS"), "true"),
          "SCOPUSFLOW_LIVE_TESTS not set to true")
  skip_if(Sys.getenv("SCOPUS_API_KEY") == "", "SCOPUS_API_KEY not set")
  skip_if_offline()
}

test_that("the live tests stay dormant unless they are switched on", {
  # devtools::test(), testthat::test_local() and devtools::check() set NOT_CRAN
  # themselves, and ?scopus_has_key recommends keeping the key in ~/.Renviron,
  # so an opt-in through NOT_CRAN spent live quota on every local run of the
  # suite. The key here is a placeholder, and no test below runs.
  withr::local_envvar(
    NOT_CRAN = "true",
    SCOPUS_API_KEY = "not-a-real-key",
    SCOPUSFLOW_LIVE_TESTS = ""
  )
  cnd <- tryCatch({
    skip_live()
    NULL
  }, condition = function(cnd) cnd)
  expect_s3_class(cnd, "skip")
  expect_match(conditionMessage(cnd), "SCOPUSFLOW_LIVE_TESTS", fixed = TRUE)
})

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

test_that("a live abstract retrieval returns metadata and the abstract", {
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  # Abstract Retrieval draws on its own, smaller quota, and scopus_abstract()
  # degrades a per-identifier failure to an NA row with a warning. On a
  # rate-limited run that NA row would read here as schema drift, so a 429 is
  # recorded and skipped rather than failed; any other warning still surfaces.
  msgs <- character()
  ab <- withCallingHandlers(
    scopus_abstract("10.1103/PhysRevLett.116.061102"),
    warning = function(w) msgs <<- c(msgs, conditionMessage(w))
  )
  if (any(grepl("HTTP 429|rate limit", msgs, ignore.case = TRUE))) {
    skip("The Abstract Retrieval API rate-limited this run.")
  }
  expect_s3_class(ab, "scopus_abstracts")
  expect_equal(nrow(ab), 1L)
  expect_false(is.na(ab$title))
  # The default view is META_ABS, so the same request carries the abstract.
  expect_false(is.na(ab$abstract))
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

test_that("a live fetch with fields = 'extended' keeps populated document types", {
  # One more Search request. A renamed subtype or aggregationType field would
  # otherwise arrive as a column of NA values, which the offline mocks cannot
  # catch.
  skip_live()
  withr::local_options(scopusflow.api_key = NULL)
  recs <- scopus_fetch("TITLE-ABS-KEY(bibliometrics)", years = 2020, max_results = 5,
                       fields = "extended")
  expect_equal(names(recs), c(scopusflow:::scopus_records_columns(),
                              scopusflow:::scopus_extended_columns()))
  expect_gt(nrow(recs), 0)
  expect_true(any(!is.na(recs$doc_type)))
  expect_true(any(!is.na(recs$source_type)))
  expect_type(recs$open_access, "integer")
})
