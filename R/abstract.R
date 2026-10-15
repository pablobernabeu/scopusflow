#' Retrieve abstracts and richer metadata
#'
#' Fetches the abstract text and core metadata for one or more records from the
#' Elsevier 'Scopus' Abstract Retrieval API. This complements the Search API used
#' elsewhere in the package: a search returns many records with a few fields each,
#' whereas this returns the fuller record, including the abstract, for a known
#' identifier. Passing `include` adds the author keywords, the index keywords
#' and the document's reference list, or any of them, to the same request.
#'
#' @param ids Character vector of identifiers to look up, either Digital Object
#'   Identifiers or 'Scopus' record identifiers (with or without the
#'   `"SCOPUS_ID:"` prefix), according to `by`.
#' @param by Either `"doi"` or `"scopus_id"`, the kind of identifier in `ids`.
#' @param view The Abstract Retrieval view to request: `"META_ABS"` (the
#'   default), `"META"`, `"REF"` or `"FULL"`, or `NULL`. `"META_ABS"` is the
#'   view Elsevier documents as carrying the abstract with the core metadata.
#'   `NULL` sends no `view` parameter, as scopusflow 0.4.0 and earlier did,
#'   and leaves the choice to the API. Elsevier documents its default as
#'   `"META"`, a view without the abstract, but a live request in October 2026
#'   returned the abstract without a view. Retrieving `include = "references"`
#'   requires `view = "FULL"` or `view = "REF"`; see *Details* for how the two
#'   differ and which to prefer.
#' @param include Optional character vector naming extra fields to retrieve in
#'   the same request: any of `"references"`, `"keywords"` (the author
#'   keywords) and `"index_terms"` (the index keywords 'Scopus' assigns).
#'   `"references"` requires `view = "FULL"` or `view = "REF"`, and
#'   `"keywords"` and `"index_terms"` require `view = "FULL"`, since the `REF`
#'   response carries neither kind of keyword.
#'   Either way this is an entitlement that is separate from ordinary abstract
#'   access and from 'Scopus' Search access, and, per Elsevier's own
#'   documentation, some fields (notably author keywords) may need to be
#'   requested from your Scopus/Elsevier account contact even when the view
#'   itself is otherwise accessible. See *Details*.
#' @param cache_dir Optional directory for per-identifier cache files, as in
#'   [scopus_fetch_plan()]. `NULL` (the default) performs no caching. Worth
#'   setting whenever `include` is used: Abstract Retrieval draws on its own
#'   weekly quota, smaller than and separate from Search's, and every
#'   identifier here costs at least one request of its own, so re-running an interrupted batch
#'   without a cache re-spends quota already spent. A `cache_dir` that cannot
#'   be written is refused before any request, and a checkpoint that cannot be
#'   written all the same warns and keeps the row, as in [scopus_fetch_plan()].
#' @param resume Logical. When `TRUE` (the default) and `cache_dir` is set, an
#'   identifier whose cache file already exists is loaded from disk, sparing a
#'   second request for it. A cache file that cannot be read back, for example
#'   one left half-written by an interrupted run, is retrieved again with a
#'   warning, and the batch carries on.
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
#'   When `include` names `"index_terms"`, an `idxterms` column is added after
#'   any `authkeywords`: the index keywords of the document, joined by `"; "`,
#'   or `NA` when the response carries none. An entry without text is dropped.
#'
#'   When `include` names `"references"`, a `references` list-column is added:
#'   one data frame per document, with one row per cited work, where a joined
#'   string would have to be parsed apart again. Its columns are `position` (the
#'   reference's place in the bibliography), `id` (the 'Scopus' identifier of
#'   the cited work, when
#'   resolved), `doi`, `title`, `authors`, `source` (the journal or other
#'   venue), `year` and `citedbycount` (the cited work's own citation count;
#'   populated only under `view = "REF"`, `NA` under `"FULL"`). A document with
#'   no resolvable references yields a zero-row data frame, so the column can
#'   always be unnested.
#' @details
#' Retrieving references needs Abstract Retrieval's `FULL` or `REF` view, and
#' keywords need `FULL`. `FULL` returns the whole bibliography in one request.
#' `REF` serves it a page at a time, about 40 references per request, so
#' `scopus_abstract()` follows the view's `startref` parameter until it holds
#' as many references as the document reports, as pybliometrics does. A `REF`
#' document with *N* references therefore costs `ceiling(N / 40)` requests,
#' each counted in `n_requests`, which makes `"FULL"` the cheaper view when
#' your entitlement allows it. Elsevier's guide numbers `startref` from 0 and
#' pybliometrics from 1, and which of the two the API follows has not been
#' confirmed. Paging stops on an empty page, on a page that adds no new
#' reference, or after as many pages as the first page's length implies, so
#' neither numbering can make it loop or repeat references. When the number
#' of references held still differs from the document's reported count, a
#' `scopus_warning_incomplete_references` warning says so. An
#' identifier whose later page fails is a failed retrieval: it gets a row of
#' `NA`s with a warning and is not checkpointed.
#'
#' Author keywords were not populated by either 'Scopus' Search's `COMPLETE`
#' view (see [scopus_records()]) or Abstract Retrieval's `FULL` view in this
#' package's own development testing, against a live, otherwise
#' fully-entitled key, on documents that do carry author keywords in 'Scopus'
#' itself. If your own keywords come back all `NA`, this is most likely an
#' entitlement gap specific to that field, worth raising with your
#' Scopus/Elsevier account contact. The documents do carry keywords.
#'
#' Index keywords are the other kind 'Scopus' records. Authors choose their own
#' keywords, whereas 'Scopus' chooses the index keywords and standardises them
#' to vocabularies derived from thesauri Elsevier owns or licenses, with
#' synonyms, spellings and plurals brought together. The two kinds therefore
#' give different keyword co-occurrence results, and a study should say which
#' it used. Elsevier's guide lists index keywords in the `FULL` view as not
#' available by default, so whether they arrive depends on your key's
#' entitlement as well. In this package's development testing, they did
#' arrive on the same key whose author keywords came back empty.
#' @section API access:
#' This performs one request per identifier, or one per page of references
#' under `view = "REF"` with `include = "references"`, and requires a valid
#' API key and internet access; full-text abstract access, and the `FULL`/`REF` views in
#' particular, can also depend on your entitlement. A view or field your key is
#' not entitled to raises a `scopus_error_forbidden` condition with a message
#' naming the view and suggesting who to contact, where a generic HTTP failure
#' would leave you guessing. Because entitlement is a property of the account,
#' retrieval stops at the first such failure, so the same refusal is not
#' repeated for every remaining identifier.
#'
#' A spent weekly quota (HTTP 429 marked `QUOTA_EXCEEDED`) also stops the
#' requests, but returns what the batch holds, since it usually arrives
#' part-way through: the rows already retrieved are kept, each identifier not
#' retrieved gets a row of `NA`s that is not checkpointed, and one
#' `scopus_warning_quota_exceeded` warning names the identifier reached, how
#' many were not retrieved and when the quota resets. A checkpoint in
#' `cache_dir` is still read after the stop. See the *API access* section of
#' [scopus_count()] for the other conditions that may be raised.
#' @seealso [scopus_fetch()], [scopus_extract_dois()], [scopus_corpus()] to
#'   assemble a minimal keyword/reference corpus across many documents.
#' @examplesIf scopusflow::scopus_has_key()
#' # One record of the bundled corpus, looked up for real.
#' scopus_abstract(scopus_extract_dois(example_records)[1])
#'
#' # Author keywords and a structured reference list, in the same request.
#' # Costs one Abstract Retrieval request per identifier, against a smaller,
#' # separate weekly quota from Search; see the API access section above for
#' # the entitlement this needs.
#' rich <- scopus_abstract(
#'   "10.1038/natrevmats.2016.33",
#'   view = "FULL", include = c("references", "keywords")
#' )
#' rich$references[[1]]
#' @examples
#' # The offline companion, which needs no key. The identifiers, titles,
#' # sources and citation counts are two records of the bundled corpus of real
#' # articles; the abstract text is what a live call adds, so it is left as a
#' # placeholder here, as is the 'Scopus' identifier the corpus does not
#' # carry.
#' cited <- example_records[order(-example_records$citations), ][1:2, ]
#' abstracts <- tibble::tibble(
#'   id = cited$doi,
#'   scopus_id = NA_character_,
#'   doi = cited$doi,
#'   title = cited$title,
#'   abstract = NA_character_,
#'   publication = cited$publication,
#'   year = cited$year,
#'   citations = cited$citations
#' )
#' class(abstracts) <- c("scopus_abstracts", class(abstracts))
#' abstracts
#'
#' # A reference list arrives as one data frame per document, in the
#' # `references` list-column added by include = "references". The corpus
#' # carries no bibliographies, so its own records fill the columns here,
#' # standing in for the works the first document cites.
#' refs <- example_records[1:3, ]
#' abstracts$references <- list(
#'   tibble::tibble(
#'     position = as.character(seq_len(nrow(refs))),
#'     id = NA_character_,
#'     doi = refs$doi,
#'     title = refs$title,
#'     authors = refs$authors,
#'     source = refs$publication,
#'     year = refs$year,
#'     citedbycount = refs$citations
#'   ),
#'   tibble::tibble()
#' )
#' abstracts$references[[1]]
#' @export
scopus_abstract <- function(ids,
                            by = c("doi", "scopus_id"),
                            view = "META_ABS",
                            include = character(),
                            cache_dir = NULL,
                            resume = TRUE,
                            api_key = NULL,
                            inst_token = NULL,
                            verbose = FALSE) {
  by <- scopus_match_arg(by, c("doi", "scopus_id"))
  include <- scopus_check_include(include)
  if (!is.null(view) && !view %in% c("META", "META_ABS", "REF", "FULL")) {
    scopus_abort_bad_input(
      "`view` must be one of \"META\", \"META_ABS\", \"REF\", \"FULL\", or NULL."
    )
  }
  if ("references" %in% include && !identical(view, "FULL") && !identical(view, "REF")) {
    scopus_abort_bad_input(
      "Retrieving `include = \"references\"` needs `view = \"FULL\"` or `view = \"REF\"`."
    )
  }
  # The REF response carries no author keywords, so accepting it (or the
  # default view) here would only yield a silent all-NA column.
  if ("keywords" %in% include && !identical(view, "FULL")) {
    scopus_abort_bad_input(
      "Retrieving `include = \"keywords\"` needs `view = \"FULL\"`."
    )
  }
  # Index keywords come only with FULL too (Scopus API Guide, V1, p. 29).
  if ("index_terms" %in% include && !identical(view, "FULL")) {
    scopus_abort_bad_input(
      "Retrieving `include = \"index_terms\"` needs `view = \"FULL\"`."
    )
  }
  if (!is.character(ids) || length(ids) == 0L || anyNA(ids) ||
      !all(nzchar(trimws(ids)))) {
    scopus_abort_bad_input(
      "`ids` must be a non-empty character vector of identifiers."
    )
  }
  ids <- trimws(ids)
  if (by == "scopus_id") {
    ids <- sub("^SCOPUS_ID:", "", ids)
  }

  # Resolve the key once up front: a missing key is a configuration error and
  # should abort at once. Caught per identifier below, it would instead be
  # turned into a whole tibble of NA rows.
  scopus_key(api_key)

  scopus_check_cache_dir(cache_dir)

  n_requests <- 0L
  quota <- NULL
  forbidden <- NULL
  # A spent weekly quota stops the requests but, unlike a 403, not the batch:
  # it usually arrives part-way through, and aborting would discard the rows
  # already paid for whenever `cache_dir` is NULL. `quota_spent` holds the
  # condition, and `quota_spent_at` the identifier it arrived on.
  quota_spent <- NULL
  quota_spent_at <- NA_character_
  not_retrieved <- 0L

  # The requested extras are part of the cache key (sorted, so the encoding is
  # stable however `include` was ordered): a resumed run that asks for
  # different extras must refetch, since the cached row would be missing the
  # requested columns. The Python twin keys its abstract cache the same way.
  include_key <- if (length(include) == 0L) "none" else paste(sort(include), collapse = "-")
  # 0.4.0 requested only the first page of a REF bibliography, so a REF
  # checkpoint it wrote may hold a truncated list that a resume would serve as
  # complete. Keying REF checkpoints afresh refetches each of them once, as
  # 0.4.0 itself did for the checkpoints it could no longer trust.
  view_key <- if (identical(view, "REF")) "REF-paged" else view %||% "default"

  rows <- vector("list", length(ids))
  for (i in seq_along(ids)) {
    cache_file <- if (is.null(cache_dir)) {
      NULL
    } else {
      file.path(
        cache_dir,
        sprintf(
          "id-%s-%s-%s.rds",
          view_key, include_key, scopus_safe_filename(ids[i])
        )
      )
    }
    if (!is.null(cache_file) && resume && file.exists(cache_file)) {
      cached <- scopus_read_checkpoint(cache_file)
      cached_id <- if (is.data.frame(cached)) cached[["id"]] else NULL
      if (is.null(cached)) {
        rlang::warn(
          sprintf(
            paste0("The checkpoint %s could not be read back, so it was ",
                   "discarded and the identifier retrieved again. An ",
                   "interrupted run can leave a checkpoint half-written."),
            cache_file
          ),
          class = "scopus_warning_cache_unreadable"
        )
      } else if (identical(cached_id, ids[i])) {
        if (verbose) cli::cli_inform("{i}/{length(ids)}: {.val {ids[i]}} loaded from cache.")
        rows[[i]] <- cached
        next
      } else {
        # scopus_safe_filename() is lossy, so a distinct identifier can map to
        # this same file; the cached row's own id says which one it holds.
        rlang::warn(
          sprintf(
            paste0("The checkpoint %s was written for a different identifier ",
                   "that shares this cache filename, so it was discarded and ",
                   "%s retrieved again."),
            cache_file, ids[i]
          ),
          class = "scopus_warning_cache_mismatch"
        )
      }
    }

    if (!is.null(quota_spent)) {
      # No request after the quota ran out. Checkpoints above are still read,
      # since they cost nothing, and the NA row is not checkpointed, so a run
      # after the reset retrieves the identifier.
      not_retrieved <- not_retrieved + 1L
      rows[[i]] <- scopus_abstract_row(ids[i], list(), include = include)
      next
    }

    if (verbose) cli::cli_inform("Retrieving {i}/{length(ids)}: {ids[i]}.")
    failed <- FALSE
    # Counts every request made for this identifier, one per REF page,
    # including those made before a later one failed.
    requests <- new.env()
    requests$n <- 0L
    row <- tryCatch({
      # A plain `<-` here. This block is evaluated directly in
      # scopus_abstract()'s own frame (tryCatch()'s first argument is not a
      # closure), and `<<-` always skips the current frame even when it is
      # the same one, so it would silently create or modify a same-named
      # variable one scope further out (confirmed directly). The handler
      # functions below are real closures, and do need `<<-` to reach back
      # into this frame.
      fetched <- scopus_abstract_one(
        ids[i], by, view = view, include = include,
        api_key = api_key, inst_token = inst_token, requests = requests
      )
      if (!is.null(fetched$quota)) quota <- fetched$quota
      fetched$row
    }, scopus_error_forbidden = function(e) {
      # Recorded here and raised later: a condition signalled from inside
      # one handler of a tryCatch() can still be caught by a sibling handler
      # of that same call (verified directly; not just a theoretical
      # concern), which would route this straight into the generic
      # scopus_error handler below and let the batch continue. Raising it after
      # tryCatch() has returned, outside any handler, avoids that.
      forbidden <<- e
      NULL
    }, scopus_error_quota_exceeded = function(e) {
      # Listed before the scopus_error handler, which would otherwise warn
      # and carry on to the next identifier.
      quota_spent <<- e
      quota_spent_at <<- ids[i]
      failed <<- TRUE
      if (!is.null(e$quota)) quota <<- e$quota
      scopus_abstract_row(ids[i], list(), include = include)
    }, scopus_error = function(e) {
      failed <<- TRUE
      cli::cli_warn("Could not retrieve {.val {ids[i]}}: {conditionMessage(e)}")
      scopus_abstract_row(ids[i], list(), include = include)
    })
    n_requests <- n_requests + requests$n
    if (!is.null(forbidden)) {
      remaining <- length(ids) - i
      rlang::abort(
        sprintf(
          paste0(
            "Abstract Retrieval refused view = \"%s\" (HTTP 403) for %s. This ",
            "usually means your 'Scopus' API key's entitlement does not cover ",
            "the requested view or field; contact your Scopus/Elsevier account ",
            "holder or institutional administrator to request access%s. Stopping ",
            "rather than repeating the same failure for the remaining %d ",
            "identifier%s (this entitlement is an account-level property, not ",
            "a per-document one, so it will not succeed on retry)."
          ),
          # sprintf() prints nothing at all for a NULL argument, so a refusal
          # of the request without a view names the default Elsevier documents.
          view %||% "META", ids[i], scopus_forbidden_hint(view), remaining,
          if (remaining == 1L) "" else "s"
        ),
        class = c("scopus_error_forbidden", "scopus_error"),
        call = rlang::caller_env()
      )
    }
    # Only a row parsed from a successful response is checkpointed. The NA row
    # a failed retrieval (a rate limit, a server error, an offline host, an
    # identifier absent from 'Scopus') leaves
    # behind keeps the batch alive, but cached it would make the failure
    # permanent: a resumed run would serve it as data and never retry.
    if (!is.null(cache_file) && !failed) scopus_write_checkpoint(row, cache_file)
    rows[[i]] <- row
    if (!is.null(quota_spent)) not_retrieved <- not_retrieved + 1L
  }

  if (!is.null(quota_spent)) {
    rlang::warn(
      sprintf(
        paste(
          "The 'Scopus' API key's weekly quota ran out (HTTP 429, QUOTA_EXCEEDED)",
          "at %s, so no further request was made, and %d %s not retrieved",
          "and given a row of NA. %s The rows already retrieved are kept. The NA",
          "rows are not checkpointed, so a run after the reset with `cache_dir`",
          "set requests only the identifiers still missing."
        ),
        quota_spent_at,
        not_retrieved,
        if (not_retrieved == 1L) "identifier was" else "identifiers were",
        scopus_quota_reset_sentence(quota_spent$quota)
      ),
      class = "scopus_warning_quota_exceeded",
      quota = quota_spent$quota
    )
  }

  # Union the columns before binding, as scopus_bind_records() does for plan
  # cells: a row loaded from a cache written with a different column set (for
  # example by an older scopusflow) can carry fewer columns than a freshly
  # fetched one, and rbind() would error on the mismatch.
  all_cols <- Reduce(union, lapply(rows, names))
  rows <- lapply(rows, function(x) {
    for (col in setdiff(all_cols, names(x))) {
      x[[col]] <- if (col == "references") list(NULL) else NA
    }
    x[all_cols]
  })
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
  known <- c("references", "keywords", "index_terms")
  if (!is.character(include) || anyNA(include) || !all(include %in% known)) {
    scopus_abort_bad_input(
      paste0(
        "`include` must be a character vector naming only \"references\", ",
        "\"keywords\" and \"index_terms\"."
      ),
      call = call
    )
  }
  unique(include)
}

