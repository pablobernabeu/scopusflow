make_records <- function() {
  scopus_records(load_page_fixture()[["search-results"]], query = "q")
}

test_that("CSV round-trips the standard schema", {
  recs <- make_records()
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  back <- read_scopus_records(path)
  expect_s3_class(back, "scopus_records")
  expect_equal(names(back), scopusflow:::scopus_records_columns())
  expect_equal(back$doi, recs$doi)
  expect_equal(back$year, recs$year)
  expect_type(back$citations, "integer")
})

test_that("RDS round-trips exactly", {
  recs <- make_records()
  path <- withr::local_tempfile(fileext = ".rds")
  write_scopus_records(recs, path)
  expect_identical(read_scopus_records(path), recs)
})

test_that("unsupported extensions are rejected", {
  recs <- make_records()
  path <- withr::local_tempfile(fileext = ".txt")
  expect_error(write_scopus_records(recs, path), class = "scopus_error_bad_input")
})

test_that("reading a missing file errors", {
  expect_error(read_scopus_records(tempfile(fileext = ".rds")),
               class = "scopus_error_bad_input")
})

test_that("writing requires scopus_records", {
  expect_error(write_scopus_records(data.frame(a = 1), tempfile(fileext = ".csv")),
               class = "scopus_error_bad_input")
})

test_that("as_bibliometrix maps to tag columns", {
  recs <- make_records()
  m <- as_bibliometrix(recs)
  expect_s3_class(m, "bibliometrixDB")
  expect_true(all(c("AU", "TI", "SO", "DI", "PY", "TC", "DB") %in% names(m)))
  expect_equal(unique(m$DB), "SCOPUS")
  expect_equal(m$DI, recs$doi)
  expect_equal(m$AU[1], toupper(recs$authors[1]))
})
