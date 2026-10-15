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
  expect_true(grepl("cache_dir = file.path(scopus_cache_dir(), ", code, fixed = TRUE))
  expect_true(grepl('scopus_top(records, by = "source")', code, fixed = TRUE))
  # The key handling is documented and the script is parseable R.
  expect_true(grepl("SCOPUS_API_KEY", code))
  expect_silent(parse(text = code))
})

test_that("app_code_mirror opens with its version and says when demo mode was on", {
  live <- app_code_mirror(query = "graphene", years = 2018:2020)
  replayed <- app_code_mirror(query = "graphene", years = 2018:2020, demo = TRUE)
  # A downloaded script records the release its behaviour belongs to, as the
  # Python twin's does, whichever mode wrote it.
  version_line <- sprintf("# scopusflow %s", utils::packageVersion("scopusflow"))
  expect_identical(strsplit(live, "\n", fixed = TRUE)[[1]][1], version_line)
  expect_identical(strsplit(replayed, "\n", fixed = TRUE)[[1]][1], version_line)
  # A demo session retrieved nothing, so its script says that the records were
  # replayed and that what follows is the live equivalent.
  expect_match(replayed, "example_records", fixed = TRUE)
  expect_false(grepl("example_records", live, fixed = TRUE))
  expect_silent(parse(text = live))
  expect_silent(parse(text = replayed))
})

test_that("the generated script saves its results before it plots", {
  # autoplot() needs ggplot2, which is only suggested, so a script that
  # plotted first stopped there on a machine without it, before saving the
  # records it had just paid for.
  lines <- strsplit(app_code_mirror(query = "x", years = 2018:2020), "\n",
                    fixed = TRUE)[[1]]
  plot <- grep("autoplot(records)", lines, fixed = TRUE)
  expect_length(plot, 1L)
  expect_match(lines[plot], 'requireNamespace("ggplot2", quietly = TRUE)',
               fixed = TRUE)
  saves <- grep("write_scopus_records|scopus_extract_dois|as_bibtex|scopus_search_report",
                lines)
  expect_length(saves, 4L)
  expect_true(all(saves < plot))
})

# The directory a generated script passes to scopus_fetch_plan() as cache_dir,
# evaluated as the script would evaluate it.
script_cache_dir <- function(code) {
  for (e in as.list(parse(text = code))) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && is.call(e[[3]]) &&
        identical(e[[3]][[1]], as.name("scopus_fetch_plan"))) {
      return(eval(e[[3]]$cache_dir))
    }
  }
  NULL
}

# Run the two lines of a generated script that reach the cache, the plan and
# the fetch. The others size, save, tally or plot.
run_script_harvest <- function(code) {
  env <- new.env()
  for (e in as.list(parse(text = code))) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && is.call(e[[3]]) &&
        as.character(e[[3]][[1]]) %in% c("scopus_plan", "scopus_fetch_plan")) {
      eval(e, env)
    }
  }
  invisible(env$records)
}

test_that("the scripts the app writes keep each plan's checkpoints apart", {
  local_scopus_test_env()
  withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir())
  requests <- 0L
  corpus <- mock_corpus(3L)
  httr2::local_mocked_responses(function(req) {
    requests <<- requests + 1L
    corpus(req)
  })
  first <- app_code_mirror(query = "graphene", years = 2023:2024)
  second <- app_code_mirror(query = "perovskite", years = 2023:2024)
  # Each plan's directory lies under the managed cache, so
  # scopus_cache_clear() still empties it, and opens with its search.
  dir <- script_cache_dir(first)
  expect_identical(dir, file.path(scopus_cache_dir(), basename(dir)))
  expect_match(basename(dir), "^graphene-2023-2024-[0-9a-f]{8}$")

  run_script_harvest(first)
  run_script_harvest(second)
  expect_identical(requests, 4L)
  # Every script used to pass the cache's root, where the second plan's cells
  # overwrote the first plan's, so each rerun refetched them with a warning.
  expect_no_warning(run_script_harvest(first), class = "scopus_warning_cache_mismatch")
  expect_identical(requests, 4L)
})