# The fallback a 403 message suggests, which depends on the view refused, as
# in the Python twin. Either reference view may be entitled where the other is
# not. A key refused META_ABS can fall back on the request without a view that
# 0.4.0 and earlier made. META, or no view at all, leaves nothing lighter to
# suggest.
scopus_forbidden_hint <- function(view) {
  if (identical(view, "FULL") || identical(view, "REF")) {
    ", or, if you have not already, try the other of \"FULL\"/\"REF\""
  } else if (identical(view, "META_ABS")) {
    ", or pass `view = NULL` to request the metadata without naming a view"
  } else {
    ""
  }
}

# A filesystem-safe cache key for an identifier: non-alphanumerics become "_",
# keeping the result human-decipherable for debugging (unlike a hash). The
# mapping is lossy, so distinct identifiers ("10.1/a.b", "10.1/a-b") can share
# a filename; the resume path in scopus_abstract() therefore checks the cached
# row's id and treats a mismatch as a cache miss.
scopus_safe_filename <- function(id) {
  gsub("[^A-Za-z0-9]+", "_", id)
}

# Build (but do not perform) an Abstract Retrieval request for one identifier.
# `startref` asks the REF view for the page of references that starts there.
scopus_abstract_request <- function(id, by, view = NULL, api_key = NULL, inst_token = NULL,
                                    startref = NULL, call = rlang::caller_env()) {
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
  if (!is.null(startref)) {
    req <- httr2::req_url_query(req, startref = startref)
  }
  scopus_req_timeout(req)
}

