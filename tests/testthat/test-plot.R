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

test_that("the Wilson band stays within 0-100 at the boundaries", {
  w0 <- scopusflow:::scopus_wilson(0, 50)    # share 0%
  w1 <- scopusflow:::scopus_wilson(50, 50)   # share 100%
  for (w in list(w0, w1)) {
    expect_gte(w$lower, 0)
    expect_lte(w$upper, 100)
    expect_lte(w$lower, w$upper)
  }
  expect_equal(w0$lower, 0)   # cannot dip below zero
  expect_equal(w1$upper, 100) # cannot exceed one hundred
})

test_that("a single-year comparison plots without error", {
  skip_if_not_installed("ggplot2")
  cmp <- tibble::tibble(
    query = "q", query_type = "comparison", abridged_query = c("a", "b"),
    year = c(2020L, 2020L), n = c(5, 3), reference_n = c(10, 10),
    comparison_percentage = c(50, 30), average_comparison_percentage = c(50, 30)
  )
  class(cmp) <- c("scopus_comparison", class(cmp))
  p <- plot_scopus_comparison(cmp)
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]$x$breaks
  expect_true(all(b == round(b), na.rm = TRUE))
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

test_that("scopus_spread_positions separates close labels in order", {
  expect_equal(scopus_spread_positions(c(10, 10.1, 10.2), 1), c(10, 11, 12))
  expect_equal(scopus_spread_positions(c(0, 5, 10), 1), c(0, 5, 10))
  out <- scopus_spread_positions(c(10.2, 10, 10.1), 1)
  expect_true(out[2] < out[3] && out[3] < out[1])
})

test_that("converging topics get vertically separated direct labels", {
  skip_if_not_installed("ggplot2")
  cmp <- make_comparison()
  # Force the two topics' final-year shares to converge.
  cmp$comparison_percentage[cmp$year == max(cmp$year) &
                              cmp$query_type == "comparison"] <- c(20, 20.1)
  p <- plot_scopus_comparison(cmp)
  text_layer <- which(vapply(p$layers,
    function(l) inherits(l$geom, "GeomText"), logical(1)))
  ly <- p$layers[[text_layer[1]]]$data$label_y
  expect_true(abs(ly[1] - ly[2]) >= 0.5)
})
