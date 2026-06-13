test_that("records normalise from the static fixture", {
  results <- load_page_fixture()[["search-results"]]
  recs <- scopus_records(results, query = "TITLE(example)")
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 3L)
  expect_equal(recs$scopus_id, c("85000000001", "85000000002", "85000000003"))
  expect_equal(recs$doi[1], "10.1000/example.001")
  expect_equal(recs$year, c(2019L, 2020L, 2021L))
  expect_equal(recs$citations, c(12L, 5L, 0L))
  expect_equal(recs$entry_number, 1:3)
  expect_true(all(recs$query == "TITLE(example)"))
})

test_that("missing fields become NA", {
  recs <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/x"))))
  expect_equal(recs$doi, "10.1/x")
  expect_true(is.na(recs$title))
  expect_true(is.na(recs$year))
  expect_true(is.na(recs$citations))
})

test_that("the empty-result sentinel yields zero rows", {
  recs <- scopus_records(list(entry = list(list(error = "Result set was empty"))))
  expect_equal(nrow(recs), 0L)
  expect_equal(names(recs), scopusflow:::scopus_records_columns())
})

test_that("an empty entry list yields a typed zero-row tibble", {
  recs <- scopus_records(list(entry = list()))
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 0L)
  expect_type(recs$year, "integer")
})

test_that("scopus_records is idempotent", {
  recs <- scopus_records(load_page_fixture()[["search-results"]])
  expect_identical(scopus_records(recs), recs)
})

test_that("is_scopus_records discriminates", {
  expect_true(is_scopus_records(scopus_records(list(entry = list()))))
  expect_false(is_scopus_records(data.frame(a = 1)))
})

test_that("bad input is rejected", {
  expect_error(scopus_records(42), class = "scopus_error_bad_input")
})
