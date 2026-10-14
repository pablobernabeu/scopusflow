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
#'   by), `title`, `year`, `keywords` (a list-column: a character vector of
#'   the document's keywords of the kind `keywords` names, split out of
#'   [scopus_abstract()]'s joined `authkeywords` and `idxterms` strings, empty
#'   when the document has none, the field is unavailable or `view = "REF"`)
#'   and `references` (a list-column: each entry is the
#'   `references` data frame [scopus_abstract()] returns for that document,
#'   with one row per cited work). A record in `records` whose identifier is
#'   `NA` is dropped, with a warning naming how many.
#' @section API access:
#' This performs one Abstract Retrieval request per usable record, or one per
#' page of references under `view = "REF"`, on top of whatever retrieved
#' `records` in the first place; see [scopus_abstract()]'s
#' *API access* section for the entitlement `view = "FULL"`/`"REF"` needs and
#' how a 403 is handled.
#' @seealso [scopus_abstract()], [as_bibliometrix()]
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
#' # neither keywords nor bibliographies, so those are illustrative.
#' docs <- example_records[order(-example_records$citations), ][1:2, ]
#' corpus <- tibble::tibble(
#'   id = docs$doi,
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

  tibble::tibble(
    id = ab$id,
    title = records$title,
    year = records$year,
    keywords = unname(terms),
    references = ab$references
  )
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
