# Every print method in the package writes a header line and then, for most of
# them, a table. cli sends its output to the message stream, which knitr
# collects separately from standard output, so a method that mixed the two
# rendered one printed object as two output blocks on the documentation site.
# These tests hold the whole family to one stream.

# One mock for both endpoints the fixtures below reach: the Abstract Retrieval
# response has a different shape from a search envelope, so the two are told
# apart by the request path.
print_mock <- function() {
  function(req) {
    if (grepl("/abstract/", req$url, fixed = TRUE)) {
      mock_abstract(list(
        `dc:identifier` = "SCOPUS_ID:85000000001",
        `prism:doi` = "10.1/a",
        `dc:title` = "A record",
        `dc:description` = "An abstract."
      ))
    } else {
      mock_search_results(list(), total = 10L)
    }
  }
}

# One object of every class the package prints, built offline. Named by class,
# so the coverage test below can check the list against the methods registered.
print_fixtures <- function() {
  local_scopus_test_env()
  httr2::local_mocked_responses(print_mock())
  list(
    scopus_abstracts = scopus_abstract("10.1/a"),
    scopus_comparison = scopus_compare_topics("ref", "t1", years = 2015:2016),
    scopus_doi_diff = scopus_diff_dois(c("10.1/a", "10.1/b"), c("10.1/b", "10.1/c")),
    scopus_intersections = scopus_intersections(
      concepts = c(A = "aaa", B = "bbb"),
      intersections = list(c("A", "B"))
    ),
    scopus_plan = scopus_plan("x", years = 2018:2019, partition = "year"),
    scopus_records = example_records,
    scopus_records_summary = summary(example_records),
    scopus_search_report = scopus_search_report(
      scopus_plan("x", years = 2018:2019, partition = "year")
    ),
    scopus_trend = scopus_trend("q", years = 2015:2016)
  )
}

test_that("no print method writes to the message stream", {
  objs <- print_fixtures()
  # Capturing the message stream leaves standard output free to reach the
  # console, which is the point of the test but noise in the reporter.
  withr::local_output_sink(nullfile())
  on_message <- vapply(
    objs,
    function(x) length(utils::capture.output(print(x), type = "message")),
    integer(1)
  )
  expect_equal(on_message, stats::setNames(rep(0L, length(objs)), names(objs)))
})

test_that("every print method puts its header on standard output", {
  objs <- print_fixtures()
  on_stdout <- vapply(
    objs,
    function(x) paste(utils::capture.output(print(x)), collapse = "\n"),
    character(1)
  )
  expect_true(all(nzchar(on_stdout)))
  expect_match(on_stdout[["scopus_doi_diff"]], "1 added, 1 removed, 1 unchanged")
  expect_match(on_stdout[["scopus_abstracts"]], "scopus_abstracts")
  expect_match(on_stdout[["scopus_comparison"]], "2 topics")
  expect_match(on_stdout[["scopus_intersections"]], "2 concepts, 1 intersection")
  expect_match(on_stdout[["scopus_plan"]], "2 cells")
  expect_match(on_stdout[["scopus_records"]], "138 records")
  expect_match(on_stdout[["scopus_records_summary"]], "138 records")
  expect_match(on_stdout[["scopus_search_report"]], "Search strategy record")
  expect_match(on_stdout[["scopus_trend"]], "2 years")
})

test_that("the record header keeps its retrieval stamp on standard output", {
  recs <- example_records
  attr(recs, "retrieved_at") <- as.POSIXct("2026-01-02 03:04:05", tz = "UTC")
  attr(recs, "scopusflow_version") <- "0.3.0"
  out <- paste(utils::capture.output(print(recs)), collapse = "\n")
  expect_match(out, "retrieved: 2026-01-02")
  expect_match(out, "scopusflow 0.3.0")
  withr::local_output_sink(nullfile())
  expect_length(utils::capture.output(print(recs), type = "message"), 0L)
})

test_that("the fixtures above cover every registered print method", {
  registered <- ls(asNamespace("scopusflow"), pattern = "^print\\.")
  expect_setequal(sub("^print\\.", "", registered), names(print_fixtures()))
})

test_that("print methods return their input invisibly", {
  objs <- print_fixtures()
  withr::local_output_sink(nullfile())
  for (x in objs) {
    expect_invisible(print(x))
  }
})
