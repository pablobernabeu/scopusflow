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

  # Label the lines directly when a legend is not needed; otherwise the legend
  # (set up at the foot of this function) is used instead. The labels are spread
  # to the real text height at draw time (see sf_geom_end_labels), but more than
  # would fit one per line in a conservatively short panel would still collide, so
  # beyond that count the legend is the backstop. One labelled line is about
  # 0.16 inch (8.8 pt text with leading); the floor tracks the app's short card.
  line_in <- 3.1 * (72.27 / 25.4) / 72.27 * 1.3
  direct <- length(topics) <= min(8L, as.integer(2.2 / line_in))

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
      # Spread the right-edge labels vertically so converging lines do not produce
      # overlapping labels, and draw a thin leader from each line's true endpoint
      # to its (nudged) label so the link is unambiguous. The spreading runs at
      # draw time against the real text height (sf_geom_end_labels), so it holds at
      # any figure size. Colour comes from the same viridis scale as the lines.
      nudge <- diff(range(yrs)) * 0.012 + 0.05
      p <- p + sf_geom_end_labels(
        ggplot2::aes(x = .data$year, y = .data$comparison_percentage,
                     label = .data$label, colour = .data$label),
        data = ends, nudge = nudge, ymax = ymax_pad
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
      sf_geom_end_labels(
        ggplot2::aes(x = .data$year, y = .data$comparison_percentage,
                     label = .data$label),
        data = ends[ends$is_hi, , drop = FALSE], colour = accent,
        nudge = diff(range(yrs)) * 0.012 + 0.05, ymax = ymax_pad
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

# Direct end-of-line labels that spread themselves apart at draw time. The label
# block is handed to grid as a gTree whose `makeContent` method (below) runs when
# the panel's physical size is finally known, so the minimum vertical gap is one
# rendered line of text rather than a fixed fraction of the data range. That keeps
# converging labels from overlapping at any figure size, the grid analogue of the
# Python plot's redraw-time de-collision. Built lazily because ggplot2 is a soft
# dependency; this is only reached after the caller has confirmed ggplot2 is
# installed. `nudge` and `ymax` are in data units; `fontsize` is the label text
# size (3.1 mm in geom_text terms) expressed in points.
sf_geom_end_labels <- function(mapping = NULL, data = NULL, nudge = 0,
                               ymax = NA_real_, ...) {
  fontsize <- 3.1 * (72.27 / 25.4)
  geom <- ggplot2::ggproto(
    "GeomEndLabels", ggplot2::Geom,
    required_aes = c("x", "y", "label"),
    default_aes = ggplot2::aes(colour = "black"),
    draw_key = ggplot2::draw_key_blank,
    draw_panel = function(self, data, panel_params, coord, nudge = 0,
                          ymax = NA_real_, fontsize = 8.82) {
      d <- coord$transform(data, panel_params)
      nudged <- data; nudged$x <- nudged$x + nudge   # label x, in the right margin
      capped <- data; capped$y <- ymax               # the y-axis cap, for overflow
      dn <- coord$transform(nudged, panel_params)
      cap <- coord$transform(capped, panel_params)$y[1]
      grid::gTree(
        x0 = d$x, y0 = d$y, xlab = dn$x, ycap = cap,
        label = as.character(data$label), col = d$colour,
        lwd = 0.4 * (72.27 / 25.4), fontsize = fontsize,
        cl = "sf_endlabels"
      )
    }
  )
  ggplot2::layer(
    geom = geom, mapping = mapping, data = data, stat = "identity",
    position = "identity", show.legend = FALSE, inherit.aes = FALSE,
    params = list(nudge = nudge, ymax = ymax, fontsize = fontsize, ...)
  )
}

#' Spread converging end-labels at draw time
#'
#' Internal grid method for the [plot_scopus_comparison()] direct labels. It runs
#' whenever the label grob is drawn, when the panel viewport (and so the rendered
#' text height) is finally known, and spreads the labels by at least one line of
#' text so converging topics never overlap however the figure is sized. The panel
#' coordinates are `[0, 1]` (npc), so the measured text height, the spread and the
#' overflow shift are all in those units. Not called directly.
#' @param x The `sf_endlabels` gTree built by `sf_geom_end_labels()`.
#' @return The gTree with its leader-and-text children set.
#' @keywords internal
#' @exportS3Method grid::makeContent
makeContent.sf_endlabels <- function(x) {
  line <- grid::convertHeight(
    grid::grobHeight(grid::textGrob("Ag", gp = grid::gpar(fontsize = x$fontsize))),
    "npc", valueOnly = TRUE)
  gap <- line * 1.3  # one rendered line plus a little leading, so text never touches
  label_y <- scopus_spread_positions(x$y0, gap)
  over <- max(label_y) - x$ycap
  if (over > 0) label_y <- label_y - over
  label_y[label_y < 0] <- 0  # graceful floor if the panel is too short to fit them all
  seg <- grid::segmentsGrob(
    grid::unit(x$x0, "npc"), grid::unit(x$y0, "npc"),
    grid::unit(x$xlab, "npc"), grid::unit(label_y, "npc"),
    gp = grid::gpar(col = x$col, lwd = x$lwd), name = "sf_endlabels_leaders"
  )
  txt <- grid::textGrob(
    x$label, grid::unit(x$xlab, "npc"), grid::unit(label_y, "npc"),
    hjust = 0, gp = grid::gpar(col = x$col, fontsize = x$fontsize),
    name = "sf_endlabels_text"
  )
  grid::setChildren(x, grid::gList(seg, txt))
}

#' @rdname plot_scopus_comparison
#' @param object A `scopus_comparison` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_comparison <- function(object, ...) {
  plot_scopus_comparison(object, ...)
}
