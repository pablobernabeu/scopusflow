count_matches <- function(pattern, x) {
  m <- gregexpr(pattern, x, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1] == -1L) 0L else length(m)
}

test_that("as_bibtex emits one @article entry per record with core fields", {
  bib <- as_bibtex(example_records)
  expect_type(bib, "character")
  expect_length(bib, 1L)
  expect_equal(count_matches("@article{", bib), nrow(example_records))
  expect_true(grepl("title = {", bib, fixed = TRUE))
  expect_true(grepl("author = {", bib, fixed = TRUE))
  expect_true(grepl("doi = {", bib, fixed = TRUE))
  # Each entry closes its brace.
  expect_equal(count_matches("\n}", bib), nrow(example_records))
})

test_that("as_ris emits a JOUR record per row, terminated with ER", {
  ris <- as_ris(example_records)
  expect_equal(count_matches("TY  - JOUR", ris), nrow(example_records))
  expect_equal(count_matches("ER  - ", ris), nrow(example_records))
  expect_true(grepl("AU  - ", ris, fixed = TRUE))
  expect_true(grepl("DO  - ", ris, fixed = TRUE))
})

test_that("BibTeX escapes special characters and splits authors", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "Cost & benefit: 50% of $x",
         `dc:creator` = list("Smith J.", "Doe A."),
         `prism:coverDate` = "2021-01-01")
  )))
  bib <- as_bibtex(recs)
  expect_true(grepl("Cost \\& benefit: 50\\% of \\$x", bib, fixed = TRUE))
  expect_true(grepl("Smith J. and Doe A.", bib, fixed = TRUE))
  # Key is derived from first-author surname + year.
  expect_true(grepl("@article{smith2021,", bib, fixed = TRUE))
})

test_that("authors joined without a space after the semicolon are still split", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "T", `dc:creator` = "Smith J.;Doe A.",
         `prism:coverDate` = "2021-01-01")
  )))
  expect_true(grepl("author = {Smith J. and Doe A.}", as_bibtex(recs), fixed = TRUE))
  expect_true(grepl("AU  - Smith J.\nAU  - Doe A.", as_ris(recs), fixed = TRUE))
})

test_that("missing fields are skipped, not emitted as NA", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "Untitled with no doi")
  )))
  bib <- as_bibtex(recs)
  ris <- as_ris(recs)
  expect_false(grepl("NA", bib, fixed = TRUE))
  expect_false(grepl("doi = {", bib, fixed = TRUE))
  expect_false(grepl("DO  - ", ris, fixed = TRUE))
})

test_that("file= writes and returns invisibly", {
  path <- file.path(tempdir(), "refs.bib")
  res <- withVisible(as_bibtex(example_records, file = path))
  expect_false(res$visible)
  expect_true(file.exists(path))
  expect_match(paste(readLines(path), collapse = "\n"), "@article{", fixed = TRUE)
})

test_that("file exports carry LF line endings on every platform", {
  bib <- withr::local_tempfile(fileext = ".bib")
  as_bibtex(example_records[1:3, ], file = bib)
  expect_false(any(readBin(bib, "raw", file.size(bib)) == as.raw(0x0d)))

  ris <- withr::local_tempfile(fileext = ".ris")
  as_ris(example_records[1:3, ], file = ris)
  expect_false(any(readBin(ris, "raw", file.size(ris)) == as.raw(0x0d)))
})

test_that("file exports keep non-ASCII names intact in a non-UTF-8 locale", {
  withr::local_locale(c(LC_CTYPE = "C"))
  recs <- scopus_records(list(entry = list(
    list(`dc:creator` = "A.I. Mtz-Enr\u00edquez",
         `dc:title` = "Graphene \u2013 a study",
         `prism:coverDate` = "2021-01-01")
  )))
  bib <- withr::local_tempfile(fileext = ".bib")
  as_bibtex(recs, file = bib)
  text <- rawToChar(readBin(bib, "raw", file.size(bib)))
  expect_false(grepl("<U+", text, fixed = TRUE))
  expect_true(grepl(enc2utf8("Mtz-Enr\u00edquez"), text, fixed = TRUE, useBytes = TRUE))

  ris <- withr::local_tempfile(fileext = ".ris")
  as_ris(recs, file = ris)
  expect_false(grepl("<U+", rawToChar(readBin(ris, "raw", file.size(ris))), fixed = TRUE))
})

