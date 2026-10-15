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

test_that("an extended record set round-trips through CSV, ISSN zeros and all", {
  # read_scopus_records() kept the core columns and authkeywords alone, so
  # every extended column was lost on the way back. The ISSN begins with
  # zeros, which a reader that inferred types would drop as well.
  fx <- extended_fixture()
  recs <- scopus_records(list(entry = list(fx$complete)), query = fx$query,
                         view = "COMPLETE", fields = "extended")
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  back <- read_scopus_records(path)
  expect_record_row(back, fx$expected$complete)
  expect_identical(back$issn, "00368075")

  # The .rds form restores the object exactly, as it does for the core fields.
  rds <- withr::local_tempfile(fileext = ".rds")
  write_scopus_records(recs, rds)
  expect_identical(read_scopus_records(rds), recs)
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
  # R translates a string to the session's native encoding on its way to a
  # connection, and in a C or single-byte locale it spells every character it
  # cannot encode as the text <U+00ED>, so the file no longer held the name.
  withr::local_locale(c(LC_CTYPE = "C"))
  recs <- scopus_records(list(entry = list(
    list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
         `dc:title` = "Graphene – a study",
         `dc:creator` = "A.I. Mtz-Enríquez")
  )))
  path <- withr::local_tempfile(fileext = ".csv")
  write_scopus_records(recs, path)
  bytes <- readBin(path, "raw", file.size(path))
  expect_false(grepl("<U+", rawToChar(bytes), fixed = TRUE))
  expect_true(grepRaw(charToRaw(enc2utf8("Mtz-Enríquez")), bytes, fixed = TRUE) > 0L)
  back <- read_scopus_records(path)
  expect_identical(back$authors, recs$authors)
  expect_identical(back$title, recs$title)
})

test_that("text files are written as UTF-8 in a non-UTF-8 locale", {
  # The search record, the app's script and the exports go through this helper.
  withr::local_locale(c(LC_CTYPE = "C"))
  path <- withr::local_tempfile(fileext = ".md")
  scopusflow:::scopus_write_lines(c("# Mtz-Enríquez", "Д. М."), path)
  bytes <- readBin(path, "raw", file.size(path))
  expect_identical(bytes, charToRaw(enc2utf8("# Mtz-Enríquez\nД. М.\n")))
})

test_that("a CSV the Python twin wrote reads back with its blanks missing", {
  # pandas, and so the Python twin, writes a missing value as an empty field,
  # where R writes NA. Read as "", a blank identifier was taken for an
  # identifier by the rule of scopusflow 0.4.0, which merged every such record
  # into one, while the Python twin reads the same file with the identifiers
  # missing and falls back to the DOI. The file is byte-identical to the Python
  # twin's tests/fixtures/blank-fields.csv, whose suite asserts the same.
  withr::local_locale(c(LC_CTYPE = "C"))
  fx <- read_scopus_records(test_path("fixtures", "blank-fields.csv"))
  expect_equal(nrow(fx), 5L)
  expect_identical(is.na(fx$scopus_id), c(TRUE, TRUE, TRUE, FALSE, TRUE))
  expect_identical(is.na(fx$doi), c(FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_true(is.na(fx$publication[5]))
  # The file is UTF-8 whatever the session's locale.
  expect_identical(fx$authors[1], "A.I. Mtz-Enríquez")
  # Rows 1 and 2 share a DOI in two spellings and carry no identifier, so every
  # rule keeps one of them, and the twins keep the same rows.
  for (rule in c("id_or_shared_doi", "id_or_doi", "id_then_doi")) {
    kept <- scopus_combine(fx, dedupe = rule)
    expect_identical(kept$title, fx$title[-2], label = rule)
  }
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
  # bibliometrix writes a 'Scopus' author without full stops.
  expect_identical(recs$authors[1], "Zhang F.")
  expect_equal(m$AU[1], "ZHANG F")
})
