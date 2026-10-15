#' Assemble a minimal, cross-tool corpus with keywords and references
#'
#' Takes a [scopus_records()] tibble, such as the output of [scopus_fetch()] or
#' [scopus_fetch_plan()], and enriches it with keywords (the author keywords by
#' default, or the index keywords 'Scopus' assigns) and structured
#' references via Abstract Retrieval, returning a minimal, uniform shape close
#' to what OpenAlex's `works` API already returns: an `id`, `title`, `year`,
#' `keywords` (a list-column of character vectors) and `references` (a
#' list-column of data frames). This is meant for downstream tools that want to
#' consume 'Scopus' output without writing their own parsing layer, for example
#' for keyword co-occurrence or citation-network analysis. It does not replace
#' [as_bibliometrix()], which keeps its own established field-mapping
#' convention for users who want bibliometrix's tag names instead.
#'
#' @param records A [scopus_records()] tibble, or any data frame with `doi`,
#'   `title` and `year` columns in the same shape.
#' @param by Either `"doi"` or `"scopus_id"`, the kind of identifier in
#'   `records` to look records up by (see [scopus_abstract()]).
#' @param view Either `"FULL"` (the default) or `"REF"`, passed to
#'   [scopus_abstract()]. `"FULL"` returns a document's whole bibliography in
#'   one request. `"REF"` serves it about 40 references per request, which
#'   [scopus_abstract()] follows page by page, so a document with *N*
#'   references costs `ceiling(N / 40)` requests (see its documentation for
#'   the details and for the entitlement each view needs). The `REF` response
#'   also carries no keywords of either kind, so under that view only the
#'   references are requested and `keywords` is empty for every record.
#' @param cache_dir,resume As in [scopus_abstract()]: an optional directory
#'   for per-identifier cache files, and whether an existing one is reused.
#'   Worth setting for anything beyond a handful of records, since this
#'   performs one Abstract Retrieval request per record, against its own,
#'   smaller weekly quota.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @param keywords Which keywords fill the `keywords` column: `"author"` (the
#'   default) for the author keywords, `"index"` for the index keywords
#'   'Scopus' assigns, or `"both"` for the author keywords followed by each
#'   index keyword not already among them. The match is on the exact text, so
#'   a term that differs only in case appears twice. `"index"` and `"both"`
#'   need `view = "FULL"`, since the `REF` response carries no keywords of
#'   either kind, and raise a `scopus_error_bad_input` error under `"REF"`
#'   before any request. Index keywords and author keywords give different
#'   co-occurrence results, and the *Details* of [scopus_abstract()] describe
#'   how each is chosen and the entitlement each depends on. Either choice
#'   costs the same request per record.
#' @return A tibble with columns `id` (the identifier `records` was looked up
#'   by), `scopus_id` (the document's own 'Scopus' identifier, as Abstract
#'   Retrieval gives it, or the `scopus_id` of `records` where the lookup
#'   failed or the `REF` response omitted it, and `NA` when neither has one),
#'   `title`, `year`, `keywords` (a list-column: a character vector of
#'   the document's keywords of the kind `keywords` names, split out of
#'   [scopus_abstract()]'s joined `authkeywords` and `idxterms` strings, empty
#'   when the document has none, the field is unavailable or `view = "REF"`)
#'   and `references` (a list-column: each entry is the
#'   `references` data frame [scopus_abstract()] returns for that document,
#'   with one row per cited work). A record in `records` whose identifier is
#'   `NA` is dropped, with a warning naming how many.
#'
#'   The number of Abstract Retrieval requests made and the most recently
#'   parsed quota are attached as the `n_requests` and `quota` attributes, as
#'   [scopus_abstract()] attaches them. Three more attributes carry what
#'   [write_scopus_corpus()] records of the corpus's provenance. `query` holds
#'   the field-wrapped search expression of each cell of the records' plan,
#'   or, for records without a plan, the distinct values of their own `query`
#'   column. `retrieved_at` is when the search that found the records ran, and
#'   `keywords` is the kind of keyword chosen. `query` and `retrieved_at` are
#'   absent when `records` carries neither.
#' @section API access:
#' This performs one Abstract Retrieval request per usable record, or one per
#' page of references under `view = "REF"`, on top of whatever retrieved
#' `records` in the first place; see [scopus_abstract()]'s
#' *API access* section for the entitlement `view = "FULL"`/`"REF"` needs and
#' how a 403 is handled.
#' @seealso [scopus_abstract()], [as_bibliometrix()], and
#'   [write_scopus_corpus()] to write the corpus for theoryforge.
#' @examplesIf scopusflow::scopus_has_key()
#' # Costs one Abstract Retrieval request per record, against a smaller,
#' # separate weekly quota from Search; see the API access section above.
#' recs <- scopus_fetch("DOI(10.1038/natrevmats.2016.33)", max_results = 1)
#' corpus <- scopus_corpus(recs)
#' corpus$keywords[[1]]
#' corpus$references[[1]]
#' @examples
#' # The offline companion, which needs no key: one row per document, with
#' # keywords and references as list-columns. The identifiers, titles and
#' # years are records of the bundled corpus of real articles, which stands in
#' # for a harvest because 'Scopus' records may not be redistributed. It holds
#' # no keywords, bibliographies or 'Scopus' identifiers, so the keywords and
#' # references are illustrative and the identifiers are left NA.
#' docs <- example_records[order(-example_records$citations), ][1:2, ]
#' corpus <- tibble::tibble(
#'   id = docs$doi,
#'   scopus_id = NA_character_,
#'   title = docs$title,
#'   year = docs$year,
#'   keywords = list(
#'     c("graphene", "supercapacitor", "energy storage"),
#'     c("laser-induced graphene", "flexible electronics")
#'   ),
#'   references = list(
#'     tibble::tibble(
#'       position = c("1", "2"),
#'       id = NA_character_,
#'       doi = example_records$doi[3:4],
#'       title = example_records$title[3:4],
#'       authors = example_records$authors[3:4],
#'       source = example_records$publication[3:4],
#'       year = example_records$year[3:4],
#'       citedbycount = example_records$citations[3:4]
#'     ),
#'     tibble::tibble()
#'   )
#' )
#' corpus
#' corpus$keywords[[1]]
#' corpus$references[[1]]
#' @export
scopus_corpus <- function(records,
                          by = c("doi", "scopus_id"),
                          view = c("FULL", "REF"),
                          cache_dir = NULL,
                          resume = TRUE,
                          api_key = NULL,
                          inst_token = NULL,
                          verbose = FALSE,
                          keywords = c("author", "index", "both")) {
  by <- scopus_match_arg(by, c("doi", "scopus_id"))
  view <- scopus_match_arg(view, c("FULL", "REF"))
  keywords <- scopus_match_arg(keywords, c("author", "index", "both"))
  scopus_check_flag(resume, "resume")
  scopus_check_flag(verbose, "verbose")
  # Checked here, so that the error names this function's own argument, where
  # scopus_abstract() would name the `include` value it was passed.
  if (keywords != "author" && view != "FULL") {
    scopus_abort_bad_input(
      sprintf(
        paste0("`keywords = \"%s\"` needs `view = \"FULL\"`, since the REF ",
               "response carries no index keywords."),
        keywords
      )
    )
  }
  required <- c(by, "title", "year")
  if (!is.data.frame(records) || !all(required %in% names(records))) {
    scopus_abort_bad_input(
      sprintf(
        "`records` must be a data frame with %s columns (as scopus_fetch()/scopus_fetch_plan() return).",
        paste(sprintf('"%s"', required), collapse = ", ")
      )
    )
  }

  # The search behind the records, read before they are subset, which need not
  # keep their attributes: the field-wrapped query each cell sent, as the
  # search record states it, and when the search ran.
  # A tibble warns when `$` names a column it lacks, so records without a
  # `query` column are not passed on.
  expression <- scopus_report_expression(
    if ("query" %in% names(records)) records else NULL,
    attr(records, "plan")
  )
  retrieved_at <- attr(records, "retrieved_at")

  ids <- records[[by]]
  keep <- !is.na(ids)
  n_dropped <- sum(!keep)
  if (n_dropped > 0L) {
    rlang::warn(
      sprintf(
        "Dropped %d record%s with no usable %s.",
        n_dropped, if (n_dropped == 1L) "" else "s", by
      ),
      class = "scopus_warning_dropped_records"
    )
  }
  if (!any(keep)) {
    scopus_abort_bad_input("`records` has no usable identifiers to look up.")
  }
  records <- records[keep, , drop = FALSE]

  # The REF response carries no author keywords (scopus_abstract() rejects the
  # combination), so under that view only the references are requested and
  # every record's keywords come back empty. Under FULL, only the kinds of
  # keyword asked for are included, which keeps the checkpoints of a default
  # corpus named as before.
  include <- "references"
  if (identical(view, "FULL")) {
    if (keywords %in% c("author", "both")) include <- c(include, "keywords")
    if (keywords %in% c("index", "both")) include <- c(include, "index_terms")
  }
  ab <- scopus_abstract(
    ids[keep], by = by, view = view, include = include,
    cache_dir = cache_dir, resume = resume,
    api_key = api_key, inst_token = inst_token, verbose = verbose
  )

  author <- scopus_split_terms(ab[["authkeywords"]], nrow(ab))
  index <- scopus_split_terms(ab[["idxterms"]], nrow(ab))
  terms <- switch(keywords,
    author = author,
    index = index,
    # unique() keeps the first of each repeated text, so the author keywords
    # come first and an index keyword they already hold is not repeated.
    both = Map(function(a, i) unique(c(a, i)), author, index)
  )

  # The document's own identifier, from Abstract Retrieval. A failed lookup,
  # or a REF response, which carries no core metadata, leaves it NA there,
  # and the records' own identifier fills the gap where they carry one.
  scopus_id <- ab$scopus_id
  if ("scopus_id" %in% names(records)) {
    fallback <- scopus_tf_text(records$scopus_id)
    scopus_id[is.na(scopus_id)] <- fallback[is.na(scopus_id)]
  }

  out <- tibble::tibble(
    id = ab$id,
    scopus_id = scopus_id,
    title = records$title,
    year = records$year,
    keywords = unname(terms),
    references = ab$references
  )
  # A fresh tibble carries none of `ab`'s attributes, so the call that spends
  # the most quota reported none of it, where the Python twin kept both.
  attr(out, "n_requests") <- attr(ab, "n_requests")
  attr(out, "quota") <- attr(ab, "quota")
  # The provenance write_scopus_corpus() records. An expression the records
  # do not hold is left out, as is a time a set without provenance lacks.
  if (!anyNA(expression)) attr(out, "query") <- expression
  attr(out, "retrieved_at") <- retrieved_at
  attr(out, "keywords") <- keywords
  out
}

