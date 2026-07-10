#' Plot concept and intersection sizes
#'
#' Draws the counts from [scopus_intersections()] as a lollipop chart on a
#' log-scale axis, so a niche of a dozen records stays legible beside a parent
#' literature of many thousands. Rows are ordered by size, with the largest at
#' the top, and one or more rows can be shown in an accent colour, typically a
#' study's own niche. The axis range and the gap between each point and its
#' count label are derived from the data, so the chart reads the same whether
#' the counts span one order of magnitude or six.
#'
#' @param x A `scopus_intersections` object from [scopus_intersections()].
#' @param highlight Optional character vector of row labels to draw in an
#'   accent colour, for example the intersection that defines a study's niche.
#' @param highlight_label Legend label for the highlighted rows. The default,
#'   `NULL`, derives the label from what is highlighted: "Focal intersection"
#'   when every highlighted row is an intersection, "Focal concept" when every
#'   one is a concept, and "Focal set" for a mixture. Supply a string to use
#'   that instead.
#' @param ... Currently unused, present for S3 consistency.
#' @return A [ggplot2::ggplot] object. Needs the suggested package \pkg{ggplot2}.
#' @details
#' A count of zero cannot be placed on a log axis, so rows whose count is
#' zero or `NA` are dropped with a warning, which the caption also notes. An
#' empty intersection is itself a finding; the printed object keeps the zero
#' even though the chart cannot.
#' @seealso [scopus_intersections()]
#' @examplesIf rlang::is_installed("ggplot2")
#' sets <- tibble::tibble(
#'   label = c("semantic priming", "mental simulation",
#'             "semantic priming \u00d7 mental simulation"),
#'   query = "q",
#'   n = c(6600, 2100, 15),
#'   type = c("concept", "concept", "intersection"),
#'   size = c(1L, 1L, 2L),
#'   members = c("semantic priming", "mental simulation",
#'               "semantic priming; mental simulation")
#' )
#' class(sets) <- c("scopus_intersections", class(sets))
#' plot_scopus_intersections(sets)
#' plot_scopus_intersections(sets, highlight = sets$label[3])
#' @export
plot_scopus_intersections <- function(x, highlight = NULL,
                                      highlight_label = NULL, ...) {
  if (!inherits(x, "scopus_intersections")) {
    rlang::abort(
      "`x` must be a `scopus_intersections` object from scopus_intersections().",
      class = "scopus_error_bad_input"
    )
  }
  rlang::check_installed("ggplot2", reason = "to plot concept intersections")
  if (!all(c("label", "n", "type") %in% names(x))) {
    rlang::abort(
      "`x` must have columns `label`, `n` and `type` (see scopus_intersections()).",
      class = "scopus_error_bad_input"
    )
  }
  df <- as.data.frame(x)
  if (nrow(df) == 0L) {
    rlang::abort(
      "The `scopus_intersections` object has no rows to plot.",
      class = "scopus_error_bad_input"
    )
  }
  if (anyDuplicated(df$label)) {
    rlang::abort(
      "The `label` column must be unique to place each row on its own line.",
      class = "scopus_error_bad_input"
    )
  }
  if (!is.null(highlight)) {
    if (!is.character(highlight) || length(highlight) == 0L ||
        !all(highlight %in% df$label)) {
      rlang::abort(
        sprintf(
          "`highlight` must name rows to accent, among: %s.",
          paste(df$label, collapse = ", ")
        ),
        class = "scopus_error_bad_input"
      )
    }
  }

  n_dropped <- sum(is.na(df$n) | df$n <= 0)
  if (n_dropped > 0L) {
    cli::cli_warn(
      "{n_dropped} row{?s} without a positive count cannot sit on a log axis and {?was/were} dropped."
    )
    df <- df[!is.na(df$n) & df$n > 0, , drop = FALSE]
  }
  if (nrow(df) == 0L) {
    rlang::abort(
      "No row has a positive count to place on the log axis.",
      class = "scopus_error_bad_input"
    )
  }

  # An unset highlight label is derived from the type of the highlighted rows
  # (those still present after the zero-count drop above), so the legend says
  # what is focal rather than merely that something is.
  if (is.null(highlight_label)) {
    hi_types <- unique(df$type[df$label %in% highlight])
    highlight_label <- if (identical(hi_types, "intersection")) {
      "Focal intersection"
    } else if (identical(hi_types, "concept")) {
      "Focal concept"
    } else {
      "Focal set"
    }
  }

  cols <- c(concept = "#31688E", intersection = "#35B779",
            highlight = "#BB5566")
  legend_labels <- c(concept = "Concept", intersection = "Intersection",
                     highlight = highlight_label)
  df$grp <- df$type
  if (!is.null(highlight)) {
    df$grp[df$label %in% highlight] <- "highlight"
  }
  df$grp <- factor(df$grp, levels = names(cols))
  df$label <- factor(df$label, levels = df$label[order(df$n)])

  lo <- max(1, min(df$n)) * 0.55  # the smallest point clears the axis
  hi <- max(df$n) * 4             # headroom for the widest count label
  # Each count label sits a constant *ratio* beyond its point, not a constant
  # increment: on a log axis a fixed ratio renders as a fixed pixel gap,
  # whereas an additive nudge would hug the large counts and overshoot the
  # small ones. The ratio is in turn derived from the axis's own span, so the
  # gap occupies the same small fraction of the panel width whatever the
  # data's dynamic range; a fixed ratio tuned to one dataset reads well next
  # to wide many-digit labels but touches the point next to single-digit ones.
  gap_frac <- 0.024
  gap_mult <- 10^(gap_frac * log10(hi / lo))

  years <- attr(x, "years")
  caption <- if (is.null(years)) {
    "Source: 'Scopus' Search API."
  } else if (min(years) == max(years)) {
    sprintf("Source: 'Scopus' Search API. Year %d.", min(years))
  } else {
    sprintf("Source: 'Scopus' Search API. Years %d to %d.",
            min(years), max(years))
  }
  if (n_dropped > 0L) {
    caption <- paste0(
      caption,
      sprintf("\n%d row%s without a positive count omitted from this log-scale chart.",
              n_dropped, if (n_dropped == 1L) "" else "s")
    )
  }

  ggplot2::ggplot(df, ggplot2::aes(x = .data$n, y = .data$label,
                                   colour = .data$grp)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = lo, xend = .data$n, yend = .data$label),
      linewidth = 1.1
    ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_text(
      ggplot2::aes(
        x = .data$n * gap_mult,
        label = format(.data$n, big.mark = ",", trim = TRUE, scientific = FALSE)
      ),
      hjust = 0, size = 3, colour = "grey30"
    ) +
    ggplot2::scale_x_log10(
      breaks = scopus_log_breaks(lo, hi),
      labels = function(v) format(v, big.mark = ",", trim = TRUE, scientific = FALSE),
      limits = c(lo, hi),
      expand = ggplot2::expansion(mult = c(0.02, 0.04))
    ) +
    ggplot2::scale_colour_manual(
      values = cols, breaks = names(cols),
      labels = legend_labels[names(cols)], name = NULL,
      drop = TRUE, na.translate = FALSE
    ) +
    ggplot2::labs(
      x = "Records (log scale)", y = NULL,
      title = "Records matching each concept and intersection",
      caption = caption
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    scopus_minimal_theme(grid = "x") +
    ggplot2::theme(
      legend.position = "top",
      legend.justification = "left",
      # Grace room for the largest count label, which clip = "off" lets spill
      # past the panel on a very wide span.
      plot.margin = ggplot2::margin(6, 28, 6, 6)
    )
}

# Whole-power-of-ten breaks for a log axis, interleaved with 3 * 10^k when the
# span is narrow enough that powers of ten alone would be too sparse. Written
# here rather than taken from the scales package so that ggplot2 remains the
# plots' only suggested dependency.
scopus_log_breaks <- function(lo, hi) {
  e <- seq(floor(log10(lo)), ceiling(log10(hi)))
  brk <- 10^e
  if (sum(brk >= lo & brk <= hi) < 4L) {
    brk <- sort(c(brk, 3 * 10^e))
  }
  brk[brk >= lo & brk <= hi]
}

#' @rdname plot_scopus_intersections
#' @param object A `scopus_intersections` object (for the `autoplot()` method).
#' @exportS3Method ggplot2::autoplot
autoplot.scopus_intersections <- function(object, ...) {
  plot_scopus_intersections(object, ...)
}
