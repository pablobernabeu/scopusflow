#' Retrieve abstracts and richer metadata
#'
#' Fetches the abstract text and core metadata for one or more records from the
#' Elsevier 'Scopus' Abstract Retrieval API. This complements the Search API used
#' elsewhere in the package: a search returns many records with a few fields each,
#' whereas this returns the fuller record, including the abstract, for a known
#' identifier. Passing `include` adds author keywords and/or the document's
#' reference list to the same request.
#'
#' @param ids Character vector of identifiers to look up, either Digital Object
#'   Identifiers or 'Scopus' record identifiers (with or without the
#'   `"SCOPUS_ID:"` prefix), according to `by`.
#' @param by Either `"doi"` or `"scopus_id"`, the kind of identifier in `ids`.
#' @param view Optional character scalar naming the Abstract Retrieval view to
#'   request: one of `"META"`, `"META_ABS"`, `"REF"` or `"FULL"`. `NULL` (the
#'   default) omits the `view` parameter from the request entirely, exactly as
#'   scopusflow has always done, so existing calls that never mention `view`
#'   are unaffected. Retrieving `include = "references"` requires `view =
#'   "FULL"` or `view = "REF"`; see *Details* for how the two differ and which
#'   to prefer.
#' @param include Optional character vector naming extra fields to retrieve in
#'   the same request: `"references"` and/or `"keywords"`. Both require
#'   Abstract Retrieval's `FULL` or `REF` view (see `view`), an entitlement
#'   that is separate from ordinary abstract access and from 'Scopus' Search
#'   access, and that, per Elsevier's own documentation, some fields (notably
#'   author keywords) may need to be requested from your Scopus/Elsevier
#'   account contact even when the view itself is otherwise accessible. See
#'   *Details*.
#' @param cache_dir Optional directory for per-identifier cache files, as in
#'   [scopus_fetch_plan()]. `NULL` (the default) performs no caching. Worth
#'   setting whenever `include` is used: Abstract Retrieval draws on its own
#'   weekly quota, smaller than and separate from Search's, and every
#'   identifier here costs its own request, so re-running an interrupted batch
#'   without a cache re-spends quota already spent.
#' @param resume Logical. When `TRUE` (the default) and `cache_dir` is set, an
#'   identifier whose cache file already exists is loaded from disk rather than
#'   requested again.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble of class `scopus_abstracts`, one row per identifier, with
#'   columns `id` (the input identifier), `scopus_id`, `doi`, `title`, `abstract`,
#'   `publication`, `year` and `citations`. A field the API does not return is
#'   `NA`. An identifier that cannot be retrieved (for example one not in
#'   'Scopus') yields a row of `NA`s with a warning, so a batch is not lost to a
#'   single failure. The number of Abstract Retrieval requests made and the
#'   most recently parsed quota (see [scopus_quota()]) are attached as the
#'   `n_requests` and `quota` attributes, since this is a materially more
#'   expensive operation than a search call.
#'
#'   When `include` names `"keywords"`, an `authkeywords` column is added: the
#'   document's author-supplied keywords, joined the same way as `authors`
#'   (`"; "`-separated), or `NA` when the document has none, or when the API
#'   omits the field for a given key's entitlement (see *Details*).
#'
#'   When `include` names `"references"`, a `references` list-column is added:
#'   one data frame per document, with one row per cited work, rather than a
#'   single joined string. Its columns are `position` (the reference's place in
#'   the bibliography), `id` (the 'Scopus' identifier of the cited work, when
#'   resolved), `doi`, `title`, `authors`, `source` (the journal or other
#'   venue), `year` and `citedbycount` (the cited work's own citation count;
#'   populated only under `view = "REF"`, `NA` under `"FULL"`). A document with
#'   no resolvable references yields a zero-row data frame, not `NA`, so the
#'   column can always be unnested. This is a leaner field set than
#'   pybliometrics' own `references` in the Python twin, which exposes several
#'   further fields pybliometrics already parses; see the Python package's
#'   equivalent documentation for that fuller shape.
#' @details
#' Retrieving references or keywords needs Abstract Retrieval's `FULL` or `REF`
#' view. In development, against a live key with full Abstract Retrieval
#' access, `view = "FULL"` returned a complete, correctly counted reference
#' list for every document tried. `view = "REF"` returned the identical,
#' complete list in one case but a truncated (paginated) subset in another, on
#' an otherwise identical request made moments apart, so `"FULL"` is
#' recommended when your entitlement allows it. `"REF"` remains available for
#' accounts entitled only to it; when the number of references returned does
#' not match the document's own reported reference count, a warning is issued
#' naming the identifier, since the list may be an incomplete page rather than
#' the whole bibliography.
#'
#' Author keywords were not populated by either 'Scopus' Search's `COMPLETE`
#' view (see [scopus_records()]) or Abstract Retrieval's `FULL` view in this
#' package's own development testing, against a live, otherwise
#' fully-entitled key, on documents that do carry author keywords in 'Scopus'
#' itself. If your own keywords come back all `NA`, this is most likely an
#' entitlement gap specific to that field, worth raising with your
#' Scopus/Elsevier account contact, rather than the documents genuinely having
#' none.
#' @section API access:
#' This performs one request per identifier and requires a valid API key and
#' internet access; full-text abstract access, and the `FULL`/`REF` views in
#' particular, can also depend on your entitlement. A view or field your key is
#' not entitled to raises a `scopus_error_forbidden` condition with a message
#' naming the view and suggesting who to contact, rather than a generic HTTP
#' failure; because entitlement is an account-level property, not a
#' per-document one, retrieval stops at the first such failure instead of
#' repeating it for every remaining identifier. See the *API access* section of
#' [scopus_count()] for the other conditions that may be raised.
#' @seealso [scopus_fetch()], [scopus_extract_dois()], [scopus_corpus()] to
#'   assemble a minimal keyword/reference corpus across many documents.
#' @examplesIf scopusflow::scopus_has_key()
#' scopus_abstract("10.1038/s41586-019-0001-1")
#'
#' # Author keywords and a structured reference list, in the same request.
#' # Costs one Abstract Retrieval request per identifier, against a smaller,
#' # separate weekly quota from Search; see the API access section above for
#' # the entitlement this needs.
#' rich <- scopus_abstract(
#'   "10.1038/nature14539",
#'   view = "FULL", include = c("references", "keywords")
#' )
#' rich$references[[1]]
#' @export
scopus_abstract <- function(ids,
                            by = c("doi", "scopus_id"),
                            view = NULL,
                            include = character(),
                            cache_dir = NULL,
                            resume = TRUE,
                            api_key = NULL,
                            inst_token = NULL,
                            verbose = FALSE) {
  by <- rlang::arg_match(by)
  include <- scopus_check_include(include)
  if (!is.null(view) && !view %in% c("META", "META_ABS", "REF", "FULL")) {
    rlang::abort(
      "`view` must be one of \"META\", \"META_ABS\", \"REF\", \"FULL\", or NULL.",
      class = "scopus_error_bad_input"
    )
  }
  if ("references" %in% include && !identical(view, "FULL") && !identical(view, "REF")) {
    rlang::abort(
      "Retrieving `include = \"references\"` needs `view = \"FULL\"` or `view = \"REF\"`.",
      class = "scopus_error_bad_input"
    )
  }
  if (!is.character(ids) || length(ids) == 0L || anyNA(ids) ||
      !all(nzchar(trimws(ids)))) {
    rlang::abort(
      "`ids` must be a non-empty character vector of identifiers.",
      class = "scopus_error_bad_input"
    )
  }
  ids <- trimws(ids)
  if (by == "scopus_id") {
    ids <- sub("^SCOPUS_ID:", "", ids)
  }

  # Resolve the key once up front: a missing key is a configuration error and
  # should abort clearly, rather than being caught per identifier below and
  # turned into a whole tibble of NA rows.
  scopus_key(api_key)

  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  n_requests <- 0L
  quota <- NULL
  forbidden <- NULL

  rows <- vector("list", length(ids))
  for (i in seq_along(ids)) {
    cache_file <- if (is.null(cache_dir)) {
      NULL
    } else {
      file.path(
        cache_dir,
        sprintf("id-%s-%s.rds", view %||% "default", scopus_safe_filename(ids[i]))
      )
    }
    if (!is.null(cache_file) && resume && file.exists(cache_file)) {
      if (verbose) cli::cli_inform("{i}/{length(ids)}: {.val {ids[i]}} loaded from cache.")
      rows[[i]] <- readRDS(cache_file)
      next
    }

    if (verbose) cli::cli_inform("Retrieving {i}/{length(ids)}: {ids[i]}.")
    row <- tryCatch({
      # A plain `<-` here, not `<<-`: this block is evaluated directly in
      # scopus_abstract()'s own frame (tryCatch()'s first argument is not a
      # closure), and `<<-` always skips the current frame even when it is
      # the same one, so it would silently create/modify a same-named
      # variable one scope further out instead (confirmed directly). The
      # handler functions below, which are genuine closures, correctly need
      # `<<-` to reach back into this frame.
      fetched <- scopus_abstract_one(
        ids[i], by, view = view, include = include,
        api_key = api_key, inst_token = inst_token
      )
      n_requests <- n_requests + 1L
      if (!is.null(fetched$quota)) quota <- fetched$quota
      fetched$row
    }, scopus_error_forbidden = function(e) {
      # Recorded rather than raised here: a condition signalled from inside
      # one handler of a tryCatch() can still be caught by a sibling handler
      # of that same call (verified directly; not just a theoretical
      # concern), which would route this straight into the generic
      # scopus_error handler below instead of stopping the batch. Raising it
      # after tryCatch() has returned, outside any handler, avoids that.
      n_requests <<- n_requests + 1L
      forbidden <<- e
      NULL
    }, scopus_error = function(e) {
      n_requests <<- n_requests + 1L
      cli::cli_warn("Could not retrieve {.val {ids[i]}}: {conditionMessage(e)}")
      scopus_abstract_row(ids[i], list(), include = include)
    })
    if (!is.null(forbidden)) {
      remaining <- length(ids) - i
      rlang::abort(
        sprintf(
          paste0(
            "Abstract Retrieval refused view = \"%s\" (HTTP 403) for %s. This ",
            "usually means your 'Scopus' API key's entitlement does not cover ",
            "the requested view or field; contact your Scopus/Elsevier account ",
            "holder or institutional administrator to request access, or, if ",
            "you have not already, try the other of \"FULL\"/\"REF\". Stopping ",
            "rather than repeating the same failure for the remaining %d ",
            "identifier%s (this entitlement is an account-level property, not ",
            "a per-document one, so it will not succeed on retry)."
          ),
          view %||% "META", ids[i], remaining, if (remaining == 1L) "" else "s"
        ),
        class = c("scopus_error_forbidden", "scopus_error"),
        call = rlang::caller_env()
      )
    }
    if (!is.null(cache_file)) saveRDS(row, cache_file)
    rows[[i]] <- row
  }

  out <- do.call(rbind, rows)
  out <- tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_abstracts")
  attr(out, "n_requests") <- n_requests
  attr(out, "quota") <- quota
  out
}

