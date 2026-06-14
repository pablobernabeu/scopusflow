#' Normalise raw 'Scopus' entries to a stable tidy schema
#'
#' Converts the nested list returned by the 'Scopus' Search API into a flat,
#' predictable [tibble][tibble::tibble] with one row per record. This shape is
#' the common currency of the package. Both [scopus_fetch()] and
#' [scopus_fetch_plan()] return it, and the DOI, comparison and export helpers
#' all consume it.
#'
#' @param x A parsed `search-results` list (the value of
#'   `httr2::resp_body_json(resp)[["search-results"]]`), a bare list of entry
#'   objects, or an existing `scopus_records` object, which is returned
#'   unchanged.
#' @param query Optional character scalar recording the query that produced the
#'   entries, kept in the `query` column for provenance.
#' @return A tibble of class `scopus_records` with the columns
#'   `entry_number` (integer), `scopus_id` (character), `doi` (character),
#'   `title` (character), `authors` (character, the creator names joined with
#'   `"; "` when several are listed), `year` (integer, the leading four digits of
#'   the cover date), `date` (character, the ISO cover date), `publication`
#'   (character, the source title), `citations` (integer) and `query`
#'   (character). A missing field becomes `NA`, and an empty result set yields a
#'   zero-row tibble with the same columns.
#' @details
#' The 'Scopus' API signals an empty result set with a single sentinel entry that
#' carries an `error` field and no identifier. This is detected and turned into a
#' zero-row result rather than a spurious record, while a genuine record that also
#' carries a per-entry `error` annotation is kept.
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
      "Cannot extract 'Scopus' entries from `x`. Provide a list or a `search-results` object.",
      class = "scopus_error_bad_input"
    )
  }
  # Detect the empty-result sentinel: a lone entry carrying an `error` field and
  # no bibliographic identifier. A real single record can also carry a per-entry
  # `error` annotation, so requiring the identifiers to be absent avoids dropping
  # it.
  if (length(entries) == 1L && scopus_is_empty_sentinel(entries[[1]])) {
    return(list())
  }
  entries
}

scopus_is_empty_sentinel <- function(entry) {
  is.list(entry) && !is.null(entry[["error"]]) &&
    is.null(entry[["dc:identifier"]]) && is.null(entry[["prism:doi"]])
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
  year <- scopus_parse_year(date)
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

# Pull a character field from an entry, returning NA when absent. A field that
# arrives as an array of scalars (for example several authors under `dc:creator`,
# which jsonlite keeps as a list because the response is parsed with
# simplifyVector = FALSE) is collapsed into one semicolon-separated string rather
# than silently reduced to its first element. A field that is a list of objects
# is not a simple value and is reported as missing.
scopus_field <- function(entry, name) {
  if (!is.list(entry) || is.null(entry[[name]])) {
    return(NA_character_)
  }
  val <- entry[[name]]
  if (length(val) == 0L) {
    return(NA_character_)
  }
  if (is.list(val)) {
    scalar <- vapply(val, function(v) is.atomic(v) && length(v) == 1L, logical(1))
    if (!all(scalar)) {
      return(NA_character_)
    }
    val <- unlist(val, use.names = FALSE)
  }
  if (!is.atomic(val)) {
    return(NA_character_)
  }
  paste(as.character(val), collapse = "; ")
}

# The publication year is the leading four-digit run of `prism:coverDate`, and is
# NA when the date is absent or does not begin with four digits.
scopus_parse_year <- function(date) {
  if (length(date) != 1L || is.na(date)) {
    return(NA_integer_)
  }
  m <- regmatches(date, regexpr("^[0-9]{4}", date))
  if (length(m) == 0L || !nzchar(m)) NA_integer_ else as.integer(m)
}

#' @export
print.scopus_records <- function(x, ...) {
  n <- nrow(x)
  total <- attr(x, "total_results")
  header <- sprintf("<scopus_records> %d record%s", n, if (n == 1L) "" else "s")
  if (!is.null(total) && length(total) == 1L && !is.na(total) && total > n) {
    header <- sprintf("%s of %s matching", header, format(total, big.mark = ","))
  }
  cli::cli_text("{header}")

  # When the query is the same for every row, lift it into the header and hide
  # the column to keep the table readable.
  body <- x
  q <- unique(x$query)
  if (length(q) == 1L && !is.na(q)) {
    cli::cli_text("query: {.val {q}}")
    body <- x[setdiff(names(x), "query")]
  }
  print(tibble::as_tibble(body), ...)
  invisible(x)
}
