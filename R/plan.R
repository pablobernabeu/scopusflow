#' Build a reproducible 'Scopus' search plan
#'
#' A *plan* is a fully specified, inspectable description of one or more 'Scopus'
#' queries to run. Splitting the act of *describing* a search from *executing* it
#' makes workflows reproducible (the plan can be saved, reviewed and version
#' controlled) and lets large retrievals be partitioned, for example one cell per
#' year, so they can be cached and resumed.
#'
#' @param query Character scalar. The base search expression, without field tags
#'   or year filters (these are added through `field` and `years`).
#' @param years Optional integer vector of publication years to restrict to, for
#'   example `2015:2020`. When `partition = "year"`, one plan cell is created for
#'   each distinct year. Otherwise the minimum and maximum define a single date
#'   range.
#' @param field Optional character scalar naming a 'Scopus' field tag to wrap the
#'   query in, for example `"TITLE-ABS-KEY"`, `"TITLE"`, `"AUTH"` or `"AFFIL"`.
#'   When `NULL`, the query is used verbatim. See [scopus_field_tags()] for the
#'   common tags.
#' @param view Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` returns more
#'   fields but requires a subscriber entitlement and is limited to a smaller
#'   page size.
#' @param page_size Integer number of records to request per page, or `NULL`
#'   (the default) to use the largest page the view allows. The 'Scopus' Search
#'   API permits up to 200 records per page for the `STANDARD` view but only 25
#'   for `COMPLETE`. Because the weekly quota is charged per request, requesting
#'   the maximum page size keeps the number of requests, and so the quota, as low
#'   as possible for a given result set. Lower it only where you have a reason to.
#' @param partition Either `"none"` (a single query cell) or `"year"` (one cell
#'   per year in `years`). Partitioning by year is the recommended way to stay
#'   under the API's hard limit of `start < 5000`.
#' @return A tibble of class `scopus_plan`, one row per cell, with columns
#'   `cell`, `query` (field-wrapped), `date` (year range string or `NA`), `year`
#'   (integer or `NA`), `view` and `page_size`. Plan-level settings are stored as
#'   attributes.
#' @seealso [scopus_fetch_plan()] to execute a plan, [scopus_count()] to size it.
#' @examples
#' scopus_plan("language learning", years = 2018:2020, field = "TITLE-ABS-KEY")
#' scopus_plan("machine translation", years = 2010:2020, partition = "year")
#' @export
scopus_plan <- function(query,
                        years = NULL,
                        field = NULL,
                        view = c("STANDARD", "COMPLETE"),
                        page_size = NULL,
                        partition = c("none", "year")) {
  view <- rlang::arg_match(view)
  partition <- rlang::arg_match(partition)
  scopus_check_query(query)
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  page_size <- scopus_resolve_page_size(page_size, view)

  wrapped <- scopus_wrap_field(query, field)

  if (partition == "year") {
    if (is.null(years)) {
      rlang::abort(
        "`partition = \"year\"` requires `years` to be supplied.",
        class = "scopus_error_bad_input"
      )
    }
    yrs <- sort(unique(years))
    cells <- tibble::tibble(
      cell = seq_along(yrs),
      query = wrapped,
      date = as.character(yrs),
      year = as.integer(yrs),
      view = view,
      page_size = page_size
    )
  } else {
    date <- if (is.null(years)) NA_character_ else scopus_year_range(years)
    cells <- tibble::tibble(
      cell = 1L,
      query = wrapped,
      date = date,
      year = NA_integer_,
      view = view,
      page_size = page_size
    )
  }

  structure(
    cells,
    class = c("scopus_plan", class(tibble::tibble())),
    base_query = query,
    field = field,
    view = view,
    page_size = page_size,
    partition = partition
  )
}

#' @rdname scopus_plan
#' @param x An object to test or print.
#' @return `is_scopus_plan()` returns a length-one logical.
#' @export
is_scopus_plan <- function(x) {
  inherits(x, "scopus_plan")
}

#' @export
print.scopus_plan <- function(x, ...) {
  cli::cli_text(
    "{.cls scopus_plan} ({nrow(x)} cell{?s}, view {.val {attr(x, 'view')}}, ",
    "partition {.val {attr(x, 'partition')}})"
  )
  NextMethod()
  invisible(x)
}

# Input validation helpers --------------------------------------------------

scopus_check_query <- function(query, call = rlang::caller_env()) {
  if (!is.character(query) || length(query) != 1L || is.na(query) || !nzchar(trimws(query))) {
    rlang::abort(
      "`query` must be a single, non-empty character string.",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  invisible(query)
}

scopus_check_field <- function(field, call = rlang::caller_env()) {
  if (is.null(field)) {
    return(NULL)
  }
  if (!is.character(field) || length(field) != 1L || is.na(field) || !nzchar(field)) {
    rlang::abort(
      "`field` must be `NULL` or a single character field tag (e.g. \"TITLE-ABS-KEY\").",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  field <- toupper(trimws(field))
  if (!grepl("^[A-Z-]+$", field)) {
    rlang::abort(
      "`field` must contain only letters and hyphens (e.g. \"TITLE-ABS-KEY\").",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  field
}

scopus_check_years <- function(years, call = rlang::caller_env()) {
  if (is.null(years)) {
    return(NULL)
  }
  if (!is.numeric(years) || anyNA(years) || any(years != floor(years))) {
    rlang::abort(
      "`years` must be `NULL` or a vector of whole numbers (e.g. 2015:2020).",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  years <- as.integer(years)
  if (any(years < 1700L) || any(years > 2200L)) {
    rlang::abort(
      "`years` must lie within a plausible publication range (1700-2200).",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  years
}

# The Scopus Search API page-size ceiling, which depends on the view:
# 200 records per request for STANDARD, 25 for COMPLETE.
scopus_view_max <- function(view) {
  if (identical(view, "COMPLETE")) 25L else 200L
}

# Resolve page_size: NULL means "use the most quota-efficient page for the view".
scopus_resolve_page_size <- function(page_size, view, call = rlang::caller_env()) {
  if (is.null(page_size)) {
    return(scopus_view_max(view))
  }
  scopus_check_page_size(page_size, view, call = call)
}

scopus_check_page_size <- function(page_size, view = "STANDARD",
                                   call = rlang::caller_env()) {
  if (!is.numeric(page_size) || length(page_size) != 1L || is.na(page_size) ||
      page_size != floor(page_size)) {
    rlang::abort(
      "`page_size` must be a single whole number or `NULL`.",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  page_size <- as.integer(page_size)
  max_size <- scopus_view_max(view)
  if (page_size < 1L || page_size > max_size) {
    rlang::abort(
      sprintf(
        "`page_size` must be between 1 and %d for the %s view (the 'Scopus' Search API page limit).",
        max_size, view
      ),
      class = "scopus_error_bad_input",
      call = call
    )
  }
  page_size
}

# Wrap a query in a field tag, e.g. TITLE-ABS-KEY(language learning).
scopus_wrap_field <- function(query, field) {
  if (is.null(field)) query else sprintf("%s(%s)", field, query)
}

# Build a "min-max" (or "yyyy") date range string from a vector of years.
scopus_year_range <- function(years) {
  lo <- min(years)
  hi <- max(years)
  if (lo == hi) as.character(lo) else sprintf("%d-%d", lo, hi)
}
