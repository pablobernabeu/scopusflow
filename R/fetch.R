#' Fetch 'Scopus' records for a query
#'
#' Retrieves records page by page, accumulating them and returning a single
#' normalised [scopus_records] tibble. Pagination, the API's hard `start < 5000`
#' ceiling, rate-limit handling and retry with back-off are all managed for you.
#'
#' @inheritParams scopus_count
#' @param max_results Maximum number of records to retrieve. Defaults to `Inf`,
#'   meaning all available records up to the API ceiling. With the default
#'   offset-based paging the 'Scopus' Search API refuses offsets of 5000 or more,
#'   so a single query yields at most 5000 records; set `cursor = TRUE`, or
#'   partition the search by year with [scopus_plan()], to go beyond that.
#' @param page_size Integer records per page, or `NULL` (default) to use the
#'   most quota-efficient page the view allows (200 for `STANDARD`, 25 for
#'   `COMPLETE`). See [scopus_plan()] for why larger pages cost less quota.
#' @param cursor Logical. When `TRUE`, retrieve the result set with cursor-based
#'   pagination, which has no 5000-record ceiling, so an entire large query can be
#'   harvested in one call. The records then arrive in the API's deep-paging
#'   order, which is no longer relevance order. As a safeguard against a
#'   non-conforming server that never signals the end, cursor paging stops after
#'   `getOption("scopusflow.max_cursor_pages", 1e5)` pages with a warning; set
#'   that option to `Inf` to remove the ceiling.
#' @param verbose Logical. When `TRUE`, progress is reported as the retrieval
#'   proceeds.
#' @return A [scopus_records] tibble. The reported total and the most recent
#'   parsed quota are attached as the `total_results` and `quota` attributes,
#'   the harvest is dated by `retrieved_at` (a `POSIXct`) and
#'   `scopusflow_version`, and `paging` records whether it was retrieved by
#'   offset or by cursor. The date and version matter because `citations` is a
#'   snapshot value that keeps moving, so two saved sets are only comparable if
#'   each records when it was taken, and [scopus_search_report()] reads all of
#'   them back. They survive a `.rds` round trip through
#'   [write_scopus_records()] but not a `.csv` one, which carries columns only.
#' @section API access:
#' Requires a valid API key and internet access. The *API access* section of
#' [scopus_count()] lists the conditions that may be raised.
#' @seealso [scopus_fetch_plan()] for cached, resumable, partitioned retrieval.
#' @examplesIf scopusflow::scopus_has_key()
#' recs <- scopus_fetch("graphene supercapacitor", field = "TITLE-ABS-KEY",
#'                      max_results = 50)
#' recs
#' @examples
#' # The offline companion, which needs no key. 'Scopus' records may not be
#' # redistributed, so the package bundles a corpus of real articles in this
#' # same schema; a live harvest returns exactly this shape.
#' recs <- example_records
#' recs
#' nrow(recs)
#' is_scopus_records(recs)
#' @export
scopus_fetch <- function(query,
                         max_results = Inf,
                         view = c("STANDARD", "COMPLETE"),
                         page_size = NULL,
                         field = NULL,
                         years = NULL,
                         cursor = FALSE,
                         api_key = NULL,
                         inst_token = NULL,
                         verbose = FALSE) {
  view <- rlang::arg_match(view)
  scopus_check_query(query)
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  page_size <- scopus_resolve_page_size(page_size, view)
  max_results <- scopus_check_max_results(max_results)
  scopus_check_flag(cursor, "cursor")
  scopus_check_flag(verbose, "verbose")

  wrapped <- scopus_wrap_field(query, field)
  date <- if (is.null(years)) NULL else scopus_year_range(years)

  records <- scopus_fetch_core(
    wrapped = wrapped, date = date, view = view, page_size = page_size,
    max_results = max_results, cursor = isTRUE(cursor),
    api_key = api_key, inst_token = inst_token, verbose = verbose
  )
  scopus_warn_fetch_shortfall(records, max_results = max_results)
  records
}

