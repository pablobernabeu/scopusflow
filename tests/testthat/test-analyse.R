test_that("scopus_top tallies sources, counting the modal one highest", {
  top <- scopus_top(example_records, by = "source")
  expect_s3_class(top, "scopus_top")
  expect_equal(top$value[1], "ACS Applied Materials & Interfaces")
  expect_equal(top$n[1], 8L)             # the modal source in the harvest
  expect_equal(nrow(top), 10L)           # the default keeps the top ten
})

test_that("scopus_top splits multi-author strings and honours n", {
  # Several names reach the column only from the COMPLETE view's author array,
  # since dc:creator is the first author alone.
  recs <- scopus_records(list(entry = list(
    parse_entry(paste0('{"dc:creator": "Smith J.", "author": [',
                       '{"surname": "Smith", "given-name": "J."}, ',
                       '{"surname": "Doe", "given-name": "A."}]}')),
    parse_entry('{"dc:creator": "Smith J.", "author": [{"surname": "Smith", "given-name": "J."}]}')
  )), view = "COMPLETE")
  top <- scopus_top(recs, by = "author")
  expect_equal(top$value, c("Smith, J.", "Doe, A."))
  expect_equal(top$n, c(2L, 1L))
  expect_equal(nrow(scopus_top(example_records, by = "author", n = 3)), 3L)
})

test_that("an author tally of a STANDARD harvest says once that it counts first authors", {
  # The sentinel lives for the whole session, so it is cleared on both sides
  # of the test, which would otherwise depend on the order the tests run in.
  rlang::reset_warning_verbosity("scopusflow_first_author_only")
  withr::defer(rlang::reset_warning_verbosity("scopusflow_first_author_only"))
  standard <- example_records
  attr(standard, "view") <- "STANDARD"
  w <- expect_warning(scopus_top(standard, by = "author"),
                      class = "scopus_warning_first_author_only")
  # The wording is shared with the Python twin through the fixture.
  expect_identical(w$message, complete_authors_fixture()$first_author_warning)
  # Once per session, and one warning covers as_bibliometrix() as well.
  expect_no_warning(scopus_top(standard, by = "author"))
  expect_no_warning(as_bibliometrix(standard))
})

test_that("the first-author warning is reserved for author tallies of STANDARD sets", {
  # With verbosity forced, every call that should warn does, so each silence
  # below is the function declining to warn.
  withr::local_options(rlib_warning_verbosity = "verbose")
  standard <- complete <- example_records
  attr(standard, "view") <- "STANDARD"
  attr(complete, "view") <- "COMPLETE"
  expect_warning(scopus_top(standard, by = "author"),
                 class = "scopus_warning_first_author_only")
  # A set that records no view, as the bundled corpus records none, cannot be
  # judged, and a COMPLETE set lists its authors.
  expect_no_warning(scopus_top(example_records, by = "author"))
  expect_no_warning(scopus_top(complete, by = "author"))
  # A source tally and the reference-manager exports are not author tallies.
  expect_no_warning(scopus_top(standard, by = "source"))
  expect_no_warning(as_bibtex(standard))
  expect_no_warning(as_ris(standard))
})

test_that("scopus_top rejects bad input", {
  expect_error(scopus_top(data.frame(a = 1)), class = "scopus_error_bad_input")
  expect_error(scopus_top(example_records, n = 0), class = "scopus_error_bad_input")
  expect_error(scopus_top(example_records, by = "doi"))
})

test_that("scopus_top requires a finite, whole, positive n", {
  expect_error(scopus_top(example_records, n = 2.5), class = "scopus_error_bad_input")
  expect_error(scopus_top(example_records, n = Inf), class = "scopus_error_bad_input")
})

test_that("scopus_top accepts an n beyond integer range and returns every row", {
  # The validator accepts any finite whole n, so anything past 2^31 must not be
  # coerced to a 32-bit integer on the way to head(): that yielded NA and an
  # untyped base error from head.data.frame(). A cut wider than the tally is
  # simply the whole tally, and the answer matches the Python twin's, whose
  # pandas head() has never had a 32-bit ceiling.
  all_sources <- scopus_top(example_records, by = "source", n = 1000L)
  expect_no_error(wide <- scopus_top(example_records, by = "source", n = 1e10))
  expect_identical(wide, all_sources)
  expect_identical(scopus_top(example_records, by = "source", n = 2^40), all_sources)
})

test_that("scopus_top breaks count ties deterministically by value", {
  # Six contributors, five tied at count 1 differing only by case, so the
  # head(n) cut among ties must be reproducible (byte order), not locale-driven.
  recs <- scopus_records(list(entry = list(
    list(`dc:creator` = "zeta"), list(`dc:creator` = "zeta"),
    list(`dc:creator` = "zeta"), list(`dc:creator` = "Apple"),
    list(`dc:creator` = "apple"), list(`dc:creator` = "Banana")
  )))
  top <- scopus_top(recs, by = "author", n = 2L)
  expect_equal(top$value, c("zeta", "Apple"))  # 'A' (0x41) precedes 'B' and 'a'
  expect_equal(top$n, c(3L, 1L))
})

test_that("scopus_trend counts each year via the API", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    q <- httr2::url_parse(req$url)$query
    yr <- as.integer(q$date)
    mock_search_results(list(), total = (yr - 2000L) * 10L)
  })
  tr <- scopus_trend("anything", years = 2015:2017)
  expect_s3_class(tr, "scopus_trend")
  expect_equal(tr$year, 2015:2017)
  expect_equal(tr$n, c(150, 160, 170))
})