# Retrieve one identifier. `requests` is an environment whose `n` counts every
# request made, one per REF page, so the caller can account for the pages
# spent on an identifier whose later page fails.
scopus_abstract_one <- function(id, by, view = NULL, include = character(),
                                api_key = NULL, inst_token = NULL,
                                requests = new.env()) {
  get_page <- function(startref = NULL) {
    req <- scopus_abstract_request(
      id, by, view = view, api_key = api_key, inst_token = inst_token,
      startref = startref
    )
    requests$n <- (requests$n %||% 0L) + 1L
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
    list(full = body[["abstracts-retrieval-response"]], resp = resp)
  }
  page <- get_page()
  full <- page$full
  # Under view = "REF", the response carries only `references`, with no
  # `coredata`; the identifying/abstract columns are then NA, which is
  # expected, the REF view being for reference retrieval alone.
  if (is.null(full[["coredata"]]) && is.null(full[["references"]])) {
    rlang::abort(
      "The 'Scopus' abstract response did not contain a `coredata` element.",
      class = c("scopus_error_malformed", "scopus_error")
    )
  }
  if (identical(view, "REF") && "references" %in% include) {
    paged <- scopus_page_references(full, get_page)
    full <- paged$full
    page$resp <- paged$resp %||% page$resp
  }
  list(
    row = scopus_abstract_row(id, full[["coredata"]] %||% list(), full = full, view = view, include = include),
    quota = tryCatch(scopus_quota(page$resp), error = function(e) NULL)
  )
}