# A harvest that came back with fewer records than the API said it had is the
# one failure mode a caller cannot see for themselves, since a truncated or
# refused download arrives as a merely small result set. `scopus_fetch_plan()`
# raises the same warning per cell. A retrieval the caller deliberately limited
# is exempt, and so is one that stopped at the API's offset ceiling, which
# already warns for itself.
scopus_warn_fetch_shortfall <- function(records, max_results) {
  total <- scopus_reported_total(records)
  n <- nrow(records)
  if (is.na(total) || n >= total) {
    return(invisible(NULL))
  }
  if (is.finite(max_results) && n >= max_results) {
    return(invisible(NULL))
  }
  hard_cap <- as.integer(getOption("scopusflow.hard_cap", 5000L))
  if (identical(attr(records, "paging"), "offset") && n >= hard_cap) {
    return(invisible(NULL))
  }
  rlang::warn(
    sprintf(
      paste0("Retrieved %d record(s), but the Scopus API reports %s for this ",
             "query, so the harvest may be incomplete. Check the key's ",
             "remaining quota, and consider partitioning the search by year ",
             "with scopus_plan()."),
      n, format(total, big.mark = ",", scientific = FALSE)
    ),
    class = "scopus_warning_shortfall"
  )
}

# Internal pagination engine shared by scopus_fetch() and scopus_fetch_plan().
# `wrapped` is the field-wrapped query. `date` is a year-range string or NULL.
scopus_fetch_core <- function(wrapped, date, view, page_size, max_results,
                              cursor = FALSE, api_key = NULL, inst_token = NULL,
                              verbose = FALSE) {
  if (isTRUE(cursor)) {
    return(scopus_fetch_cursor(
      wrapped = wrapped, date = date, view = view, page_size = page_size,
      max_results = max_results, api_key = api_key, inst_token = inst_token,
      verbose = verbose
    ))
  }
  # The API refuses start >= 5000; configurable only to keep tests fast.
  hard_cap <- as.integer(getOption("scopusflow.hard_cap", 5000L))

  fetch_page <- function(start, count) {
    scopus_search_page(
      query = wrapped, start = start, count = count, view = view,
      date = date, api_key = api_key, inst_token = inst_token
    )
  }

  # First page: also tells us the total (a double, possibly NA when the API
  # omits it).
  first_count <- min(page_size, max_results)
  first <- fetch_page(0L, first_count)
  total <- scopus_total_results(first)
  quota <- attr(first, "quota")
  pages <- list(scopus_entries(first))
  fetched <- length(pages[[1]])

  known_total <- !is.na(total)
  # `max_results` has to enter this: a caller who asked for fewer records than
  # the ceiling gets exactly what they asked for, and telling them their
  # retrieval was truncated, and to restructure it, would be false.
  capped <- known_total && total > hard_cap && max_results > hard_cap
  if (capped) {
    rlang::warn(
      sprintf(
        paste0("This query matches %s records, but the 'Scopus' API returns at ",
               "most the first %d under offset paging. Use scopus_fetch(cursor ",
               "= TRUE), or partition by year with scopus_plan(), to go further."),
        format(total, big.mark = ","), hard_cap
      ),
      class = "scopus_warning_capped"
    )
  }

  # How many to aim for: the reported total when known, otherwise page up to the
  # ceiling and let the empty-page break below end the harvest.
  to_fetch <- if (known_total) {
    min(max_results, total, hard_cap)
  } else {
    min(max_results, hard_cap)
  }
  if (verbose) {
    cli::cli_inform("Fetching up to {to_fetch} record{?s}.")
  }

  # The next offset is what has actually been received, not what was asked for.
  # A key whose entitlement caps the page below `page_size` returns fewer
  # entries than requested without having reached the end of the set, and
  # advancing by the request would step over the records in between; only an
  # empty page means there is no more to come.
  start <- fetched
  while (fetched < to_fetch && start < hard_cap) {
    count <- min(page_size, to_fetch - fetched)
    page <- fetch_page(start, count)
    quota <- attr(page, "quota")
    entries <- scopus_entries(page)
    if (length(entries) == 0L) break
    pages[[length(pages) + 1L]] <- entries
    fetched <- fetched + length(entries)
    if (verbose) cli::cli_inform("  {fetched}/{to_fetch} retrieved.")
    start <- start + length(entries)
  }

  # Concatenate entries once, then normalise a single time.
  all_entries <- unlist(pages, recursive = FALSE)
  if (is.null(all_entries)) all_entries <- list()
  records <- scopus_records(list(entry = all_entries), query = wrapped, view = view)
  scopus_attach_provenance(records, total = total, quota = quota, paging = "offset")
}

