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
#' When the years plotted reach the year recorded in the `retrieved_at`
#' attribute that [scopus_trend()] attaches, the caption adds a line such as
#' "2026 was incomplete when retrieved on 2026-09-29." 'Scopus' goes on
#' indexing a year's publications after the year has begun, so the last point
#' of such a figure is a count so far, easily read as a decline. The line is
#' read from the recorded time alone, never from the clock of the session
#' drawing the figure, so a trend that records none, such as one tallied by
#' hand, is drawn without it.
#'
#' @param x A `scopus_trend` object from [scopus_trend()].
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Needs the suggested package \pkg{ggplot2}.
#' @seealso [scopus_trend()]
#' @examplesIf rlang::is_installed("ggplot2")
#' # Drawn from the bundled corpus of real articles, which needs no key. That
#' # corpus is a complete harvest of OpenAlex's exact-phrase search for the
#' # phrase below, so its rows per year are the publications per year of that
#' # search.
#' by_year <- table(example_records$year)
#' tr <- tibble::tibble(
#'   query = 'TITLE-ABS-KEY("graphene supercapacitor")',
#'   year = as.integer(names(by_year)),
#'   n = as.numeric(by_year)
#' )
#' class(tr) <- c("scopus_trend", class(tr))
#' plot_scopus_trend(tr)
#' @export
plot_scopus_trend <- function(x, ...) {
  if (!inherits(x, "scopus_trend")) {
    scopus_abort_bad_input("`x` must be a `scopus_trend` object from scopus_trend().")
  }
  rlang::check_installed("ggplot2", reason = "to plot a trend")
  yrs <- sort(unique(x$year))
  if (length(yrs) == 0L) {
    scopus_abort_bad_input("The trend has no years to plot.")
  }
  caption <- paste(c(
    sprintf("Source: 'Scopus' Search API. Years %d to %d.", min(yrs), max(yrs)),
    scopus_incomplete_note(yrs, attr(x, "retrieved_at"))
  ), collapse = "\n")
  ggplot2::ggplot(x, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_area(fill = "#31688E", alpha = 0.16) +
    ggplot2::geom_line(colour = "#31688E", linewidth = 1) +
    ggplot2::geom_point(colour = "#31688E", size = 1.8, stroke = 0) +
    ggplot2::scale_x_continuous(breaks = scopus_year_breaks(yrs), minor_breaks = NULL) +
    ggplot2::scale_y_continuous(
      labels = function(v) format(v, big.mark = ",", trim = TRUE, scientific = FALSE),
      limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.06))
    ) +
    ggplot2::labs(x = NULL, y = "Records", title = "Publications per year",
                  caption = caption) +
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
    scopus_abort_bad_input("`x` must be a `scopus_top` object from scopus_top().")
  }
  rlang::check_installed("ggplot2", reason = "to plot top values")
  if (nrow(x) == 0L) {
    scopus_abort_bad_input("The `scopus_top` object has no values to plot.")
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
#'   year. The bars cover every year the set's plan searched, a year without
#'   records drawn as a zero bar, and no year the plan did not search. A plan
#'   over 2015, 2016, 2019 and 2020 therefore draws no bar for 2017 or 2018. A
#'   harvest stopped before its last cell covers only the cells it ran. Without
#'   a plan, or with one that sent no year limit, the bars run from the first
#'   year in the records to the last. When a `max_results` cap stopped any
#'   cell of the retrieval, a caption says that the bars count records
#'   retrieved, not publications per year. When the years plotted reach the
#'   year of the recorded `retrieved_at`, the caption also says that year was
#'   incomplete when the records were retrieved, as [plot_scopus_trend()] does.
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_records <- function(object, ...) {
  rlang::check_installed("ggplot2", reason = "to plot records")
  yc <- scopus_year_counts(object)
  if (nrow(yc) == 0L) {
    scopus_abort_bad_input("The records have no years to plot.")
  }
  p <- ggplot2::ggplot(yc, ggplot2::aes(x = .data$year, y = .data$n)) +
    ggplot2::geom_col(fill = "#31688E", width = 0.8) +
    ggplot2::scale_x_continuous(breaks = scopus_year_breaks(yc$year), minor_breaks = NULL) +
    ggplot2::scale_y_continuous(limits = c(0, NA),
                                expand = ggplot2::expansion(mult = c(0, 0.06))) +
    ggplot2::labs(x = NULL, y = "Records", title = "Records by year") +
    scopus_minimal_theme()
  # Under a cap that stopped a cell, the bars reach the cap, and a figure of
  # records by year would be read as publications per year. The cells are read
  # as the search record reads them.
  cap <- scopus_records_cap(object)
  captions <- character()
  if (!is.null(cap) && cap$capped > 0L) {
    captions <- sprintf(
      paste("Retrieval capped at %s records per cell: the bars count records",
            "retrieved, not publications per year."),
      scopus_report_count(cap$cap)
    )
  }
  # A combined set carries the earliest of its parts' times, since it is only
  # as fresh as its oldest part.
  captions <- c(captions, scopus_incomplete_note(yc$year, attr(object, "retrieved_at")))
  if (length(captions) > 0L) {
    p <- p + ggplot2::labs(caption = paste(captions, collapse = "\n"))
  }
  p
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