# The REF view serves a bibliography a page at a time, about 40 references per
# request, and documents `startref` as the position a page starts from.
# As in pybliometrics, which has paged REF since its version 3.6, each later
# page starts one past the references held (startref = held + 1, read as
# one-based) and names no `refcount`: pybliometrics found that refcount leads
# to errors, and a live request with refcount = 200 was refused in October
# 2026. Elsevier's own guide gives startref a zero base. A zero-based server or
# one that ignores startref must not loop or duplicate, so paging stops on an
# empty page, on a page that adds no new reference, or after ceiling(n / k)
# pages, k being the first page's length. A list still short of its total is
# then warned about by scopus_parse_references(). `get_page(startref)` performs
# one request and returns the parsed response with the httr2 response.
scopus_page_references <- function(full, get_page) {
  bib <- full[["references"]]
  total <- suppressWarnings(as.integer(bib[["@total-references"]]))
  items <- scopus_listify(bib[["reference"]])
  k <- length(items)
  if (length(total) != 1L || is.na(total) || k == 0L || k >= total) {
    return(list(full = full, resp = NULL))
  }
  # A reference is matched on its `@id`, its position in the bibliography. One
  # without a usable `@id` is matched on its whole content, so a server that
  # ignores startref cannot slip the same references in twice, which would
  # also bring the count up to the total and silence the warning.
  reference_key <- function(x) {
    id <- if (is.list(x)) x[["@id"]] else NULL
    if (length(id) == 1L && is.atomic(id) && !is.na(id)) {
      return(paste0("@id:", id))
    }
    paste0("content:", paste(deparse(x), collapse = "\n"))
  }
  seen <- vapply(items, reference_key, character(1))
  resp <- NULL
  pages <- 1L
  while (length(items) < total && pages < ceiling(total / k)) {
    page <- get_page(startref = length(items) + 1L)
    pages <- pages + 1L
    resp <- page$resp
    new <- scopus_listify(chained_get(page$full, c("references", "reference")))
    if (length(new) == 0L) break
    new_keys <- vapply(new, reference_key, character(1))
    fresh <- !(new_keys %in% seen | duplicated(new_keys))
    if (!any(fresh)) break
    items <- c(items, new[fresh])
    seen <- c(seen, new_keys[fresh])
  }
  full[["references"]][["reference"]] <- items
  list(full = full, resp = resp)
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
    row$authkeywords <- scopus_parse_optional(
      scopus_parse_authkeywords(full), "author keywords"
    )
  }
  if ("index_terms" %in% include) {
    row$idxterms <- scopus_parse_optional(
      scopus_parse_idxterms(full), "index keywords"
    )
  }
  if ("references" %in% include) {
    row$references <- list(scopus_parse_optional(
      scopus_parse_references(full, view), "reference list"
    ))
  }
  row
}

