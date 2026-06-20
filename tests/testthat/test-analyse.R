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
