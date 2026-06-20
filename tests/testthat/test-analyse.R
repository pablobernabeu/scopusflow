test_that("scopus_top tallies sources, counting the modal one highest", {
  top <- scopus_top(example_records, by = "source")
  expect_s3_class(top, "scopus_top")
  expect_equal(top$value[1], "Nature")   # appears twice in the fixture
  expect_equal(top$n[1], 2L)
  expect_equal(nrow(top), 5L)            # five distinct sources
})

test_that("scopus_top splits multi-author strings and honours n", {
  recs <- scopus_records(list(entry = list(
    list(`dc:creator` = list("Smith J.", "Doe A.")),
    list(`dc:creator` = "Smith J.")
  )))
  top <- scopus_top(recs, by = "author")
  expect_equal(top$value[1], "Smith J.")
  expect_equal(top$n[1], 2L)
  expect_equal(nrow(scopus_top(example_records, by = "author", n = 3)), 3L)
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