test_that("scopus_trend requires years", {
  local_scopus_test_env()
  expect_error(scopus_trend("x", years = NULL), class = "scopus_error_bad_input")
})

test_that("scopus_trend warns and records NA for a year with no reported total", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    yr <- as.integer(httr2::url_parse(req$url)$query$date)
    if (yr == 2016L) {
      mock_json_response(list(`search-results` = list(entry = list())))  # no total
    } else {
      mock_search_results(list(), total = 100L)
    }
  })
  expect_warning(tr <- scopus_trend("x", years = 2015:2017), "2016")
  expect_true(is.na(tr$n[tr$year == 2016L]))
  expect_equal(tr$n[tr$year == 2015L], 100)
})

test_that("scopus_trend warns (not errors) when several years lack a total", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    yr <- as.integer(httr2::url_parse(req$url)$query$date)
    if (yr %in% c(2015L, 2017L)) {
      mock_json_response(list(`search-results` = list(entry = list())))
    } else {
      mock_search_results(list(), total = 50L)
    }
  })
  # Two missing years must still warn and return the tibble, not raise an error.
  expect_warning(tr <- scopus_trend("x", years = 2015:2017), "2 years")
  expect_equal(is.na(tr$n), c(TRUE, FALSE, TRUE))
})

test_that("the new plots return ggplot objects", {
  skip_if_not_installed("ggplot2")
  tr <- tibble::tibble(query = "q", year = 2015:2018, n = c(10, 20, 30, 40))
  class(tr) <- c("scopus_trend", class(tr))
  expect_s3_class(plot_scopus_trend(tr), "ggplot")
  expect_s3_class(ggplot2::autoplot(tr), "ggplot")

  top <- scopus_top(example_records, by = "source")
  expect_s3_class(plot_scopus_top(top), "ggplot")
  expect_s3_class(ggplot2::autoplot(top), "ggplot")

  p <- ggplot2::autoplot(example_records)
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x$breaks
  expect_true(all(b == round(b), na.rm = TRUE))
})

test_that("autoplot says when a cap stopped the cells it counts", {
  skip_if_not_installed("ggplot2")
  # Under a binding cap the bars count records retrieved, so a figure titled by
  # year would otherwise be read as publications per year.
  recs <- example_records
  attr(recs, "plan") <- scopus_plan("graphene supercapacitor", years = 2015:2024,
                                    partition = "year")
  n <- as.integer(table(example_records$year))
  attr(recs, "cell_totals") <- tibble::tibble(
    cell = 1:10, date = as.character(2015:2024), n_records = n,
    reported_total = as.numeric(n) + c(40, rep(0, 9))
  )
  attr(recs, "max_results") <- 15L
  expect_identical(
    ggplot2::autoplot(recs)$labels$caption,
    paste("Retrieval capped at 15 records per cell: the bars count records",
          "retrieved, not publications per year.")
  )

  # A cap that stopped no cell, and a set without one, leave the figure as it was.
  attr(recs, "max_results") <- 50L
  expect_null(ggplot2::autoplot(recs)$labels$caption)
  expect_null(ggplot2::autoplot(example_records)$labels$caption)
})

test_that("plot_scopus_top uses whole-number count breaks", {
  skip_if_not_installed("ggplot2")
  # Every author in the fixture appears once, the case that used to produce
  # fractional ticks (0.3, 0.6, 0.9) on a count axis.
  p <- plot_scopus_top(scopus_top(example_records, by = "author", n = 5))
  b <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x$breaks
  b <- b[!is.na(b)]
  expect_true(all(b == round(b)))
})

test_that("the count axis clears the widest end-of-bar label", {
  skip_if_not_installed("ggplot2")
  top_of <- function(n) {
    x <- tibble::tibble(value = c("Nature", "Science"), n = c(n, 5))
    class(x) <- c("scopus_top", class(x))
    attr(x, "by") <- "source"
    x
  }
  upper_mult <- function(n) {
    p <- plot_scopus_top(top_of(n))
    xr <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x.range
    expect_equal(xr[1], 0)
    xr[2] / n
  }
  # A six-character label ("12,345") needs, and gets, more headroom than a
  # one-digit one, and enough that it sits inside the panel.
  expect_gte(upper_mult(12345), 1.18)
  expect_gt(upper_mult(12345), upper_mult(9))
})

test_that("plot dispatch rejects the wrong class", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_scopus_trend(data.frame(a = 1)), class = "scopus_error_bad_input")
  expect_error(plot_scopus_top(data.frame(a = 1)), class = "scopus_error_bad_input")
})

test_that("plots reject empty trend and top objects with a typed condition", {
  skip_if_not_installed("ggplot2")
  empty_trend <- tibble::tibble(query = character(), year = integer(), n = double())
  class(empty_trend) <- c("scopus_trend", class(empty_trend))
  expect_error(plot_scopus_trend(empty_trend), class = "scopus_error_bad_input")

  empty_top <- scopus_top(
    scopus_records(list(entry = list(list(`dc:title` = "x")))),
    by = "author"
  )
  expect_equal(nrow(empty_top), 0L)
  expect_error(plot_scopus_top(empty_top), class = "scopus_error_bad_input")
})
