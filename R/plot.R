#' Plot a topic comparison
#'
#' Draws a line chart of each comparison topic's share of the reference
#' literature over time, from the output of [scopus_compare_topics()]. The chart
#' uses integer year breaks, a colour-blind-safe palette and, for a handful of
#' topics, labels the lines directly so the reader need not consult a legend.
#' Shaded bands convey how stable each yearly share is.
#'
#' @param x A `scopus_comparison` object from [scopus_compare_topics()].
#' @param pub_count_in_legend Logical. When `TRUE` (the default), each topic's
#'   label carries its total record count, for example `effect size (n = 1,204)`.
#' @param highlight Optional character scalar naming one comparison topic to draw
#'   the eye to. The named topic is drawn in an accent colour, and the others in
#'   grey, which is useful when one topic is the focus of a figure.
#' @param interval Logical. When `TRUE` (the default), a shaded band around each
#'   line shows a Wilson interval on the yearly share. See *Details* for how to
#'   read it.
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Printing it draws the plot.
#' @details
#' This needs the suggested package \pkg{ggplot2} and raises an informative error
#' when it is absent. The chart shows the comparison topics alone, since the
#' reference is the 100% denominator against which they are measured. A year for
#' which the reference has no records carries no defined share and is omitted,
#' which is noted in the caption.
#'
#' The shaded band is a Wilson score interval computed from the comparison count
#' and the reference count for each year. 'Scopus' returns exact counts rather
#' than a sample, so the band is not a confidence interval in the inferential
#' sense. It is best read as an illustrative stability range: it is wide where the
#' reference set for a year is small, and so the share would move easily, and
#' narrow where the reference set is large. It says nothing about query wording,
#' indexing lag or coverage, which are the larger real uncertainties.
#' @seealso [scopus_compare_topics()]
#' @examplesIf rlang::is_installed("ggplot2")
#' cmp <- tibble::tibble(
#'   query = "q", query_type = "comparison",
#'   abridged_query = rep(c("computer vision", "drug discovery"), each = 4),
#'   year = rep(2017:2020, 2), n = c(220, 280, 360, 430, 30, 55, 90, 150),
#'   reference_n = rep(1500, 8),
#'   comparison_percentage = c(14.7, 18.7, 24, 28.7, 2, 3.7, 6, 10),
#'   average_comparison_percentage = rep(c(21.5, 5.4), each = 4)
#' )
#' class(cmp) <- c("scopus_comparison", class(cmp))
#' plot_scopus_comparison(cmp)
#' plot_scopus_comparison(cmp, highlight = "drug discovery")
#' @export
plot_scopus_comparison <- function(x, pub_count_in_legend = TRUE,
                                   highlight = NULL, interval = TRUE, ...) {
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

  ref_lab <- unique(x$abridged_query[x$query_type == "reference"])

  n_missing <- sum(is.na(df$comparison_percentage))
  df <- df[!is.na(df$comparison_percentage), , drop = FALSE]
  if (nrow(df) == 0L) {
    rlang::abort(
      "The comparison has no finite percentages to plot.",
      class = "scopus_error_bad_input"
    )
  }
  df <- df[order(df$abridged_query, df$year), , drop = FALSE]

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

  totals <- tapply(df$n, df$abridged_query, sum, na.rm = TRUE)
  df$label <- if (isTRUE(pub_count_in_legend)) {
    sprintf("%s (n = %s)", df$abridged_query,
            format(totals[df$abridged_query], big.mark = ","))
  } else {
    df$abridged_query
  }
  ord <- order(-df$average_comparison_percentage, df$abridged_query)
  df$label <- factor(df$label, levels = unique(df$label[ord]))

  # Wilson interval on the yearly share, when the counts are available.
  show_band <- isTRUE(interval) &&
    all(c("n", "reference_n") %in% names(df)) &&
    any(!is.na(df$reference_n) & df$reference_n > 0 & !is.na(df$n))
  if (show_band) {
    wb <- scopus_wilson(df$n, df$reference_n)
    df$ci_lower <- wb$lower
    df$ci_upper <- wb$upper
  }

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

  # A data-driven upper limit, rounded up to the next 5%, removes dead headroom.
  ymax_src <- if (show_band) df$ci_upper else df$comparison_percentage
  ymax_pad <- min(100, ceiling(max(ymax_src, na.rm = TRUE) / 5) * 5)

  # Label the lines directly when they fit legibly once spread; otherwise the
  # legend (set up at the foot of this function) is used instead.
  gap <- ymax_pad * 0.055
  direct <- length(topics) <= 8L && (length(topics) - 1L) * gap <= ymax_pad

  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = .data$year, y = .data$comparison_percentage,
                 group = .data$label)
  )

  if (is.null(highlight)) {
    if (show_band) {
      p <- p +
        ggplot2::geom_ribbon(
          ggplot2::aes(ymin = .data$ci_lower, ymax = .data$ci_upper,
                       fill = .data$label),
          alpha = 0.18, colour = NA, show.legend = FALSE
        ) +
        ggplot2::scale_fill_viridis_d(option = "viridis", begin = 0.05,
                                      end = 0.85, guide = "none")
    }
    p <- p +
      ggplot2::geom_line(ggplot2::aes(colour = .data$label), linewidth = 1) +
      ggplot2::geom_point(ggplot2::aes(colour = .data$label), size = 1.8,
                          stroke = 0) +
      ggplot2::scale_colour_viridis_d(option = "viridis", begin = 0.05,
                                      end = 0.85, name = NULL)
    if (direct) {
      # Spread the right-edge labels vertically so converging lines do not
      # produce overlapping labels, and draw a thin leader from each line's true
      # endpoint to its (possibly nudged) label so the link is unambiguous.
      nudge <- diff(range(yrs)) * 0.012 + 0.05
      ends$label_y <- scopus_spread_positions(ends$comparison_percentage, gap)
      over <- max(ends$label_y) - ymax_pad
      if (over > 0) ends$label_y <- ends$label_y - over
      p <- p +
        ggplot2::geom_segment(
          data = ends,
          ggplot2::aes(x = .data$year, y = .data$comparison_percentage,
                       xend = .data$year + nudge, yend = .data$label_y,
                       colour = .data$label),
          linewidth = 0.4, show.legend = FALSE
        ) +
        ggplot2::geom_text(
          data = ends,
          ggplot2::aes(label = .data$label, colour = .data$label, y = .data$label_y),
          hjust = 0, nudge_x = nudge, size = 3.1, show.legend = FALSE
        )
    }
  } else {
    df$is_hi <- df$abridged_query == highlight
    ends$is_hi <- ends$abridged_query == highlight
    if (show_band) {
      p <- p + ggplot2::geom_ribbon(
        data = df[df$is_hi, , drop = FALSE],
        ggplot2::aes(ymin = .data$ci_lower, ymax = .data$ci_upper),
        fill = accent, alpha = 0.16, colour = NA
      )
    }
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
        nudge_x = diff(range(yrs)) * 0.012 + 0.05, size = 3.1
      )
  }

  # Direct labels sit in the right margin (via clip = "off") rather than in a
  # wide in-panel gutter, so the panel itself stays free of empty space.
  labelled <- direct || !is.null(highlight)
  label_room <- if (labelled) {
    min(165, 8 + 4.4 * max(nchar(as.character(ends$label))))
  } else {
    5.5
  }

  caption <- sprintf("Source: 'Scopus' Search API. Years %d to %d.",
                     min(yrs), max(yrs))
  if (show_band) {
    caption <- paste0(caption, "\nShaded band: illustrative Wilson stability range (not a confidence interval), wider where the reference set is small.")
  }
  if (n_missing > 0L) {
    caption <- paste0(
      caption, sprintf("\n%d year-topic value%s omitted for want of reference records.",
                       n_missing, if (n_missing == 1L) "" else "s")
    )
  }

  p +
    ggplot2::scale_x_continuous(
      breaks = brk, minor_breaks = NULL,
      expand = ggplot2::expansion(mult = c(0.01, if (labelled) 0.03 else 0.02))
    ) +
    ggplot2::scale_y_continuous(
      labels = function(v) paste0(format(v, trim = TRUE), "%"),
      limits = c(0, ymax_pad),
      expand = ggplot2::expansion(mult = c(0, 0.02))
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
      plot.margin = ggplot2::margin(5.5, label_room, 5.5, 5.5),
      legend.position = if (direct || !is.null(highlight)) "none" else "top"
    )
}