# Evaluate the parse of an optional, nested part of a response (either kind of
# keyword, or the references) and re-raise any error as a typed condition. The shape of
# these parts varies with Elsevier's XML-to-JSON conversion. A base R error
# from a shape not foreseen here escaped scopus_abstract()'s per-identifier
# handler and aborted the whole batch, and every resume of it. As a
# scopus_error it costs that identifier an NA row and a warning, and the row is
# not checkpointed, so a resumed run retries it.
scopus_parse_optional <- function(parse, what) {
  tryCatch(parse, error = function(e) {
    rlang::abort(
      sprintf(
        "The 'Scopus' abstract response carried its %s in a shape scopusflow cannot parse.",
        what
      ),
      class = c("scopus_error_malformed", "scopus_error"),
      parent = e
    )
  })
}

# Author keywords from an Abstract Retrieval response, joined "; " to match
# the `authors` column's convention. `authkeywords` may be absent, a single
# `author-keyword` object (a one-item array collapsed to a bare object, see
# scopus_listify()) or a list of them. Only entries carrying text are kept. An
# author-keyword object can arrive with its attribute alone, as
# {"@_fa": "true"} (pybliometrics issue #436), and a lone one used to be read
# field by field, giving the keyword "true".
scopus_parse_authkeywords <- function(full) {
  ak <- full[["authkeywords"]]
  scopus_join_terms(if (is.list(ak)) ak[["author-keyword"]] %||% ak else ak)
}

