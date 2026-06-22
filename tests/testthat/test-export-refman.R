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