test_that("the script's checkpoint directory changes with the plan and only with it", {
  name <- function(...) basename(script_cache_dir(app_code_mirror(...)))
  base <- name(query = "graphene", years = 2018:2022, field = "TITLE-ABS-KEY")
  # The same search finds its checkpoints again, whatever its record cap,
  # since a checkpoint records whether a cap stopped it.
  expect_identical(name(query = "graphene", years = 2018:2022, field = "TITLE-ABS-KEY"),
                   base)
  expect_identical(name(query = "graphene", years = 2018:2022, field = "TITLE-ABS-KEY",
                        max_results = 25), base)
  # Whatever changes the cells changes the directory.
  others <- c(
    name(query = "graphene oxide", years = 2018:2022, field = "TITLE-ABS-KEY"),
    name(query = "graphene", years = 2019:2022, field = "TITLE-ABS-KEY"),
    name(query = "graphene", years = 2018:2022, field = "TITLE"),
    name(query = "graphene", years = 2018:2022, field = "TITLE-ABS-KEY",
         view = "COMPLETE"),
    name(query = "graphene", years = 2018:2022, field = "TITLE-ABS-KEY",
         partition = "none")
  )
  expect_false(base %in% others)
  expect_length(unique(others), length(others))
  # A query with no ASCII letters or digits is named by its years and hash.
  expect_match(name(query = "石墨烯", years = 2018:2022),
               "^2018-2022-[0-9a-f]{8}$")
  # Capitals fold to their ASCII lower case.
  expect_match(name(query = "Graphene IN Supercapacitors", years = 2018:2022),
               "^graphene-in-supercapacitors-2018-2022-[0-9a-f]{8}$")
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

test_that("app_code_mirror skips the comparison block only without terms or a span", {
  expect_false(grepl("compare_topics",
                     app_code_mirror(query = "x", years = 2018:2020), fixed = TRUE))
  # Terms and no span anywhere: skipped, since scopus_compare_topics() needs
  # years.
  expect_false(grepl("compare_topics",
                     app_code_mirror(query = "x", years = NULL, partition = "none",
                                     compare_terms = "a"), fixed = TRUE))
  # An unpartitioned plan has no years, but the app still compares, over the
  # years it passes as compare_years, so the script names them.
  code <- app_code_mirror(query = "x", years = NULL, partition = "none",
                          compare_terms = "a", compare_years = 2021:2026)
  expect_match(code, "scopus_compare_topics(", fixed = TRUE)
  expect_match(code, "years = 2021:2026", fixed = TRUE)
  expect_match(code, 'plan <- scopus_plan("x")', fixed = TRUE)
  expect_silent(parse(text = code))
})

test_that("a comparison costs a request per term and one for the reference, every year", {
  # scopus_compare_topics() counts the reference in each year as well as each
  # term, so the app's default of two terms over six years makes 18 requests.
  expect_identical(app_comparison_cost(2L, 6L), 18L)
  expect_identical(app_comparison_cost(1L, 1L), 2L)
  expect_identical(app_comparison_note(2L, 6L),
                   "(2 terms + the reference) x 6 years = 18 count requests.")
  expect_identical(app_comparison_note(1L, 1L),
                   "(1 term + the reference) x 1 year = 2 count requests.")
  # The advice applies above 80 requests, counted the same way.
  expect_match(app_comparison_note(2L, 27L),
               "= 81 count requests. Consider fewer terms or years.", fixed = TRUE)
  expect_false(grepl("Consider", app_comparison_note(3L, 20L), fixed = TRUE))
})

test_that("each session's checkpoints have a directory of their own", {
  root <- file.path("tmp", "scopusflow-app")
  a <- app_session_cache_dir(root, "token-a", "search")
  b <- app_session_cache_dir(root, "token-b", "search")
  # The same search in two tabs never shares a directory, while one tab that
  # fetches it again finds its own checkpoints.
  expect_false(identical(a, b))
  expect_identical(app_session_cache_dir(root, "token-a", "search"), a)
  # Each search sits in its session's base, the directory that session's
  # cleanup removes.
  expect_identical(dirname(a), app_session_cache_dir(root, "token-a"))
  expect_identical(dirname(b), app_session_cache_dir(root, "token-b"))
  expect_identical(dirname(app_session_cache_dir(root, "token-a")), root)
})

test_that("a failed harvest is reported in the worker's own words", {
  skip_if_not_installed("callr")
  skip_on_cran()
  # The worker's error reaches the app wrapped by callr, whose message opens
  # with "in callr subprocess" and a deparsed call. The worker's own condition
  # is the wrapper's parent.
  failed <- function(fun) {
    proc <- callr::r_bg(fun)
    proc$wait(timeout = 60000)
    tryCatch(proc$get_result(), error = function(e) e)
  }
  res <- failed(function() {
    rlang::abort("Scopus rejected the API key (HTTP 401).",
                 class = c("scopus_error_unauthorized", "scopus_error"))
  })
  expect_match(conditionMessage(res), "callr subprocess", fixed = TRUE)
  expect_identical(app_fetch_failure_message(res),
                   "Scopus: Scopus rejected the API key (HTTP 401).")
  # Any other failure keeps the retrieval's heading, still without the wrapper.
  res <- failed(function() stop("disk full"))
  expect_identical(app_fetch_failure_message(res),
                   "Retrieval did not complete: disk full")
  # An error raised in the app's own process has no wrapper to unpick.
  expect_identical(app_fetch_failure_message(simpleError("no worker")),
                   "Retrieval did not complete: no worker")
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

test_that("the app reads the bundled corpus with scopusflow loaded but not attached", {
  skip_if_not_installed("callr")
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  # A second R process, so the test stays off CRAN.
  skip_on_cran()
  # scopusflow::run_app() in a fresh session loads the package without
  # attaching it. Package code then reaches a lazy-loaded dataset through `::`
  # alone, because a bare name is found through the attached package. Demo
  # mode's Check size and Fetch records stopped at that lookup, and the year
  # slider, which opens on the corpus's span, would stop the app at start-up.
  ns_path <- getNamespaceInfo("scopusflow", "path")
  # The code under test is the source tree under devtools::test() and the
  # installed package under R CMD check. pkgload is reached through
  # getExportedValue(), since only the first of those has it.
  from_source <- file.exists(file.path(ns_path, "R", "run-app.R"))
  out <- callr::r(function(ns_path, from_source) {
    if (from_source) {
      load_all <- getExportedValue("pkgload", "load_all")
      suppressMessages(load_all(ns_path, attach = FALSE, export_all = FALSE,
                                helpers = FALSE, quiet = TRUE))
    } else {
      loadNamespace("scopusflow")
    }
    ns <- asNamespace("scopusflow")
    attempt <- function(expr) tryCatch(expr, error = conditionMessage)
    list(
      attached = "package:scopusflow" %in% search(),
      ui = attempt(!is.null(ns$app_ui())),
      demo = attempt(nrow(ns$app_demo_records(2015:2016)))
    )
  }, args = list(ns_path = ns_path, from_source = from_source))
  expect_false(out$attached)
  expect_identical(out$ui, TRUE)
  expect_identical(out$demo, sum(example_records$year %in% 2015:2016))
})

test_that("the record cap starts blank and is labelled per cell", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
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

test_that("the year slider opens on the span of the bundled corpus", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  # Demo mode is on when the app opens and replays the bundled corpus. A window
  # of the last six calendar years announced cells past the corpus's end, which
  # the demo harvest folded into its last year.
  span <- range(example_records$year)
  ui <- as.character(app_ui())
  slider <- regmatches(ui, regexpr("<input[^>]*id=\"years\"[^>]*>", ui))
  expect_length(slider, 1L)
  expect_match(slider, sprintf("data-from=\"%d\"", span[1L]), fixed = TRUE)
  expect_match(slider, sprintf("data-to=\"%d\"", span[2L]), fixed = TRUE)
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

test_that("the demo search record names no expression and says it was replayed", {
  # The bundled corpus carries the phrase of its own OpenAlex search in its
  # query column, which is neither what the user typed nor a search sent to
  # 'Scopus'. Carried into the record, it was the search expression of a
  # methods paragraph written to be pasted into a manuscript. The Python
  # twin's _search_record() writes the same note.
  recs <- app_demo_records(2019:2020)
  replayed <- app_search_record(recs, replayed = TRUE)
  expect_true(startsWith(
    replayed, "> Demo mode: these records were replayed from the bundled example harvest"
  ))
  expect_match(gsub("\\s+", " ", replayed), "describes no search that was run", fixed = TRUE)
  expect_match(replayed, "Search expression: unrecorded", fixed = TRUE)
  expect_false(grepl("graphene supercapacitor", replayed, fixed = TRUE))
  # A live harvest's record is the one scopus_search_report() writes, and the
  # records on screen keep their query column.
  expect_identical(app_search_record(recs, replayed = FALSE),
                   format(scopus_search_report(recs), style = "markdown"))
  expect_false(anyNA(recs$query))
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

test_that("a session that ends removes its own checkpoints and no other session's", {
  skip_if_not_installed("shiny")
  root <- file.path(tempdir(), "scopusflow-app")
  # Another tab of the same app, part-way through a harvest. Every tab is a
  # session of one R process, so they share tempdir().
  other <- file.path(root, "another-tab", "a-search")
  dir.create(other, recursive = TRUE, showWarnings = FALSE)
  withr::defer(unlink(file.path(root, "another-tab"), recursive = TRUE))
  saveRDS(1L, file.path(other, "cell-001-2024.rds"))
  own <- NULL
  shiny::testServer(app_server, {
    own <<- file.path(root, session$token)
    dir.create(file.path(own, "a-search"), recursive = TRUE, showWarnings = FALSE)
    saveRDS(1L, file.path(own, "a-search", "cell-001-2024.rds"))
  })
  # testServer() ends the session on its way out, as closing a tab does. The
  # handler used to remove the whole root, the other tab's checkpoints with it.
  expect_true(file.exists(file.path(other, "cell-001-2024.rds")))
  expect_false(dir.exists(own))
})

test_that("a harvest checkpoints into its own session's directory", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("callr")
  # Fetch starts a background R process through callr, so the test stays off
  # CRAN. Demo mode keeps that process offline.
  skip_on_cran()
  root <- file.path(tempdir(), "scopusflow-app")
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(fetch = 1)
    proc <- rv$proc
    searches <- list.dirs(file.path(root, session$token), recursive = FALSE)
    if (!is.null(proc)) try(proc$kill(), silent = TRUE)
    expect_false(is.null(proc))
    expect_length(searches, 1L)
  })
})

test_that("the Records tab says how many records its table previews", {
  skip_if_not_installed("shiny")
  # The table shows the first 25 rows, and the notification that gave the
  # count fades long before the tab is read.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    rv$records <- example_records
    session$flushReact()
    expect_match(output$records_note$html,
                 sprintf("%d records (showing the first 25)", nrow(example_records)),
                 fixed = TRUE)
    rv$records <- utils::head(example_records, 3L)
    session$flushReact()
    expect_match(output$records_note$html, "3 records", fixed = TRUE)
    expect_false(grepl("showing", output$records_note$html, fixed = TRUE))
  })
})

test_that("the comparison note counts the reference in every year", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    session$setInputs(cmp_terms = "flexible, energy storage", years = c(2021, 2026))
    expect_match(output$cmp_note$html,
                 "(2 terms + the reference) x 6 years = 18 count requests.",
                 fixed = TRUE)
    expect_false(grepl("Consider", output$cmp_note$html, fixed = TRUE))
    # The advice to trim follows the true count: 81 requests here, where the
    # note used to say 54 and stay quiet.
    session$setInputs(years = c(2000, 2026))
    expect_match(output$cmp_note$html, "x 27 years = 81 count requests.",
                 fixed = TRUE)
    expect_match(output$cmp_note$html, "Consider fewer terms or years", fixed = TRUE)
    # Unpartitioned, the comparison covers the last six years.
    session$setInputs(use_years = FALSE)
    expect_match(output$cmp_note$html, "x 6 years = 18 count requests.",
                 fixed = TRUE)
  })
})

