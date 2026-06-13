#' Normalise raw 'Scopus' entries to a stable tidy schema
#'
#' Converts the nested list returned by the 'Scopus' Search API into a flat,
#' predictable [tibble][tibble::tibble] with one row per record. This is the
#' common currency of the package: [scopus_fetch()] and [scopus_fetch_plan()]
#' return objects of this shape, and the DOI, comparison and export helpers all
#' consume it.
#'
#' @param x One of: a parsed `search-results` list (the value of
#'   `httr2::resp_body_json(resp)[["search-results"]]`), a bare list of entry
#'   objects, or an existing `scopus_records` object (returned unchanged).
#' @param query Optional character scalar recording the query that produced the
#'   entries; stored in the `query` column for provenance.
#' @return A tibble of class `scopus_records` with columns:
#'   `entry_number` (integer), `scopus_id` (character), `doi` (character),
#'   `title` (character), `authors` (character, first/corresponding creator),
#'   `year` (integer), `date` (character, ISO cover date), `publication`
#'   (character, source title), `citations` (integer) and `query` (character).
#'   Missing fields are `NA`. An empty result set yields a zero-row tibble with
#'   the same columns.
#' @details
#' The 'Scopus' API signals an empty result set with a single sentinel entry
#' containing an `error` field; this is detected and converted to a zero-row
#' result rather than a spurious record.
#' @examples
#' # A minimal entry as the API would return it.
#' raw <- list(entry = list(
#'   list(
#'     `dc:identifier` = "SCOPUS_ID:1",
#'     `prism:doi` = "10.1000/abc",
#'     `dc:title` = "An example",
#'     `dc:creator` = "Doe J.",
#'     `prism:publicationName` = "Journal of Examples",
#'     `prism:coverDate` = "2020-05-01",
#'     `citedby-count` = "7"
#'   )
#' ))
#' scopus_records(raw, query = "TITLE(example)")
#' @export
scopus_records <- function(x, query = NA_character_) {
  if (is_scopus_records(x)) {
    return(x)
  }
  entries <- scopus_entries(x)
  cols <- scopus_records_columns()

  if (length(entries) == 0L) {
    return(new_scopus_records(cols, query = query))
  }

  rows <- lapply(seq_along(entries), function(i) scopus_entry_to_row(entries[[i]], i, query))
  # Accumulate as a list and bind once (never rbind() inside the loop).
  out <- do.call(rbind, c(rows, list(stringsAsFactors = FALSE)))
  tibble::new_tibble(
    as.list(out),
    nrow = nrow(out),
    class = "scopus_records"
  )
}

#' @rdname scopus_records
#' @param x An object to test.
#' @return `is_scopus_records()` returns a length-one logical.
#' @export
is_scopus_records <- function(x) {
  inherits(x, "scopus_records")
}

# Extract the list of entries from any accepted input shape.
scopus_entries <- function(x) {
  entries <- if (is.list(x) && !is.null(x[["entry"]])) x[["entry"]] else x
  if (is.null(entries)) {
    return(list())
  }
  if (!is.list(entries)) {
    rlang::abort(
      "Cannot extract 'Scopus' entries from `x`; expected a list or `search-results`.",
      class = "scopus_error_bad_input"
    )
  }
  # Detect the empty-result sentinel: a single entry carrying an `error` field.
  if (length(entries) == 1L && is.list(entries[[1]]) && !is.null(entries[[1]][["error"]])) {
    return(list())
  }
  entries
}

scopus_records_columns <- function() {
  c("entry_number", "scopus_id", "doi", "title", "authors",
    "year", "date", "publication", "citations", "query")
}

# Build a zero/typed tibble of class scopus_records.
new_scopus_records <- function(cols, query = NA_character_) {
  proto <- list(
    entry_number = integer(),
    scopus_id = character(),
    doi = character(),
    title = character(),
    authors = character(),
    year = integer(),
    date = character(),
    publication = character(),
    citations = integer(),
    query = character()
  )
  tibble::new_tibble(proto[cols], nrow = 0L, class = "scopus_records")
}

# Convert a single entry to a one-row data frame.
scopus_entry_to_row <- function(entry, i, query) {
  id_raw <- scopus_field(entry, "dc:identifier")
  scopus_id <- if (is.na(id_raw)) NA_character_ else sub("^SCOPUS_ID:", "", id_raw)
  date <- scopus_field(entry, "prism:coverDate")
  year <- if (is.na(date)) NA_integer_ else suppressWarnings(as.integer(substr(date, 1, 4)))
  citations <- scopus_field(entry, "citedby-count")
  citations <- if (is.na(citations)) NA_integer_ else suppressWarnings(as.integer(citations))

  data.frame(
    entry_number = as.integer(i),
    scopus_id = scopus_id,
    doi = scopus_field(entry, "prism:doi"),
    title = scopus_field(entry, "dc:title"),
    authors = scopus_field(entry, "dc:creator"),
    year = year,
    date = date,
    publication = scopus_field(entry, "prism:publicationName"),
    citations = citations,
    query = query %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

# Safely pull a scalar character field from an entry, returning NA when absent.
scopus_field <- function(entry, name) {
  if (!is.list(entry) || is.null(entry[[name]])) {
    return(NA_character_)
  }
  val <- entry[[name]]
  if (length(val) == 0L) {
    return(NA_character_)
  }
  as.character(val[[1]])
}

#' @export
print.scopus_records <- function(x, ...) {
  cli::cli_text("{.cls scopus_records} ({nrow(x)} record{?s})")
  NextMethod()
  invisible(x)
}