test_that("export rejects a non-records object", {
  expect_error(as_bibtex(data.frame(a = 1)), class = "scopus_error_bad_input")
  expect_error(as_ris(mtcars), class = "scopus_error_bad_input")
})

test_that("colliding citation keys are disambiguated", {
  recs <- scopus_records(list(entry = list(
    list(`dc:creator` = "Smith J.", `prism:coverDate` = "2021-01-01", `dc:title` = "First"),
    list(`dc:creator` = "Smith K.", `prism:coverDate` = "2021-06-01", `dc:title` = "Second")
  )))
  bib <- as_bibtex(recs)
  expect_true(grepl("@article{smith2021,", bib, fixed = TRUE))
  expect_true(grepl("@article{smith2021a,", bib, fixed = TRUE))
})

test_that("a literal backslash is escaped without mangling its braces", {
  recs <- scopus_records(list(entry = list(list(`dc:title` = "path\\to\\x"))))
  bib <- as_bibtex(recs)
  expect_true(grepl("\\textbackslash{}", bib, fixed = TRUE))
  expect_false(grepl("textbackslash\\{", bib, fixed = TRUE))
})

test_that("embedded newlines are folded so RIS stays line-structured", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "Line one\nLine two", `dc:creator` = "Smith J.")
  )))
  ris <- as_ris(recs)
  expect_true(grepl("TI  - Line one Line two", ris, fixed = TRUE))
  expect_false(grepl("\nLine two", ris, fixed = TRUE))
})

test_that("a record carrying a Scopus identifier exports it as a note", {
  # example_records has no identifiers, so the note, the N1 line and the key
  # fallbacks are the lines a live harvest always runs through and the fixtures
  # never reach.
  recs <- scopus_records(load_page_fixture()[["search-results"]])
  expect_match(as_bibtex(recs), "note = {Scopus ID: 85000000001},", fixed = TRUE)
  expect_match(as_ris(recs), "N1  - Scopus ID: 85000000001", fixed = TRUE)
})

test_that("a citation key falls back to the identifier, then to a constant", {
  expect_equal(scopus_bibtex_key(NA_character_, 2020L, "85000000001"),
               "scopus85000000001")
  expect_equal(scopus_bibtex_key(NA_character_, NA_integer_, NA_character_),
               "scopusrecord")
})

test_that("repeated citation keys are suffixed past the alphabet", {
  keys <- scopus_disambiguate(rep("k", 28L))
  expect_equal(keys[1], "k")
  expect_equal(keys[2], "ka")
  expect_equal(keys[27], "kz")
  expect_equal(keys[28], "k27")
  expect_false(anyDuplicated(keys) > 0L)
})

test_that("a backslash beside a brace is escaped in one pass", {
  # The escaping runs over whole columns, so the braces its own replacements
  # introduce must not be escaped a second time.
  recs <- scopus_records(list(entry = list(list(
    `dc:title` = "Back\\slash beside {braces} & 50%",
    `dc:creator` = "M\\c{}Doe A.",
    `prism:coverDate` = "2021-01-01"
  ))))
  bib <- as_bibtex(recs)
  expect_match(
    bib,
    "title = {Back\\textbackslash{}slash beside \\{braces\\} \\& 50\\%},",
    fixed = TRUE
  )
  expect_match(bib, "author = {M\\textbackslash{}c\\{\\}Doe A.},", fixed = TRUE)
})

test_that("a field holding the control character used to park backslashes escapes too", {
  expect_equal(
    scopus_bibtex_escape(c("a\001b\\c{d}", "plain\\z")),
    c("a\001b\\textbackslash{}c\\{d\\}", "plain\\textbackslash{}z")
  )
})

test_that("an empty record set exports as an empty string", {
  empty <- scopus_records(list(entry = list()))
  expect_equal(as_bibtex(empty), "")
  expect_equal(as_ris(empty), "")
})