test_that("the script panel follows demo mode and the years the app compares", {
  skip_if_not_installed("shiny")
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    expect_match(code_text(), "example_records", fixed = TRUE)
    session$setInputs(demo = FALSE)
    expect_false(grepl("example_records", code_text(), fixed = TRUE))
    # With the partition off, the script still carries the comparison, over
    # the last six years, which are the ones the app compares.
    session$setInputs(use_years = FALSE, cmp_terms = "flexible")
    yrs <- cmp_years_value()
    expect_identical(yrs, seq(yrs[1L], yrs[1L] + 5L))
    # The test read the date before the server did, so a new year arriving in
    # between can only move the server's window on by one.
    expect_true(yrs[6L] %in% (this_year + 0:1))
    code <- code_text()
    expect_match(code, "scopus_compare_topics(", fixed = TRUE)
    expect_match(code, sprintf("years = %d:%d", yrs[1L], yrs[6L]), fixed = TRUE)
  })
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

test_that("Search record downloads the replayed record for demo records", {
  skip_if_not_installed("shiny")
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene supercapacitor", demo = TRUE)
    rv$records <- app_demo_records(2019:2020)
    rv$replayed <- TRUE
    # Switching Demo mode off leaves the records on screen, so the record has to
    # keep describing the harvest that drew them.
    session$setInputs(demo = FALSE)
    path <- output$dl_report
    text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    expect_match(text, "replayed from the bundled example harvest", fixed = TRUE)
    expect_false(grepl("graphene supercapacitor", text, fixed = TRUE))
  })
})

