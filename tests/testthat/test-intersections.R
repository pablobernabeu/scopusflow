# Mock returning deterministic counts keyed on the query: an intersection (an
# AND of parenthesised parts) matches 15, a query containing "aaa" 600 and
# anything else 200. Requests are recorded in `seen`, when given, so a test
# can assert on the exact queries and dates sent.
intersections_mock <- function(seen = NULL) {
  function(req) {
    q <- httr2::url_parse(req$url)$query
    if (!is.null(seen)) {
      seen$queries <- c(seen$queries, q$query)
      seen$dates <- c(seen$dates, if (is.null(q$date)) NA_character_ else q$date)
    }
    total <- if (grepl(" AND ", q$query, fixed = TRUE)) {
      15L
    } else if (grepl("aaa", q$query, fixed = TRUE)) {
      600L
    } else {
      200L
    }
    mock_search_results(list(), total = total)
  }
}

new_seen <- function() {
  seen <- new.env(parent = emptyenv())
  seen$queries <- character()
  seen$dates <- character()
  seen
}

# The default label separator, a multiplication sign, built from its code
# point so this file stays ASCII.
times_sign <- intToUtf8(215L)

test_that("concepts and intersections are counted, one request per row", {
  local_scopus_test_env()
  seen <- new_seen()
  httr2::local_mocked_responses(intersections_mock(seen))
  sets <- scopus_intersections(
    concepts = c(A = "aaa", B = "bbb"),
    intersections = list(c("A", "B")),
    field = "TITLE-ABS-KEY"
  )
  expect_s3_class(sets, "scopus_intersections")
  expect_equal(sets$label, c("A", "B", paste("A", times_sign, "B")))
  expect_equal(sets$n, c(600, 200, 15))
  expect_equal(sets$type, c("concept", "concept", "intersection"))
  expect_equal(sets$size, c(1L, 1L, 2L))
  expect_equal(sets$members, c("A", "B", "A; B"))
  expect_length(seen$queries, 3L)  # counts only: one request per row, no fetch
})

test_that("bare terms are wrapped in the field and the intersection ANDs the parts", {
  local_scopus_test_env()
  seen <- new_seen()
  httr2::local_mocked_responses(intersections_mock(seen))
  sets <- scopus_intersections(
    concepts = c(A = "aaa", B = "bbb"),
    intersections = list(c("A", "B")),
    field = "TITLE-ABS-KEY"
  )
  expect_equal(seen$queries[1:2], c("TITLE-ABS-KEY(aaa)", "TITLE-ABS-KEY(bbb)"))
  expect_equal(seen$queries[3], "(TITLE-ABS-KEY(aaa)) AND (TITLE-ABS-KEY(bbb))")
  expect_equal(sets$query, seen$queries)
})

test_that("a value that is already field-tagged is never wrapped again", {
  local_scopus_test_env()
  seen <- new_seen()
  httr2::local_mocked_responses(intersections_mock(seen))
  sets <- scopus_intersections(
    concepts = c(A = "TITLE(aaa)", B = "bbb"),
    field = "TITLE-ABS-KEY"
  )
  expect_equal(seen$queries, c("TITLE(aaa)", "TITLE-ABS-KEY(bbb)"))
  expect_equal(sets$query, c("TITLE(aaa)", "TITLE-ABS-KEY(bbb)"))
})

test_that("scopus_wrap_concept guards the double wrapping the API rejects", {
  expect_equal(
    scopusflow:::scopus_wrap_concept("aaa", "TITLE-ABS-KEY"),
    "TITLE-ABS-KEY(aaa)"
  )
  expect_equal(
    scopusflow:::scopus_wrap_concept("TITLE(aaa)", "TITLE-ABS-KEY"),
    "TITLE(aaa)"
  )
  # A leading space must not defeat the guard.
  expect_equal(
    scopusflow:::scopus_wrap_concept("  TITLE(aaa)", "TITLE-ABS-KEY"),
    "TITLE(aaa)"
  )
  # Without a field, terms pass through untouched.
  expect_equal(scopusflow:::scopus_wrap_concept("aaa", NULL), "aaa")
})