# Index keywords from a FULL-view response, joined "; " as the author keywords
# are. `idxterms` holds `mainterm`, a list of objects whose text is under "$"
# beside attributes such as "@weight" and "@candidate", or one such object
# sent bare. pybliometrics reads the same path (AbstractRetrieval.idxterms in
# its 4.4.1 release). A null or absent `idxterms` gives NA, and an entry without
# text is dropped, as for the author keywords.
scopus_parse_idxterms <- function(full) {
  it <- full[["idxterms"]]
  scopus_join_terms(if (is.list(it)) it[["mainterm"]] else NULL)
}

# The text of a list of keyword entries, joined "; ", or NA when none carries
# any. An entry is an object holding its text under "$", a bare string, or one
# such object sent bare (see scopus_listify()). Entries without text are
# dropped.
scopus_join_terms <- function(items) {
  text <- vapply(scopus_listify(items), function(x) {
    value <- if (is.list(x)) x[["$"]] else x
    if (length(value) == 1L) as.character(value) else NA_character_
  }, character(1))
  text <- text[!is.na(text) & nzchar(text)]
  if (length(text) == 0L) NA_character_ else paste(text, collapse = "; ")
}

# Elsevier's XML-to-JSON conversion sends a one-item array as a bare object. A
# list the API documents as an array can then arrive parsed as a named list
# (one JSON object), and iterating over it walks the object's fields. This
# gives each such list one shape to iterate. An absent or empty list becomes an
# empty one, and so does an empty object, which carries no item and would
# otherwise add a reference or an author whose every field is missing. A bare
# object is wrapped as a one-item list, and anything else is returned
# unchanged.
scopus_listify <- function(x) {
  if (length(x) == 0L) {
    list()
  } else if (is.list(x) && !is.null(names(x))) {
    list(x)
  } else {
    x
  }
}