# Validate the `include` argument: character(), or a subset of the known
# extras, each named at most once.
scopus_check_include <- function(include, call = rlang::caller_env()) {
  if (length(include) == 0L) {
    return(character())
  }
  known <- c("references", "keywords")
  if (!is.character(include) || anyNA(include) || !all(include %in% known)) {
    rlang::abort(
      "`include` must be a character vector made up of \"references\" and/or \"keywords\".",
      class = "scopus_error_bad_input", call = call
    )
  }
  unique(include)
}

# A filesystem-safe cache key for an identifier: non-alphanumerics become "_",
# keeping the result human-decipherable for debugging (unlike a hash) since
# collisions between distinct real DOIs/Scopus IDs are effectively impossible.
scopus_safe_filename <- function(id) {
  gsub("[^A-Za-z0-9]+", "_", id)
}

# Build (but do not perform) an Abstract Retrieval request for one identifier.
scopus_abstract_request <- function(id, by, view = NULL, api_key = NULL, inst_token = NULL,
                                    call = rlang::caller_env()) {
  key <- scopus_key(api_key, call = call)
  token <- scopus_inst_token(inst_token)
  base <- getOption("scopusflow.abstract_url",
                    "https://api.elsevier.com/content/abstract")
  # A DOI may itself contain slashes, which the API expects literally, so each
  # path segment is percent-encoded individually and the slashes are preserved.
  # This escapes characters such as '?', '#' or spaces that would otherwise be
  # misparsed, without touching the structural slashes.
  id_path <- paste(
    vapply(
      strsplit(id, "/", fixed = TRUE)[[1]],
      function(segment) utils::URLencode(segment, reserved = TRUE),
      character(1)
    ),
    collapse = "/"
  )
  req <- httr2::request(paste0(base, "/", by, "/", id_path))
  req <- httr2::req_user_agent(req, scopus_user_agent())
  req <- httr2::req_headers(
    req, `X-ELS-APIKey` = key, Accept = "application/json",
    .redact = "X-ELS-APIKey"
  )
  if (!is.null(token)) {
    req <- httr2::req_headers(req, `X-ELS-Insttoken` = token, .redact = "X-ELS-Insttoken")
  }
  if (!is.null(view)) {
    req <- httr2::req_url_query(req, view = view)
  }
  req
}

