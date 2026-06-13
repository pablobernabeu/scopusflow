make_comparison <- function() {
  cmp <- tibble::tibble(
    query = "q",
    query_type = rep(c("reference", "comparison", "comparison"), each = 3),
    abridged_query = rep(c("ref", "a", "b"), each = 3),
    year = rep(2018:2020, 3),
    n = c(10, 10, 10, 5, 6, 7, 1, 2, 3),
    reference_n = rep(10, 9),
    comparison_percentage = c(100, 100, 100, 50, 60, 70, 10, 20, 30),
    average_comparison_percentage = rep(c(100, 60, 20), each = 3)
  )
  class(cmp) <- c("scopus_comparison", class(cmp))
  cmp
}

test_that("plot_scopus_comparison returns a ggplot", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison())
  expect_s3_class(p, "ggplot")
  # Only comparison topics are drawn (reference excluded).
  expect_equal(length(unique(p$data$abridged_query)), 2L)
})

test_that("autoplot dispatches to the same plot", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::autoplot(make_comparison())
  expect_s3_class(p, "ggplot")
})

test_that("legend labels can include counts", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison(), pub_count_in_legend = TRUE)
  expect_true(any(grepl("n =", levels(p$data$label))))
})

test_that("plotting a non-comparison object errors", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_scopus_comparison(data.frame(a = 1)),
               class = "scopus_error_bad_input")
})
