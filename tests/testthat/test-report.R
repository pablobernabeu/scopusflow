# The search report is written for a methods section, so most of what is
# tested here is what it refuses to say: no completeness without a reported
# total, no date without a recorded one, no duplicate count without a merge.

# A harvest with every provenance attribute a live run records, assembled by
# hand because the bundled corpus carries none of them.
report_fixture <- function(plan = NULL, cells = TRUE) {
  plan <- plan %||% scopus_plan("graphene supercapacitor", years = 2015:2024,
                                field = "TITLE-ABS-KEY", partition = "year")
  recs <- example_records
  attr(recs, "plan") <- plan
  attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
  attr(recs, "scopusflow_version") <- "0.3.0"
  attr(recs, "paging") <- "offset"
  if (isTRUE(cells)) {
    n <- as.integer(table(example_records$year))
    attr(recs, "cell_totals") <- tibble::tibble(
      cell = seq_along(n), date = as.character(2015:2024),
      n_records = n, reported_total = as.numeric(n)
    )
  }
  recs
}

test_that("a report from a plan and records carries the recorded facts", {
  report <- scopus_search_report(report_fixture())
  expect_s3_class(report, "scopus_search_report")
  expect_equal(report$query, "graphene supercapacitor")
  expect_equal(report$expression, "TITLE-ABS-KEY(graphene supercapacitor)")
  expect_equal(report$field, "TITLE-ABS-KEY")
  expect_equal(report$view, "STANDARD")
  expect_equal(report$page_size, 200L)
  expect_equal(report$paging, "offset")
  expect_equal(report$partition, "year")
  expect_equal(report$n_cells, 10L)
  expect_equal(report$years, "2015 to 2024")
  expect_equal(report$n_records, 138L)
  expect_equal(report$n_with_doi, 127L)
  expect_equal(report$reported_total, 138)
  expect_equal(nrow(report$cells), 10L)
})

test_that("the readable report and the paragraph state the recorded numbers", {
  report <- scopus_search_report(report_fixture())
  text <- format(report, style = "report")
  expect_true(grepl("Date searched: 2026-07-22 09:15:00 UTC", text, fixed = TRUE))
  expect_true(grepl("Records retrieved: 138", text, fixed = TRUE))
  expect_true(grepl("Records carrying a DOI: 127 of 138", text, fixed = TRUE))
  expect_true(grepl("every record the API reported as matching was retrieved",
                    text, fixed = TRUE))

  para <- format(report, style = "paragraph")
  expect_length(para, 1L)
  expect_true(grepl("on 22 July 2026", para, fixed = TRUE))
  expect_true(grepl("retrieved 138 records", para, fixed = TRUE))
  expect_true(grepl("127 carry a DOI", para, fixed = TRUE))
  expect_true(grepl("scopusflow 0.3.0", para, fixed = TRUE))
})

