#' Fetch 'Scopus' records for a query
#'
#' Retrieves records page by page, accumulating them and returning a single
#' normalised [scopus_records] tibble. Pagination, the API's hard `start < 5000`
#' ceiling, rate-limit handling and retry with back-off are all managed for you.
#'
#' @inheritParams scopus_count
#' @param max_results Maximum number of records to retrieve. Defaults to `Inf`,
#'   meaning all available records up to the API ceiling. The 'Scopus' Search
#'   API refuses offsets of 5000 or more, so a single query yields at most 5000
#'   records. To go beyond that, partition the search by year with
#'   [scopus_plan()].
#' @param page_size Integer records per page, or `NULL` (default) to use the
#'   most quota-efficient page the view allows (200 for `STANDARD`, 25 for
#'   `COMPLETE`). See [scopus_plan()] for why larger pages cost less quota.
#' @param verbose Logical. When `TRUE`, progress is reported as the retrieval
#'   proceeds.
#' @return A [scopus_records] tibble. The reported total and the most recent
#'   parsed quota are attached as the `total_results` and `quota` attributes.
#' @section API access:
#' Requires a valid API key and internet access. The *API access* section of
#' [scopus_count()] lists the conditions that may be raised.
#' @seealso [scopus_fetch_plan()] for cached, resumable, partitioned retrieval.
#' @examplesIf scopusflow::scopus_has_key()
#' recs <- scopus_fetch("TITLE-ABS-KEY(bibliometric)", max_results = 50)
#' recs
#' @export
scopus_fetch <- function(query,
                         max_results = Inf,
                         view = c("STANDARD", "COMPLETE"),
                         page_size = NULL,
                         field = NULL,
                         years = NULL,
                         api_key = NULL,
                         inst_token = NULL,
                         verbose = FALSE) {
  view <- rlang::arg_match(view)
  scopus_check_query(query)
  field <- scopus_check_field(field)
  years <- scopus_check_years(years)
  page_size <- scopus_resolve_page_size(page_size, view)
  max_results <- scopus_check_max_results(max_results)

  wrapped <- scopus_wrap_field(query, field)
  date <- if (is.null(years)) NULL else scopus_year_range(years)

  scopus_fetch_core(
    wrapped = wrapped, date = date, view = view, page_size = page_size,
    max_results = max_results, api_key = api_key, inst_token = inst_token,
    verbose = verbose
  )
}

# Internal pagination engine shared by scopus_fetch() and scopus_fetch_plan().
# `wrapped` is the field-wrapped query. `date` is a year-range string or NULL.
scopus_fetch_core <- function(wrapped, date, view, page_size, max_results,
                              api_key = NULL, inst_token = NULL, verbose = FALSE) {
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
  capped <- known_total && total > hard_cap
  if (capped) {
    rlang::warn(
      sprintf(
        paste0("This query matches %s records, but the 'Scopus' API returns at ",
               "most the first %d. Partition by year with scopus_plan() to go further."),
        format(total, big.mark = ","), hard_cap
      ),
      class = "scopus_warning_capped"
    )
  }

  # How many to aim for: the reported total when known, otherwise keep paging
  # (up to the ceiling) until a short or empty page signals the end. A first page
  # shorter than requested already means there is nothing more to fetch.
  to_fetch <- if (known_total) {
    min(max_results, total, hard_cap)
  } else if (fetched < first_count) {
    fetched
  } else {
    min(max_results, hard_cap)
  }
  if (verbose) {
    cli::cli_inform("Fetching up to {to_fetch} record{?s}.")
  }

  start <- page_size
  while (fetched < to_fetch && start < hard_cap) {
    count <- min(page_size, to_fetch - fetched)
    page <- fetch_page(start, count)
    quota <- attr(page, "quota")
    entries <- scopus_entries(page)
    if (length(entries) == 0L) break
    pages[[length(pages) + 1L]] <- entries
    fetched <- fetched + length(entries)
    if (verbose) cli::cli_inform("  {fetched}/{to_fetch} retrieved.")
    start <- start + page_size
    # A page shorter than requested is the last page; stop without a wasted call.
    if (length(entries) < count) break
  }

  # Concatenate entries once, then normalise a single time.
  all_entries <- unlist(pages, recursive = FALSE)
  if (is.null(all_entries)) all_entries <- list()
  records <- scopus_records(list(entry = all_entries), query = wrapped)
  attr(records, "total_results") <- total
  attr(records, "quota") <- quota
  records
}

scopus_check_max_results <- function(max_results, call = rlang::caller_env()) {
  if (length(max_results) != 1L || is.na(max_results) || !is.numeric(max_results) ||
      max_results < 1 || (is.finite(max_results) && max_results != floor(max_results))) {
    rlang::abort(
      "`max_results` must be a single positive whole number or `Inf`.",
      class = "scopus_error_bad_input",
      call = call
    )
  }
  if (is.infinite(max_results)) max_results else as.integer(max_results)
}