test_that("years restrict every request through the date parameter", {
  local_scopus_test_env()
  seen <- new_seen()
  httr2::local_mocked_responses(intersections_mock(seen))
  sets <- scopus_intersections(c(A = "aaa"), years = 2015:2020)
  expect_equal(unique(seen$dates), "2015-2020")
  expect_equal(attr(sets, "years"), 2015:2020)
})

test_that("abbrev shortens intersection labels only, and sep is honoured", {
  local_scopus_test_env()
  httr2::local_mocked_responses(intersections_mock())
  sets <- scopus_intersections(
    concepts = c("semantic priming" = "aaa", "mental simulation" = "bbb"),
    intersections = list(c("semantic priming", "mental simulation")),
    abbrev = c("semantic priming" = "SP", "mental simulation" = "MS"),
    sep = " & "
  )
  expect_equal(sets$label, c("semantic priming", "mental simulation", "SP & MS"))
  expect_equal(sets$members[3], "semantic priming; mental simulation")
})

test_that("a single character vector is accepted as one intersection", {
  local_scopus_test_env()
  httr2::local_mocked_responses(intersections_mock())
  sets <- scopus_intersections(
    concepts = c(A = "aaa", B = "bbb"),
    intersections = c("A", "B")
  )
  expect_equal(sum(sets$type == "intersection"), 1L)
})

test_that("invalid inputs are rejected before any request", {
  local_scopus_test_env()
  # No responses are mocked, so reaching the network would fail differently.
  expect_error(scopus_intersections(c("aaa", "bbb")),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(stats::setNames(c("aaa", "bbb"), c("A", ""))),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa", A = "bbb")),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(character(0)),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa"), intersections = list(c("A", "Z"))),
               regexp = "Z", class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa"), intersections = list("A")),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa", B = "bbb"),
                                    intersections = list(c("A", "A"))),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa"), abbrev = c(Z = "z")),
               regexp = "Z", class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa"), abbrev = c(A = "")),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa"), abbrev = c(A = "  ")),
               class = "scopus_error_bad_input")
  expect_error(scopus_intersections(c(A = "aaa", B = "bbb"), sep = 1),
               class = "scopus_error_bad_input")
})

test_that("an abbrev that collapses two labels into one is caught while free", {
  local_scopus_test_env()
  # No responses are mocked: the collision must be caught before any request.
  expect_error(
    scopus_intersections(
      concepts = c(A = "aaa", B = "bbb", C = "ccc"),
      intersections = list(c("A", "B"), c("A", "C")),
      abbrev = c(B = "X", C = "X")
    ),
    class = "scopus_error_bad_input"
  )
})

test_that("a response without a total warns and records NA", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(`search-results` = list(entry = list())))
  })
  expect_warning(sets <- scopus_intersections(c(A = "aaa", B = "bbb")),
                 "2 queries")
  expect_true(all(is.na(sets$n)))
})

test_that("print gives a one-line class summary", {
  local_scopus_test_env()
  httr2::local_mocked_responses(intersections_mock())
  sets <- scopus_intersections(
    concepts = c(A = "aaa", B = "bbb"),
    intersections = list(c("A", "B"))
  )
  # The summary line arrives through cli's message stream, not stdout.
  expect_message(invisible(capture.output(print(sets))), "2 concepts")
  expect_message(invisible(capture.output(print(sets))), "1 intersection")
})

# A ready-made object for the plot tests, mirroring the compute output.
make_intersections <- function(n = c(6600, 2100, 15)) {
  sets <- tibble::tibble(
    label = c("A", "B", paste("A", times_sign, "B")),
    query = "q",
    n = n,
    type = c("concept", "concept", "intersection"),
    size = c(1L, 1L, 2L),
    members = c("A", "B", "A; B")
  )
  class(sets) <- c("scopus_intersections", class(sets))
  sets
}

test_that("plot_scopus_intersections returns a log-scale lollipop", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_intersections(make_intersections())
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$x, "log")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true(all(c("GeomSegment", "GeomPoint", "GeomText") %in% geoms))
  # Rows are ordered by size, the largest at the top, as documented.
  expect_equal(levels(p$data$label),
               as.character(p$data$label[order(p$data$n)]))
  # The widened right margin gives the largest count label grace room at the
  # figure edge, since clip = "off" lets it spill past the panel.
  expect_equal(as.numeric(p$theme$plot.margin[2]), 28)
})