# Split a joined keyword column ("; "-separated, see scopus_abstract()) into
# one character vector per row, empty for NA or for a column the request did
# not include.
scopus_split_terms <- function(joined, n) {
  joined <- joined %||% rep(NA_character_, n)
  lapply(joined, function(x) {
    if (length(x) != 1L || is.na(x)) character() else trimws(strsplit(x, ";", fixed = TRUE)[[1]])
  })
}

#' Write a corpus in theoryforge's corpus schema
#'
#' Turns a [scopus_corpus()] result into the literature corpus that
#' theoryforge's `tf_read_corpus()`, `tf_litmap()` and `tf_landscape()` read,
#' following the corpus schema theoryforge publishes
#' (`schema/corpus.schema.json` in its repository). `as_theoryforge_corpus()`
#' returns the document as a list, and `write_scopus_corpus()` writes it to a
#' JSON file. Neither needs theoryforge installed, and neither makes a request.
#'
#' theoryforge compares references as exact strings, so the writer gives each
#' cited work one key across the whole corpus, its 'Scopus' identifier, as
#' `scopus:<id>`. 'Scopus' gives a cited work's DOI in some bibliographies
#' only, and in different cases. A key built from the DOI wherever there is one
#' would therefore split one work into several nodes and lose the
#' co-citation edges between them. A reference that carries only a DOI takes
#' the 'Scopus' identifier that a document or reference
#' elsewhere in the corpus pairs with the same DOI, the documents' own
#' identifiers counting first. A DOI that nothing pairs with is keyed as
#' `doi:<doi>`, without its resolver prefix and with its ASCII letters
#' lower-cased, since DOIs are case-insensitive over ASCII (DOI Handbook,
#' section 2.4). A reference with neither is dropped, and a
#' `scopus_warning_dropped_references` warning says how many. Each document is
#' keyed the same way, from its `scopus_id` or else from an `id` that is a DOI
#' or a 'Scopus' identifier, so a citation of a document in the corpus and the
#' document itself share one key.
#'
#' Keywords are trimmed, lower-cased with [tolower()] and made unique, keeping
#' the first of each, and empty ones are dropped, so `"Graphene"` and
#' `"graphene "` count as one keyword. The Python twin lower-cases with
#' `str.lower()`. The two agree on the Latin, Greek and Cyrillic letters in
#' common use and differ on a few special cases, such as the Turkish capital I
#' with a dot and a capital sigma ending a word, which Python writes as a
#' final sigma. A missing year is written as `null`, and a missing title is
#' left out, since the schema admits the one and not the other.
#'
#' The document also carries a `provenance` object, which the schema admits
#' beside its own fields: `source` (`"Scopus via scopusflow <version>"`),
#' `query`, `retrieved_at` (in UTC, as `YYYY-MM-DDTHH:MM:SSZ`), `keywords`,
#' `n_records`, `n_references_dropped` and `n_records_without_keywords`.
#' `query`, `retrieved_at` and `keywords` come from the attributes
#' [scopus_corpus()] attaches, and are `null` when the corpus lacks them.
#' `query` is a string, or an array of strings when the records were searched
#' with several expressions. Author keywords can come back empty under some
#' entitlements (see [scopus_abstract()]), which leaves theoryforge's keyword
#' themes empty whatever the writer does, and `n_records_without_keywords`
#' shows when that happened.
#'
#' The file is UTF-8, with no escaping beyond what JSON requires, sorted keys,
#' no spaces between tokens and one line feed at the end, so the same corpus
#' gives the same bytes from either twin.
#'
#' @param corpus A [scopus_corpus()] result, or a data frame with the same
#'   `id`, `title`, `year`, `keywords` and `references` columns, where each
#'   `references` entry is a data frame with `id` and `doi` columns. A
#'   `scopus_id` column is used when present.
#' @param id A non-empty string naming the corpus, written as its top-level
#'   `id`. It is required, since a [scopus_corpus()] result carries no name of
#'   its own.
#' @param path The file to write, exactly as given. Parent directories are
#'   assumed to exist already.
#' @return `as_theoryforge_corpus()` returns the document as a list with the
#'   elements `id`, `provenance`, `records` and `schema_version` (`"1.0"`).
#'   `write_scopus_corpus()` returns the same list invisibly.
#' @seealso [scopus_corpus()], which builds the corpus.
#' @examples
#' # Two records of the bundled corpus of real articles, each citing the same
#' # two others. The keywords and the citations are illustrative, since the
#' # bundled records carry neither.
#' docs <- example_records[!is.na(example_records$doi), ][1:4, ]
#' cited <- tibble::tibble(id = NA_character_, doi = docs$doi[3:4])
#' corpus <- tibble::tibble(
#'   id = docs$doi[1:2],
#'   scopus_id = NA_character_,
#'   title = docs$title[1:2],
#'   year = docs$year[1:2],
#'   keywords = list(c("Graphene", "supercapacitor"), "graphene"),
#'   references = list(cited, cited)
#' )
#' doc <- as_theoryforge_corpus(corpus, id = "graphene-supercapacitors")
#' doc$records[[1]]$keywords
#' doc$records[[1]]$references
#'
#' # Written to a temporary file (never the working directory).
#' path <- tempfile(fileext = ".json")
#' write_scopus_corpus(corpus, path, id = "graphene-supercapacitors")
#' substr(readLines(path, encoding = "UTF-8"), 1, 160)
#' @rdname write_scopus_corpus
#' @export
as_theoryforge_corpus <- function(corpus, id) {
  if (missing(id) || !is.character(id) || length(id) != 1L || is.na(id) ||
      !nzchar(trimws(id))) {
    scopus_abort_bad_input(
      paste0("`id` must be a single non-empty string naming the corpus, since ",
             "a scopus_corpus() result carries no name of its own.")
    )
  }
  required <- c("id", "title", "year", "keywords", "references")
  if (!is.data.frame(corpus) || !all(required %in% names(corpus))) {
    scopus_abort_bad_input(
      sprintf(
        "`corpus` must be a data frame with %s columns (as scopus_corpus() returns).",
        paste(sprintf('"%s"', required), collapse = ", ")
      )
    )
  }
  n <- nrow(corpus)

  # Each document's own identifiers: its scopus_id, else an `id` that is a
  # 'Scopus' identifier (a corpus looked up by scopus_id), and an `id` that
  # is a DOI (a corpus looked up by DOI).
  ids <- scopus_tf_text(corpus$id)
  record_doi <- scopus_tf_doi(ids)
  record_doi[!grepl("^10\\.[0-9]+(\\.[0-9]+)*/.", record_doi)] <- NA_character_
  given <- if ("scopus_id" %in% names(corpus)) corpus$scopus_id else rep(NA_character_, n)
  record_sid <- scopus_tf_sid(given)
  from_id <- is.na(record_sid) & is.na(record_doi)
  record_sid[from_id] <- scopus_tf_sid(ids)[from_id]

  cited <- lapply(corpus$references, function(refs) {
    if (!is.data.frame(refs) || nrow(refs) == 0L) {
      return(list(sid = character(), doi = character()))
    }
    list(sid = scopus_tf_sid(refs[["id"]] %||% rep(NA, nrow(refs))),
         doi = scopus_tf_doi(refs[["doi"]] %||% rep(NA, nrow(refs))))
  })

  # Every document and reference carrying both says which identifier a DOI
  # belongs to. The first pair met wins, the documents' own coming first.
  pair_sid <- c(record_sid, unlist(lapply(cited, `[[`, "sid")))
  pair_doi <- c(record_doi, unlist(lapply(cited, `[[`, "doi")))
  both <- !is.na(pair_sid) & !is.na(pair_doi)
  pair_sid <- pair_sid[both]
  pair_doi <- pair_doi[both]
  first <- !duplicated(pair_doi)
  sid_of_doi <- stats::setNames(pair_sid[first], pair_doi[first])
  key <- function(sid, doi) {
    borrow <- is.na(sid) & !is.na(doi)
    sid[borrow] <- unname(sid_of_doi[doi[borrow]])
    out <- rep(NA_character_, length(sid))
    out[!is.na(doi)] <- paste0("doi:", doi[!is.na(doi)])
    out[!is.na(sid)] <- paste0("scopus:", sid[!is.na(sid)])
    out
  }

  record_key <- key(record_sid, record_doi)
  if (anyNA(record_key)) {
    unkeyed <- which(is.na(record_key))
    scopus_abort_bad_input(
      sprintf(
        paste0("%d record%s of `corpus` (row %s) carr%s neither a 'Scopus' ",
               "identifier nor a DOI to key on."),
        length(unkeyed), if (length(unkeyed) == 1L) "" else "s",
        paste(utils::head(unkeyed, 10L), collapse = ", "),
        if (length(unkeyed) == 1L) "ies" else "y"
      )
    )
  }

  dropped <- 0L
  records <- lapply(seq_len(n), function(i) {
    refs <- key(cited[[i]]$sid, cited[[i]]$doi)
    dropped <<- dropped + sum(is.na(refs))
    record <- list(
      id = record_key[[i]],
      keywords = I(scopus_tf_keywords(corpus$keywords[[i]])),
      references = I(unique(refs[!is.na(refs)]))
    )
    title <- corpus$title[[i]]
    if (is.character(title) && length(title) == 1L && !is.na(title) && nzchar(trimws(title))) {
      record$title <- trimws(title)
    }
    record["year"] <- list(scopus_tf_year(corpus$year[[i]]))
    record
  })
  if (dropped > 0L) {
    rlang::warn(
      sprintf(
        paste0("Dropped %d reference%s with neither a 'Scopus' identifier nor a ",
               "DOI, which no key can name."),
        dropped, if (dropped == 1L) "" else "s"
      ),
      class = "scopus_warning_dropped_references"
    )
  }

  query <- attr(corpus, "query")
  query <- if (is.character(query)) query[!is.na(query)] else character()
  kind <- attr(corpus, "keywords")
  kind <- if (is.character(kind) && length(kind) == 1L && !is.na(kind)) kind else NULL
  provenance <- list(
    keywords = kind,
    n_records = n,
    n_records_without_keywords = sum(vapply(records, function(r) length(r$keywords) == 0L, logical(1))),
    n_references_dropped = dropped,
    query = if (length(query) == 0L) NULL else query,
    retrieved_at = scopus_tf_time(attr(corpus, "retrieved_at")),
    source = paste("Scopus via scopusflow", utils::packageVersion("scopusflow"))
  )
  list(id = id, provenance = provenance, records = records, schema_version = "1.0")
}