scopus_abstract_one <- function(id, by, view = NULL, include = character(),
                                api_key = NULL, inst_token = NULL) {
  req <- scopus_abstract_request(id, by, view = view, api_key = api_key, inst_token = inst_token)
  resp <- scopus_perform(req)
  body <- tryCatch(
    jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE),
    error = function(e) {
      rlang::abort(
        "The 'Scopus' abstract response was not valid JSON.",
        class = c("scopus_error_malformed", "scopus_error"),
        parent = e
      )
    }
  )
  full <- body[["abstracts-retrieval-response"]]
  # Under view = "REF", the response carries only `references`, with no
  # `coredata`; the identifying/abstract columns are then NA, which is
  # expected (REF view is for reference retrieval, not abstract metadata).
  if (is.null(full[["coredata"]]) && is.null(full[["references"]])) {
    rlang::abort(
      "The 'Scopus' abstract response did not contain a `coredata` element.",
      class = c("scopus_error_malformed", "scopus_error")
    )
  }
  list(
    row = scopus_abstract_row(id, full[["coredata"]] %||% list(), full = full, view = view, include = include),
    quota = tryCatch(scopus_quota(resp), error = function(e) NULL)
  )
}

scopus_abstract_row <- function(id, core, full = list(), view = NULL, include = character()) {
  citations <- scopus_field(core, "citedby-count")
  row <- data.frame(
    id = id,
    scopus_id = sub("^SCOPUS_ID:", "", scopus_field(core, "dc:identifier")),
    doi = scopus_field(core, "prism:doi"),
    title = scopus_field(core, "dc:title"),
    abstract = scopus_field(core, "dc:description"),
    publication = scopus_field(core, "prism:publicationName"),
    year = scopus_parse_year(scopus_field(core, "prism:coverDate")),
    citations = if (is.na(citations)) NA_integer_ else suppressWarnings(as.integer(citations)),
    stringsAsFactors = FALSE
  )
  if ("keywords" %in% include) {
    row$authkeywords <- scopus_parse_authkeywords(full)
  }
  if ("references" %in% include) {
    row$references <- list(scopus_parse_references(full, view))
  }
  row
}

