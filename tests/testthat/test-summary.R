test_that("summary reports the expected figures", {
  s <- summary(example_records)
  expect_s3_class(s, "scopus_records_summary")
  expect_equal(s$n_records, 138L)
  expect_equal(s$years, c(2015L, 2024L))
  expect_equal(s$n_sources, 90L)
  # Eleven of the 138 records arrive without a DOI, as in any real harvest.
  expect_equal(s$n_with_doi, 127L)
  expect_equal(s$total_citations, 7015L)
  expect_equal(s$median_citations, 24)
  expect_equal(s$top_source, "ACS Applied Materials & Interfaces")
  expect_equal(s$top_cited, example_records$title[which.max(example_records$citations)])
})

test_that("summary copes with empty records and missing years", {
  empty <- scopus_records(list(entry = list()))
  s <- summary(empty)
  expect_equal(s$n_records, 0L)
  expect_true(all(is.na(s$years)))
  expect_true(is.na(s$total_citations))
})

test_that("summary counts document types and the errata and retracted items Scopus labels", {
  fx <- extended_fixture()
  typed <- function(code, description) {
    entry <- fx$standard
    entry$subtype <- code
    entry$subtypeDescription <- description
    entry
  }
  recs <- scopus_records(list(entry = list(
    typed("ar", "Article"), typed("er", "Erratum"),
    typed("tb", "Retracted"), typed("tb", "Retracted")
  )), view = "STANDARD", fields = "extended")
  s <- summary(recs)
  # Most frequent first, ties in byte order whatever the locale.
  expect_identical(s$doc_types, c(tb = 2L, ar = 1L, er = 1L))
  out <- paste(utils::capture.output(print(s)), collapse = " ")
  expect_match(out, "Document types: 2 tb, 1 ar and 1 er.", fixed = TRUE)
  expect_match(out, "Scopus labels 1 record an erratum (er) and 2 retracted (tb).",
               fixed = TRUE)

  articles <- summary(recs[recs$doc_type == "ar", ])
  out <- paste(utils::capture.output(print(articles)), collapse = " ")
  expect_match(out, "Scopus labels 0 records errata (er) and 0 retracted (tb).",
               fixed = TRUE)
})

test_that("summary of a set without document types says nothing about them", {
  s <- summary(example_records)
  expect_null(s$doc_types)
  out <- paste(utils::capture.output(print(s)), collapse = " ")
  expect_false(grepl("Document types", out, fixed = TRUE))
  expect_false(grepl("Scopus labels", out, fixed = TRUE))
})

test_that("summary prints a readable report", {
  out <- paste(utils::capture.output(print(summary(example_records))), collapse = " ")
  expect_match(out, "record")
  withr::local_output_sink(nullfile())
  expect_invisible(print(summary(example_records)))
})