# When a retrieval was taken, by which version of the package, and how it was
# paged. `citations` is a snapshot value that moves continuously, and the
# change-tracking workflow rests on diffing two pulls, so a saved set that
# cannot say when it was taken cannot honestly be compared with another. The
# paging mode belongs with them because it decides what the set can contain: an
# offset-paged query stops at the API's ceiling where a cursor-paged one does
# not, and a search report has to state which was used. Attributes, never
# columns, so the documented schema and the CSV round-trip are untouched.
scopus_attach_provenance <- function(records, total, quota, paging) {
  attr(records, "total_results") <- total
  attr(records, "quota") <- quota
  attr(records, "retrieved_at") <- Sys.time()
  attr(records, "scopusflow_version") <-
    as.character(utils::packageVersion("scopusflow"))
  attr(records, "paging") <- paging
  records
}

# Cursor-based pagination: follow the `@next` cursor the API returns until the
# result set is exhausted, so there is no 5000-record ceiling.
scopus_fetch_cursor <- function(wrapped, date, view, page_size, max_results,
                                api_key = NULL, inst_token = NULL, verbose = FALSE) {
  pages <- list()
  fetched <- 0L
  total <- NA_real_
  quota <- NULL
  cursor <- "*"
  page_no <- 0L
  # A safety ceiling on the number of cursor pages, in case a misbehaving API
  # keeps advancing the cursor without ever signalling the end. Set generously
  # so it never bites a conforming server; configurable to keep tests fast.
  # A non-finite or invalid option means "no ceiling" (Inf), so `page_no >= Inf`
  # is simply never true, where coercing to NA would abort the loop.
  max_pages <- suppressWarnings(as.numeric(
    getOption("scopusflow.max_cursor_pages", 100000L)
  ))
  if (length(max_pages) != 1L || is.na(max_pages) || max_pages < 1) {
    max_pages <- Inf
  }

  repeat {
    count <- if (is.finite(max_results)) min(page_size, max_results - fetched) else page_size
    if (count <= 0L) break
    results <- scopus_search_page(
      query = wrapped, cursor = cursor, count = count, view = view,
      date = date, api_key = api_key, inst_token = inst_token
    )
    if (is.na(total)) total <- scopus_total_results(results)
    quota <- attr(results, "quota")
    entries <- scopus_entries(results)
    if (length(entries) == 0L) break
    pages[[length(pages) + 1L]] <- entries
    fetched <- fetched + length(entries)
    page_no <- page_no + 1L
    if (verbose) cli::cli_inform("  {fetched} retrieved.")

    # Stop once the reported total is reached: an API that keeps advancing the
    # cursor beyond its own total has started repeating, so there is no more.
    if (!is.na(total) && fetched >= total) break

    next_cursor <- results[["cursor"]][["@next"]]
    # Stop when the API offers no further cursor or stops advancing.
    if (is.null(next_cursor) || identical(next_cursor, cursor)) break
    cursor <- next_cursor

    # Backstop: a non-conforming API that never signals the end must not page
    # forever, burning memory, requests and quota. Warn and return what we have.
    if (page_no >= max_pages) {
      rlang::warn(
        sprintf(
          paste0("Cursor paging stopped after %d pages (%s records) without the ",
                 "'Scopus' API signalling the end; returning what was retrieved. ",
                 "Raise scopusflow.max_cursor_pages if the result set is larger."),
          page_no, format(fetched, big.mark = ",")
        ),
        class = "scopus_warning_capped"
      )
      break
    }
  }

  all_entries <- unlist(pages, recursive = FALSE)
  if (is.null(all_entries)) all_entries <- list()
  records <- scopus_records(list(entry = all_entries), query = wrapped, view = view)
  scopus_attach_provenance(records, total = total, quota = quota, paging = "cursor")
}

scopus_check_max_results <- function(max_results, call = rlang::caller_env()) {
  if (length(max_results) != 1L || is.na(max_results) || !is.numeric(max_results) ||
      max_results < 1 || (is.finite(max_results) && max_results != floor(max_results))) {
    rlang::abort(
      "`max_results` must be a single positive whole number or `Inf`.",
      class = c("scopus_error_bad_input", "scopus_error"),
      call = call
    )
  }
  # An integer only where one fits. The validator above accepts any finite whole
  # number, and as.integer() turns anything past the 32-bit ceiling into NA,
  # after which every `n >= max_results` downstream is NA and the retrieval dies
  # on an untyped "missing value where TRUE/FALSE needed". Every use of this
  # value is a min(), an is.finite() or a head(), all of which take a double, so
  # a cap that large is simply carried as one.
  if (is.infinite(max_results) || max_results > .Machine$integer.max) {
    max_results
  } else {
    as.integer(max_results)
  }
}