test_that("the count labels sit a constant ratio beyond their points", {
  skip_if_not_installed("ggplot2")
  b <- ggplot2::ggplot_build(plot_scopus_intersections(make_intersections()))
  # On the log axis the built positions are log10 values, so a constant
  # multiplicative offset must appear as a constant difference.
  gap <- b$data[[3]]$x - b$data[[2]]$x
  expect_true(all(gap > 0))
  expect_lt(max(gap) - min(gap), 1e-8)
})

test_that("the label gap is derived from the axis's own span", {
  skip_if_not_installed("ggplot2")
  gap_of <- function(x) {
    b <- ggplot2::ggplot_build(plot_scopus_intersections(x))
    (b$data[[3]]$x - b$data[[2]]$x)[1]
  }
  narrow <- make_intersections(n = c(40, 30, 12))
  wide <- make_intersections(n = c(2e6, 2100, 3))
  expect_gt(gap_of(wide), gap_of(narrow))
})

test_that("highlight accents the named rows", {
  skip_if_not_installed("ggplot2")
  sets <- make_intersections()
  p <- plot_scopus_intersections(sets, highlight = sets$label[3])
  cols <- unlist(lapply(ggplot2::ggplot_build(p)$data, function(d) {
    if ("colour" %in% names(d)) unique(d$colour) else NULL
  }))
  expect_true("#BB5566" %in% cols)
})

test_that("the highlight legend label is derived from what is highlighted", {
  skip_if_not_installed("ggplot2")
  sets <- make_intersections()
  labels_of <- function(p) p$scales$get_scales("colour")$labels
  expect_true("Focal intersection" %in%
                labels_of(plot_scopus_intersections(sets,
                                                    highlight = sets$label[3])))
  expect_true("Focal concept" %in%
                labels_of(plot_scopus_intersections(sets,
                                                    highlight = sets$label[1])))
  expect_true("Focal set" %in%
                labels_of(plot_scopus_intersections(sets,
                                                    highlight = sets$label[c(1, 3)])))
  # An explicit label still wins over the derived one.
  expect_true("My niche" %in%
                labels_of(plot_scopus_intersections(sets,
                                                    highlight = sets$label[3],
                                                    highlight_label = "My niche")))
})

test_that("an unknown highlight is rejected", {
  skip_if_not_installed("ggplot2")
  expect_error(
    plot_scopus_intersections(make_intersections(), highlight = "zzz"),
    class = "scopus_error_bad_input"
  )
})

test_that("zero counts are dropped with a warning and noted in the caption", {
  skip_if_not_installed("ggplot2")
  sets <- make_intersections(n = c(6600, 2100, 0))
  expect_warning(p <- plot_scopus_intersections(sets), "log axis")
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$caption, "omitted")
  expect_equal(nrow(p$data), 2L)
})

test_that("an object with no positive counts is rejected", {
  skip_if_not_installed("ggplot2")
  sets <- make_intersections(n = c(0, 0, NA))
  suppressWarnings(
    expect_error(plot_scopus_intersections(sets),
                 class = "scopus_error_bad_input")
  )
})

test_that("empty and foreign objects are rejected with a typed condition", {
  skip_if_not_installed("ggplot2")
  empty <- tibble::tibble(
    label = character(), query = character(), n = double(),
    type = character(), size = integer(), members = character()
  )
  class(empty) <- c("scopus_intersections", class(empty))
  expect_error(plot_scopus_intersections(empty), class = "scopus_error_bad_input")
  expect_error(plot_scopus_intersections(data.frame(a = 1)),
               class = "scopus_error_bad_input")
})

test_that("the caption carries the year restriction", {
  skip_if_not_installed("ggplot2")
  sets <- make_intersections()
  attr(sets, "years") <- 2015:2020
  expect_match(plot_scopus_intersections(sets)$labels$caption, "2015 to 2020")
  attr(sets, "years") <- 2020L
  expect_match(plot_scopus_intersections(sets)$labels$caption, "Year 2020")
})

test_that("autoplot dispatches to the intersections plot", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(ggplot2::autoplot(make_intersections()), "ggplot")
})

test_that("scopus_log_breaks stays in range and densifies narrow spans", {
  expect_equal(scopusflow:::scopus_log_breaks(0.55, 26400), 10^(0:4))
  expect_equal(scopusflow:::scopus_log_breaks(8, 60), c(10, 30))
})
