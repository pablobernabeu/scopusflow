# These tests pin the pure helpers behind the app, and then drive the server
# itself through shiny::testServer(). Only the synchronous paths are reachable
# that way: the harvest runs in a background callr process, so it is left out,
# and every server test stays in demo mode or without a key so that nothing here
# reaches the network.

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

test_that("app_code_mirror writes a huge record cap as a literal, not as NA", {
  # The record-cap box takes any number the user types. sprintf("%d") used to
  # coerce it, so anything past 2^31 reached the panel as `max_results = NA`,
  # which is not runnable R and is precisely what the mirror promises never to
  # emit. Scientific notation would be legal but is unreadable in a script.
  code <- app_code_mirror(query = "x", years = 2018:2020, max_results = 1e10)
  expect_true(grepl("max_results = 10000000000", code, fixed = TRUE))
  expect_false(grepl("max_results = NA", code, fixed = TRUE))
  expect_false(grepl("1e+10", code, fixed = TRUE))
  expect_silent(parse(text = code))
})

test_that("app_demo_records ignores a per-year cap past integer range", {
  # A cap wider than any year of the corpus leaves every row in place. It used
  # to reach NA through as.integer() and land on the same answer by accident.
  span <- range(example_records$year)
  all_rows <- app_demo_records(span[1L]:span[2L])
  expect_equal(nrow(app_demo_records(span[1L]:span[2L], max_per_year = 1e10)),
               nrow(all_rows))
  expect_equal(nrow(app_demo_records(span[1L]:span[2L], max_per_year = 1)),
               length(span[1L]:span[2L]))
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

test_that("run_app stops on an absent suggested package", {
  skip_if_not_installed("shiny")
  # runApp() is mocked too, so that a guard which stopped firing would fail this
  # test rather than start a real server in the middle of the suite.
  local_mocked_bindings(runApp = function(...) "started", .package = "shiny")
  local_mocked_bindings(
    check_installed = function(pkg, reason = NULL, ...) {
      cli::cli_abort("The package {.pkg {pkg[1]}} is required {reason}.",
                     class = "rlib_error_package_not_found")
    },
    .package = "rlang"
  )
  expect_error(run_app(), class = "rlib_error_package_not_found")
})

test_that("the server reports the key status and mirrors the plan as code", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2017),
      max_results = 5, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    expect_equal(years_value(), 2015:2017)
    expect_equal(max_value(), 5)
    expect_match(as.character(output$key_status$html), "Demo mode")
    expect_match(output$code_mirror, "scopus_plan(", fixed = TRUE)
    expect_match(output$code_mirror, "years = 2015:2017", fixed = TRUE)

    # The demo size note comes from the same corpus the demo harvest draws on.
    session$setInputs(count = 1)
    expect_match(rv$size_note, "^Demo plan: 3 year-cells; would draw \\d+ records")

    session$setInputs(demo = FALSE)
    expect_match(as.character(output$key_status$html), "Enter your key")
    session$setInputs(api_key = " k ")
    expect_match(as.character(output$key_status$html), "Key set")
    expect_equal(api_key(), "k")

    session$setInputs(use_years = FALSE)
    expect_null(years_value())
    expect_false(grepl("years =", output$code_mirror, fixed = TRUE))
  })
})

test_that("the server spends nothing without a key", {
  skip_if_not_installed("shiny")
  # Each of these handlers would otherwise issue live requests, so this is what
  # keeps a keyless click off the network rather than on it.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = FALSE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2016),
      max_results = 5, cmp_terms = "flexible", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    session$setInputs(count = 1)
    expect_null(rv$size_note)
    session$setInputs(compare = 1)
    expect_null(rv$comparison)
    session$setInputs(fetch = 1)
    expect_null(rv$proc)
    expect_equal(rv$status, "idle")
  })
})

test_that("the server compares topics in demo mode and prices a real comparison", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    session$setInputs(
      demo = FALSE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2016),
      max_results = 5, cmp_terms = " flexible , energy storage , flexible ",
      cmp_highlight = "", cmp_interval = TRUE, cmp_counts = TRUE
    )
    # A repeated term is dropped before it is priced, plotted or counted.
    expect_equal(cmp_terms_value(), c("flexible", "energy storage"))
    expect_match(as.character(output$cmp_note$html),
                 "2 terms x 2 years = 4 count requests")

    session$setInputs(demo = TRUE)
    expect_null(output$cmp_note)
    session$setInputs(compare = 1)
    expect_s3_class(rv$comparison, "scopus_comparison")
    expect_setequal(
      unique(rv$comparison$abridged_query[rv$comparison$query_type == "comparison"]),
      c("flexible", "energy storage")
    )
  })
})
