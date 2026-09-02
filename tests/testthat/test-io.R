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

test_that("an empty record set round-trips through CSV", {
  empty <- scopus_records(list(entry = list()))
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(empty, path)
  back <- read_scopus_records(path)
  expect_equal(nrow(back), 0L)
  expect_type(back$year, "integer")
})

test_that("a COMPLETE-view authkeywords column survives the CSV round-trip", {
  recs <- scopus_records(
    list(entry = list(list(`prism:doi` = "10.1/a",
                           authkeywords = "graphene | supercapacitor"))),
    query = "q", view = "COMPLETE"
  )
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  back <- read_scopus_records(path)
  expect_true("authkeywords" %in% names(back))
  expect_equal(back$authkeywords, "graphene | supercapacitor")
})

test_that("a title with comma, quote and newline survives CSV round-trip", {
  recs <- scopus_records(list(entry = list(
    list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
         `dc:title` = "A \"tricky\", title\nwith breaks")
  )))
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  expect_equal(read_scopus_records(path)$title, recs$title)
})

test_that("non-ASCII names survive the CSV round trip in a non-UTF-8 locale", {
  # R translates a UTF-8 string to the native encoding on the way to a
  # connection, which in a C or single-byte locale spells every accented or
  # Cyrillic character as the literal text <U+00ED>.
  withr::local_locale(c(LC_CTYPE = "C"))
  recs <- scopus_records(list(entry = list(
    list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
         `dc:title` = "Graphene \u2013 a study",
         `dc:creator` = "A.I. Mtz-Enr\u00edquez; \u0414. \u0410. \u041c\u0430\u0447\u0435\u0440\u0435\u0442")
  )))
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  bytes <- rawToChar(readBin(path, "raw", file.size(path)))
  expect_false(grepl("<U+", bytes, fixed = TRUE))
  back <- read_scopus_records(path)
  expect_identical(back$authors, recs$authors)
  expect_identical(back$title, recs$title)
})

test_that("blank CSV fields read as missing, as other tools write them", {
  # pandas, Excel and the Python twin leave a missing value as an empty field
  # rather than the token NA, and an empty identifier would key every row alike.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "entry_number,scopus_id,doi,title,authors,year,date,publication,citations,query",
    "1,,,First,A,2020,2020-01-01,J,0,q",
    "2,,,Second,B,2021,2021-01-01,J,1,q"
  ), path)
  back <- read_scopus_records(path)
  expect_true(all(is.na(back$scopus_id)))
  expect_true(all(is.na(back$doi)))
  expect_equal(nrow(scopus_combine(back, back, dedupe = TRUE)), 4L)
})

test_that("a CSV that is not a record set is refused", {
  # Every schema column is filled in when absent, so a foreign file used to
  # read back as a well-formed set of empty records.
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(a = 1:3, b = letters[1:3]), path, row.names = FALSE)
  expect_error(read_scopus_records(path), class = "scopus_error_bad_input")
  expect_error(read_scopus_records(path), "Columns found: a, b.", fixed = TRUE)
})

test_that("a CSV holding part of the schema is read with a warning", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("doi,title", "10.1/a,First", "10.1/b,Second"), path)
  expect_warning(back <- read_scopus_records(path),
                 class = "scopus_warning_partial_schema")
  expect_equal(nrow(back), 2L)
  expect_equal(back$doi, c("10.1/a", "10.1/b"))
  expect_true(all(is.na(back$publication)))
  expect_true(is.integer(back$citations) && all(is.na(back$citations)))
})

test_that("an .rds that is not a record set is refused", {
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(mtcars, path)
  expect_error(read_scopus_records(path), class = "scopus_error_bad_input")
})

test_that("a record set written by the package reads back without a warning", {
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(make_records(), path)
  expect_no_warning(read_scopus_records(path))
})

test_that("the record CSV carries LF line endings on every platform", {
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(make_records(), path)
  expect_false(any(readBin(path, "raw", file.size(path)) == as.raw(0x0d)))
})

test_that("scopus_write_lines writes LF endings on every platform", {
  # The app's script download writes through this helper, so pinning it here
  # covers that path too.
  path <- withr::local_tempfile(fileext = ".R")
  scopusflow:::scopus_write_lines(c("library(scopusflow)", "example_records"), path)
  bytes <- readBin(path, "raw", file.size(path))
  expect_false(any(bytes == as.raw(0x0d)))
  expect_equal(readLines(path), c("library(scopusflow)", "example_records"))
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
