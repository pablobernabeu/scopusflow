#' Plot a topic comparison
#'
#' Draws a line chart of comparison percentage over time, one line per comparison
#' topic, from the output of [scopus_compare_topics()].
#'
#' @param x A `scopus_comparison` object from [scopus_compare_topics()].
#' @param pub_count_in_legend Logical; append each topic's total record count to
#'   its legend label (default `TRUE`).
#' @param ... Currently unused; present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Printing it draws the plot.
#' @details
#' Requires the suggested package \pkg{ggplot2}; an informative error is raised
#' if it is not installed. Only comparison topics are drawn (the reference
#' baseline is the 100% denominator and is omitted).
#' @seealso [scopus_compare_topics()]
#' @examplesIf rlang::is_installed("ggplot2")
#' cmp <- tibble::tibble(
#'   query = "q", query_type = "comparison", abridged_query = rep(c("a", "b"), each = 3),
#'   year = rep(2018:2020, 2), n = c(5, 6, 7, 1, 2, 3), reference_n = rep(10, 6),
#'   comparison_percentage = c(50, 60, 70, 10, 20, 30),
#'   average_comparison_percentage = rep(c(60, 20), each = 3)
#' )
#' class(cmp) <- c("scopus_comparison", class(cmp))
#' plot_scopus_comparison(cmp)
#' @export
plot_scopus_comparison <- function(x, pub_count_in_legend = TRUE, ...) {
  if (!inherits(x, "scopus_comparison")) {
    rlang::abort(
      "`x` must be a `scopus_comparison` object from scopus_compare_topics().",
      class = "scopus_error_bad_input"
    )
  }
  rlang::check_installed("ggplot2", reason = "to plot a topic comparison")

  df <- x[x$query_type == "comparison", , drop = FALSE]
  if (nrow(df) == 0L) {
    rlang::abort(
      "The comparison contains no comparison topics to plot.",
      class = "scopus_error_bad_input"
    )
  }

  # Build a stable legend label, optionally with the total record count.
  totals <- tapply(df$n, df$abridged_query, sum)
  df$label <- if (isTRUE(pub_count_in_legend)) {
    sprintf("%s (n = %s)", df$abridged_query,
            format(totals[df$abridged_query], big.mark = ","))
  } else {
    df$abridged_query
  }
  # Preserve ordering by average percentage for a tidy legend.
  ord <- order(-df$average_comparison_percentage, df$abridged_query)
  df$label <- factor(df$label, levels = unique(df$label[ord]))

  ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = .data$year, y = .data$comparison_percentage,
      colour = .data$label, group = .data$label
    )
  ) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_point(size = 1.6) +
    ggplot2::scale_y_continuous(
      labels = function(v) paste0(format(v, trim = TRUE), "%")
    ) +
    ggplot2::labs(
      x = "Year", y = "Share of reference literature",
      colour = "Topic",
      title = "Topic comparison over time"
    ) +
    ggplot2::theme_minimal()
}

#' @rdname plot_scopus_comparison
#' @param object A `scopus_comparison` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_comparison <- function(object, ...) {
  plot_scopus_comparison(object, ...)
}