test_that("an unrun plan claims nothing about a harvest", {
  plan <- scopus_plan("x", years = 2019:2021, partition = "year")
  report <- scopus_search_report(plan)
  expect_true(is.na(report$n_records))
  expect_true(is.na(report$searched_at))
  expect_true(is.na(report$reported_total))
  text <- format(report, style = "report")
  expect_true(grepl("Records retrieved: none, this plan has not been run",
                    text, fixed = TRUE))
  expect_false(grepl("Completeness: every", text, fixed = TRUE))
  expect_true(grepl("The search described here has not been run.",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("an absent retrieval time is never replaced by the current time", {
  recs <- report_fixture()
  attr(recs, "retrieved_at") <- NULL
  report <- scopus_search_report(recs)
  expect_true(is.na(report$searched_at))
  text <- format(report, style = "report")
  expect_true(grepl("Date searched: unrecorded, this set does not carry the time it was retrieved",
                    text, fixed = TRUE))
  expect_false(grepl(format(Sys.time(), "%Y-%m-%d"), text, fixed = TRUE))
  expect_true(grepl("on a date this record does not carry",
                    format(report, style = "paragraph"), fixed = TRUE))
  # Item 13 moves to the author's side of the map.
  expect_equal(report$prisma$source[13], "author")
})

test_that("an unrecorded total means no completeness figure", {
  recs <- report_fixture(cells = FALSE)
  report <- scopus_search_report(recs)
  expect_true(is.na(report$reported_total))
  text <- format(report, style = "report")
  expect_true(grepl("Records reported as matching: unrecorded, the API's own count did not travel with this set",
                    text, fixed = TRUE))
  expect_true(grepl("Completeness: unrecorded, since the number of records the API reported as matching is not known",
                    text, fixed = TRUE))
  expect_true(grepl("cannot be shown to be complete",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a total reported for only some cells gives no overall figure", {
  recs <- report_fixture()
  totals <- attr(recs, "cell_totals")
  totals$reported_total[c(2L, 5L)] <- NA_real_
  attr(recs, "cell_totals") <- totals
  report <- scopus_search_report(recs)
  expect_true(is.na(report$reported_total))
  expect_equal(report$cells_reported, 8L)
  expect_true(grepl("unrecorded for 2 of 10 cells, so no overall figure is given",
                    format(report, style = "report"), fixed = TRUE))
  expect_true(grepl("missing for 2 of the 10 cells",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a shortfall is reported as incomplete rather than smoothed over", {
  recs <- report_fixture()
  totals <- attr(recs, "cell_totals")
  totals$reported_total[3L] <- totals$reported_total[3L] + 20
  attr(recs, "cell_totals") <- totals
  report <- scopus_search_report(recs)
  expect_equal(report$reported_total, 158)
  expect_true(grepl("138 of the 158 records reported as matching were retrieved",
                    format(report, style = "report"), fixed = TRUE))
  expect_true(grepl("(2017): 10 retrieved, 30 reported, incomplete",
                    format(report, style = "report"), fixed = TRUE))
  expect_true(grepl("so the harvest is incomplete",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("duplicates are reported only where a merge recorded them", {
  recs <- report_fixture()
  report <- scopus_search_report(recs)
  expect_true(is.na(report$duplicates_removed))
  expect_true(grepl("Duplicates removed: unrecorded, no de-duplication step was recorded for this set",
                    format(report, style = "report"), fixed = TRUE))
  expect_equal(report$prisma$source[16], "author")

  attr(recs, "combined") <- list(n_in = 149L, n_out = 138L, n_removed = 11L,
                                 deduplicated = TRUE)
  deduped <- scopus_search_report(recs)
  expect_equal(deduped$duplicates_removed, 11L)
  expect_equal(deduped$prisma$source[16], "record")
  expect_true(grepl("Duplicates removed: 11 of 149 combined records",
                    format(deduped, style = "report"), fixed = TRUE))

  attr(recs, "combined") <- list(n_in = 276L, n_out = 276L, n_removed = 0L,
                                 deduplicated = FALSE)
  plain <- scopus_search_report(recs)
  expect_equal(plain$prisma$source[16], "author")
  expect_true(grepl("none, the sets were combined without de-duplication",
                    format(plain, style = "report"), fixed = TRUE))
})

test_that("the PRISMA 2020 identification counts reconcile with the set", {
  # The flow diagram subtracts the duplicates removed from the records
  # identified to reach the records screened, so identification is counted
  # before the merge dropped anything: 149 less 11 is the 138 rows held.
  recs <- report_fixture()
  attr(recs, "combined") <- list(n_in = 149L, n_out = 138L, n_removed = 11L,
                                 deduplicated = TRUE)
  text <- format(scopus_search_report(recs), style = "report")
  expect_true(grepl("Records identified from Scopus: 149", text, fixed = TRUE))
  expect_true(grepl("Duplicate records removed before screening: 11",
                    text, fixed = TRUE))

  # With no merge recorded there is nothing to subtract, and the rows retrieved
  # are the records identified.
  plain <- format(scopus_search_report(report_fixture()), style = "report")
  expect_true(grepl("Records identified from Scopus: 138", plain, fixed = TRUE))
})

test_that("a plan that has not run is described in the present", {
  para <- format(
    scopus_search_report(scopus_plan("x", years = 2019:2021, partition = "year")),
    style = "paragraph"
  )
  expect_true(grepl("The search expression is x, limited to publication years 2019 to 2021.",
                    para, fixed = TRUE))
  expect_true(grepl("It would be partitioned into 3 cells", para, fixed = TRUE))
  expect_false(grepl("The search expression was", para, fixed = TRUE))

  # No line may imply a set exists to have carried something.
  text <- format(scopus_search_report(scopus_plan("x")), style = "report")
  expect_true(grepl("The search expression is x, with no year limit.",
                    format(scopus_search_report(scopus_plan("x")), style = "paragraph"),
                    fixed = TRUE))
  expect_true(grepl("Date searched: unrecorded, this plan has not been run",
                    text, fixed = TRUE))
  expect_false(grepl("the time it was retrieved", text, fixed = TRUE))
  expect_false(grepl("which this set does not carry", text, fixed = TRUE))

  # A harvest that simply lost its stamp still says so as a set.
  recs <- report_fixture()
  attr(recs, "retrieved_at") <- NULL
  run <- format(scopus_search_report(recs), style = "report")
  expect_true(grepl("Date searched: unrecorded, this set does not carry the time it was retrieved",
                    run, fixed = TRUE))
})

test_that("the PRISMA-S map never claims an item the package cannot know", {
  report <- scopus_search_report(report_fixture())
  expect_equal(nrow(report$prisma), 16L)
  expect_equal(report$prisma$item, 1:16)
  author_only <- c(2L, 3L, 4L, 5L, 6L, 7L, 10L, 11L, 12L, 14L)
  expect_true(all(report$prisma$source[author_only] == "author"))
  expect_true(all(report$prisma$source[c(1L, 8L, 9L, 13L, 15L)] == "record"))
  expect_equal(report$prisma$name[14], "Peer review")
})

test_that("a record set without a plan reports what it holds and no more", {
  recs <- example_records
  attr(recs, "total_results") <- 200
  report <- scopus_search_report(recs)
  expect_true(is.na(report$view))
  expect_true(is.na(report$partition))
  expect_equal(report$expression, "graphene supercapacitor")
  expect_equal(report$reported_total, 200)
  expect_true(is.na(report$snippet))
  text <- format(report, style = "report")
  expect_true(grepl("View: unrecorded", text, fixed = TRUE))
  expect_true(grepl("Field tag: unrecorded", text, fixed = TRUE))
  expect_true(grepl("no reproduction snippet can be written",
                    format(report, style = "markdown"), fixed = TRUE))

  # A plan supplied by hand fills those fields in.
  plan <- scopus_plan("graphene supercapacitor", field = "TITLE-ABS-KEY")
  expect_equal(scopus_search_report(recs, plan = plan)$view, "STANDARD")
})

test_that("the reproduction snippet rebuilds the plan it describes", {
  grid <- list(
    scopus_plan("a b", years = 2015:2020, field = "TITLE-ABS-KEY", partition = "year"),
    scopus_plan("a b", years = c(2015L, 2017L, 2021L), partition = "year"),
    scopus_plan("a b", years = 2015:2020, partition = "none"),
    scopus_plan("a b", partition = "none"),
    scopus_plan("a b", years = 2019L),
    scopus_plan("a \"quoted\" query", years = 2015:2016, view = "COMPLETE"),
    scopus_plan("a b", view = "COMPLETE", partition = "none"),
    scopus_plan("a b", years = 2015:2016, page_size = 37, partition = "year")
  )
  for (plan in grid) {
    snippet <- scopus_search_report(plan)$snippet
    env <- new.env(parent = globalenv())
    # The fetch is masked: the claim under test is that the plan comes back
    # identical, and running the harvest would need a key and spend quota.
    env$scopus_fetch_plan <- function(p, ...) p
    eval(parse(text = snippet), envir = env)
    expect_identical(env$plan, plan)
  }
})

test_that("file = writes Markdown, and only when supplied", {
  report <- scopus_search_report(report_fixture())
  path <- withr::local_tempfile(fileext = ".md")
  expect_false(file.exists(path))
  out <- scopus_search_report(report_fixture(), file = path)
  expect_true(file.exists(path))
  expect_s3_class(out, "scopus_search_report")
  written <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_equal(written, format(report, style = "markdown"))
  expect_true(startsWith(written, "# Search strategy record"))
})

test_that("degenerate inputs are handled rather than guessed at", {
  # An empty record set: the counts are zero, and zero is a fact, not a gap.
  empty <- new_scopus_records(scopus_records_columns())
  attr(empty, "plan") <- scopus_plan("x")
  report <- scopus_search_report(empty)
  expect_equal(report$n_records, 0L)
  expect_equal(report$n_with_doi, 0L)
  expect_true(grepl("Records retrieved: 0", format(report, style = "report"), fixed = TRUE))

  # A single record, and a single-year plan.
  one <- example_records[1, ]
  attr(one, "plan") <- scopus_plan("x", years = 2015L)
  single <- scopus_search_report(one)
  expect_equal(single$years, "2015")
  expect_equal(single$n_records, 1L)

  # A plan with no year limit says so rather than inventing a span.
  none <- scopus_search_report(scopus_plan("x"))
  expect_true(is.na(none$years))
  expect_true(grepl("Years: no year limit was applied",
                    format(none, style = "report"), fixed = TRUE))
})

test_that("the report refuses what it cannot describe", {
  expect_error(scopus_search_report(data.frame(a = 1)),
               class = "scopus_error_bad_input")
  expect_error(scopus_search_report("records"),
               class = "scopus_error_bad_input")
  expect_error(scopus_search_report(example_records, plan = "not a plan"),
               class = "scopus_error_bad_input")
  expect_error(scopus_search_report(example_records, file = ""),
               class = "scopus_error_bad_input")
  expect_error(scopus_search_report(example_records, file = c("a.md", "b.md")),
               class = "scopus_error_bad_input")
  expect_error(format(scopus_search_report(scopus_plan("x")), style = "prose"))
})

test_that("refusal messages read the same in both engines", {
  expect_error(scopus_search_report(1),
               "A search report needs a record set or a search plan.", fixed = TRUE)
  expect_error(scopus_search_report(example_records, plan = 1),
               "The plan must be a search plan.", fixed = TRUE)
  expect_error(scopus_search_report(example_records, file = NA_character_),
               "The file must be a single non-empty path.", fixed = TRUE)
})

test_that("the record matches the golden file both twins are pinned to", {
  # golden-search-record.txt is byte-identical to the Python twin's copy at
  # scopusflow-py/tests/golden-search-record.txt. The family advertises feature
  # parity, and this record is destined for a manuscript, so a search written up
  # in one language has to read identically in the other. Anything that changes
  # the wording has to change both files, which is the point of the pin.
  recs <- report_fixture()
  attr(recs, "combined") <- list(n_in = 149L, n_out = 138L, n_removed = 11L,
                                 deduplicated = TRUE)
  report <- scopus_search_report(recs)
  rendered <- paste0(format(report, style = "report"), "\n\n",
                     format(report, style = "paragraph"), "\n")
  golden <- rawToChar(readBin(test_path("golden-search-record.txt"), "raw",
                              file.size(test_path("golden-search-record.txt"))))
  expect_identical(rendered, golden)
})
