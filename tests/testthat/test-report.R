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
  author_only <- c(3L, 4L, 5L, 6L, 7L, 10L, 11L, 12L, 14L)
  expect_true(all(report$prisma$source[author_only] == "author"))
  expect_true(all(report$prisma$source[c(1L, 2L, 8L, 9L, 13L, 15L)] == "record"))
  expect_equal(report$prisma$name[14], "Peer review")
})

test_that("item 2 says Scopus was searched on its own", {
  # PRISMA-S item 2 asks which databases were searched together on one
  # platform, as Ovid searches several at once. Scopus is searched alone, so
  # the record can say so. Other databases a review searched are named under
  # item 1, by the author.
  report <- scopus_search_report(report_fixture())
  expect_equal(report$prisma$source[2], "record")
  expect_equal(
    report$prisma$note[2],
    "Scopus was searched on its own, not as one of several databases searched together on one platform."
  )
  # A plan not yet run is described in the present, as the paragraph is.
  unrun <- scopus_search_report(scopus_plan("x"))
  expect_equal(unrun$prisma$source[2], "record")
  expect_equal(
    unrun$prisma$note[2],
    "Scopus is searched on its own, not as one of several databases searched together on one platform."
  )
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

  # The year limit is unrecorded, which is not the same as there being none.
  expect_true(grepl("  1 (year limit unrecorded): 138 retrieved, 200 reported, incomplete",
                    text, fixed = TRUE))
  expect_false(grepl("no year limit", text, fixed = TRUE))
  expect_true(grepl("| 1 | year limit unrecorded | 138 | 200 | no |",
                    format(report, style = "markdown"), fixed = TRUE))

  # The expression is there, but nothing records the field tag and the year
  # limit it was sent with, so the full strategy is the author's to give.
  expect_equal(report$prisma$source[8], "author")
  expect_equal(report$prisma$note[8],
               "The search expression is recorded, but no plan records the limits it was sent with.")

  # A plan supplied by hand fills those fields in.
  plan <- scopus_plan("graphene supercapacitor", field = "TITLE-ABS-KEY")
  with_plan <- scopus_search_report(recs, plan = plan)
  expect_equal(with_plan$view, "STANDARD")
  expect_equal(with_plan$prisma$source[8], "record")

  # A one-cell plan describes the one search the set came from, so the set's
  # own counts stay with it. They used to become unrecorded the moment the
  # plan the help page recommends was supplied.
  expect_equal(with_plan$cells$n_records, 138L)
  expect_equal(with_plan$cells$reported_total, 200)
  expect_equal(with_plan$reported_total, 200)
  expect_true(grepl("  1 (no year limit): 138 retrieved, 200 reported, incomplete",
                    format(with_plan, style = "report"), fixed = TRUE))

  # A partitioned plan cannot say which cell the count belongs to, so its
  # cells stay unrecorded.
  by_year <- scopus_plan("graphene supercapacitor", years = 2015:2016,
                         partition = "year")
  split <- scopus_search_report(recs, plan = by_year)
  expect_true(all(is.na(split$cells$n_records)))
  expect_true(is.na(split$reported_total))
})

test_that("a plan that sets no year limit still says there is none", {
  text <- format(scopus_search_report(scopus_plan("x")), style = "report")
  expect_true(grepl("  1 (no year limit): retrieved records unrecorded", text, fixed = TRUE))
  expect_false(grepl("year limit unrecorded", text, fixed = TRUE))
})

test_that("a harvest run over several days is dated from its first search to its last", {
  # PRISMA-S item 13 asks for the date of the last search. A resumed harvest
  # or a merged set spans days, and its earliest stamp alone hid when it was
  # last searched.
  recs <- report_fixture()
  attr(recs, "retrieved_at") <- as.POSIXct("2026-07-20 09:00:00", tz = "UTC")
  attr(recs, "retrieved_until") <- as.POSIXct("2026-07-27 16:30:00", tz = "UTC")
  report <- scopus_search_report(recs)
  expect_equal(report$searched_at, as.POSIXct("2026-07-20 09:00:00", tz = "UTC"))
  expect_equal(report$searched_until, as.POSIXct("2026-07-27 16:30:00", tz = "UTC"))
  expect_true(grepl("Date searched: 2026-07-20 09:00:00 UTC to 2026-07-27 16:30:00 UTC\n",
                    format(report, style = "report"), fixed = TRUE))
  expect_equal(report$prisma$source[13], "record")
  expect_equal(
    report$prisma$note[13],
    paste("Last searched on 2026-07-27 16:30:00 UTC; the records were retrieved",
          "between 2026-07-20 09:00:00 UTC and 2026-07-27 16:30:00 UTC.")
  )
  expect_true(grepl(
    "searched in Scopus, on the Elsevier Scopus Search API, between 20 July 2026 and 27 July 2026.",
    format(report, style = "paragraph"), fixed = TRUE
  ))
})