# Wilson score interval on a binomial share, returned as percentages in [0, 100].
# `x` is the comparison count and `n` the reference count per year.
scopus_wilson <- function(x, n, z = 1.96) {
  phat <- x / n
  denom <- 1 + z^2 / n
  centre <- (phat + z^2 / (2 * n)) / denom
  margin <- (z / denom) * sqrt(phat * (1 - phat) / n + z^2 / (4 * n^2))
  list(
    lower = pmin(pmax((centre - margin) * 100, 0), 100),
    upper = pmin(pmax((centre + margin) * 100, 0), 100)
  )
}

# Nudge label positions apart so none sits within `gap` of another, in their
# original order, moving each as little as possible upwards. Keeps the direct
# end-labels legible where lines converge near the final year.
scopus_spread_positions <- function(values, gap) {
  ord <- order(values)
  adjusted <- values
  for (k in seq_along(ord)[-1]) {
    i <- ord[k]
    prev <- ord[k - 1L]
    if (adjusted[i] < adjusted[prev] + gap) {
      adjusted[i] <- adjusted[prev] + gap
    }
  }
  adjusted
}

#' @rdname plot_scopus_comparison
#' @param object A `scopus_comparison` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_comparison <- function(object, ...) {
  plot_scopus_comparison(object, ...)
}
