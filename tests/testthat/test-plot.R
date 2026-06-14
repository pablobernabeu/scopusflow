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

test_that("plot_scopus_comparison returns a ggplot of the comparison topics", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison())
  expect_s3_class(p, "ggplot")
  expect_equal(length(unique(p$data$abridged_query)), 2L)
})

test_that("the x-axis uses whole-number year breaks", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison())
  b <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x$breaks
  expect_true(all(b == round(b), na.rm = TRUE))
})

test_that("a colour-blind-safe (viridis) palette is used, not the default hue", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison())
  cols <- unlist(lapply(ggplot2::ggplot_build(p)$data, function(d) {
    if ("colour" %in% names(d)) unique(d$colour) else NULL
  }))
  expect_false("#F8766D" %in% cols)  # ggplot2's default 2-hue first colour
  expect_true(any(grepl("^#", cols)))
})

test_that("an uncertainty band is drawn by default and can be switched off", {
  skip_if_not_installed("ggplot2")
  has_ribbon <- function(p) {
    any(vapply(p$layers, function(l) inherits(l$geom, "GeomRibbon"), logical(1)))
  }
  expect_true(has_ribbon(plot_scopus_comparison(make_comparison())))
  expect_false(has_ribbon(plot_scopus_comparison(make_comparison(), interval = FALSE)))
})

test_that("the Wilson band is wider for smaller reference counts", {
  w_small <- scopusflow:::scopus_wilson(5, 10)
  w_large <- scopusflow:::scopus_wilson(500, 1000)
  expect_gt(w_small$upper - w_small$lower, w_large$upper - w_large$lower)
})

test_that("autoplot dispatches to the same plot", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::autoplot(make_comparison())
  expect_s3_class(p, "ggplot")
})

test_that("legend/line labels can include counts", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison(), pub_count_in_legend = TRUE)
  expect_true(any(grepl("n =", levels(p$data$label))))
})

test_that("highlight greys the others and accents one topic", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison(), highlight = "a")
  cols <- unlist(lapply(ggplot2::ggplot_build(p)$data, function(d) unique(d$colour)))
  expect_true("#BB5566" %in% cols)
  expect_true("grey75" %in% cols)
})

test_that("an unknown highlight is rejected", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_scopus_comparison(make_comparison(), highlight = "zzz"),
               class = "scopus_error_bad_input")
})

test_that("a year without reference records is dropped, not errored", {
  skip_if_not_installed("ggplot2")
  cmp <- make_comparison()
  cmp$reference_n[cmp$year == 2018] <- 0
  cmp$comparison_percentage[cmp$year == 2018 & cmp$query_type == "comparison"] <- NA
  expect_s3_class(plot_scopus_comparison(cmp), "ggplot")
})

test_that("plotting a non-comparison object errors", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_scopus_comparison(data.frame(a = 1)),
               class = "scopus_error_bad_input")
})
