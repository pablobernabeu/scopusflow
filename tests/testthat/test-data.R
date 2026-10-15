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

test_that("example_records stores U+2010 as the ASCII hyphen, as the Python twin's does", {
  # The shared CSV keeps OpenAlex's U+2010 in five author names. Both twins
  # write it as "-", so the two corpora hold the same strings.
  text <- unlist(example_records[vapply(example_records, is.character, logical(1))],
                 use.names = FALSE)
  expect_false(any(grepl("\u2010", text, fixed = TRUE)))
  expect_true(all(c("Chih-Tao Chien", "Zhong-Shuai Wu", "Maher F. El-Kady",
                    "Xiu-Yan Fu", "Woo-Jae Lee") %in% example_records$authors))
})

test_that("example_records is a complete harvest, so its year counts are real", {
  expect_setequal(unique(example_records$year), 2015:2024)
  expect_false(anyNA(example_records$year))
  expect_false(anyNA(example_records$citations))
})

# The bundled records came from OpenAlex's exact-phrase search for "graphene
# supercapacitor" in titles and abstracts, limited to journal articles.
# 'Scopus' joins the words of an unquoted phrase with AND, so the unquoted
# TITLE-ABS-KEY(graphene supercapacitor) the articles gave as the corpus's own
# search matches far more, about a hundred times as many records in OpenAlex.
# A methods paragraph built on it described a search that never ran.
#
# These tests read the package sources, from the source tree under
# devtools::test() and from the copy R CMD check extracts beside its check
# directory.
scopus_doc_root <- function() {
  skip_on_cran()
  roots <- c(test_path("..", ".."), test_path("..", "..", "00_pkg_src", "scopusflow"))
  for (root in roots) {
    if (dir.exists(file.path(root, "vignettes")) && dir.exists(file.path(root, "man"))) {
      return(root)
    }
  }
  skip("the package sources are not available")
}

# A page with its white space folded and the comment markers at the start of
# its lines dropped, so a sentence wrapped across lines, in prose or in an
# example's comment, still matches.
scopus_doc_text <- function(root, ...) {
  lines <- readLines(file.path(root, ...), encoding = "UTF-8", warn = FALSE)
  lines <- sub("^\\s*#+'?", "", lines)
  gsub("\\s+", " ", paste(lines, collapse = " "))
}

test_that("no page presents the unquoted phrase as the corpus's search", {
  root <- scopus_doc_root()
  paths <- c(
    file.path("vignettes", list.files(file.path(root, "vignettes"), "\\.Rmd$")),
    file.path("man", list.files(file.path(root, "man"), "\\.Rd$"))
  )
  claims <- c(
    "search the bundled records came from",
    "describes the search that produced the bundled corpus",
    "the plan describes the same search",
    "reproduces the yearly counts that query returns",
    "the publications per year its query returns",
    "its row count is the total that query returned",
    "Running the equivalent query",
    "TITLE-ABS-KEY(graphene supercapacitor)"
  )
  found <- character()
  for (path in paths) {
    text <- scopus_doc_text(root, path)
    hits <- claims[vapply(claims, grepl, logical(1), x = text, fixed = TRUE)]
    found <- c(found, if (length(hits)) paste(path, hits, sep = ": "))
  }
  expect_identical(found, character())
  for (path in c("vignettes/scopusflow.Rmd", "vignettes/plans-and-quota.Rmd",
                 "vignettes/analysing-a-literature.Rmd", "man/example_records.Rd")) {
    expect_match(scopus_doc_text(root, path), "OpenAlex's exact-phrase search",
                 fixed = TRUE, info = path)
  }
})

test_that("the demonstration searches quote the phrase", {
  root <- scopus_doc_root()
  # Quoted, the phrase is searched as the corpus searched it.
  plan <- "scopus_plan\\( ?'\"graphene supercapacitor\"'"
  for (path in c("vignettes/scopusflow.Rmd", "vignettes/plans-and-quota.Rmd",
                 "man/scopus_fetch_plan.Rd", "man/scopus_search_report.Rd")) {
    expect_match(scopus_doc_text(root, path), plan, info = path)
  }
  expect_match(scopus_doc_text(root, "vignettes/analysing-a-literature.Rmd"),
               "scopus_trend('\"graphene supercapacitor\"'", fixed = TRUE)
  # The dataset's help names the query a 'Scopus' run of the phrase sends,
  # where it pointed at "the equivalent query".
  expect_match(scopus_doc_text(root, "man/example_records.Rd"),
               "TITLE-ABS-KEY(\"graphene supercapacitor\")", fixed = TRUE)
  # That holds only if no page sends the phrase unquoted, the live harvest the
  # tracking article sets against the bundled baseline included.
  pages <- c(
    file.path("vignettes", list.files(file.path(root, "vignettes"), "\\.Rmd$")),
    file.path("man", list.files(file.path(root, "man"), "\\.Rd$"))
  )
  unquoted <- "scopus_(plan|fetch|count|trend)\\( ?\"graphene supercapacitor\""
  sent <- pages[vapply(pages, function(path) {
    grepl(unquoted, scopus_doc_text(root, path))
  }, logical(1))]
  expect_identical(sent, character())
  tracking <- scopus_doc_text(root, "vignettes/tracking-literature-change.Rmd")
  expect_match(tracking, "scopus_fetch('\"graphene supercapacitor\"'", fixed = TRUE)
  # A live pull is diffed against a baseline of the reader's own, not against
  # the bundled one.
  expect_match(tracking, "the bundled one came from OpenAlex", fixed = TRUE)
})

test_that("the search-record demonstrations say they describe no search that was run", {
  root <- scopus_doc_root()
  for (path in c("vignettes/scopusflow.Rmd", "vignettes/plans-and-quota.Rmd",
                 "man/scopus_search_report.Rd")) {
    expect_match(scopus_doc_text(root, path), "describes no search that was run",
                 fixed = TRUE, info = path)
  }
  # The attributes set by hand, the reported totals among them, are the
  # corpus's own counts.
  for (path in c("vignettes/plans-and-quota.Rmd", "man/scopus_search_report.Rd")) {
    expect_match(scopus_doc_text(root, path), "illustrative", fixed = TRUE, info = path)
  }
})

test_that("the keywords-and-references article prints nothing invented beneath a live call", {
  root <- scopus_doc_root()
  text <- scopus_doc_text(root, "vignettes", "keywords-and-references.Rmd")
  # The article printed invented author keywords, four references for a paper
  # citing 103 works, names in a form the parser never writes and a quota
  # nobody observed, all beneath real calls on a real DOI, built in hidden
  # chunks. Only the knitr set-up chunk is hidden now.
  expect_false(grepl("deep learning | neural networks", text, fixed = TRUE))
  expect_false(grepl("Gradient-based learning applied to document recognition",
                     text, fixed = TRUE))
  expect_false(grepl("LeCun Y.", text, fixed = TRUE))
  expect_false(grepl("24999", text, fixed = TRUE))
  expect_identical(lengths(regmatches(text, gregexpr("include = FALSE", text, fixed = TRUE))), 1L)
  # The shapes are built in view from the bundled corpus, and keywords are
  # counted in pairs over its titles.
  expect_match(text, "example_records", fixed = TRUE)
  expect_match(text, "combn(", fixed = TRUE)
})
