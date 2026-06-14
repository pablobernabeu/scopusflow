test_that("scopus_combine binds and renumbers entries", {
  a <- example_records
  b <- example_records
  out <- scopus_combine(a, b)
  expect_s3_class(out, "scopus_records")
  expect_equal(nrow(out), 12L)
  expect_equal(out$entry_number, 1:12)
})

test_that("scopus_combine de-duplicates by id then DOI", {
  out <- scopus_combine(example_records, example_records, dedupe = TRUE)
  expect_equal(nrow(out), 6L)
  expect_equal(out$entry_number, 1:6)
})

test_that("scopus_combine accepts a single list and rejects non-records", {
  out <- scopus_combine(list(example_records, example_records))
  expect_equal(nrow(out), 12L)
  expect_error(scopus_combine(data.frame(a = 1)), class = "scopus_error_bad_input")
})

test_that("c() method combines record sets", {
  out <- c(example_records, example_records)
  expect_s3_class(out, "scopus_records")
  expect_equal(nrow(out), 12L)
})

test_that("dedupe keeps records that have neither an id nor a DOI", {
  r <- scopus_records(list(entry = list(
    list(`dc:title` = "A"), list(`dc:title` = "B")
  )))
  out <- scopus_combine(r, r, dedupe = TRUE)
  expect_equal(nrow(out), 4L) # no keys, so nothing is treated as a duplicate
})

test_that("dedupe falls back to the DOI (case-insensitively) when the id is absent", {
  r1 <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/x"))))
  r2 <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/X"))))
  out <- scopus_combine(r1, r2, dedupe = TRUE)
  expect_equal(nrow(out), 1L)
})

test_that("coercion strips the scopus_records class", {
  tb <- tibble::as_tibble(example_records)
  expect_false(inherits(tb, "scopus_records"))
  expect_s3_class(tb, "tbl_df")
  df <- as.data.frame(example_records)
  expect_false(inherits(df, "scopus_records"))
  expect_true(is.data.frame(df))
})
