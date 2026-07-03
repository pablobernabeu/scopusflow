#' Assemble a minimal, cross-tool corpus with keywords and references
#'
#' Takes a [scopus_records()] tibble, such as the output of [scopus_fetch()] or
#' [scopus_fetch_plan()], and enriches it with author keywords and structured
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
#'   [scopus_abstract()]. `"FULL"` is recommended: in development, it
#'   returned a complete, correctly counted reference list for every document
#'   tried, while `"REF"` returned an inconsistent, sometimes-truncated
#'   subset (see [scopus_abstract()]'s documentation for the details and for
#'   the entitlement each view needs).
#' @param cache_dir,resume As in [scopus_abstract()]: an optional directory
#'   for per-identifier cache files, and whether an existing one is reused.
#'   Worth setting for anything beyond a handful of records, since this
#'   performs one Abstract Retrieval request per record, against its own,
#'   smaller weekly quota.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble with columns `id` (the identifier `records` was looked up
#'   by), `title`, `year`, `keywords` (a list-column: a character vector of
#'   the document's author keywords, split out of [scopus_abstract()]'s
#'   joined `authkeywords` string, empty when the document has none or the
#'   field is unavailable) and `references` (a list-column: each entry is the
#'   `references` data frame [scopus_abstract()] returns for that document,
#'   with one row per cited work). A record in `records` whose identifier is
#'   `NA` is dropped, with a warning naming how many.
#' @section API access:
#' This performs one Abstract Retrieval request per usable record, on top of
#' whatever retrieved `records` in the first place; see [scopus_abstract()]'s
#' *API access* section for the entitlement `view = "FULL"`/`"REF"` needs and
#' how a 403 is handled.
#' @seealso [scopus_abstract()], [as_bibliometrix()]
#' @examplesIf scopusflow::scopus_has_key()
#' # Costs one Abstract Retrieval request per record, against a smaller,
#' # separate weekly quota from Search; see the API access section above.
#' recs <- scopus_fetch("DOI(10.1038/nature14539)", max_results = 1)
#' corpus <- scopus_corpus(recs)
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
                          verbose = FALSE) {
  by <- rlang::arg_match(by)
  view <- rlang::arg_match(view)
  required <- c(by, "title", "year")
  if (!is.data.frame(records) || !all(required %in% names(records))) {
    rlang::abort(
      sprintf(
        "`records` must be a data frame with %s columns (as scopus_fetch()/scopus_fetch_plan() return).",
        paste(sprintf('"%s"', required), collapse = ", ")
      ),
      class = "scopus_error_bad_input"
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
    rlang::abort("`records` has no usable identifiers to look up.", class = "scopus_error_bad_input")
  }
  records <- records[keep, , drop = FALSE]

  ab <- scopus_abstract(
    ids[keep], by = by, view = view, include = c("references", "keywords"),
    cache_dir = cache_dir, resume = resume,
    api_key = api_key, inst_token = inst_token, verbose = verbose
  )

  keywords <- lapply(ab$authkeywords, function(x) {
    if (length(x) != 1L || is.na(x)) character() else trimws(strsplit(x, ";", fixed = TRUE)[[1]])
  })

  tibble::tibble(
    id = ab$id,
    title = records$title,
    year = records$year,
    keywords = keywords,
    references = ab$references
  )
}
