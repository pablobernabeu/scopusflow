# Internal condition system -------------------------------------------------
#
# All errors raised by scopusflow inherit from the parent class
# `scopus_error`, which itself inherits from `rlang_error`/`error`. This lets
# callers catch a whole family of problems (for example, with
# `tryCatch(scopus_error = ...)`) or respond to a specific status. None of these
# helpers are exported; they are documented here for maintainers.

# Map an HTTP status code to a scopusflow condition subclass.
scopus_status_class <- function(status) {
  switch(
    as.character(status),
    "400" = "scopus_error_bad_request",
    "401" = "scopus_error_unauthorized",
    "403" = "scopus_error_forbidden",
    "404" = "scopus_error_not_found",
    "413" = "scopus_error_payload_too_large",
    "414" = "scopus_error_uri_too_long",
    "429" = "scopus_error_rate_limit",
    "scopus_error_server"
  )
}

# Human-readable default message for each status.
scopus_status_message <- function(status) {
  switch(
    as.character(status),
    "400" = "The 'Scopus' API rejected the request as malformed (HTTP 400).",
    "401" = "The 'Scopus' API key is missing or invalid (HTTP 401).",
    "403" = paste0(
      "Access to the 'Scopus' API was refused (HTTP 403). This usually means ",
      "the quota is exhausted or your key lacks the required entitlement."
    ),
    "404" = "The requested 'Scopus' resource was not found (HTTP 404).",
    "413" = "The request payload was too large (HTTP 413).",
    "414" = "The request URI was too long (HTTP 414); shorten the query.",
    "429" = "The 'Scopus' API rate limit was exceeded (HTTP 429).",
    sprintf("The 'Scopus' API returned a server error (HTTP %s).", status)
  )
}

# Abort with a typed condition derived from an HTTP status.
#
# `resp` is an optional httr2 response used to attach quota metadata.
scopus_abort_status <- function(status, resp = NULL, call = rlang::caller_env()) {
  quota <- if (!is.null(resp)) tryCatch(scopus_quota(resp), error = function(e) NULL) else NULL
  rlang::abort(
    message = scopus_status_message(status),
    class = c(scopus_status_class(status), "scopus_error"),
    status = status,
    quota = quota,
    call = call
  )
}

# Abort because no API key is available.
scopus_abort_no_key <- function(call = rlang::caller_env()) {
  rlang::abort(
    message = c(
      "No 'Scopus' API key was found.",
      i = "Set the SCOPUS_API_KEY environment variable, the {.code scopusflow.api_key} option, or pass {.arg api_key}.",
      i = "Request a key at {.url https://dev.elsevier.com/}."
    ),
    class = c("scopus_error_no_key", "scopus_error"),
    call = call
  )
}

# Abort because the host is unreachable (offline / DNS failure).
scopus_abort_offline <- function(parent = NULL, call = rlang::caller_env()) {
  rlang::abort(
    message = "Could not reach the 'Scopus' API; the service may be unavailable or you may be offline.",
    class = c("scopus_error_offline", "scopus_error"),
    parent = parent,
    call = call
  )
}
