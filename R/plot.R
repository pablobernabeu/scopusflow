#' Plot a topic comparison
#'
#' Draws a line chart of each comparison topic's share of the reference
#' literature over time, from the output of [scopus_compare_topics()]. The chart
#' uses integer year breaks, a colour-blind-safe palette and, for a handful of
#' topics, labels the lines directly so the reader need not consult a legend.
#'
#' @param x A `scopus_comparison` object from [scopus_compare_topics()].
#' @param pub_count_in_legend Logical. When `TRUE` (the default), each topic's
#'   label carries its total record count, for example `effect size (n = 1,204)`.
#' @param highlight Optional character scalar naming one comparison topic to draw
#'   the eye to. The named topic is drawn in an accent colour and the others in
#'   grey, which is useful when one topic is the focus of a figure.
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Printing it draws the plot.
#' @details
#' This needs the suggested package \pkg{ggplot2} and raises an informative error
#' when it is absent. The chart shows the comparison topics alone, since the
#' reference is the 100% denominator against which they are measured. A year for
#' which the reference has no records carries no defined share and is omitted,
#' which is noted in the caption.
#' @seealso [scopus_compare_topics()]
#' @examplesIf rlang::is_installed("ggplot2")
#' cmp <- tibble::tibble(
#'   query = "q", query_type = "comparison",
#'   abridged_query = rep(c("effect size", "Bayesian"), each = 4),
#'   year = rep(2017:2020, 2), n = c(20, 24, 30, 33, 5, 7, 9, 12),
#'   reference_n = rep(120, 8),
#'   comparison_percentage = c(17, 20, 25, 27, 4, 6, 8, 10),
#'   average_comparison_percentage = rep(c(22, 7), each = 4)
#' )
#' class(cmp) <- c("scopus_comparison", class(cmp))
#' plot_scopus_comparison(cmp)
#' plot_scopus_comparison(cmp, highlight = "Bayesian")
#' @export
plot_scopus_comparison <- function(x, pub_count_in_legend = TRUE,
                                   highlight = NULL, ...) {
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

  # The reference label (held in the rows we discard) names the denominator.
  ref_lab <- unique(x$abridged_query[x$query_type == "reference"])

  # Drop years with no defined share (reference_n == 0) so lines stay continuous.
  n_missing <- sum(is.na(df$comparison_percentage))
  df <- df[!is.na(df$comparison_percentage), , drop = FALSE]
  if (nrow(df) == 0L) {
    rlang::abort(
      "The comparison has no finite percentages to plot.",
      class = "scopus_error_bad_input"
    )
  }

  topics <- unique(df$abridged_query)
  if (!is.null(highlight)) {
    if (!is.character(highlight) || length(highlight) != 1L ||
        !highlight %in% topics) {
      rlang::abort(
        sprintf("`highlight` must be one of the comparison topics: %s.",
                paste(topics, collapse = ", ")),
        class = "scopus_error_bad_input"
      )
    }
  }

  # Build a stable topic label, ordered by average share, optionally with counts.
  totals <- tapply(df$n, df$abridged_query, sum, na.rm = TRUE)
  df$label <- if (isTRUE(pub_count_in_legend)) {
    sprintf("%s (n = %s)", df$abridged_query,
            format(totals[df$abridged_query], big.mark = ","))
  } else {
    df$abridged_query
  }
  ord <- order(-df$average_comparison_percentage, df$abridged_query)
  df$label <- factor(df$label, levels = unique(df$label[ord]))

  direct <- length(topics) <= 6L
  yrs <- sort(unique(df$year))
  brk <- if (length(yrs) > 12L) {
    p <- pretty(yrs)
    p[p == round(p)]
  } else {
    yrs
  }
  ends <- df[df$year == max(yrs), , drop = FALSE]
  accent <- "#BB5566"
  grey <- "grey75"

  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = .data$year, y = .data$comparison_percentage,
                 group = .data$label)
  )

  if (is.null(highlight)) {
    p <- p +
      ggplot2::geom_line(ggplot2::aes(colour = .data$label), linewidth = 1) +
      ggplot2::geom_point(ggplot2::aes(colour = .data$label), size = 1.8,
                          stroke = 0) +
      ggplot2::scale_colour_viridis_d(option = "viridis", begin = 0.05,
                                      end = 0.85, name = NULL)
    if (direct) {
      p <- p + ggplot2::geom_text(
        data = ends,
        ggplot2::aes(label = .data$label, colour = .data$label),
        hjust = 0, nudge_x = diff(range(yrs)) * 0.02 + 0.1, size = 3.2,
        show.legend = FALSE
      )
    }
  } else {
    df$is_hi <- df$abridged_query == highlight
    ends$is_hi <- ends$abridged_query == highlight
    p <- p +
      ggplot2::geom_line(data = df[!df$is_hi, , drop = FALSE], colour = grey,
                         linewidth = 0.7) +
      ggplot2::geom_line(data = df[df$is_hi, , drop = FALSE], colour = accent,
                         linewidth = 1.3) +
      ggplot2::geom_point(data = df[df$is_hi, , drop = FALSE], colour = accent,
                          size = 2.2, stroke = 0) +
      ggplot2::geom_text(
        data = ends[ends$is_hi, , drop = FALSE],
        ggplot2::aes(label = .data$label), colour = accent, hjust = 0,
        nudge_x = diff(range(yrs)) * 0.02 + 0.1, size = 3.2
      )
  }

  # When lines are labelled directly, leave room on the right for the longest
  # label so it is not clipped.
  labelled <- direct || !is.null(highlight)
  right_pad <- if (labelled) {
    0.06 + 0.02 * max(nchar(as.character(ends$label)))
  } else {
    0.05
  }
  caption <- sprintf("Source: 'Scopus' Search API. Years %d to %d.",
                     min(yrs), max(yrs))
  if (n_missing > 0L) {
    caption <- paste0(
      caption, sprintf("\n%d year-topic value%s omitted for want of reference records.",
                       n_missing, if (n_missing == 1L) "" else "s")
    )
  }

  p +
    ggplot2::scale_x_continuous(
      breaks = brk, minor_breaks = NULL,
      expand = ggplot2::expansion(mult = c(0.02, right_pad))
    ) +
    ggplot2::scale_y_continuous(
      labels = function(v) paste0(format(v, trim = TRUE), "%"),
      limits = c(0, NA),
      expand = ggplot2::expansion(mult = c(0, 0.08))
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, y = "Share of reference records",
      title = "Topic share within a reference literature, over time",
      subtitle = if (length(ref_lab) == 1L) {
        sprintf("Each line: %% of '%s' records that also match the topic", ref_lab)
      } else {
        NULL
      },
      caption = caption
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(colour = "grey45", size = 8),
      legend.position = if (direct || !is.null(highlight)) "none" else "top"
    )
}

#' @rdname plot_scopus_comparison
#' @param object A `scopus_comparison` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_comparison <- function(object, ...) {
  plot_scopus_comparison(object, ...)
}