# Structured references from an Abstract Retrieval response, as a data frame
# (one row per cited work), for the `references` list-column. The raw shape
# differs by view: REF view nests them under `references$reference`, FULL
# view under `item$bibrecord$tail$bibliography$reference`, and per-reference
# field names differ between the two (see scopus_abstract()'s documentation).
# REF names a cited work's title and source `title` and `sourcetitle`, where
# FULL uses `ref-title` and `ref-sourcetitle`, and pybliometrics reads either
# (abstract_retrieval.py in its 4.4.1 release). Only the FULL names used to be
# read here, which most likely accounts for the NA `title` and `source` of
# every REF reference seen in development testing against a live key.
scopus_parse_references <- function(full, view) {
  empty <- data.frame(
    position = character(), id = character(), doi = character(),
    title = character(), authors = character(), source = character(),
    year = integer(), citedbycount = integer(), stringsAsFactors = FALSE
  )
  if (identical(view, "REF")) {
    bib <- full[["references"]]
    total <- suppressWarnings(as.integer(bib[["@total-references"]]))
  } else {
    bib <- chained_get(full, c("item", "bibrecord", "tail", "bibliography"))
    total <- suppressWarnings(as.integer(bib[["@refcount"]]))
  }
  # A lone reference arrives as a bare object in either view.
  items <- scopus_listify(bib[["reference"]])
  if (length(items) == 0L) {
    return(empty)
  }
  rows <- lapply(items, scopus_parse_one_reference, view = view)
  out <- do.call(rbind, c(rows, list(stringsAsFactors = FALSE)))
  # `total` is integer(0) when the response omits its count attribute
  # altogether, which `!is.na()` alone would pass straight into `if` as a
  # zero-length condition and abort the whole batch on one malformed document.
  if (length(total) == 1L && !is.na(total) && nrow(out) != total) {
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
    author_names <- scopus_reference_authors(authors, "ce:given-name")
    doi <- info[["ce:doi"]]
    ref_id <- info[["scopus-id"]]
    # REF names a cited work's title and source `title` and `sourcetitle`.
    # The FULL names are tried first, as pybliometrics tries them, and neither
    # column is filled from the other.
    title <- chained_get(info, c("ref-title", "ref-titletext")) %||% chained_get(info, "title")
    source <- chained_get(info, "ref-sourcetitle") %||% chained_get(info, "sourcetitle")
    citedbycount <- suppressWarnings(as.integer(info[["citedby-count"]]))
    year <- scopus_parse_year(info[["ref-coverdate"]] %||% info[["prism:coverDate"]])
  } else {
    authors <- chained_get(info, c("ref-authors", "author"))
    author_names <- scopus_reference_authors(authors, "ce:initials")
    ids <- chained_get(info, c("refd-itemidlist", "itemid")) %||% list()
    doi <- scopus_select_itemid(ids, "DOI")
    ref_id <- scopus_select_itemid(ids, "SGR")
    title <- chained_get(info, c("ref-title", "ref-titletext"))
    source <- chained_get(info, "ref-sourcetitle")
    citedbycount <- NA_integer_
    year <- suppressWarnings(as.integer(chained_get(info, c("ref-publicationyear", "@first"))))
  }
  data.frame(
    position = as.character(item[["@id"]] %||% NA_character_),
    id = as.character(ref_id %||% NA_character_),
    doi = as.character(doi %||% NA_character_),
    title = as.character(title %||% NA_character_),
    authors = if (length(author_names) == 0L) NA_character_ else paste(author_names, collapse = "; "),
    source = as.character(source %||% NA_character_),
    year = if (length(year) == 0L) NA_integer_ else year,
    citedbycount = if (length(citedbycount) == 0L) NA_integer_ else citedbycount,
    stringsAsFactors = FALSE
  )
}

# "Surname, Given" for each author of one cited reference. The given names sit
# in `ce:given-name` under REF and in `ce:initials` under FULL, and a lone
# author arrives as a bare object.
scopus_reference_authors <- function(authors, given_field) {
  vapply(scopus_listify(authors), function(a) {
    paste(stats::na.omit(c(a[["ce:surname"]], a[[given_field]])), collapse = ", ")
  }, character(1))
}

# Pick the itemid entry of a given @idtype from a FULL-view refd-itemidlist,
# which may be a single object or a list of them.
scopus_select_itemid <- function(ids, idtype) {
  for (item in scopus_listify(ids)) {
    if (is.list(item) && identical(item[["@idtype"]], idtype)) {
      return(item[["$"]])
    }
  }
  NULL
}

# Walk a chain of list indices, returning NULL as soon as any step is absent,
# where indexing straight through a partially-missing nested path would error.
chained_get <- function(x, path) {
  for (key in path) {
    if (is.null(x) || !is.list(x)) return(NULL)
    x <- x[[key]]
  }
  x
}

#' @export
print.scopus_abstracts <- function(x, ...) {
  scopus_print_line("{.cls scopus_abstracts} ({nrow(x)} record{?s})")
  NextMethod()
  invisible(x)
}