#' @rdname write_scopus_corpus
#' @export
write_scopus_corpus <- function(corpus, path, id) {
  scopus_check_path(path)
  doc <- as_theoryforge_corpus(corpus, id)
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(scopus_tf_json(doc)), con)
  invisible(doc)
}

# The document as the bytes both twins write: sorted keys, compact
# separators, UTF-8 without escaping, a closing line feed. Python's
# json.dumps(sort_keys = True, separators = (",", ":"), ensure_ascii = False)
# escapes exactly the characters jsonlite does, quotation marks, backslashes
# and control characters, with the same short forms and lower-case \u
# sequences (checked with jsonlite 2.0.0). I() keeps a one-element keyword or
# reference list an array under auto_unbox.
scopus_tf_json <- function(doc) {
  json <- jsonlite::toJSON(scopus_tf_sort_keys(doc), auto_unbox = TRUE,
                           null = "null", na = "null", digits = NA)
  paste0(enc2utf8(as.character(json)), "\n")
}

# Order the names of every JSON object in a nested list by code point, as
# Python's sort_keys does. A radix sort orders strings as the C locale does,
# whatever the session's locale.
scopus_tf_sort_keys <- function(x) {
  if (!is.list(x) || inherits(x, "AsIs")) {
    return(x)
  }
  if (!is.null(names(x))) {
    x <- x[order(names(x), method = "radix")]
  }
  out <- lapply(x, scopus_tf_sort_keys)
  attributes(out) <- attributes(x)
  out
}