test_that("stamps on one UTC day give the single date they always gave", {
  recs <- report_fixture()
  attr(recs, "retrieved_until") <- as.POSIXct("2026-07-22 18:45:00", tz = "UTC")
  report <- scopus_search_report(recs)
  expect_true(grepl("Date searched: 2026-07-22 09:15:00 UTC\n",
                    format(report, style = "report"), fixed = TRUE))
  expect_equal(report$prisma$note[13], "2026-07-22 09:15:00 UTC.")
  expect_true(grepl("Search API, on 22 July 2026.",
                    format(report, style = "paragraph"), fixed = TRUE))

  # The day is the UTC day, so an hour either side of midnight is two days.
  attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 23:30:00", tz = "UTC")
  attr(recs, "retrieved_until") <- as.POSIXct("2026-07-23 00:30:00", tz = "UTC")
  expect_true(grepl("Date searched: 2026-07-22 23:30:00 UTC to 2026-07-23 00:30:00 UTC",
                    format(scopus_search_report(recs), style = "report"), fixed = TRUE))

  # A latest stamp recorded before the earliest is no span at all.
  attr(recs, "retrieved_until") <- as.POSIXct("2026-07-01 00:00:00", tz = "UTC")
  expect_equal(scopus_search_report(recs)$searched_until, attr(recs, "retrieved_at"))
})

