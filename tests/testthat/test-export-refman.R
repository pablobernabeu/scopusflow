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
  # dc:creator is the first author alone. The list comes from the COMPLETE
  # view's author array.
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "Cost & benefit: 50% of $x",
         `dc:creator` = "Smith J.",
         author = list(list(surname = "Smith", `given-name` = "J."),
                       list(surname = "Doe", `given-name` = "A.")),
         `prism:coverDate` = "2021-01-01")
  )), view = "COMPLETE")
  bib <- as_bibtex(recs)
  expect_true(grepl("Cost \\& benefit: 50\\% of \\$x", bib, fixed = TRUE))
  expect_true(grepl("Smith, J. and Doe, A.", bib, fixed = TRUE))
  # Key is derived from first-author surname + year.
  expect_true(grepl("@article{smith2021,", bib, fixed = TRUE))
})

test_that("RIS gives each author of a COMPLETE record a line of its own", {
  fx <- complete_authors_fixture()
  ris <- as_ris(scopus_records(list(entry = list(fx$entry)), view = "COMPLETE"))
  expect_true(grepl(
    "AU  - Cong, Le\nAU  - Zhang, Feng\nAU  - Doudna, Jennifer A.\n", ris, fixed = TRUE
  ))
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

# The name and export fixtures are shared byte for byte with the Python suite,
# so both twins write the same names, titles and RIS tags.
author_names_fixture <- function() {
  jsonlite::fromJSON(test_path("fixtures", "author-names.json"), simplifyVector = FALSE)
}

# A record set of one record per name, each name its record's only author.
records_with_authors <- function(authors) {
  scopusflow:::scopus_coerce_records(
    data.frame(authors = authors, stringsAsFactors = FALSE)
  )
}

test_that("RIS writes each name in the shared fixture's RIS form", {
  cases <- author_names_fixture()$cases
  expect_gt(length(cases), 20L)
  inputs <- vapply(cases, function(case) case$input, character(1))
  entries <- strsplit(as_ris(records_with_authors(inputs)), "\n\n", fixed = TRUE)[[1]]
  for (i in seq_along(cases)) {
    expect_match(entries[i], paste0("\nAU  - ", cases[[i]]$ris, "\n"),
                 fixed = TRUE, label = cases[[i]]$input)
  }
})

test_that("BibTeX writes each name in the shared fixture's BibTeX form", {
  cases <- author_names_fixture()$cases
  inputs <- vapply(cases, function(case) case$input, character(1))
  entries <- strsplit(as_bibtex(records_with_authors(inputs)), "\n\n", fixed = TRUE)[[1]]
  for (i in seq_along(cases)) {
    expect_match(entries[i], paste0("\n  author = {", cases[[i]]$bibtex, "},\n"),
                 fixed = TRUE, label = cases[[i]]$input)
  }
})

test_that("the authors column and the citation keys are left as Scopus sent them", {
  recs <- records_with_authors(c("Zhang F.", "Kitchin J.R."))
  bib <- as_bibtex(recs)
  expect_identical(recs$authors, c("Zhang F.", "Kitchin J.R."))
  expect_match(bib, "@article{zhang,", fixed = TRUE)
  expect_match(bib, "@article{kitchin,", fixed = TRUE)
})

test_that("BibTeX titles protect words with capitals after their first letter", {
  recs <- scopusflow:::scopus_coerce_records(data.frame(
    title = "Bayesian (DNA) and mRNA: R&D on CRISPR-Cas9 in the U.S. and 5G",
    stringsAsFactors = FALSE
  ))
  expect_match(
    as_bibtex(recs),
    "title = {Bayesian ({DNA}) and {mRNA}: {R\\&D} on {CRISPR-Cas9} in the {U.S}. and {5G}},",
    fixed = TRUE
  )
  # RIS titles are plain text and stay as they are.
  expect_match(
    as_ris(recs),
    "TI  - Bayesian (DNA) and mRNA: R&D on CRISPR-Cas9 in the U.S. and 5G\n",
    fixed = TRUE
  )
})

test_that("a title word opening with an escape is braced twice", {
  # BibTeX reads a brace group that opens with a backslash as a special
  # character and lower-cases the letters inside it, so `{\#MeToo}` would
  # still print as "#metoo".
  recs <- scopusflow:::scopus_coerce_records(data.frame(
    title = "#MeToo, ~ABC and DNA in #science",
    stringsAsFactors = FALSE
  ))
  expect_match(
    as_bibtex(recs),
    "title = {{{\\#MeToo}}, {{\\textasciitilde{}ABC}} and {DNA} in \\#science},",
    fixed = TRUE
  )
})

test_that("RIS files the source under T2 and names the database and the EID", {
  recs <- scopus_records(list(entry = list(list(
    `dc:identifier` = "SCOPUS_ID:85000000201",
    `dc:title` = "A record",
    `prism:publicationName` = "Journal of Mocking"
  ))))
  ris <- as_ris(recs)
  expect_match(ris, "\nT2  - Journal of Mocking\n", fixed = TRUE)
  expect_false(grepl("JO  - ", ris, fixed = TRUE))
  expect_match(ris, "\nAN  - 2-s2.0-85000000201\n", fixed = TRUE)
  expect_match(ris, "\nDB  - Scopus\n", fixed = TRUE)
  # With no identifier there is no accession number to give.
  ris <- as_ris(scopus_records(list(entry = list(list(`dc:title` = "No identifier")))))
  expect_false(grepl("AN  - ", ris, fixed = TRUE))
  expect_match(ris, "\nDB  - Scopus\n", fixed = TRUE)
})

test_that("the export fixture renders to the shared BibTeX and RIS goldens", {
  # The goldens were written by hand from the rules above, not generated by
  # either twin, and both suites compare against the same bytes. The fixture
  # and the goldens hold non-ASCII names, which read.csv() and the file writer
  # handle in the session's native encoding.
  skip_if_not(l10n_info()[["UTF-8"]], "the session's locale is not UTF-8")
  recs <- read_scopus_records(test_path("fixtures", "export-fixture.csv"))
  expect_identical(nrow(recs), 6L)
  for (ext in c("bib", "ris")) {
    golden <- test_path("fixtures", paste0("export-fixture.", ext))
    out <- withr::local_tempfile(fileext = paste0(".", ext))
    if (ext == "bib") as_bibtex(recs, file = out) else as_ris(recs, file = out)
    expect_identical(
      readBin(out, "raw", file.size(out)),
      readBin(golden, "raw", file.size(golden)),
      label = paste("the", ext, "export of the fixture")
    )
  }
})

test_that("embedded newlines are folded so RIS stays line-structured", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = "Line one\nLine two", `dc:creator` = "Smith J.")
  )))
  ris <- as_ris(recs)
  expect_true(grepl("TI  - Line one Line two", ris, fixed = TRUE))
  expect_false(grepl("\nLine two", ris, fixed = TRUE))
})
