#' Locate the 'Scopus' API key and institutional token
#'
#' `scopus_has_key()` reports whether an API key can be found, without revealing
#' it. The key itself is resolved internally and is never printed by the
#' package.
#'
#' @details
#' The key is looked up first from the `api_key` argument of whichever function
#' is being called, then from the `scopusflow.api_key` option, and finally from
#' the `SCOPUS_API_KEY` environment variable. An optional institutional token,
#' used for off-campus access to subscriber content, is resolved the same way
#' from the `inst_token` argument, the `scopusflow.inst_token` option, or the
#' `SCOPUS_INST_TOKEN` environment variable.
#'
#' A key is a secret. The safest home for it is `~/.Renviron`, as in
#' `SCOPUS_API_KEY=xxxx`, rather than a script, and it should stay out of version
#' control.
#'
#' @return A length-one logical that is safe to print, `TRUE` when a non-empty
#'   key is available and `FALSE` otherwise.
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