# Author keywords from an Abstract Retrieval response, joined "; " to match
# the `authors` column's convention. `authkeywords` may be absent, a single
# `author-keyword` object, or a list of them (a common Elsevier XML-to-JSON
# quirk where a single-item array collapses to a bare object).
scopus_parse_authkeywords <- function(full) {
  ak <- full[["authkeywords"]]
  if (is.null(ak)) {
    return(NA_character_)
  }
  items <- ak[["author-keyword"]] %||% ak
  if (is.null(items)) {
    return(NA_character_)
  }
  if (!is.null(names(items)) && "$" %in% names(items)) {
    items <- list(items)  # a single keyword collapsed to a bare object
  }
  text <- vapply(items, function(x) {
    if (is.list(x)) as.character(x[["$"]] %||% NA_character_) else as.character(x)
  }, character(1))
  text <- text[!is.na(text) & nzchar(text)]
  if (length(text) == 0L) NA_character_ else paste(text, collapse = "; ")
}

# Structured references from an Abstract Retrieval response, as a data frame
# (one row per cited work), for the `references` list-column. The raw shape
# differs by view: REF view nests them under `references$reference`, FULL
# view under `item$bibrecord$tail$bibliography$reference`, and per-reference
# field names differ between the two (see scopus_abstract()'s documentation).
# Confirmed directly against a live key for both views. Under REF view,
# `title` and `source` came back NA for every reference tried, even where
# `doi`, `year` and `citedbycount` were populated on the same row, so REF
# view is a genuinely leaner shape here, not an extraction gap; FULL view
# populated `title`/`authors`/`source` throughout.
scopus_parse_references <- function(full, view) {
  empty <- data.frame(
    position = character(), id = character(), doi = character(),
    title = character(), authors = character(), source = character(),
    year = integer(), citedbycount = integer(), stringsAsFactors = FALSE
  )
  if (identical(view, "REF")) {
    bib <- full[["references"]]
    total <- suppressWarnings(as.integer(bib[["@total-references"]]))
    items <- bib[["reference"]]
  } else {
    bib <- chained_get(full, c("item", "bibrecord", "tail", "bibliography"))
    total <- suppressWarnings(as.integer(bib[["@refcount"]]))
    items <- bib[["reference"]]
  }
  if (is.null(items) || length(items) == 0L) {
    return(empty)
  }
  rows <- lapply(items, scopus_parse_one_reference, view = view)
  out <- do.call(rbind, c(rows, list(stringsAsFactors = FALSE)))
  if (!is.na(total) && nrow(out) != total) {
    rlang::warn(
      sprintf(
        paste0("A document reports %d references but only %d were returned ",
               "under view = \"%s\"; the list may be an incomplete page ",
               "rather than the whole bibliography."),
        total, nrow(out), view
      ),
      class = "scopus_warning_incomplete_references"
    )
  }
  out
}