# Identifiers as trimmed text, NA for a missing or blank one. A number is
# written whole (85000000001, not 8.5e+10), and one that is not whole is no
# identifier.
scopus_tf_text <- function(x) {
  if (is.null(x)) {
    return(character())
  }
  if (is.factor(x)) x <- as.character(x)
  if (is.numeric(x)) {
    out <- rep(NA_character_, length(x))
    whole <- !is.na(x) & is.finite(x) & x == round(x)
    out[whole] <- sprintf("%.0f", x[whole])
    return(out)
  }
  x <- trimws(as.character(x))
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

# A 'Scopus' identifier as digits, without a SCOPUS_ID: or EID prefix, or NA.
scopus_tf_sid <- function(x) {
  x <- sub("^(SCOPUS_ID:|2-s2\\.0-)", "", scopus_tf_text(x))
  x[!grepl("^[0-9]+$", x)] <- NA_character_
  x
}

# A DOI cleaned as scopus_extract_dois() cleans one, with its ASCII letters
# lower-cased, or NA. DOIs are case-insensitive over ASCII only (DOI
# Handbook, section 2.4), so no other letter is folded.
scopus_tf_doi <- function(x) {
  x <- scopus_tf_text(x)
  cleaned <- vapply(x, function(d) {
    if (is.na(d)) return(NA_character_)
    d <- scopus_clean_dois(d)
    if (length(d) == 0L) NA_character_ else d
  }, character(1), USE.NAMES = FALSE)
  chartr(paste(LETTERS, collapse = ""), paste(letters, collapse = ""), cleaned)
}

# Keywords trimmed, lower-cased, non-empty and unique, the first of each kept.
scopus_tf_keywords <- function(x) {
  x <- unlist(x, use.names = FALSE)
  if (!is.character(x)) {
    return(character())
  }
  x <- tolower(trimws(x))
  unique(x[!is.na(x) & nzchar(x)])
}

# A year as a whole number, or NA, which is written as null.
scopus_tf_year <- function(x) {
  x <- suppressWarnings(as.numeric(unlist(x, use.names = FALSE)))
  if (length(x) != 1L || is.na(x) || !is.finite(x) || x != round(x)) {
    return(NA_integer_)
  }
  as.integer(x)
}

# A retrieval time in UTC, YYYY-MM-DDTHH:MM:SSZ, as theoryforge's schema
# writes one, or NULL when the corpus records none. scopus_fetch() and
# scopus_fetch_plan() record it as a POSIXct.
scopus_tf_time <- function(x) {
  if (!inherits(x, "POSIXt") || length(x) != 1L || is.na(x)) {
    return(NULL)
  }
  format(as.POSIXct(x), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}
