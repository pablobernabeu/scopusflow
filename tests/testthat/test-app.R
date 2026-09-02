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

test_that("app_code_mirror marks demo mode and records its version", {
  live <- app_code_mirror(query = "graphene", years = 2018:2020)
  replayed <- app_code_mirror(query = "graphene", years = 2018:2020, demo = TRUE)

  # The script pins the release that wrote it, whichever mode produced it.
  version_line <- sprintf("# scopusflow %s", utils::packageVersion("scopusflow"))
  expect_equal(strsplit(live, "\n")[[1]][1], version_line)
  expect_equal(strsplit(replayed, "\n")[[1]][1], version_line)

  # Under a panel headed "Reproducible code", a demo script that said nothing
  # would reproduce a live harvest the user never ran.
  expect_true(grepl("example_records", replayed, fixed = TRUE))
  expect_false(grepl("example_records", live, fixed = TRUE))
  # Both stay runnable R.
  expect_silent(parse(text = live))
  expect_silent(parse(text = replayed))
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

test_that("app_session_dir keeps one session's cleanup out of another's cache", {
  # Every open tab shares the base, so a session that removed the base rather
  # than its own subdirectory would delete another tab's checkpoints mid-harvest.
  base <- file.path(tempdir(), "scopusflow-app-test")
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  a <- app_session_dir(base)
  b <- app_session_dir(base)
  expect_false(identical(a, b))
  expect_equal(dirname(a), base)
  expect_equal(dirname(b), base)

  dir.create(file.path(a, "cell"), recursive = TRUE)
  dir.create(file.path(b, "cell"), recursive = TRUE)
  saveRDS(1, file.path(b, "cell", "cell-001.rds"))
  unlink(a, recursive = TRUE)          # session A's tab closes
  expect_false(dir.exists(a))
  expect_true(file.exists(file.path(b, "cell", "cell-001.rds")))
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

test_that("the app's year slider opens on the bundled corpus span", {
  skip_if_not_installed("shiny")
  # Demo mode is on when the app opens, and the demo harvest clamps a year
  # outside the corpus into it, so a default window of the last calendar years
  # announced cells it drew nothing from, and drifted further every year.
  span <- app_demo_year_span()
  expect_equal(span, range(example_records$year))
  html <- as.character(app_ui())
  expect_match(html, sprintf('data-from="%d"', span[1L]), fixed = TRUE)
  expect_match(html, sprintf('data-to="%d"', span[2L]), fixed = TRUE)
  # Every cell of that default window has records of its own to replay.
  recs <- app_demo_records(span[1L]:span[2L])
  expect_setequal(unique(recs$year), span[1L]:span[2L])
})

test_that("the demo worker announces the cells it cannot draw from", {
  span <- app_demo_year_span()
  yrs <- c(span[2L], span[2L] + 1L)
  log <- utils::capture.output(
    invisible(app_demo_fetch_worker("graphene", yrs, app_demo_records(yrs), span = span))
  )
  expect_match(log[1], sprintf("^Cell 1/2: demo records for graphene \\(%d\\)$", span[2L]))
  expect_match(log[2], sprintf("^Cell 2/2: demo records for graphene \\(%d\\)$", span[2L] + 1L))
  expect_match(log[3], sprintf("%d is outside the bundled example harvest", span[2L] + 1L))
  # An unpartitioned run is one cell over every year, once announced as "(0)".
  no_years <- utils::capture.output(
    invisible(app_demo_fetch_worker("graphene", NULL, app_demo_records(NULL)))
  )
  expect_equal(no_years, "Cell 1/1: demo records for graphene")
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

test_that("every field the app offers is one the package documents", {
  choices <- app_field_choices()
  tagged <- choices[nzchar(choices)]
  expect_true(all(tagged %in% scopus_field_tags()$tag))
  # The same label sends the same tag in the Python app, whose selector reads
  # "AUTH": "Author"; a surname-only tag would search something else there.
  expect_equal(unname(choices[["Author"]]), "AUTH")
  # The untagged option is the app's own, and leaves the query unwrapped.
  expect_true("" %in% choices)
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
    # The reference topic is counted once per year too, so two terms over two
    # years is six requests rather than four.
    expect_match(as.character(output$cmp_note$html),
                 "(2 terms plus the reference) x 2 years (2015 to 2016) = 6 count requests",
                 fixed = TRUE)

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

test_that("the server refuses a blank query rather than spending on it", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "   ", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2016),
      max_results = 5, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    session$setInputs(count = 1)
    expect_null(rv$size_note)
    # With a key the worker would only call scopus_plan("") and die, after the
    # user had waited for a background process to start.
    session$setInputs(fetch = 1)
    expect_null(rv$proc)
    expect_equal(rv$status, "idle")
  })
})

test_that("the server declines a size check while a harvest is running", {
  skip_if_not_installed("shiny")
  # The app runs one operation at a time: scopus_count() runs on the single
  # Shiny thread, so a size check fired mid-harvest would freeze the live
  # terminal and the progress poller.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2016),
      max_results = 5, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    rv$proc <- list(is_alive = function() TRUE)
    session$setInputs(count = 1)
    expect_null(rv$size_note)
  })
})

test_that("the server turns any size failure into a notification, not a red screen", {
  skip_if_not_installed("shiny")
  # A failure carrying no scopus_error class used to escape the observer, which
  # in Shiny ends the client session rather than showing the message.
  local_mocked_bindings(scopus_count = function(...) stop("boom"))
  shiny::testServer(app_server, {
    session$setInputs(
      demo = FALSE, api_key = "k", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = FALSE, years = c(2015, 2016),
      max_results = 5, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    session$setInputs(count = 1)
    expect_equal(rv$status, "error")
    expect_null(rv$size_note)
  })
})

test_that("the server plots a comparison whose highlight has no plottable share", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # plot_scopus_comparison() drops the years with no share before it reads the
  # highlight, so a topic whose counts all came back missing would abort it.
  cmp <- app_demo_comparison("graphene", c("flexible", "opaque"), 2015:2017)
  cmp$comparison_percentage[cmp$abridged_query == "opaque"] <- NA_real_
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2017),
      max_results = 5, cmp_terms = "flexible, opaque", cmp_highlight = "opaque",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    rv$comparison <- cmp
    session$flushReact()
    expect_no_error(output$plot_comparison)
    session$setInputs(cmp_highlight = "flexible")
    expect_no_error(output$plot_comparison)
  })
})

