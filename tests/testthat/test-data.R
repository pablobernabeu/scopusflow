test_that("example_records is a valid bundled dataset", {
  expect_true(is_scopus_records(example_records))
  expect_equal(nrow(example_records), 138L)
  expect_equal(names(example_records), scopusflow:::scopus_records_columns())
})

test_that("example_records keeps the gaps a real harvest has", {
  # Not a defect: eleven records arrive without a DOI and two without a source
  # title, and they are kept so the reference-set examples can show how such
  # records are handled.
  expect_equal(sum(is.na(example_records$doi)), 11L)
  expect_equal(sum(is.na(example_records$publication)), 2L)
  # The records did not come from 'Scopus', so they carry no 'Scopus' id.
  expect_true(all(is.na(example_records$scopus_id)))
})

test_that("example_records is a complete harvest, so its year counts are real", {
  expect_setequal(unique(example_records$year), 2015:2024)
  expect_false(anyNA(example_records$year))
  expect_false(anyNA(example_records$citations))
})
