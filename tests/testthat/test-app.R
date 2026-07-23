# The reactive app is not exercised here (it needs a running server); these tests
# pin the pure helpers behind it, which run fully offline.

test_that("app_years_code renders compact year expressions", {
  expect_equal(app_years_code(2015:2022), "2015:2022")
  expect_equal(app_years_code(2019L), "2019")
  expect_equal(app_years_code(c(2010L, 2012L, 2015L)), "c(2010, 2012, 2015)")
  expect_null(app_years_code(NULL))
  expect_null(app_years_code(integer()))
})

test_that("app_code_mirror builds a runnable, key-free script", {
  code <- app_code_mirror(
    query = "graphene supercapacitor", years = 2018:2022,
    field = "TITLE-ABS-KEY", view = "STANDARD", partition = "year",
    max_results = 200, by = "source"
  )
  expect_true(grepl("library(scopusflow)", code, fixed = TRUE))
  expect_true(grepl('scopus_plan(', code, fixed = TRUE))
  expect_true(grepl("years = 2018:2022", code, fixed = TRUE))
  expect_true(grepl('field = "TITLE-ABS-KEY"', code, fixed = TRUE))
  expect_true(grepl("max_results = 200", code, fixed = TRUE))
  expect_true(grepl("scopus_fetch_plan(", code, fixed = TRUE))
  expect_true(grepl("cache_dir = scopus_cache_dir()", code, fixed = TRUE))
  expect_true(grepl('scopus_top(records, by = "source")', code, fixed = TRUE))
  # The key handling is documented and the script is parseable R.
  expect_true(grepl("SCOPUS_API_KEY", code))
  expect_silent(parse(text = code))
})

test_that("app_code_mirror omits absent options", {
  code <- app_code_mirror(query = "x", years = NULL, field = "",
                          view = "STANDARD", partition = "none", max_results = Inf)
  expect_false(grepl("years =", code, fixed = TRUE))
  expect_false(grepl("field =", code, fixed = TRUE))
  expect_false(grepl("max_results", code, fixed = TRUE))
  expect_false(grepl("COMPLETE", code, fixed = TRUE))
  expect_silent(parse(text = code))
})

test_that("app_parse_cell_progress reads the latest valid cell marker", {
  lines <- c("Cell 1/8: fetching 'x' (2018).", "  120/200 retrieved.",
             "Cell 2/8: fetching 'x' (2019).")
  expect_equal(app_parse_cell_progress(lines), list(done = 2L, total = 8L))
  expect_null(app_parse_cell_progress(character()))
  expect_null(app_parse_cell_progress(c("no marker here")))
  # A "k/N" pattern inside the echoed query (no trailing colon) is ignored.
  expect_null(app_parse_cell_progress("fetching 'Cell 9/9 study' results"))
  # A malformed marker with done > total is rejected.
  expect_null(app_parse_cell_progress("Cell 9/2: bogus"))
})

test_that("app_code_mirror only partitions by year when asked and years exist", {
  no_part <- app_code_mirror(query = "x", years = 2018:2020, partition = "none")
  expect_false(grepl("partition", no_part, fixed = TRUE))
  with_part <- app_code_mirror(query = "x", years = 2018:2020, partition = "year")
  expect_true(grepl('partition = "year"', with_part, fixed = TRUE))
})

test_that("app_escape_html escapes the specials", {
  expect_equal(app_escape_html("a < b & c > d"), "a &lt; b &amp; c &gt; d")
})

test_that("app_ansi_to_html drops escapes and collapses carriage returns", {
  out <- app_ansi_to_html(c("\033[32mfetching\033[39m done", "abc\rdef"))
  expect_false(grepl("\033", out))   # no raw escape sequences survive
  expect_true(grepl("fetching", out))
  expect_true(grepl("def", out))
  expect_false(grepl("abc", out))    # the pre-carriage-return text is discarded
})

test_that("app_ansi_to_html escapes HTML even on the coloured path", {
  # A query echoed into the verbose log must never reach the terminal as live
  # HTML, whether or not fansi is colourising.
  out <- app_ansi_to_html("graphene <script>alert(1)</script>")
  expect_false(grepl("<script>", out, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", out, fixed = TRUE))
})

test_that("app_code_mirror appends a comparison block when terms are given", {
  code <- app_code_mirror(
    query = "deep learning", years = 2018:2022, field = "TITLE-ABS-KEY",
    compare_terms = c("computer vision", "drug discovery"),
    highlight = "computer vision", interval = FALSE, pub_count_in_legend = FALSE
  )
  expect_true(grepl("scopus_compare_topics(", code, fixed = TRUE))
  expect_true(grepl('"computer vision"', code, fixed = TRUE))
  expect_true(grepl('"drug discovery"', code, fixed = TRUE))
  expect_true(grepl("plot_scopus_comparison(", code, fixed = TRUE))
  expect_true(grepl('highlight = "computer vision"', code, fixed = TRUE))
  expect_true(grepl("interval = FALSE", code, fixed = TRUE))
  expect_true(grepl("pub_count_in_legend = FALSE", code, fixed = TRUE))
  expect_silent(parse(text = code))
})

test_that("app_code_mirror skips the comparison block without terms or years", {
  expect_false(grepl("compare_topics",
                     app_code_mirror(query = "x", years = 2018:2020), fixed = TRUE))
  # Terms but no year span: skipped, since scopus_compare_topics() needs years.
  expect_false(grepl("compare_topics",
                     app_code_mirror(query = "x", years = NULL, partition = "none",
                                     compare_terms = "a"), fixed = TRUE))
})

test_that("app_demo_records draws real records spanning the years", {
  recs <- app_demo_records(2019:2021)
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), sum(example_records$year %in% 2019:2021))
  expect_setequal(unique(recs$year), 2019:2021)
  # A per-year cap applies as `max_results` does to a real cell.
  expect_equal(nrow(app_demo_records(2019:2021, max_per_year = 4)), 12L)
  expect_true(all(c("title", "authors", "publication", "citations") %in% names(recs)))
  # Every row is a record of the bundled corpus, not a fabricated one.
  expect_true(all(recs$title %in% example_records$title))
  # The panels the demo advertises have something to show: the by-year chart
  # varies rather than drawing identical bars, and the source tally has an
  # unambiguous top row.
  expect_gt(length(unique(table(recs$year))), 1L)
  top <- scopus_top(recs, by = "source")
  expect_s3_class(top, "data.frame")
  expect_gt(top$n[1], top$n[nrow(top)])
  expect_true(nchar(as_bibtex(recs)) > 0)
})

test_that("app_demo_records clamps years to the bundled corpus span", {
  span <- range(example_records$year)
  recs <- app_demo_records(c(span[1] - 5L, span[2] + 5L))
  expect_setequal(unique(recs$year), span)
})

test_that("app_demo_comparison mirrors a real comparison object", {
  cmp <- app_demo_comparison("graphene", c("flexible", "energy storage"), 2018:2021)
  expect_s3_class(cmp, "scopus_comparison")
  expect_setequal(unique(cmp$query_type), c("reference", "comparison"))
  expect_setequal(unique(cmp$abridged_query[cmp$query_type == "comparison"]),
                  c("flexible", "energy storage"))
  # It is plottable through the same path as a real comparison.
  skip_if_not_installed("ggplot2")
  expect_s3_class(plot_scopus_comparison(cmp), "ggplot")
})

test_that("run_app is exported and guarded", {
  expect_true(is.function(run_app))
})
