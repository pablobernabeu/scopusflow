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
#'   objects, a data frame already in the schema below, which is coerced to it
#'   (a set read back with [read_scopus_records()] or `read.csv()`, a tibble
#'   copy, a subset built elsewhere), or an existing `scopus_records` object,
#'   which is returned unchanged. A data frame carrying neither `doi` nor
#'   `title` is not a record set, and is refused.
#' @param query Optional character scalar recording the query that produced the
#'   entries, kept in the `query` column for provenance. `NULL` or `NA` records
#'   none.
#' @param view Optional character scalar naming the Search API view the entries
#'   came from. Pass `"COMPLETE"` to add an `authkeywords` column (see below);
#'   any other value, including the default `NULL`, reproduces the original
#'   columns exactly, so existing callers that never mention `view` see no
#'   change at all. [scopus_fetch()] and [scopus_fetch_plan()] pass this through
#'   automatically.
#' @return A tibble of class `scopus_records` with the columns
#'   `entry_number` (integer), `scopus_id` (character), `doi` (character),
#'   `title` (character), `authors` (character, the creator names joined with
#'   `"; "` when several are listed), `year` (integer, the leading four digits of
#'   the cover date), `date` (character, the ISO cover date), `publication`
#'   (character, the source title), `citations` (integer) and `query`
#'   (character). A missing field becomes `NA`, and an empty result set yields a
#'   zero-row tibble with the same columns. When `view = "COMPLETE"`, an
#'   `authkeywords` column is added: the author-supplied keywords the 'Scopus'
#'   Search API returns under that view, as a single string in 'Scopus'
#'   own `" | "`-delimited form (`NA` when the document has none, or when the
#'   API omits the field for a given key's entitlement; see *Details*).
#' @details
#' The 'Scopus' API signals an empty result set with a single sentinel entry that
#' carries an `error` field and no identifier. This is detected and turned into a
#' zero-row result, with no spurious record in it, while a genuine record that also
#' carries a per-entry `error` annotation is kept.
#'
#' A data frame already in this schema is coerced rather than read as a list of
#' entries, so a set that has lost its class along the way, one read back with
#' `read.csv()`, a tibble copy, a subset built elsewhere, can be handed
#' straight to the functions that require the class. Such a frame keeps the
#' columns it already carries, so `view` bears on entry lists only. A data
#' frame carrying neither `doi` nor `title` is not a record set, and is
#' refused.
#'
#' Author keywords are only ever present under `view = "COMPLETE"`; the
#' `STANDARD` view (the default throughout the package) never includes them,
#' and `authkeywords` is not added to the output at all in that case, so
#' existing code that inspects the column names of a `STANDARD`-view result is
#' unaffected. Even under `COMPLETE` view, some 'Scopus' API keys do not return
#' populated author keywords (this was observed directly against a live,
#' otherwise fully-entitled key during development, on documents that do carry
#' author keywords in 'Scopus' itself); if your own keywords come back all
#' `NA`, the field is most likely gated by your account's entitlement rather
#' than genuinely absent, and is worth raising with your 'Scopus'/Elsevier
#' account contact.
#' @examples
#' # An entry in the shape the Search API returns it. The fields are those of
#' # a real article, taken from the bundled `example_records`, which stands in
#' # for a harvest because 'Scopus' records may not be redistributed. It
#' # carries no 'Scopus' identifier, so `dc:identifier` is absent and
#' # `scopus_id` comes back NA, as it does for any unidentified record.
#' raw <- list(entry = list(
#'   list(
#'     `prism:doi` = "10.1021/am509065d",
#'     `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
#'     `dc:creator` = "Zhiwei Peng",
#'     `prism:publicationName` = "ACS Applied Materials & Interfaces",
#'     `prism:coverDate` = "2015-01-13",
#'     `citedby-count` = "469"
#'   )
#' ))
#' scopus_records(raw, query = "TITLE-ABS-KEY(graphene supercapacitor)")
#'
#' # Under COMPLETE view an entry may also carry author keywords, which the
#' # Search API returns in its own " | "-delimited form. The bundled corpus
#' # holds no keywords, so the ones below are illustrative.
#' raw_complete <- list(entry = list(
#'   list(
#'     `prism:doi` = "10.1021/am509065d",
#'     `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
#'     authkeywords = "graphene | supercapacitor | energy storage"
#'   )
#' ))
#' scopus_records(raw_complete, view = "COMPLETE")
#'
#' # A plain data frame in this schema is coerced, so a set that lost its class
#' # on the way through another tool can be used with the rest of the package.
#' scopus_records(as.data.frame(example_records)[1:2, c("doi", "title", "year")])
#'
#' # An object already in this schema is returned unchanged.
#' identical(scopus_records(example_records), example_records)
#' @export
scopus_records <- function(x, query = NA_character_, view = NULL) {
  if (is_scopus_records(x)) {
    return(x)
  }
  scopus_check_query_label(query)
  if (is.data.frame(x)) {
    return(scopus_records_from_frame(x, query))
  }
  entries <- scopus_entries(x)
  cols <- scopus_records_columns()

  if (length(entries) == 0L) {
    return(new_scopus_records(cols, view = view))
  }

  # Column by column, rather than a one-row data frame per entry bound
  # together: a cursor-paged harvest normalises tens of thousands of entries,
  # and building and binding that many data frames dominated the retrieval once
  # the network was done.
  tibble::new_tibble(
    scopus_entry_columns(entries, query, view),
    nrow = length(entries),
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

# A data frame already in the schema is a record set that has lost its class: a
# frame read with read.csv(), an as_tibble() copy, a subset built with dplyr.
# A data frame is also a list of columns, so scopus_entries() would take it for
# a list of entries and return one all-NA row per column, which looks like a
# result and is not one.
scopus_records_from_frame <- function(x, query, call = rlang::caller_env()) {
  if (!any(c("doi", "title") %in% names(x))) {
    rlang::abort(
      paste0("A data frame must already be in the record schema. Neither ",
             "`doi` nor `title` is present."),
      class = c("scopus_error_bad_input", "scopus_error"),
      call = call
    )
  }
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (is.null(x[["query"]])) {
    x$query <- query %||% NA_character_
  }
  scopus_coerce_records(x)
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
      class = c("scopus_error_bad_input", "scopus_error")
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

# Build a zero/typed tibble of class scopus_records. `authkeywords` is added
# only for view = "COMPLETE", so a STANDARD-view (or view-less) empty result
# keeps exactly the historical column set.
new_scopus_records <- function(cols, view = NULL) {
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
  if (identical(view, "COMPLETE")) {
    proto$authkeywords <- character()
    cols <- union(cols, "authkeywords")
  }
  tibble::new_tibble(proto[cols], nrow = 0L, class = "scopus_records")
}

# The columns of a normalised set, each pulled across every entry at once.
# `authkeywords` is added only for view = "COMPLETE" (see scopus_records());
# other views, and the default view = NULL, reproduce the original column set
# exactly.
scopus_entry_columns <- function(entries, query, view = NULL) {
  column <- function(name) {
    vapply(entries, scopus_field, character(1), name = name, USE.NAMES = FALSE)
  }
  date <- column("prism:coverDate")
  out <- list(
    entry_number = seq_along(entries),
    scopus_id = sub("^SCOPUS_ID:", "", column("dc:identifier")),
    doi = column("prism:doi"),
    title = column("dc:title"),
    authors = column("dc:creator"),
    year = vapply(date, scopus_parse_year, integer(1), USE.NAMES = FALSE),
    date = date,
    publication = column("prism:publicationName"),
    citations = suppressWarnings(as.integer(column("citedby-count"))),
    query = rep_len(as.character(query %||% NA_character_), length(entries))
  )
  if (identical(view, "COMPLETE")) {
    out$authkeywords <- column("authkeywords")
  }
  out
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
  scopus_print_line("{header}")

  # Dating the harvest matters here more than in most print methods: `citations`
  # is a snapshot, so two sets are only comparable if each says when it was
  # taken. Absent on the bundled corpus and on anything read back from CSV.
  retrieved <- attr(x, "retrieved_at")
  if (!is.null(retrieved) && length(retrieved) >= 1L) {
    stamp <- format(min(retrieved), "%Y-%m-%d %H:%M:%S %Z")
    version <- attr(x, "scopusflow_version")
    if (!is.null(version)) {
      stamp <- sprintf("%s (scopusflow %s)", stamp, paste(version, collapse = ", "))
    }
    scopus_print_line("retrieved: {stamp}")
  }

  # When the query is the same for every row, lift it into the header and hide
  # the column to keep the table readable.
  body <- x
  q <- unique(x$query)
  if (length(q) == 1L && !is.na(q)) {
    scopus_print_line("query: {.val {q}}")
    body <- x[setdiff(names(x), "query")]
  }
  print(tibble::as_tibble(body), ...)
  invisible(x)
}
