# Shared minimal theme for the package's plots. Internal, and only ever called
# from a plotting function that has already checked ggplot2 is installed.
scopus_minimal_theme <- function(base_size = 12, grid = "y") {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = if (grid == "y") ggplot2::element_blank() else NULL,
      panel.grid.major.y = if (grid == "x") ggplot2::element_blank() else NULL,
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(colour = "grey45", size = 8)
    )
}

scopus_year_breaks <- function(years) {
  if (length(years) > 12L) {
    p <- pretty(years)
    p[p == round(p)]
  } else {
    years
  }
}

#' Plot a publication trend
#'
#' Draws annual record counts over time from the output of [scopus_trend()].
#'
#' @param x A `scopus_trend` object from [scopus_trend()].
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Needs the suggested package \pkg{ggplot2}.
#' @seealso [scopus_trend()]
#' @examplesIf rlang::is_installed("ggplot2")
#' # Drawn from the bundled corpus of real articles, which needs no key. That
#' # corpus is a complete harvest, so its rows per year are the publications
#' # per year its query returns.
#' by_year <- table(example_records$year)
#' tr <- tibble::tibble(
#'   query = "TITLE-ABS-KEY(graphene supercapacitor)",
#'   year = as.integer(names(by_year)),
#'   n = as.numeric(by_year)
#' )
#' class(tr) <- c("scopus_trend", class(tr))
#' plot_scopus_trend(tr)
#' @export
plot_scopus_trend <- function(x, ...) {
  if (!inherits(x, "scopus_trend")) {
    rlang::abort("`x` must be a `scopus_trend` object from scopus_trend().",
                 class = "scopus_error_bad_input")
  }
  rlang::check_installed("ggplot2", reason = "to plot a trend")
  yrs <- sort(unique(x$year))
  if (length(yrs) == 0L) {
    rlang::abort("The trend has no years to plot.",
                 class = "scopus_error_bad_input")
  }
  ggplot2::ggplot(x, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_area(fill = "#31688E", alpha = 0.16) +
    ggplot2::geom_line(colour = "#31688E", linewidth = 1) +
    ggplot2::geom_point(colour = "#31688E", size = 1.8, stroke = 0) +
    ggplot2::scale_x_continuous(breaks = scopus_year_breaks(yrs), minor_breaks = NULL) +
    ggplot2::scale_y_continuous(
      labels = function(v) format(v, big.mark = ",", trim = TRUE, scientific = FALSE),
      limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.06))
    ) +
    ggplot2::labs(
      x = NULL, y = "Records", title = "Publications per year",
      caption = sprintf("Source: 'Scopus' Search API. Years %d to %d.", min(yrs), max(yrs))
    ) +
    scopus_minimal_theme()
}

#' Plot the most frequent values in a record set
#'
#' Draws a horizontal bar chart from the output of [scopus_top()].
#'
#' @param x A `scopus_top` object from [scopus_top()].
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Needs the suggested package \pkg{ggplot2}.
#' @seealso [scopus_top()]
#' @examplesIf rlang::is_installed("ggplot2")
#' # On the bundled corpus of real articles, which needs no key.
#' plot_scopus_top(scopus_top(example_records, by = "source"))
#' @export
plot_scopus_top <- function(x, ...) {
  if (!inherits(x, "scopus_top")) {
    rlang::abort("`x` must be a `scopus_top` object from scopus_top().",
                 class = "scopus_error_bad_input")
  }
  rlang::check_installed("ggplot2", reason = "to plot top values")
  if (nrow(x) == 0L) {
    rlang::abort("The `scopus_top` object has no values to plot.",
                 class = "scopus_error_bad_input")
  }
  by <- attr(x, "by") %||% "value"
  df <- x
  df$value <- factor(df$value, levels = rev(df$value))
  # Headroom for the end-of-bar count labels, derived from the widest label as
  # plot-intersections.R derives its gap: each label sits just past its bar, so
  # the axis must extend by that label's rendered width or it clips at the
  # panel edge. A fixed multiple tuned to one dataset reads well next to short
  # labels but truncates wide many-digit ones; scaling the expansion with the
  # character count keeps the widest label inside the panel, and clip = "off"
  # backstops an unusually narrow device.
  count_labels <- format(df$n, big.mark = ",", trim = TRUE)
  headroom <- 0.06 + 0.024 * max(nchar(count_labels))
  ggplot2::ggplot(df, ggplot2::aes(x = .data$n, y = .data$value)) +
    ggplot2::geom_col(fill = "#35B779", width = 0.72) +
    ggplot2::geom_text(
      ggplot2::aes(label = format(.data$n, big.mark = ",", trim = TRUE)),
      hjust = -0.15, size = 3, colour = "grey30"
    ) +
    # Counts are whole numbers, so fractional axis ticks would be noise.
    ggplot2::scale_x_continuous(
      breaks = function(v) {
        p <- pretty(v)
        p[p == round(p)]
      },
      expand = ggplot2::expansion(mult = c(0, headroom))
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = "Records", y = NULL,
      title = sprintf("Top %s", switch(by, source = "sources", author = "authors", by))
    ) +
    scopus_minimal_theme(grid = "x")
}

#' @rdname scopus_records
#' @param object A [scopus_records] object (for the `autoplot()` method).
#' @return The `autoplot()` method returns a [ggplot2::ggplot] of the records per
#'   year.
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_records <- function(object, ...) {
  rlang::check_installed("ggplot2", reason = "to plot records")
  yc <- scopus_year_counts(object)
  if (nrow(yc) == 0L) {
    rlang::abort("The records have no years to plot.", class = "scopus_error_bad_input")
  }
  ggplot2::ggplot(yc, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_col(fill = "#31688E", width = 0.8) +
    ggplot2::scale_x_continuous(breaks = scopus_year_breaks(yc$year), minor_breaks = NULL) +
    ggplot2::scale_y_continuous(limits = c(0, NA),
                                expand = ggplot2::expansion(mult = c(0, 0.06))) +
    ggplot2::labs(x = NULL, y = "Records", title = "Records by year") +
    scopus_minimal_theme()
}

#' @rdname plot_scopus_trend
#' @param object A `scopus_trend` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_trend <- function(object, ...) {
  plot_scopus_trend(object, ...)
}

#' @rdname plot_scopus_top
#' @param object A `scopus_top` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_top <- function(object, ...) {
  plot_scopus_top(object, ...)
}