test_that("every field the app offers is one the package documents", {
  # The Author entry sent AUTHLASTNAME, a tag scopus_field_tags() does not list
  # and which searches surnames alone, while the Python app sends AUTH under the
  # same label, so one choice ran a different search in each app.
  choices <- app_field_choices()
  tagged <- unname(choices[nzchar(choices)])
  expect_true(all(tagged %in% scopus_field_tags()$tag))
  expect_identical(unname(choices[["Author"]]), "AUTH")
  expect_true("" %in% choices)
})

test_that("the demo worker names its cells as the harvest it replays would", {
  # An unpartitioned run is one cell over every year, which the terminal used
  # to announce as year 0, and a year outside the bundled corpus is drawn from
  # the nearest year it holds, which the terminal now says.
  span <- range(example_records$year)
  years <- c(span[2L], span[2L] + 1L)
  log <- utils::capture.output(invisible(
    app_demo_fetch_worker("graphene", years, app_demo_records(years), span = span)
  ))
  expect_identical(log[1], sprintf("Cell 1/2: demo records for graphene (%d)", span[2L]))
  expect_identical(log[2], sprintf("Cell 2/2: demo records for graphene (%d)", span[2L] + 1L))
  expect_identical(log[3], sprintf(
    "  %d is outside the bundled example harvest (%d-%d), so it is drawn from %d.",
    span[2L] + 1L, span[1L], span[2L], span[2L]
  ))
  expect_length(log, 3L)
  unpartitioned <- utils::capture.output(invisible(
    app_demo_fetch_worker("graphene", NULL, app_demo_records(NULL), span = span)
  ))
  expect_identical(unpartitioned, "Cell 1/1: demo records for graphene")
})

