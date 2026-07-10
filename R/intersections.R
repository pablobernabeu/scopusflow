#' Count a set of concepts and their intersections
#'
#' Counts how many records match each of a named set of concepts, and each
#' requested intersection of those concepts. This gives a size-of-field
#' snapshot that shows where a study or a niche sits within a wider
#' literature: one field may hold thousands of records and another hundreds,
#' while their intersection holds a dozen. Where [scopus_compare_topics()]
#' tracks topics' shares of a reference over time, this sizes a set of
#' concepts and their overlap at a single point. Like [scopus_count()], it
#' retrieves totals only, never records, so a whole landscape costs one
#' request per row of the result.
#'
#' A concept value that already reads as a complete field-tagged expression,
#' such as `"TITLE(virtual reality)"`, is used exactly as given, so `field`
#' never wraps it a second time, which the API would reject as malformed. Any
#' other value is treated as a bare term and wrapped in `field` when one is
#' supplied. An intersection is counted by joining its members' queries with
#' `AND`, each part in parentheses.
#'
#' @param concepts Named character vector. The names are display labels and
#'   the values are search terms (wrapped in `field` when one is given) or
#'   complete field-tagged query expressions (used as-is). The labels must be
#'   unique.
#' @param intersections Optional list of character vectors, each naming two or
#'   more distinct concept labels whose intersection should be counted, for
#'   example `list(c("A", "B"), c("A", "B", "C"))`. A single character vector
#'   is taken as one intersection.
#' @param abbrev Optional named character vector of short labels, keyed by
#'   concept label and used only when composing intersection labels, so those
#'   rows stay readable while the concept rows keep their full names.
#' @param sep Separator joining the member labels in an intersection label.
#'   Defaults to a multiplication sign between spaces.
#' @param field Optional 'Scopus' field tag wrapped around each concept value
#'   that is not already a complete field-tagged expression (see
#'   [scopus_field_tags()]).
#' @inheritParams scopus_count
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble of class `scopus_intersections` with one row per concept
#'   and per intersection: `label` (the display label), `query` (the exact
#'   query counted), `n` (the count, as a double so very large totals are
#'   exact), `type` (`"concept"` or `"intersection"`), `size` (the number of
#'   member concepts) and `members` (the member labels, joined by `"; "`). A
#'   row whose response omits a total is recorded as `NA`, with a warning. The
#'   `years` restriction, when given, is stored in the `years` attribute.
#' @section API access:
#' This performs one count request per concept and per intersection, so it
#' requires a valid API key and internet access; see the *API access* section
#' of [scopus_count()].
#' @seealso [plot_scopus_intersections()] to visualise the result, and
#'   [scopus_count()] for a single query.
#' @examplesIf scopusflow::scopus_has_key()
#' sets <- scopus_intersections(
#'   concepts = c(
#'     "semantic priming"  = "semantic priming",
#'     "mental simulation" = "mental simulation"
#'   ),
#'   intersections = list(c("semantic priming", "mental simulation")),
#'   field = "TITLE-ABS-KEY"
#' )
#' sets
#' @export
scopus_intersections <- function(concepts,
                                 intersections = NULL,
                                 abbrev = NULL,
                                 sep = " \u00d7 ",
                                 years = NULL,
                                 field = NULL,
                                 view = c("STANDARD", "COMPLETE"),
                                 api_key = NULL,
                                 inst_token = NULL,
                                 verbose = FALSE) {
  view <- rlang::arg_match(view)
  if (!is.character(concepts) || length(concepts) == 0L || anyNA(concepts) ||
      !all(nzchar(trimws(concepts)))) {
    rlang::abort(
      "`concepts` must be a non-empty character vector of non-empty terms or queries.",
      class = "scopus_error_bad_input"
    )
  }
  labels <- names(concepts)
  if (is.null(labels) || anyNA(labels) || !all(nzchar(trimws(labels)))) {
    rlang::abort(
      "`concepts` must be fully named: the names are display labels, the values terms or queries.",
      class = "scopus_error_bad_input"
    )
  }
  if (anyDuplicated(labels)) {
    rlang::abort(
      "The names of `concepts` must be unique.",
      class = "scopus_error_bad_input"
    )
  }
  if (!is.null(intersections)) {
    if (is.character(intersections)) {
      intersections <- list(intersections)
    }
    if (!is.list(intersections) ||
        !all(vapply(intersections, is.character, logical(1)))) {
      rlang::abort(
        "`intersections` must be a list of character vectors of concept labels.",
        class = "scopus_error_bad_input"
      )
    }
    for (combo in intersections) {
      if (length(combo) < 2L || anyNA(combo) || anyDuplicated(combo)) {
        rlang::abort(
          "Each intersection must name two or more distinct concept labels.",
          class = "scopus_error_bad_input"
        )
      }
      unknown <- setdiff(combo, labels)
      if (length(unknown) > 0L) {
        rlang::abort(
          sprintf(
            "Intersection member%s not among the concept labels: %s.",
            if (length(unknown) == 1L) "" else "s",
            paste(unknown, collapse = ", ")
          ),
          class = "scopus_error_bad_input"
        )
      }
    }
  }
  if (!is.null(abbrev)) {
    if (!is.character(abbrev) || length(abbrev) == 0L || anyNA(abbrev) ||
        !all(nzchar(trimws(abbrev))) ||
        is.null(names(abbrev)) || anyNA(names(abbrev)) ||
        !all(nzchar(trimws(names(abbrev))))) {
      rlang::abort(
        "`abbrev` must be a named character vector of short labels, keyed by concept label.",
        class = "scopus_error_bad_input"
      )
    }
    unknown <- setdiff(names(abbrev), labels)
    if (length(unknown) > 0L) {
      rlang::abort(
        sprintf(
          "`abbrev` name%s not among the concept labels: %s.",
          if (length(unknown) == 1L) "" else "s",
          paste(unknown, collapse = ", ")
        ),
        class = "scopus_error_bad_input"
      )
    }
  }
  if (!is.character(sep) || length(sep) != 1L || is.na(sep) || !nzchar(sep)) {
    rlang::abort(
      "`sep` must be a single non-empty string.",
      class = "scopus_error_bad_input"
    )
  }
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)

  queries <- vapply(unname(concepts), function(term) {
    scopus_wrap_concept(term, field)
  }, character(1))
  names(queries) <- labels
  short <- function(label) {
    if (!is.null(abbrev) && label %in% names(abbrev)) abbrev[[label]] else label
  }

  # Assemble every row's label and query before the first request, so that a
  # label collision (say, an `abbrev` that maps two concepts to one short
  # form) is caught while the call is still free.
  rows <- list(data.frame(
    label = labels,
    query = unname(queries),
    type = "concept",
    size = 1L,
    members = labels,
    stringsAsFactors = FALSE
  ))
  for (combo in intersections) {
    rows[[length(rows) + 1L]] <- data.frame(
      label = paste(vapply(combo, short, character(1)), collapse = sep),
      query = paste(sprintf("(%s)", queries[combo]), collapse = " AND "),
      type = "intersection",
      size = length(combo),
      members = paste(combo, collapse = "; "),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (anyDuplicated(out$label)) {
    rlang::abort(
      "The concept and intersection labels must be distinct; adjust `abbrev` or `sep`.",
      class = "scopus_error_bad_input"
    )
  }

  date <- if (is.null(years)) NULL else scopus_year_range(years)
  if (verbose) {
    cli::cli_inform("Counting {nrow(out)} quer{?y/ies} ({sum(out$type == 'intersection')} intersection{?s}).")
  }
  out$n <- vapply(out$query, function(q) {
    scopus_total_results(scopus_search_page(
      query = q, start = 0L, count = 1L, view = view,
      date = date, api_key = api_key, inst_token = inst_token
    ))
  }, numeric(1), USE.NAMES = FALSE)

  if (anyNA(out$n)) {
    missing_labels <- out$label[is.na(out$n)]
    n_missing <- length(missing_labels)
    cli::cli_warn(
      "No count returned for {n_missing} quer{?y/ies} ({.val {missing_labels}}); recorded as {.val NA}."
    )
  }

  out <- out[, c("label", "query", "n", "type", "size", "members")]
  structure(
    tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_intersections"),
    years = years
  )
}

#' @export
print.scopus_intersections <- function(x, ...) {
  n_concepts <- sum(x$type == "concept")
  n_inter <- sum(x$type == "intersection")
  cli::cli_text(
    "{.cls scopus_intersections} ({n_concepts} concept{?s}, {n_inter} intersection{?s})"
  )
  NextMethod()
  invisible(x)
}

# Wrap a bare term in the field tag, but pass a value that already reads as a
# field-tagged expression through untouched: wrapping it again (for example
# TITLE-ABS-KEY(TITLE(x))) is malformed and the API rejects it with HTTP 400.
scopus_wrap_concept <- function(term, field) {
  term <- trimws(term)
  if (grepl("^[A-Z][A-Z-]*\\(", term)) term else scopus_wrap_field(term, field)
}