scopus_parse_one_reference <- function(item, view) {
  info <- item[["ref-info"]] %||% item
  if (identical(view, "REF")) {
    authors <- (info[["author-list"]] %||% list())[["author"]]
    author_names <- vapply(authors %||% list(), function(a) {
      paste(stats::na.omit(c(a[["ce:surname"]], a[["ce:given-name"]])), collapse = ", ")
    }, character(1))
    doi <- info[["ce:doi"]]
    ref_id <- info[["scopus-id"]]
    # `ref-title` appears to be a shared field name across REF and FULL views;
    # left NA rather than guessed at (for example from `ref-sourcetitle`, the
    # cited work's journal, which is not its title) if genuinely absent.
    title <- chained_get(info, c("ref-title", "ref-titletext"))
    citedbycount <- suppressWarnings(as.integer(info[["citedby-count"]]))
    year <- scopus_parse_year(info[["ref-coverdate"]] %||% info[["prism:coverDate"]])
  } else {
    authors <- chained_get(info, c("ref-authors", "author"))
    author_names <- vapply(authors %||% list(), function(a) {
      paste(stats::na.omit(c(a[["ce:surname"]], a[["ce:initials"]])), collapse = ", ")
    }, character(1))
    ids <- chained_get(info, c("refd-itemidlist", "itemid")) %||% list()
    doi <- scopus_select_itemid(ids, "DOI")
    ref_id <- scopus_select_itemid(ids, "SGR")
    title <- chained_get(info, c("ref-title", "ref-titletext"))
    citedbycount <- NA_integer_
    year <- suppressWarnings(as.integer(chained_get(info, c("ref-publicationyear", "@first"))))
  }
  data.frame(
    position = as.character(item[["@id"]] %||% NA_character_),
    id = as.character(ref_id %||% NA_character_),
    doi = as.character(doi %||% NA_character_),
    title = as.character(title %||% NA_character_),
    authors = if (length(author_names) == 0L) NA_character_ else paste(author_names, collapse = "; "),
    source = as.character(chained_get(info, c("ref-sourcetitle")) %||% NA_character_),
    year = if (length(year) == 0L) NA_integer_ else year,
    citedbycount = if (length(citedbycount) == 0L) NA_integer_ else citedbycount,
    stringsAsFactors = FALSE
  )
}

# Pick the itemid entry of a given @idtype from a FULL-view refd-itemidlist,
# which may be a single object or a list of them.
scopus_select_itemid <- function(ids, idtype) {
  if (!is.null(names(ids)) && "@idtype" %in% names(ids)) {
    ids <- list(ids)
  }
  for (item in ids) {
    if (identical(item[["@idtype"]], idtype)) {
      return(item[["$"]])
    }
  }
  NULL
}

# Walk a chain of list indices, returning NULL as soon as any step is absent,
# rather than erroring on a partially-missing nested path.
chained_get <- function(x, path) {
  for (key in path) {
    if (is.null(x) || !is.list(x)) return(NULL)
    x <- x[[key]]
  }
  x
}

#' @export
print.scopus_abstracts <- function(x, ...) {
  cli::cli_text("{.cls scopus_abstracts} ({nrow(x)} record{?s})")
  NextMethod()
  invisible(x)
}
