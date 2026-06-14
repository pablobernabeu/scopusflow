test_that("summary reports the expected figures", {
  s <- summary(example_records)
  expect_s3_class(s, "scopus_records_summary")
  expect_equal(s$n_records, 6L)
  expect_equal(s$years, c(2016L, 2021L))
  expect_equal(s$n_sources, 5L)
  expect_equal(s$n_with_doi, 6L)
  expect_equal(s$total_citations, 5505L)
  expect_equal(s$median_citations, 299)
  expect_equal(s$top_source, "Nature")
  expect_equal(s$top_cited, example_records$title[which.max(example_records$citations)])
})

test_that("summary copes with empty records and missing years", {
  empty <- scopus_records(list(entry = list()))
  s <- summary(empty)
  expect_equal(s$n_records, 0L)
  expect_true(all(is.na(s$years)))
  expect_true(is.na(s$total_citations))
})

test_that("summary prints a readable report", {
  out <- paste(cli::cli_fmt(print(summary(example_records))), collapse = " ")
  expect_match(out, "record")
  expect_invisible(print(summary(example_records)))
})