test_that("non-contiguous year cells are listed, not shown as one span", {
  # Three year cells for 2015, 2020 and 2025 searched three years. Written up
  # as 2015 to 2025 they claimed eight more.
  report <- scopus_search_report(
    scopus_plan("x", years = c(2015, 2020, 2025), partition = "year")
  )
  expect_equal(report$years, "2015, 2020 and 2025")
  text <- format(report, style = "report")
  expect_true(grepl("Years: 2015, 2020 and 2025\n", text, fixed = TRUE))
  expect_true(grepl("9 Limits and restrictions. Publication years 2015, 2020 and 2025.",
                    text, fixed = TRUE))
  expect_true(grepl("limited to publication years 2015, 2020 and 2025.",
                    format(report, style = "paragraph"), fixed = TRUE))

  years_of <- function(...) scopus_search_report(scopus_plan("x", ...))$years
  # A run of three or more years within the list reads as a span.
  expect_equal(years_of(years = c(2010:2013, 2020:2022), partition = "year"),
               "2010 to 2013 and 2020 to 2022")
  expect_equal(years_of(years = c(2015, 2016, 2020), partition = "year"),
               "2015, 2016 and 2020")
  expect_equal(years_of(years = c(2015, 2017:2020), partition = "year"),
               "2015 and 2017 to 2020")
  # Contiguous cells stay one span. A single cell sends one range from the
  # earliest year to the latest, which is what the record states for it.
  expect_equal(years_of(years = 2015:2025, partition = "year"), "2015 to 2025")
  expect_equal(years_of(years = c(2015, 2020, 2025)), "2015 to 2025")
  expect_equal(years_of(years = 2019L, partition = "year"), "2019")
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

test_that("the snippet pages the search as the records were paged", {
  # scopus_fetch_plan() pages by offset unless told otherwise, so only
  # cursor = TRUE reproduces a harvest paged by cursor.
  recs <- report_fixture()
  attr(recs, "paging") <- "cursor"
  snippet <- scopus_search_report(recs)$snippet
  expect_true(endsWith(snippet, "\nrecords <- scopus_fetch_plan(plan, cursor = TRUE)"))
  env <- new.env(parent = globalenv())
  env$scopus_fetch_plan <- function(p, ...) list(plan = p, args = list(...))
  eval(parse(text = snippet), envir = env)
  expect_identical(env$records$plan, attr(recs, "plan"))
  expect_identical(env$records$args, list(cursor = TRUE))

  # A harvest paged by offset, one that does not record its paging and a plan
  # not yet run all take the default.
  offset <- scopus_search_report(report_fixture())$snippet
  attr(recs, "paging") <- NULL
  unrecorded <- scopus_search_report(recs)$snippet
  for (s in list(offset, unrecorded, scopus_search_report(attr(recs, "plan"))$snippet)) {
    expect_true(endsWith(s, "\nrecords <- scopus_fetch_plan(plan)"))
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

# A baseline search and a later update of it, merged with de-duplication, as a
# review that re-runs its search a year on would hold them. Built by hand in the
# same way in the Python suite, whose copy of the golden file below is
# byte-identical.
merged_fixture <- function() {
  baseline <- example_records[example_records$year <= 2023, ]
  attr(baseline, "retrieved_at") <- as.POSIXct("2024-01-10 09:00:00", tz = "UTC")
  attr(baseline, "scopusflow_version") <- "0.3.0"
  attr(baseline, "paging") <- "offset"
  update <- example_records
  attr(update, "retrieved_at") <- as.POSIXct("2025-01-10 09:00:00", tz = "UTC")
  attr(update, "scopusflow_version") <- "0.4.0"
  attr(update, "paging") <- "offset"
  scopus_combine(baseline, update, dedupe = TRUE)
}

test_that("a merged set's record matches the golden file both twins are pinned to", {
  # golden-search-record-merged.txt is byte-identical to the Python twin's copy.
  # The merge keeps both retrieval dates, so the record is dated from the
  # baseline to the update, and item 13 gives the update's date as the last
  # search. No plan survives a merge, so the year limit is unrecorded and the
  # full strategy is the author's to give.
  report <- scopus_search_report(merged_fixture())
  rendered <- paste0(format(report, style = "report"), "\n\n",
                     format(report, style = "paragraph"), "\n")
  path <- test_path("golden-search-record-merged.txt")
  golden <- rawToChar(readBin(path, "raw", file.size(path)))
  expect_identical(rendered, golden)
})

# The report and paragraph renderings, as the golden files hold them.
render_record <- function(report) {
  paste0(format(report, style = "report"), "\n\n",
         format(report, style = "paragraph"), "\n")
}

read_golden <- function(name) {
  path <- test_path(name)
  rawToChar(readBin(path, "raw", file.size(path)))
}

# A plan harvest stopped by max_results: two year cells for which the API
# reported 1,532 records each, capped at 200. The rows are the bundled corpus
# in order, recycled to the 400 the cells held, since the record reads only
# how many rows there are and how many carry a DOI. The Python suite builds
# the same set, and its copy of golden-search-record-capped.txt is
# byte-identical.
capped_fixture <- function(cap = 200, n_records = c(200L, 200L),
                           reported = c(1532, 1532)) {
  recs <- example_records[rep_len(seq_len(nrow(example_records)), sum(n_records)), ]
  attr(recs, "plan") <- scopus_plan("graphene supercapacitor", years = 2023:2024,
                                    field = "TITLE-ABS-KEY", partition = "year")
  attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
  attr(recs, "scopusflow_version") <- "0.4.0"
  attr(recs, "paging") <- "offset"
  attr(recs, "cell_totals") <- tibble::tibble(
    cell = 1:2, date = c("2023", "2024"), n_records = as.integer(n_records),
    reported_total = as.numeric(reported)
  )
  attr(recs, "max_results") <- cap
  recs
}

test_that("a capped harvest's record matches the golden file both twins are pinned to", {
  expect_identical(render_record(scopus_search_report(capped_fixture())),
                   read_golden("golden-search-record-capped.txt"))
})

test_that("a cell stopped at the cap says so, and the record names the cap", {
  # The record used to call each cell incomplete, and the harvest incomplete,
  # without the cap that explained both, and item 9 left the cap out.
  report <- scopus_search_report(capped_fixture())
  expect_equal(report$max_results, 200)
  text <- format(report, style = "report")
  expect_true(grepl(
    "  1 (2023): 200 retrieved, 1,532 reported, stopped at the requested cap of 200\n",
    text, fixed = TRUE
  ))
  expect_true(grepl(paste0(
    "Completeness: 400 of the 3,064 records reported as matching were retrieved, ",
    "a shortfall due to the requested cap of 200 records per cell\n"
  ), text, fixed = TRUE))
  expect_equal(report$prisma$source[9], "record")
  expect_equal(report$prisma$note[9], paste(
    "Publication years 2023 to 2024. Records per cell were capped at 200.",
    "scopusflow applies no document type, language or subject area limit of its own."
  ))
  expect_true(grepl("| 1 | 2023 | 200 | 1,532 | capped at 200 |",
                    format(report, style = "markdown"), fixed = TRUE))
  expect_true(grepl(paste(
    "so the harvest is incomplete. Records per cell were capped at 200, which",
    "accounts for the whole shortfall."
  ), format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a cap that never bound is named, and nothing is called capped", {
  report <- scopus_search_report(
    capped_fixture(cap = 2000, n_records = c(150L, 120L), reported = c(150, 120))
  )
  text <- format(report, style = "report")
  expect_true(grepl("  1 (2023): 150 retrieved, 150 reported, complete\n", text, fixed = TRUE))
  expect_true(grepl("Completeness: every record the API reported as matching was retrieved\n",
                    text, fixed = TRUE))
  expect_false(grepl("stopped at", text, fixed = TRUE))
  expect_equal(report$prisma$note[9], paste(
    "Publication years 2023 to 2024. A cap of 2,000 records per cell was set and",
    "did not bind. scopusflow applies no document type, language or subject area",
    "limit of its own."
  ))
  expect_true(grepl("A cap of 2,000 records per cell was set and did not bind.",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a shortfall the cap explains only in part counts the capped cells", {
  # The second cell came back short of its total without reaching the cap, so
  # the cap is not the whole story.
  report <- scopus_search_report(
    capped_fixture(n_records = c(200L, 150L), reported = c(1532, 160))
  )
  text <- format(report, style = "report")
  expect_true(grepl("  2 (2024): 150 retrieved, 160 reported, incomplete\n", text, fixed = TRUE))
  expect_true(grepl(paste0(
    "Completeness: 350 of the 1,692 records reported as matching were retrieved, ",
    "and 1 of 2 cells stopped at the requested cap of 200\n"
  ), text, fixed = TRUE))
  expect_true(grepl("Records per cell were capped at 200, and 1 of 2 cells stopped at that cap.",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a cell at the cap without a reported total still stopped at the cap", {
  report <- scopus_search_report(capped_fixture(reported = c(NA, NA)))
  text <- format(report, style = "report")
  expect_true(grepl(paste0(
    "  1 (2023): 200 retrieved, reported total unrecorded, stopped at the ",
    "requested cap of 200\n"
  ), text, fixed = TRUE))
  expect_true(grepl(paste0(
    "Completeness: unrecorded, since the number of records the API reported as ",
    "matching is not known, and 2 of 2 cells stopped at the requested cap of 200\n"
  ), text, fixed = TRUE))
})

test_that("a single search stopped at its cap is written up as capped", {
  # What scopus_fetch(max_results = 25) returns against 500 matches: one cell,
  # with no year limit.
  recs <- example_records[1:25, ]
  attr(recs, "plan") <- scopus_plan("graphene supercapacitor", field = "TITLE-ABS-KEY")
  attr(recs, "total_results") <- 500
  attr(recs, "max_results") <- 25L
  report <- scopus_search_report(recs)
  expect_true(grepl(
    "  1 (no year limit): 25 retrieved, 500 reported, stopped at the requested cap of 25\n",
    format(report, style = "report"), fixed = TRUE
  ))
  expect_equal(report$prisma$note[9], paste(
    "No year limit was applied. Records per cell were capped at 25. scopusflow",
    "applies no document type, language or subject area limit of its own."
  ))
})

test_that("the snippet passes the cap the harvest was run under", {
  snippet <- scopus_search_report(capped_fixture())$snippet
  expect_true(endsWith(snippet, "\nrecords <- scopus_fetch_plan(plan, max_results = 200)"))
  env <- new.env(parent = globalenv())
  env$scopus_fetch_plan <- function(p, ...) list(plan = p, args = list(...))
  eval(parse(text = snippet), envir = env)
  expect_identical(env$records$args, list(max_results = 200))

  recs <- capped_fixture(cap = 1e10)
  attr(recs, "paging") <- "cursor"
  expect_true(endsWith(
    scopus_search_report(recs)$snippet,
    "\nrecords <- scopus_fetch_plan(plan, max_results = 10000000000, cursor = TRUE)"
  ))
})

test_that("a capped plan harvest is written up as capped, end to end", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_corpus(total = 30L))
  plan <- scopus_plan("graphene", years = 2023:2024, partition = "year")
  recs <- expect_no_warning(scopus_fetch_plan(plan, max_results = 10))
  report <- scopus_search_report(recs)
  text <- format(report, style = "report")
  expect_true(grepl("  1 (2023): 10 retrieved, 30 reported, stopped at the requested cap of 10\n",
                    text, fixed = TRUE))
  expect_true(grepl("a shortfall due to the requested cap of 10 records per cell", text,
                    fixed = TRUE))
  expect_true(endsWith(report$snippet, "\nrecords <- scopus_fetch_plan(plan, max_results = 10)"))
})

# A harvest stopped after two of its five year cells, as the Python twin's
# fetch_plan() records one when its should_stop callable, which the app's Cancel
# sets, returns True. This twin has no partial-return path, since the app's
# Cancel kills the background worker, so the branch is dormant here and the
# attributes are set by hand. It is kept so that the two renderers stay one
# function. The Python suite builds the same set, and its copy of
# golden-search-record-stopped.txt is byte-identical. A harvest stopped before
# its first cell records no time and no version, as the Python twin's does not.
stopped_fixture <- function(run = 2L) {
  years <- 2015L + seq_len(run)
  recs <- example_records[example_records$year %in% years, ]
  n <- as.integer(table(factor(recs$year, levels = years)))
  attr(recs, "plan") <- scopus_plan("graphene supercapacitor", years = 2016:2020,
                                    field = "TITLE-ABS-KEY", partition = "year")
  if (run > 0L) {
    attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
    attr(recs, "scopusflow_version") <- "0.4.0"
  }
  attr(recs, "paging") <- "cursor"
  attr(recs, "cell_totals") <- tibble::tibble(
    cell = seq_len(run), date = as.character(years), n_records = n,
    reported_total = as.numeric(n)
  )
  attr(recs, "stopped_early") <- TRUE
  attr(recs, "cells_planned") <- 5L
  attr(recs, "cells_run") <- run
  recs
}

test_that("a stopped harvest's record matches the golden file both twins are pinned to", {
  expect_identical(render_record(scopus_search_report(stopped_fixture())),
                   read_golden("golden-search-record-stopped.txt"))
})

test_that("a stopped harvest says how many cells ran, and which years", {
  report <- scopus_search_report(stopped_fixture())
  expect_true(report$stopped_early)
  expect_identical(report$cells_run, 2L)
  expect_identical(report$cells_planned, 5L)
  expect_identical(report$not_run, 3:5)
  expect_equal(report$years, "2016 to 2020")
  expect_equal(report$years_run, "2016 to 2017")
  text <- format(report, style = "report")
  expect_true(grepl("Years: 2016 to 2017, of 2016 to 2020 planned\n", text, fixed = TRUE))
  expect_true(grepl(paste0(
    "Records reported as matching: not counted for the 3 cells not run, so no ",
    "overall figure is given\n"
  ), text, fixed = TRUE))
  expect_true(grepl("Completeness: incomplete, the harvest was stopped after 2 of 5 cells\n",
                    text, fixed = TRUE))
  expect_true(grepl("  1 (2016): 9 retrieved, 9 reported, complete\n", text, fixed = TRUE))
  expect_true(grepl("  3 (2018): not run\n", text, fixed = TRUE))
  expect_true(grepl("| 3 | 2018 | not run | not run | no |",
                    format(report, style = "markdown"), fixed = TRUE))
  expect_equal(report$prisma$note[9], paste(
    "Publication years 2016 to 2020. Of the 5 cells planned, 2 were retrieved",
    "before the harvest was stopped (2016 to 2017). scopusflow applies no document",
    "type, language or subject area limit of its own."
  ))
  expect_equal(report$prisma$note[15], paste(
    "19 records retrieved from Scopus before the harvest was stopped after 2 of 5",
    "cells."
  ))
  para <- format(report, style = "paragraph")
  expect_true(grepl("one per year, each to be retrieved through the STANDARD view", para,
                    fixed = TRUE))
  expect_false(grepl("each retrieved through", para, fixed = TRUE))
  expect_true(grepl(paste(
    "Of the 5 cells planned, 2 were retrieved before the harvest was stopped",
    "(2016 to 2017), so the harvest is incomplete. The search retrieved 19 records."
  ), para, fixed = TRUE))
})

test_that("a harvest stopped before its first cell claims no search", {
  report <- scopus_search_report(stopped_fixture(run = 0L))
  expect_identical(report$not_run, 1:5)
  text <- format(report, style = "report")
  expect_true(grepl("Years: none, of 2016 to 2020 planned\n", text, fixed = TRUE))
  expect_true(grepl("Date searched: none, the harvest was stopped before its first cell\n",
                    text, fixed = TRUE))
  expect_true(grepl("Completeness: incomplete, the harvest was stopped after 0 of 5 cells\n",
                    text, fixed = TRUE))
  expect_true(grepl("  1 (2016): not run\n", text, fixed = TRUE))
  expect_equal(report$prisma$note[9], paste(
    "Publication years 2016 to 2020. Of the 5 cells planned, none was retrieved",
    "before the harvest was stopped. scopusflow applies no document type, language",
    "or subject area limit of its own."
  ))
  para <- format(report, style = "paragraph")
  expect_true(startsWith(
    para, "The literature was to be searched in Scopus, on the Elsevier Scopus Search API."
  ))
  expect_false(grepl("The literature was searched", para, fixed = TRUE))
  expect_true(grepl(paste(
    "Of the 5 cells planned, none was retrieved before the harvest was stopped,",
    "so the harvest is incomplete."
  ), para, fixed = TRUE))
})

test_that("a cap is not said to have held on a harvest stopped before its first cell", {
  # No cell ran, so nothing was retrieved under the cap, and "did not bind"
  # would describe a retrieval that never happened.
  recs <- stopped_fixture(run = 0L)
  attr(recs, "max_results") <- 50L
  report <- scopus_search_report(recs)
  expect_equal(report$prisma$note[9], paste(
    "Publication years 2016 to 2020. A cap of 50 records per cell was set. Of the",
    "5 cells planned, none was retrieved before the harvest was stopped. scopusflow",
    "applies no document type, language or subject area limit of its own."
  ))
  for (style in c("report", "paragraph", "markdown")) {
    expect_false(grepl("did not bind", format(report, style = style), fixed = TRUE))
  }
  expect_true(grepl("The search retrieved 0 records. A cap of 50 records per cell was set.",
                    format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a stopped set without its plan still says it was stopped", {
  recs <- stopped_fixture()
  attr(recs, "plan") <- NULL
  report <- scopus_search_report(recs)
  text <- format(report, style = "report")
  expect_true(grepl("Completeness: incomplete, the harvest was stopped after 2 of 5 cells\n",
                    text, fixed = TRUE))
  expect_true(grepl(paste(
    "Of the 5 cells planned, 2 were retrieved before the harvest was stopped, so",
    "the harvest is incomplete."
  ), format(report, style = "paragraph"), fixed = TRUE))
})

test_that("a plan that is not the one a stopped harvest ran leaves its cells unrecorded", {
  # Three cells where the harvest planned five: the recorded counts cannot be
  # placed on this plan's cells, so none is marked as run or not run.
  other <- scopus_plan("graphene supercapacitor", years = 2016:2018, partition = "year")
  report <- scopus_search_report(stopped_fixture(), plan = other)
  expect_true(all(is.na(report$cells$n_records)))
  expect_length(report$not_run, 0L)
  text <- format(report, style = "report")
  expect_true(grepl("  1 (2016): retrieved records unrecorded\n", text, fixed = TRUE))
  expect_false(grepl("not run\n", text, fixed = TRUE))
  expect_true(grepl("Years: 2016 to 2018\n", text, fixed = TRUE))
  expect_true(grepl("Completeness: incomplete, the harvest was stopped after 2 of 5 cells\n",
                    text, fixed = TRUE))
})

test_that("a harvest neither capped nor stopped reads as it always has", {
  # The golden test above pins the whole record. The new attributes, absent,
  # leave nothing behind in any rendering.
  report <- scopus_search_report(report_fixture())
  expect_true(is.na(report$max_results))
  expect_false(report$stopped_early)
  expect_length(report$not_run, 0L)
  for (style in c("report", "paragraph", "markdown")) {
    text <- format(report, style = style)
    expect_false(grepl("capped|cap of", text))
    expect_false(grepl("stopped", text, fixed = TRUE))
    expect_false(grepl("not run", text, fixed = TRUE))
  }
})
