#' Locate the 'Scopus' API key and institutional token
#'
#' `scopus_has_key()` reports whether an API key can be found, without revealing
#' it. The key itself is resolved internally and is never printed by the
#' package.
#'
#' @details
#' The key is looked up, in order, from:
#' \enumerate{
#'   \item the `api_key` argument, when supplied to a function;
#'   \item the `scopusflow.api_key` option (`getOption("scopusflow.api_key")`);
#'   \item the `SCOPUS_API_KEY` environment variable.
#' }
#' An optional institutional token (for off-campus access to subscriber content)
#' is resolved the same way from the `inst_token` argument, the
#' `scopusflow.inst_token` option, or the `SCOPUS_INST_TOKEN` environment
#' variable.
#'
#' Keys are secrets: store them in `~/.Renviron` (for example,
#' `SCOPUS_API_KEY=xxxx`) rather than in scripts, and never commit them to
#' version control.
#'
#' @return `scopus_has_key()` returns a length-one logical, invisibly safe to
#'   print. `TRUE` if a non-empty key is available, otherwise `FALSE`.
#' @seealso [scopus_count()], [scopus_fetch()]
#' @examples
#' # Does the current session have a key configured?
#' scopus_has_key()
#' @export
scopus_has_key <- function() {
  key <- tryCatch(scopus_key(), error = function(e) "")
  nzchar(key)
}

# Internal: resolve the API key or abort with `scopus_error_no_key`.
scopus_key <- function(api_key = NULL, call = rlang::caller_env()) {
  key <- api_key %||% getOption("scopusflow.api_key") %||% Sys.getenv("SCOPUS_API_KEY", "")
  if (is.null(key) || !nzchar(key)) {
    scopus_abort_no_key(call = call)
  }
  key
}

# Internal: resolve an optional institutional token (may be empty).
scopus_inst_token <- function(inst_token = NULL) {
  token <- inst_token %||% getOption("scopusflow.inst_token") %||%
    Sys.getenv("SCOPUS_INST_TOKEN", "")
  if (is.null(token) || !nzchar(token)) NULL else token
}

# A local definition of the null-coalescing operator avoids importing it.
`%||%` <- function(x, y) if (is.null(x)) y else x
