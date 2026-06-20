#' Retrieve abstracts and richer metadata
#'
#' Fetches the abstract text and core metadata for one or more records from the
#' Elsevier 'Scopus' Abstract Retrieval API. This complements the Search API used
#' elsewhere in the package: a search returns many records with a few fields each,
#' whereas this returns the fuller record, including the abstract, for a known
#' identifier.
#'
#' @param ids Character vector of identifiers to look up, either Digital Object
#'   Identifiers or 'Scopus' record identifiers (with or without the
#'   `"SCOPUS_ID:"` prefix), according to `by`.
#' @param by Either `"doi"` or `"scopus_id"`, the kind of identifier in `ids`.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, progress is reported.
#' @return A tibble of class `scopus_abstracts`, one row per identifier, with
#'   columns `id` (the input identifier), `scopus_id`, `doi`, `title`, `abstract`,
#'   `publication`, `year` and `citations`. A field the API does not return is
#'   `NA`. An identifier that cannot be retrieved (for example one not in
#'   'Scopus') yields a row of `NA`s with a warning, so a batch is not lost to a
#'   single failure.
#' @section API access:
#' This performs one request per identifier and requires a valid API key and
#' internet access; full-text abstract access can also depend on your
#' entitlement. See the *API access* section of [scopus_count()] for the
#' conditions that may be raised.
#' @seealso [scopus_fetch()], [scopus_extract_dois()]
#' @examplesIf scopusflow::scopus_has_key()
#' scopus_abstract("10.1038/s41586-019-0001-1")
#' @export
scopus_abstract <- function(ids,
                            by = c("doi", "scopus_id"),
                            api_key = NULL,
                            inst_token = NULL,
                            verbose = FALSE) {
  by <- rlang::arg_match(by)
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

  rows <- lapply(seq_along(ids), function(i) {
    if (verbose) cli::cli_inform("Retrieving {i}/{length(ids)}: {ids[i]}.")
    tryCatch(
      scopus_abstract_one(ids[i], by, api_key = api_key, inst_token = inst_token),
      scopus_error = function(e) {
        cli::cli_warn("Could not retrieve {.val {ids[i]}}: {conditionMessage(e)}")
        scopus_abstract_row(ids[i], list())
      }
    )
  })
  out <- do.call(rbind, rows)
  tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_abstracts")
}

# Build (but do not perform) an Abstract Retrieval request for one identifier.
scopus_abstract_request <- function(id, by, api_key = NULL, inst_token = NULL,
                                    call = rlang::caller_env()) {
  key <- scopus_key(api_key, call = call)
  token <- scopus_inst_token(inst_token)
  base <- getOption("scopusflow.abstract_url",
                    "https://api.elsevier.com/content/abstract")
  # The DOI may itself contain slashes, which the API expects literally, so the
  # path is assembled directly rather than escaped segment by segment.
  req <- httr2::request(paste0(base, "/", by, "/", id))
  req <- httr2::req_user_agent(req, scopus_user_agent())
  req <- httr2::req_headers(
    req, `X-ELS-APIKey` = key, Accept = "application/json",
    .redact = "X-ELS-APIKey"
  )
  if (!is.null(token)) {
    req <- httr2::req_headers(req, `X-ELS-Insttoken` = token, .redact = "X-ELS-Insttoken")
  }
  req
}

scopus_abstract_one <- function(id, by, api_key = NULL, inst_token = NULL) {
  req <- scopus_abstract_request(id, by, api_key = api_key, inst_token = inst_token)
  resp <- scopus_perform(req)
  body <- jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
  core <- body[["abstracts-retrieval-response"]][["coredata"]]
  if (is.null(core)) {
    rlang::abort(
      "The 'Scopus' abstract response did not contain a `coredata` element.",
      class = c("scopus_error_malformed", "scopus_error")
    )
  }
  scopus_abstract_row(id, core)
}

scopus_abstract_row <- function(id, core) {
  citations <- scopus_field(core, "citedby-count")
  data.frame(
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
}

#' @export
print.scopus_abstracts <- function(x, ...) {
  cli::cli_text("{.cls scopus_abstracts} ({nrow(x)} record{?s})")
  NextMethod()
  invisible(x)
}