test_that("Check size waits while a retrieval is running", {
  skip_if_not_installed("shiny")
  # A real count runs on the one Shiny thread, so it would freeze the live
  # terminal and the progress poller for the length of the request. The app
  # runs one job at a time.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    rv$proc <- list(is_alive = function() TRUE)
    session$setInputs(count = 1)
    expect_null(rv$size_note)
    rv$proc <- NULL
    session$setInputs(count = 2)
    expect_match(rv$size_note, "^Demo plan: 2 year-cells")
  })
})

test_that("a size note goes when the search it answers for changes", {
  skip_if_not_installed("shiny")
  # The note is the app's statement of what a search costs, so one left over
  # from a plan no longer on screen read as the price of the new one.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(count = 1)
    expect_match(rv$size_note, "^Demo plan: 2 year-cells")
    session$setInputs(query = "perovskite")
    expect_null(rv$size_note)
    session$setInputs(count = 2)
    session$setInputs(years = c(2015, 2020))
    expect_null(rv$size_note)
    session$setInputs(count = 3)
    expect_match(rv$size_note, "^Demo plan: 6 year-cells")
    session$setInputs(field = "TITLE")
    expect_null(rv$size_note)
    session$setInputs(count = 4)
    session$setInputs(demo = FALSE)
    expect_null(rv$size_note)
  })
})

test_that("a size note writes its count in full and goes when a later check fails", {
  skip_if_not_installed("shiny")
  # format() writes 100000 as 1e+05. The second check fails in the transport
  # layer, as an untyped error.
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    if (calls > 1L) stop("connection reset in a test")
    mock_search_results(list(), total = 100000)
  })
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene")
    session$setInputs(count = 1)
    expect_identical(rv$size_note,
                     "This query matches 100,000 records across 2 year-cells.")
    session$setInputs(count = 2)
    expect_identical(rv$status, "error")
    expect_null(rv$size_note)
  })
})

test_that("starting a harvest drops the size note", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("callr")
  # Fetch starts a background R process through callr, so the test stays off
  # CRAN. Demo mode keeps that process offline, and it is stopped at once.
  skip_on_cran()
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(count = 1)
    expect_false(is.null(rv$size_note))
    session$setInputs(fetch = 1)
    proc <- rv$proc
    if (!is.null(proc)) try(proc$kill(), silent = TRUE)
    expect_null(rv$size_note)
  })
})

