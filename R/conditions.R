# Internal condition system -------------------------------------------------
#
# All errors raised by scopusflow inherit from the parent class
# `scopus_error`, which itself inherits from `rlang_error`/`error`. This lets
# callers catch a whole family of problems (for example, with
# `tryCatch(scopus_error = ...)`) or respond to a specific status. None of these
# helpers are exported. They are documented here for maintainers.
#
# Invalid arguments are raised through scopus_abort_bad_input(), and choices
# among fixed values are matched through scopus_match_arg(), so that no input
# error can leave the hierarchy. Before both existed, 66 sites raised
# `scopus_error_bad_input` on its own and the argument matching raised bare
# rlang errors, so a `scopus_error` handler missed every input error.

# Abort because an argument is invalid. `...` passes further fields to
# rlang::abort(). An input error will not succeed on retry, which is why it
# carries its own subclass beneath `scopus_error`.
scopus_abort_bad_input <- function(message, ..., call = rlang::caller_env()) {
  rlang::abort(
    message = message,
    class = c("scopus_error_bad_input", "scopus_error"),
    ...,
    call = call
  )
}

# rlang::arg_match() with its failure moved into the hierarchy. `values` is
# passed explicitly because arg_match() would otherwise read the choices from
# this helper's own formals. Callers pass the same vector as the formal's
# default, and a mismatch shows at once, because a call that leaves the
# argument at its default then fails to match. The rlang error is re-signalled
# whole, with the two classes prepended, so its message, bullets, call and
# backtrace are unchanged.
scopus_match_arg <- function(arg, values, error_arg = rlang::caller_arg(arg),
                             error_call = rlang::caller_env()) {
  # Forced first, so that an error raised while evaluating the caller's
  # expression keeps its own class and is not relabelled as bad input.
  force(arg)
  tryCatch(
    rlang::arg_match(arg, values, error_arg = error_arg, error_call = error_call),
    rlang_error = function(e) {
      class(e) <- c("scopus_error_bad_input", "scopus_error", class(e))
      rlang::cnd_signal(e)
    }
  )
}

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
    "414" = "The request URI was too long (HTTP 414). Try a shorter query.",
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

# Abort because no API key is available. Raised through cli_abort(), which
# wraps rlang::abort() and so leaves the condition classes unchanged. Calling
# rlang::abort() directly would print the message's inline cli spans as raw
# markup.
scopus_abort_no_key <- function(call = rlang::caller_env()) {
  cli::cli_abort(
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
    message = "Could not reach the 'Scopus' API. The service may be unavailable, or you may be offline.",
    class = c("scopus_error_offline", "scopus_error"),
    parent = parent,
    call = call
  )
}