test_that("the server labels a demo comparison and a demo script", {
  skip_if_not_installed("shiny")
  # The figure's own caption names the Search API, which is true of a real
  # comparison but not of the synthesised one demo mode draws, and the script
  # panel would otherwise hand over a live harvest the user never ran.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2017),
      max_results = 5, cmp_terms = "flexible", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    expect_match(output$code_mirror, "example_records", fixed = TRUE)
    expect_null(output$cmp_demo_note)

    session$setInputs(compare = 1)
    expect_match(as.character(output$cmp_demo_note$html), "illustrative rather than retrieved")

    # The note stays with the figure it describes once the switch is flipped,
    # and a live script stops claiming the records were replayed.
    session$setInputs(demo = FALSE)
    expect_false(grepl("example_records", output$code_mirror, fixed = TRUE))
    expect_match(as.character(output$cmp_demo_note$html), "illustrative rather than retrieved")
  })
})

test_that("the server prices the record cap into the size it reports", {
  skip_if_not_installed("shiny")
  # scopus_fetch_plan() stops a cell at the cap without warning, since a cap the
  # caller set is short by request, so the size note is where the count and the
  # cap have to meet.
  local_mocked_bindings(scopus_count = function(...) 250000)
  shiny::testServer(app_server, {
    session$setInputs(
      demo = FALSE, api_key = "k", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2020),
      max_results = 200, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    session$setInputs(count = 1)
    expect_equal(
      rv$size_note,
      paste("This query matches 250,000 records across 6 year-cells.",
            "The cap of 200 per cell would retrieve at most 1,200.")
    )
    # A blank cap retrieves everything, so there is nothing to warn about.
    session$setInputs(max_results = NA_integer_)
    session$setInputs(count = 2)
    expect_equal(rv$size_note,
                 "This query matches 250,000 records across 6 year-cells.")
  })
})

