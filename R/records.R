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
#' @param view Optional character scalar naming the Search API view the entries
#'   came from. Pass `"COMPLETE"` to read `authors` from the author list that
#'   view carries and to add an `authkeywords` column (see below). Any other
#'   value, including the default `NULL`, reads the first author and reproduces
#'   the original columns exactly, so existing callers that never mention
#'   `view` see no change at all. [scopus_fetch()] and [scopus_fetch_plan()]
#'   pass this through automatically.
#' @param fields `"core"` (the default) builds the columns listed under
#'   *Value*, exactly as before. `"extended"` also keeps the document type,
#'   source type, volume, issue, pages, ISSN, PubMed identifier and open-access
#'   status the Search API sends with every record, and under
#'   `view = "COMPLETE"` the abstract, at no extra quota (see *Extended
#'   fields*). [scopus_fetch()] and [scopus_fetch_plan()] pass this through.
#' @return A tibble of class `scopus_records` with the columns
#'   `entry_number` (integer), `scopus_id` (character), `doi` (character),
#'   `title` (character), `authors` (character, the author list under
#'   `view = "COMPLETE"` and the first author otherwise, as *Details* explains),
#'   `year` (integer, the leading four digits of the cover date), `date`
#'   (character, the ISO cover date), `publication` (character, the source
#'   title), `citations` (integer) and `query` (character). A missing field
#'   becomes `NA`, and an empty result set yields a
#'   zero-row tibble with the same columns. When `view = "COMPLETE"`, an
#'   `authkeywords` column is added: the author-supplied keywords the 'Scopus'
#'   Search API returns under that view, as a single string in 'Scopus'
#'   own `" | "`-delimited form (`NA` when the document has none, or when the
#'   API omits the field for a given key's entitlement; see *Details*).
#'   With `fields = "extended"`, the character columns `doc_type`,
#'   `doc_type_description`, `source_type`, `volume`, `issue`, `pages`, `issn`
#'   and `pubmed_id` follow, then the integer `open_access` and, under
#'   `view = "COMPLETE"`, the character `abstract`. `doc_type` and
#'   `doc_type_description` hold the document-type code and name 'Scopus' gives
#'   the record, such as `"ar"` and `"Article"`, and `source_type` holds the
#'   source type, such as `"Journal"`. `issn` is the print ISSN as 'Scopus'
#'   writes it, without the hyphen, kept as text so its leading zeros survive.
#'   `open_access` is the open-access status code (see *Extended fields*).
#' @details
#' The 'Scopus' API signals an empty result set with a single sentinel entry that
#' carries an `error` field and no identifier. This is detected and turned into a
#' zero-row result, with no spurious record in it, while a genuine record that also
#' carries a per-entry `error` annotation is kept.
#'
#' What `authors` holds depends on the view. The Search API's `dc:creator`
#' field is the first author alone under either view, in the indexed form
#' 'Scopus' uses (`"Zhang F."`). The author list arrives only under
#' `view = "COMPLETE"`, as the `author` objects Elsevier's views table lists
#' for that view alone. A `STANDARD` record therefore names its first author,
#' and a tally of `STANDARD` authors counts first authorships. A harvest
#' records its view in the `view` attribute (see [scopus_fetch()]), and
#' [scopus_top()] and [as_bibliometrix()] say once per session that a set
#' retrieved under `STANDARD` names first authors only. Under `COMPLETE`, each
#' author is written as `"Surname, Given"`, as the surname alone when the given
#' name is missing or empty, or as the indexed name when the surname is
#' missing. Exact duplicates are dropped. The API lists at most 100 authors per
#' record, and its `author-count` field gives the total. A record whose list
#' names nobody falls back to `dc:creator`. The Python twin builds the same
#' string from pybliometrics' `author_names` in the common case, and parts
#' company at two edges. Where an author object lacks a `surname` or
#' `given-name` key, pybliometrics builds no list, so that twin keeps the first
#' author while this one lists every author. Where a surname is null or empty,
#' pybliometrics writes the given name after a bare comma, and this package uses
#' the indexed name.
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
#' @section Extended fields:
#' Elsevier's [Search views table](https://dev.elsevier.com/sc_search_views.html)
#' lists every field `fields = "extended"` reads under both views, except the
#' abstract (`dc:description`), which only the `COMPLETE` view carries. They
#' arrive in the responses a retrieval already pays for, so they cost no extra
#' quota. A `COMPLETE` harvest returns up to 25 abstracts with each request,
#' while [scopus_abstract()] spends one request per record from the separate
#' Abstract Retrieval quota.
#'
#' `doc_type` holds the code the `DOCTYPE()` search field takes. Elsevier's
#' [search tips](https://dev.elsevier.com/sc_search_tips.html) list the codes
#' with their names: `ar` for an article, `re` a review, `cp` a conference
#' paper, `er` an erratum and others. A retracted item carries `tb`, which that
#' list leaves out. The 'Scopus' Content Coverage Guide (section 3.1) defines
#' an erratum as a report of an error, correction or retraction of a previously
#' published paper, so `er` covers retraction notices as well as corrections.
#' The guide gives an article the type Retracted once a retraction notice for
#' it is published. These codes are the labels 'Scopus' assigns, and they do
#' not screen a set for retractions, since 'Scopus' does not label every
#' retracted item (Ortega and Delgado-Quirós, 2024). Check a set against the
#' [Retraction Watch database](https://www.crossref.org/documentation/retrieve-metadata/retraction-watch/),
#' which Crossref makes openly available, before relying on it.
#' [summary()][summary.scopus_records()] reports how many records 'Scopus'
#' labels `er` and `tb`. Errata can also be left out of the search itself with
#' `AND NOT DOCTYPE(er)`, joined by [scopus_query()], which brackets the rest of
#' the query first, since 'Scopus' applies AND NOT last (see *Examples*).
#'
#' `open_access` holds the code 'Scopus' sends in its `openaccess` field.
#' Elsevier's Scopus APIs Getting Started Guide (section 17) illustrates its
#' values with 0 for a record that is not open access, 1 for gold and 2 for
#' green. The column therefore holds a status code, which can take values
#' other than 0 and 1.
#' @references
#' Elsevier. (2023). *Scopus APIs getting started guide* (Version 1).
#' <https://dev.elsevier.com/guides/Scopus%20API%20Guide_V1_20230907.pdf>
#'
#' Elsevier. (2023). *Scopus content coverage guide*.
#' <https://supportcontent.elsevier.com/Support%20Hub/Scopus/Scopus_ContentCoverage_Guide_WEB.pdf>
#'
#' Ortega, J. L., & Delgado-Quirós, L. (2024). The indexation of retracted
#' literature in seven principal scholarly databases: A coverage comparison of
#' Dimensions, OpenAlex, PubMed, Scilit, Scopus, The Lens and Web of Science.
#' *Scientometrics*, *129*(7), 3769–3785. \doi{10.1007/s11192-024-05034-y}
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
#' scopus_records(raw, query = 'TITLE-ABS-KEY("graphene supercapacitor")')
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
#' # fields = "extended" keeps the fields both views send beyond the core ones.
#' # The volume, issue, pages and print ISSN below are the article's own. The
#' # document type and source type are illustrative, since the bundled corpus
#' # came from OpenAlex and records no 'Scopus' labels.
#' raw_extended <- list(entry = list(
#'   list(
#'     `prism:doi` = "10.1021/am509065d",
#'     `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
#'     subtype = "ar",
#'     subtypeDescription = "Article",
#'     `prism:aggregationType` = "Journal",
#'     `prism:volume` = "7",
#'     `prism:issueIdentifier` = "5",
#'     `prism:pageRange` = "3414-3419",
#'     `prism:issn` = "19448244"
#'   )
#' ))
#' extended <- scopus_records(raw_extended, fields = "extended")
#' as.data.frame(extended)[, c("doc_type", "volume", "issue", "pages", "issn")]
#'
#' # Errata can be left out of the search itself. scopus_query() brackets the
#' # rest of the query, since 'Scopus' applies AND NOT last.
#' scopus_query(
#'   scopus_query("graphene", "graphite", .op = "OR", .field = "TITLE-ABS-KEY"),
#'   "DOCTYPE(er)", .op = "AND NOT"
#' )
#'
#' # An object already in this schema is returned unchanged.
#' identical(scopus_records(example_records), example_records)
#' @export
scopus_records <- function(x, query = NA_character_, view = NULL,
                           fields = c("core", "extended")) {
  fields <- scopus_match_arg(fields, c("core", "extended"))
  if (is_scopus_records(x)) {
    return(x)
  }
  entries <- scopus_entries(x)
  cols <- scopus_records_columns()

  if (length(entries) == 0L) {
    return(new_scopus_records(cols, view = view, fields = fields))
  }

  rows <- lapply(
    seq_along(entries),
    function(i) scopus_entry_to_row(entries[[i]], i, query, view, fields)
  )
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
    scopus_abort_bad_input(
      "Cannot extract 'Scopus' entries from `x`. Provide a list or a `search-results` object."
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

# The columns fields = "extended" adds, in order, as typed empty vectors. Every
# one but `abstract` comes in both views, and `abstract` follows them under
# COMPLETE, as `authkeywords` follows the core columns. The Python twin's
# EXTENDED_COLUMNS lists the same names, and both suites hold the two to
# tests/testthat/fixtures/extended-entry.json.
scopus_extended_proto <- function(view = NULL) {
  proto <- list(
    doc_type = character(),
    doc_type_description = character(),
    source_type = character(),
    volume = character(),
    issue = character(),
    pages = character(),
    issn = character(),
    pubmed_id = character(),
    open_access = integer()
  )
  if (identical(view, "COMPLETE")) {
    proto$abstract <- character()
  }
  proto
}

scopus_extended_columns <- function(view = NULL) {
  names(scopus_extended_proto(view))
}

# The Search API field each extended text column is read from. `open_access`
# comes from `openaccess` and `abstract` from `dc:description`, both handled
# apart, the first because it is a number and the second because only COMPLETE
# carries it.
scopus_extended_sources <- c(
  doc_type = "subtype",
  doc_type_description = "subtypeDescription",
  source_type = "prism:aggregationType",
  volume = "prism:volume",
  issue = "prism:issueIdentifier",
  pages = "prism:pageRange",
  issn = "prism:issn",
  pubmed_id = "pubmed-id"
)

# Build a zero/typed tibble of class scopus_records. `authkeywords` is added
# only for view = "COMPLETE", and the extended columns only for fields =
# "extended", so a core STANDARD-view (or view-less) empty result keeps exactly
# the historical column set.
new_scopus_records <- function(cols, view = NULL, fields = "core") {
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
  if (identical(fields, "extended")) {
    extended <- scopus_extended_proto(view)
    proto <- c(proto, extended)
    cols <- union(cols, names(extended))
  }
  tibble::new_tibble(proto[cols], nrow = 0L, class = "scopus_records")
}

# Convert a single entry to a one-row data frame. `authkeywords` is added only
# for view = "COMPLETE" and the extended columns only for fields = "extended"
# (see scopus_records()). The defaults, view = NULL and fields = "core",
# reproduce the original column set exactly.
scopus_entry_to_row <- function(entry, i, query, view = NULL, fields = "core") {
  id_raw <- scopus_field(entry, "dc:identifier")
  scopus_id <- if (is.na(id_raw)) NA_character_ else sub("^SCOPUS_ID:", "", id_raw)
  date <- scopus_field(entry, "prism:coverDate")
  year <- scopus_parse_year(date)
  citations <- scopus_field(entry, "citedby-count")
  citations <- if (is.na(citations)) NA_integer_ else suppressWarnings(as.integer(citations))

  # dc:creator is the first author under either view. The author list is the
  # `author` array, which only the COMPLETE view carries.
  authors <- if (identical(view, "COMPLETE") && is.list(entry)) {
    scopus_complete_authors(entry[["author"]])
  } else {
    NA_character_
  }
  if (is.na(authors)) authors <- scopus_field(entry, "dc:creator")

  row <- data.frame(
    entry_number = as.integer(i),
    scopus_id = scopus_id,
    doi = scopus_field(entry, "prism:doi"),
    title = scopus_field(entry, "dc:title"),
    authors = authors,
    year = year,
    date = date,
    publication = scopus_field(entry, "prism:publicationName"),
    citations = citations,
    query = query %||% NA_character_,
    stringsAsFactors = FALSE
  )
  if (identical(view, "COMPLETE")) {
    row$authkeywords <- scopus_field(entry, "authkeywords")
  }
  if (identical(fields, "extended")) {
    for (col in names(scopus_extended_sources)) {
      row[[col]] <- scopus_field(entry, scopus_extended_sources[[col]])
    }
    # Sent as text ("0", "1", "2"), and read as a whole number, as
    # pybliometrics reads it, so the twins hold the same code.
    open_access <- scopus_field(entry, "openaccess")
    row$open_access <- if (is.na(open_access)) {
      NA_integer_
    } else {
      suppressWarnings(as.integer(open_access))
    }
    if (identical(view, "COMPLETE")) {
      row$abstract <- scopus_field(entry, "dc:description")
    }
  }
  row
}

# The author list of one COMPLETE-view entry, as "Surname, Given" names joined
# by "; ", or NA when no author can be named. Exact copies are dropped, as
# pybliometrics' deduplicate() drops them, so the Python twin builds the same
# string from the same entry. A lone author sent as a bare object, which is how
# Elsevier's JSON sends a one-item array, is wrapped by scopus_listify().
scopus_complete_authors <- function(authors) {
  authors <- scopus_listify(authors)
  authors <- authors[!duplicated(authors)]
  listed <- vapply(authors, scopus_complete_author_name, character(1),
                   USE.NAMES = FALSE)
  listed <- listed[!is.na(listed)]
  if (length(listed) == 0L) NA_character_ else paste(listed, collapse = "; ")
}

# One author's name: the surname alone when the given name is missing or
# blank, and the indexed form (`authname`, "Zhang F.") when the surname is. The
# joined name is trimmed as a whole, as the Python twin trims the
# "Surname, Given" string pybliometrics writes, so the twins agree byte for byte
# even on a name padded with white space.
scopus_complete_author_name <- function(author) {
  part <- function(name) {
    value <- if (is.list(author)) author[[name]] else NULL
    if (length(value) != 1L || !is.atomic(value) || is.na(value)) {
      return(NA_character_)
    }
    value <- as.character(value)
    if (nzchar(scopus_trim(value))) value else NA_character_
  }
  surname <- part("surname")
  if (is.na(surname)) {
    authname <- part("authname")
    return(if (is.na(authname)) NA_character_ else scopus_trim(authname))
  }
  given <- part("given-name")
  if (is.na(given)) scopus_trim(surname) else scopus_trim(paste0(surname, ", ", given))
}

# Say, once per session, that a set retrieved under STANDARD names first
# authors only. It is raised where those names would otherwise be read as every
# author: scopus_top(by = "author") and as_bibliometrix(). A set that records
# no view, such as the bundled corpus or a set read back from CSV, cannot be
# judged and passes in silence. The text is shared with the Python twin through
# tests/testthat/fixtures/complete-authors.json.
scopus_warn_first_author_only <- function(x) {
  if (!identical(attr(x, "view"), "STANDARD")) {
    return(invisible(NULL))
  }
  rlang::warn(
    paste0(
      "These records were retrieved under the STANDARD view, whose dc:creator ",
      "field holds the first author only, so each record names one author and ",
      "an author tally counts first authorships. Retrieve with view = ",
      "\"COMPLETE\" for the author list (up to 100 authors per record)."
    ),
    class = "scopus_warning_first_author_only",
    .frequency = "once",
    .frequency_id = "scopusflow_first_author_only"
  )
}

# Pull a character field from an entry, returning NA when absent. A field that
# arrives as an array of scalars, which jsonlite keeps as a list because the
# response is parsed with simplifyVector = FALSE, is collapsed into one
# semicolon-separated string rather than silently reduced to its first
# element. None of the fields read here is sent that way. A field that is a list
# of objects, such as the COMPLETE view's `author` array, is not a simple value
# and is reported as missing.
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