test_that("the app sends the query it shows, trimmed", {
  skip_if_not_installed("shiny")
  # The script panel trims the query, while the count, the comparison and the
  # harvest sent it as typed, so a query pasted with surrounding space went to
  # the API inside the field tag and into the search record. The white space
  # here is what the Python twin's str.strip() removes, a no-break space and a
  # tab among it.
  sent <- character()
  httr2::local_mocked_responses(function(req) {
    sent <<- c(sent, httr2::url_parse(req$url)$query$query)
    mock_search_results(list(), total = 10L)
  })
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "  graphene supercapacitor\t")
    expect_match(code_text(), "scopus_plan(\n  \"graphene supercapacitor\",", fixed = TRUE)
    session$setInputs(count = 1)
    session$setInputs(cmp_terms = "flexible", compare = 1)
  })
  # One count, then the reference and the term in each of the two years.
  expect_length(sent, 5L)
  expect_true(all(grepl("TITLE-ABS-KEY(graphene supercapacitor)", sent, fixed = TRUE)))
})

test_that("a harvest is started with the query trimmed", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("callr")
  # Fetch starts a background R process through callr, so the test stays off
  # CRAN. Demo mode keeps that process offline, and its first line names the
  # query the worker was given.
  skip_on_cran()
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "  graphene  ", demo = TRUE)
    session$setInputs(fetch = 1)
    proc <- rv$proc
    lines <- character()
    for (i in seq_len(100L)) {
      lines <- readLines(rv$logfile, warn = FALSE)
      if (length(lines) > 0L) break
      Sys.sleep(0.1)
    }
    if (!is.null(proc)) try(proc$kill(), silent = TRUE)
    expect_identical(lines[1], "Cell 1/2: demo records for graphene (2019)")
  })
})

test_that("a highlighted topic with no share to plot is left unhighlighted", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # plot_scopus_comparison() drops the years with no share before it reads the
  # highlight, so a topic whose counts all came back missing was offered in the
  # selector and then replaced the figure with an error. The Python app leaves
  # such a topic unhighlighted.
  cmp <- app_demo_comparison("graphene", c("flexible", "opaque"), 2015:2017)
  cmp$comparison_percentage[cmp$abridged_query == "opaque"] <- NA_real_
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(cmp_terms = "flexible, opaque", cmp_highlight = "opaque")
    rv$comparison <- cmp
    session$flushReact()
    expect_no_error(output$plot_comparison)
    session$setInputs(cmp_highlight = "flexible")
    expect_no_error(output$plot_comparison)
  })
})

test_that("a demo comparison says its counts are illustrative", {
  skip_if_not_installed("shiny")
  # The figure's caption names the Search API as its source, which is true of a
  # real comparison and not of the one demo mode synthesises. The Python app
  # already says so.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(cmp_terms = "flexible")
    expect_null(output$cmp_demo_note)
    session$setInputs(compare = 1)
    expect_match(output$cmp_demo_note$html, "illustrative rather than retrieved",
                 fixed = TRUE)
    # The note describes the figure on screen, which switching Demo mode off
    # leaves there.
    session$setInputs(demo = FALSE)
    expect_match(output$cmp_demo_note$html, "illustrative rather than retrieved",
                 fixed = TRUE)
  })
})

test_that("the export buttons arrive with what they write", {
  skip_if_not_installed("shiny")
  # Every download opens with req(), and a click with nothing to write fails
  # in the browser with nothing on screen to say why. The Python app builds its
  # buttons with the results they write.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(cmp_terms = "flexible")
    expect_match(output$export_buttons$html, "Fetch records to export them.",
                 fixed = TRUE)
    expect_false(grepl("dl_rds", output$export_buttons$html, fixed = TRUE))
    expect_null(output$cmp_download)
    rv$records <- example_records
    rv$comparison <- app_demo_comparison("graphene", "flexible", 2019:2020)
    session$flushReact()
    for (id in c("dl_rds", "dl_dois", "dl_bibtex", "dl_ris", "dl_report")) {
      expect_match(output$export_buttons$html, id, fixed = TRUE)
    }
    expect_match(output$cmp_download$html, "dl_comparison", fixed = TRUE)
  })
})

