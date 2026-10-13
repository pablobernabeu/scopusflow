# Most of these tests pin the pure helpers behind the app, which run fully
# offline. The server tests at the end drive app_server() through
# shiny::testServer(), synchronously and with every request mocked.

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

test_that("app_demo_comparison joins its queries as scopus_compare_topics does", {
  cmp <- app_demo_comparison("a OR b", "c d", 2019:2020)
  expect_identical(
    unique(cmp$query[cmp$query_type == "comparison"]),
    "(a OR b) AND (c d)"
  )
})

test_that("run_app is exported and guarded", {
  expect_true(is.function(run_app))
})

test_that("the record cap starts blank and is labelled per cell", {
  # The field used to default to 200 records per year, so every live harvest
  # was capped unless the user cleared it, and the By year tab then plotted
  # the cap. With partitioning off it caps the whole search, a single cell.
  ui <- as.character(app_ui())
  expect_true(grepl("Max records per cell (blank = all)", ui, fixed = TRUE))
  expect_false(grepl("Max records per year", ui, fixed = TRUE))
  input <- regmatches(ui, regexpr("<input id=\"max_results\"[^>]*>", ui))
  expect_length(input, 1L)
  # shiny writes a missing value as "NA". A browser shows that as an empty
  # number field, and shiny's number input hands the server NA for it, read
  # as no cap.
  expect_true(grepl("value=\"NA\"", input, fixed = TRUE))
})

# A two-cell harvest whose first cell stopped at a cap of 15.
app_capped_records <- function(cap = 15L) {
  recs <- example_records[1:30, ]
  attr(recs, "plan") <- scopus_plan("graphene", years = 2019:2020, partition = "year")
  attr(recs, "cell_totals") <- tibble::tibble(
    cell = 1:2, date = c("2019", "2020"), n_records = c(15L, 15L),
    reported_total = c(40, 15)
  )
  attr(recs, "max_results") <- cap
  recs
}

test_that("the app notes a harvest whose cap stopped a cell", {
  expect_identical(
    app_cap_note(app_capped_records()),
    paste("The cap of 15 records per cell stopped 1 of 2 cells. Each capped cell",
          "holds only its first 15 matches, so By year counts the records",
          "retrieved, not publications per year. Clear Max records per cell and",
          "fetch again to lift the cap.")
  )
  # A cap that stopped nothing, an uncapped harvest and the demo replay, which
  # records no cap, show no note.
  expect_null(app_cap_note(app_capped_records(cap = 100L)))
  expect_null(app_cap_note(example_records))
  expect_null(app_cap_note(app_demo_records(2019:2020, max_per_year = 2)))
  expect_null(app_cap_note(NULL))
})

test_that("the authors tab says when a STANDARD harvest names first authors only", {
  standard <- complete <- example_records
  attr(standard, "view") <- "STANDARD"
  attr(complete, "view") <- "COMPLETE"
  expect_identical(
    app_authors_note(standard),
    "STANDARD view: first authors only. Choose COMPLETE under Detail to tally every author."
  )
  expect_null(app_authors_note(complete))
  # The demo replays the bundled corpus, which records no view.
  expect_null(app_authors_note(app_demo_records(2019:2020)))
  expect_null(app_authors_note(NULL))
})

# Inputs for a server test: a key in the box, demo mode off unless asked.
app_test_inputs <- function(session, query, demo = FALSE, ...) {
  session$setInputs(
    demo = demo, api_key = "test-key", query = query, field = "TITLE-ABS-KEY",
    view = "STANDARD", use_years = TRUE, years = c(2019, 2020),
    max_results = 5, cmp_terms = "", cmp_highlight = "",
    cmp_interval = TRUE, cmp_counts = TRUE, ...
  )
}

test_that("Check size on a blank query keeps the session open and sends nothing", {
  skip_if_not_installed("shiny")
  requested <- FALSE
  httr2::local_mocked_responses(function(req) {
    requested <<- TRUE
    httr2::response(status_code = 500L)
  })
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "   ")
    session$setInputs(count = 1)
    # scopus_count() refused the blank query with an input error that the
    # handler, which caught scopus_error alone, let through, and an error
    # escaping an observer ends the Shiny session.
    expect_false(session$isClosed())
    expect_null(rv$size_note)
    expect_false(identical(rv$status, "error"))
  })
  expect_false(requested)
})

test_that("Fetch on a blank query starts no retrieval", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("callr")
  # A regression here starts a background R process through callr, so the
  # test stays off CRAN. Demo mode keeps even that process offline.
  skip_on_cran()
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "", demo = TRUE)
    session$setInputs(fetch = 1)
    proc <- rv$proc
    if (!is.null(proc)) try(proc$kill(), silent = TRUE)
    expect_false(session$isClosed())
    expect_null(proc)
    expect_false(identical(rv$status, "running"))
  })
})

test_that("Check size turns an untyped failure into a notification", {
  skip_if_not_installed("shiny")
  # An error from the transport layer that carries no scopus_error class, as
  # an internal fault would. It used to escape the observer and end the
  # session.
  httr2::local_mocked_responses(function(req) stop("connection reset in a test"))
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    session$setInputs(count = 1)
    expect_false(session$isClosed())
    expect_identical(rv$status, "error")
    expect_null(rv$size_note)
  })
})

test_that("Check size in demo mode prices the plan from the bundled corpus", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(count = 1)
    expect_false(session$isClosed())
    expect_match(rv$size_note, "^Demo plan: 2 year-cells")
  })
})

test_that("Compare refuses a blank query and compares in demo mode", {
  skip_if_not_installed("shiny")
  requested <- FALSE
  httr2::local_mocked_responses(function(req) {
    requested <<- TRUE
    httr2::response(status_code = 500L)
  })
  shiny::testServer(app_server, {
    app_test_inputs(session, query = " ")
    session$setInputs(cmp_terms = "flexible, energy storage", compare = 1)
    expect_false(session$isClosed())
    expect_null(rv$comparison)

    session$setInputs(demo = TRUE, query = "graphene", compare = 2)
    expect_false(session$isClosed())
    expect_s3_class(rv$comparison, "scopus_comparison")
    expect_setequal(
      unique(rv$comparison$abridged_query[rv$comparison$query_type == "comparison"]),
      c("flexible", "energy storage")
    )
  })
  expect_false(requested)
})

test_that("the authors tab notes a STANDARD harvest, and leaves the session's warning", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  rlang::reset_warning_verbosity("scopusflow_first_author_only")
  withr::defer(rlang::reset_warning_verbosity("scopusflow_first_author_only"))
  standard <- example_records
  attr(standard, "view") <- "STANDARD"
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    rv$records <- standard
    session$flushReact()
    expect_match(output$authors_note$html, "first authors only", fixed = TRUE)
    # Drawing the tally must not spend the once-per-session warning, which the
    # note has already given in the app.
    expect_no_warning(output$plot_authors)
    rv$records <- example_records
    session$flushReact()
    expect_false(grepl("first authors only", output$authors_note$html %||% "", fixed = TRUE))
  })
  expect_warning(scopus_top(standard, by = "author"),
                 class = "scopus_warning_first_author_only")
})

test_that("the Retrieval card shows the cap note after a capped harvest", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    rv$records <- app_capped_records()
    session$flushReact()
    expect_match(output$cap_note$html, "stopped 1 of 2 cells", fixed = TRUE)
    rv$records <- example_records
    session$flushReact()
    expect_false(grepl("stopped", output$cap_note$html %||% "", fixed = TRUE))
  })
})
