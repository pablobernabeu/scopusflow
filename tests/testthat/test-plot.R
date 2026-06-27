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

test_that("the comparison caption guards the Wilson band", {
  skip_if_not_installed("ggplot2")
  p <- plot_scopus_comparison(make_comparison())
  expect_true(grepl("not a confidence interval", p$labels$caption, fixed = TRUE))
  expect_true(grepl("Source: 'Scopus'", p$labels$caption, fixed = TRUE))
})

test_that("scopus_spread_positions separates close labels in order", {
  expect_equal(scopus_spread_positions(c(10, 10.1, 10.2), 1), c(10, 11, 12))
  expect_equal(scopus_spread_positions(c(0, 5, 10), 1), c(0, 5, 10))
  out <- scopus_spread_positions(c(10.2, 10, 10.1), 1)
  expect_true(out[2] < out[3] && out[3] < out[1])
})

# A six-topic frame whose final-year shares converge tightly, so the end-labels
# must be spread apart to stay legible.
make_converging <- function(nt = 6L) {
  years <- 2015:2021
  ends <- seq(18, 21, length.out = nt)
  rows <- list()
  for (y in years) rows[[length(rows) + 1L]] <- data.frame(
    query = "r", query_type = "reference", abridged_query = "ref", year = y,
    n = 1000L, reference_n = 1000L, comparison_percentage = 100,
    average_comparison_percentage = 100)
  for (k in seq_len(nt)) for (y in years) {
    pct <- ends[k] * (0.5 + 0.5 * (y - years[1]) / (years[length(years)] - years[1]))
    rows[[length(rows) + 1L]] <- data.frame(
      query = paste0("t", k), query_type = "comparison",
      abridged_query = sprintf("topic %d", k), year = y, n = as.integer(pct * 10),
      reference_n = 1000L, comparison_percentage = pct,
      average_comparison_percentage = ends[k])
  }
  cmp <- do.call(rbind, rows)
  class(cmp) <- c("scopus_comparison", class(cmp))
  cmp
}

# Render to a headless PDF device, then read back the drawn end-label y positions
# (in npc) and the rendered text-line height, so a test can assert no overlap.
rendered_label_gaps <- function(p, height, width = 8) {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = width, height = height)
  on.exit({grDevices::dev.off(); unlink(f)}, add = TRUE)
  grid::grid.newpage(); print(p); grid::grid.force()
  txt <- grid::grid.get("sf_endlabels_text", grep = TRUE, global = TRUE)
  if (is.null(txt)) return(NULL)
  ys <- sort(as.numeric(txt$y))                      # label positions, already npc
  nms <- grid::grid.ls(viewports = TRUE, grobs = FALSE, print = FALSE)$name
  grid::seekViewport(grep("^panel", nms, value = TRUE)[1])
  line <- grid::convertHeight(
    grid::grobHeight(grid::textGrob("Ag", gp = txt$gp)), "npc", valueOnly = TRUE)
  grid::upViewport(0)
  list(y = ys, line = line)
}

test_that("converging topics get a self-spreading end-label layer with leaders", {
  skip_if_not_installed("ggplot2")
  cmp <- make_comparison()
  cmp$comparison_percentage[cmp$year == max(cmp$year) &
                              cmp$query_type == "comparison"] <- c(20, 20.1)
  p <- plot_scopus_comparison(cmp)
  # Direct labels are one custom end-label geom (leader + text drawn at render
  # time), not a build-time geom_text/geom_segment pair.
  expect_true(any(vapply(p$layers,
    function(l) inherits(l$geom, "GeomEndLabels"), logical(1))))
})

test_that("end-labels never overlap, even on a short device", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("grid")
  p <- plot_scopus_comparison(make_converging(6L))
  # The same six converging topics overlapped at <= 3.5 in before the draw-time
  # de-collision; now each label sits at least one rendered line apart at every
  # size, including the app's short card.
  for (h in c(4.4, 3.5, 2.8)) {
    m <- rendered_label_gaps(p, h)
    expect_identical(length(m$y), 6L)
    expect_gte(min(diff(m$y)), m$line)
  }
})

test_that("the spread is deterministic at a fixed size", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("grid")
  p <- plot_scopus_comparison(make_converging(6L))
  expect_equal(rendered_label_gaps(p, 3.5)$y, rendered_label_gaps(p, 3.5)$y)
})

test_that("a single highlighted topic draws exactly one end-label", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("grid")
  p <- plot_scopus_comparison(make_converging(6L), highlight = "topic 3")
  m <- rendered_label_gaps(p, 3.2)
  expect_identical(length(m$y), 1L)
})

test_that("many topics fall back to a legend instead of direct labels", {
  skip_if_not_installed("ggplot2")
  cmp <- tibble::tibble(
    query = "q",
    query_type = c(rep("reference", 2), rep("comparison", 2 * 10)),
    abridged_query = c(rep("ref", 2), rep(sprintf("t%02d", 1:10), each = 2)),
    year = c(2019, 2020, rep(c(2019, 2020), 10)),
    n = c(100, 100, rep(c(5, 6), 10)),
    reference_n = rep(100, 22),
    comparison_percentage = c(100, 100, rep(c(5, 6), 10)),
    average_comparison_percentage = c(100, 100, rep(5.5, 20))
  )
  class(cmp) <- c("scopus_comparison", class(cmp))
  p <- plot_scopus_comparison(cmp)
  expect_identical(p$theme$legend.position, "top")   # legend, not direct labels
  expect_false(any(vapply(p$layers,
    function(l) inherits(l$geom, "GeomEndLabels"), logical(1))))
})