test_that("a harvest with nothing to plot says so in each panel", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # A search that matched nothing returns a record set with no rows, which the
  # NULL guard let through, and each panel then showed a plotting function's
  # own error.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    rv$records <- scopus_records(list())
    session$flushReact()
    expect_error(output$plot_year, "No records to plot.", class = "validation")
    expect_error(output$plot_sources, "No source titles to tally.", class = "validation")
    expect_error(output$plot_authors, "No author names to tally.", class = "validation")
    # Records whose source titles are all missing still plot by year.
    recs <- app_demo_records(2019:2020)
    recs$publication <- NA_character_
    rv$records <- recs
    session$flushReact()
    expect_error(output$plot_sources, "No source titles to tally.", class = "validation")
    expect_type(output$plot_year, "list")
  })
})

test_that("the key status is written in colours dark enough to read", {
  skip_if_not_installed("shiny")
  # Bootstrap's .text-info, .text-warning and .text-success stand at about
  # 1.7:1, 1.5:1 and 4.1:1 on the sidebar's ground, under the 4.5:1 text needs.
  # Their -emphasis variants clear 7:1.
  shiny::testServer(app_server, {
    session$setInputs(demo = TRUE, api_key = "")
    expect_match(output$key_status$html, "class=\"text-info-emphasis\"", fixed = TRUE)
    session$setInputs(demo = FALSE)
    expect_match(output$key_status$html, "class=\"text-warning-emphasis\"", fixed = TRUE)
    session$setInputs(api_key = "a-key")
    expect_match(output$key_status$html, "class=\"text-success-emphasis\"", fixed = TRUE)
  })
})

test_that("the progress bar tells assistive technology how far a harvest has come", {
  skip_if_not_installed("shiny")
  # role="progressbar" with no name and no value announced nothing during the
  # long wait it is there for.
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    rv$status <- "running"
    rv$progress <- list(done = 4L, total = 10L)
    session$flushReact()
    bar <- output$progress_ui$html
    expect_match(bar, 'aria-label="Fetching cell 4 of 10"', fixed = TRUE)
    expect_match(bar, 'aria-valuenow="30"', fixed = TRUE)
    expect_match(bar, 'aria-valuemin="0"', fixed = TRUE)
    expect_match(bar, 'aria-valuemax="100"', fixed = TRUE)
    # A bar still animated has no value to report, which ARIA spells as no
    # aria-valuenow.
    rv$progress <- NULL
    session$flushReact()
    bar <- output$progress_ui$html
    expect_match(bar, 'aria-label="Working..."', fixed = TRUE)
    expect_false(grepl("aria-valuenow", bar, fixed = TRUE))
    rv$status <- "idle"
  })
})

test_that("every figure the app draws carries a text alternative", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ggplot2")
  # Each figure reached the browser described only as "Plot object".
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene", demo = TRUE)
    session$setInputs(cmp_terms = "flexible")
    rv$records <- app_demo_records(2019:2020)
    session$flushReact()
    n <- nrow(rv$records)
    expect_identical(output$plot_year$alt,
                     sprintf("Bar chart of records by year: %d records from 2019 to 2020.", n))
    expect_match(output$plot_sources$alt,
                 "^Bar chart of the \\d+ most frequent source titles: .+ leads with \\d+ records?\\.$")
    expect_match(output$plot_authors$alt,
                 "^Bar chart of the \\d+ most frequent author names: .+ leads with \\d+ records?\\.$")
    session$setInputs(compare = 1)
    expect_identical(output$plot_comparison$alt,
                     "Line chart of the share of 'graphene' records matching 'flexible', 2019 to 2020.")
    # The alternative is computed even when the panel validates away, so a tally
    # with nothing in it must not fail in place of the message.
    recs <- app_demo_records(2019:2020)
    recs$publication <- NA_character_
    rv$records <- recs
    session$flushReact()
    expect_error(output$plot_sources, "No source titles to tally.", class = "validation")
  })
})

test_that("a demo harvest marks the records it draws as replayed", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("callr")
  # Fetch starts a background R process through callr, so the test stays off
  # CRAN. Demo mode keeps that process offline, and it is stopped at once.
  skip_on_cran()
  shiny::testServer(app_server, {
    app_test_inputs(session, query = "graphene supercapacitor", demo = TRUE)
    session$setInputs(fetch = 1)
    proc <- rv$proc
    if (!is.null(proc)) try(proc$kill(), silent = TRUE)
    expect_false(is.null(proc))
    expect_true(isTRUE(rv$replayed))
  })
})