test_that("the server drops a size note the search has outgrown", {
  skip_if_not_installed("shiny")
  # The note sits in an alert box as the app's one statement of what a search
  # costs, so one left over from a plan no longer on screen is worse than none.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2017),
      max_results = 5, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    session$setInputs(count = 1)
    expect_match(rv$size_note, "^Demo plan: 3 year-cells")
    session$setInputs(query = "perovskite")
    expect_null(rv$size_note)

    session$setInputs(count = 2)
    expect_match(rv$size_note, "^Demo plan: 3 year-cells")
    session$setInputs(years = c(2015, 2020))
    expect_null(rv$size_note)

    # Nothing a demo note says about the bundled corpus is true of a real
    # search, or the other way about.
    session$setInputs(count = 3)
    expect_match(rv$size_note, "^Demo plan: 6 year-cells")
    session$setInputs(demo = FALSE)
    expect_null(rv$size_note)
    session$setInputs(demo = TRUE)

    # Starting a harvest also settles the question the note was answering.
    session$setInputs(count = 4)
    expect_match(rv$size_note, "^Demo plan: 6 year-cells")
    session$setInputs(fetch = 1)
    expect_null(rv$size_note)
    if (!is.null(rv$proc)) rv$proc$kill()
  })
})

test_that("the Records tab says how many records it is previewing", {
  skip_if_not_installed("shiny")
  # The table shows 25 rows whatever the harvest, and the notification carrying
  # the true count has faded by the time the tab is read.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = FALSE, years = c(2015, 2024),
      max_results = NA_integer_, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    expect_null(output$records_note)

    rv$records <- example_records
    session$flushReact()
    note <- as.character(output$records_note$html)
    expect_match(note, sprintf("%s records", format(nrow(example_records),
                                                    big.mark = ",")))
    expect_match(note, "Showing the first 25")

    # A harvest the table shows whole is not called a preview.
    rv$records <- utils::head(example_records, 3L)
    session$flushReact()
    note <- as.character(output$records_note$html)
    expect_match(note, "3 records.", fixed = TRUE)
    expect_false(grepl("Showing", note, fixed = TRUE))
  })
})

test_that("a comparison with the year partition off names the years it used", {
  skip_if_not_installed("shiny")
  # Without a slider span the comparison falls back to the last six years, which
  # nothing on screen used to show and the script left out altogether.
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  shiny::testServer(app_server, {
    session$setInputs(
      demo = FALSE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = FALSE, years = c(2015, 2016),
      max_results = 5, cmp_terms = "flexible, energy storage",
      cmp_highlight = "", cmp_interval = TRUE, cmp_counts = TRUE
    )
    expect_equal(cmp_years_value(), seq(this_year - 5L, this_year))
    expect_match(as.character(output$cmp_note$html),
                 sprintf("x 6 years (%d to %d) = 18 count requests",
                         this_year - 5L, this_year),
                 fixed = TRUE)

    # The script carries the comparison the user can run, over those years.
    code <- code_text()
    expect_true(grepl("scopus_compare_topics(", code, fixed = TRUE))
    expect_true(grepl(sprintf("years = %d:%d", this_year - 5L, this_year),
                      code, fixed = TRUE))
    # The plan above it still has no year restriction of its own.
    expect_false(grepl("partition = \"year\"", code, fixed = TRUE))

    session$setInputs(demo = TRUE, compare = 1)
    expect_setequal(unique(rv$comparison$year), seq(this_year - 5L, this_year))
  })
})

test_that("an empty harvest says so rather than showing an internal abort", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # A query that matched nothing returns a record set with no rows, which the
  # is.null() guard lets through and every plotting function refuses.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = FALSE, years = c(2015, 2024),
      max_results = NA_integer_, cmp_terms = "", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    rv$records <- scopus_records(list())
    session$flushReact()
    expect_error(output$plot_year, "No records to plot.", class = "validation")
    expect_error(output$plot_sources, "No source titles to tally.",
                 class = "validation")
    expect_error(output$plot_authors, "No author names to tally.",
                 class = "validation")

    # Records with no source titles tally to nothing, while the years still plot.
    recs <- app_demo_records(2015:2016)
    recs$publication <- NA_character_
    rv$records <- recs
    session$flushReact()
    expect_error(output$plot_sources, "No source titles to tally.",
                 class = "validation")
    expect_type(output$plot_year, "list")
  })
})

