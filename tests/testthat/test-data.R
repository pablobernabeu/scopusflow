test_that("example_records is a valid bundled dataset", {
  expect_true(is_scopus_records(example_records))
  expect_equal(nrow(example_records), 3L)
  expect_equal(names(example_records), scopusflow:::scopus_records_columns())
  expect_false(anyNA(example_records$doi))
})