test_that("the export buttons arrive with the records they write", {
  skip_if_not_installed("shiny")
  # Each download handler opens with req(), which fails the download in the
  # browser with nothing on screen to say why, so a button with nothing to
  # write is not offered.
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = FALSE, years = c(2015, 2024),
      max_results = NA_integer_, cmp_terms = "flexible", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    empty <- as.character(output$export_buttons$html)
    expect_match(empty, "Fetch records to export them")
    expect_false(grepl("dl_rds", empty, fixed = TRUE))
    expect_null(output$cmp_download)

    rv$records <- example_records
    rv$comparison <- app_demo_comparison("graphene", "flexible", 2015:2017)
    session$flushReact()
    filled <- as.character(output$export_buttons$html)
    for (id in c("dl_rds", "dl_dois", "dl_bibtex", "dl_ris", "dl_report")) {
      expect_match(filled, id, fixed = TRUE)
    }
    expect_match(as.character(output$cmp_download$html), "dl_comparison",
                 fixed = TRUE)
  })
})

test_that("the key status uses colours dark enough to read", {
  skip_if_not_installed("shiny")
  # Bootstrap's plain .text-info, .text-warning and .text-success all fall
  # under 4.5:1 against the sidebar, so the banner every session opens on was
  # unreadable.
  shiny::testServer(app_server, {
    session$setInputs(demo = TRUE, api_key = "")
    expect_match(as.character(output$key_status$html), "text-info-emphasis")

    session$setInputs(demo = FALSE)
    expect_match(as.character(output$key_status$html), "text-warning-emphasis")
    session$setInputs(api_key = "k")
    expect_match(as.character(output$key_status$html), "text-success-emphasis")
  })
})

test_that("the progress bar reports its value to assistive technology", {
  skip_if_not_installed("shiny")
  # role="progressbar" with no value and no name announces nothing during the
  # long wait it exists for.
  shiny::testServer(app_server, {
    session$setInputs(demo = TRUE, api_key = "")
    rv$status <- "running"
    rv$progress <- list(done = 4L, total = 10L)
    session$flushReact()
    bar <- as.character(output$progress_ui$html)
    expect_match(bar, 'aria-label="Fetching cell 4 of 10"', fixed = TRUE)
    expect_match(bar, 'aria-valuenow="30"', fixed = TRUE)
    expect_match(bar, 'aria-valuemin="0"', fixed = TRUE)
    expect_match(bar, 'aria-valuemax="100"', fixed = TRUE)

    # An animated bar has no value yet, which ARIA spells as no aria-valuenow.
    rv$progress <- NULL
    session$flushReact()
    bar <- as.character(output$progress_ui$html)
    expect_match(bar, 'aria-label="Working..."', fixed = TRUE)
    expect_false(grepl("aria-valuenow", bar, fixed = TRUE))
  })
})

test_that("every figure the app draws carries a text alternative", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # Without alt, each figure reaches the browser as shiny's "Plot object".
  shiny::testServer(app_server, {
    session$setInputs(
      demo = TRUE, api_key = "", query = "graphene", field = "TITLE-ABS-KEY",
      view = "STANDARD", use_years = TRUE, years = c(2015, 2016),
      max_results = NA_integer_, cmp_terms = "flexible", cmp_highlight = "",
      cmp_interval = TRUE, cmp_counts = TRUE
    )
    rv$records <- app_demo_records(2015:2016)
    session$flushReact()
    expect_match(output$plot_year$alt, "^Bar chart of records by year: \\d+ records from 2015 to 2016\\.$")
    expect_match(output$plot_sources$alt, "^Bar chart of the \\d+ most frequent source titles: .+ leads with \\d+ record")
    expect_match(output$plot_authors$alt, "^Bar chart of the \\d+ most frequent author names: .+ leads with \\d+ record")

    session$setInputs(compare = 1)
    expect_match(output$plot_comparison$alt,
                 "share of 'graphene' records matching 'flexible', 2015 to 2016")

    # shiny evaluates alt even when the panel validates away, so a tally with
    # nothing in it must not let the alt text abort in place of the message.
    recs <- app_demo_records(2015:2016)
    recs$publication <- NA_character_
    rv$records <- recs
    session$flushReact()
    expect_error(output$plot_sources, "No source titles to tally.",
                 class = "validation")
  })
})
