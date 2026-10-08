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
    # The Search API's WADL calls 403 an authorisation or entitlements error.
    # A spent quota is a 429 (see scopus_abort_quota_exceeded()).
    "403" = paste0(
      "Access to the 'Scopus' API was refused (HTTP 403). The key, the ",
      "institutional token or the network you are calling from is not ",
      "entitled to this resource or view."
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
  if (!is.null(resp) && scopus_quota_exceeded(resp)) {
    scopus_abort_quota_exceeded(quota, call = call)
  }
  rlang::abort(
    message = scopus_status_message(status),
    class = c(scopus_status_class(status), "scopus_error"),
    status = status,
    quota = quota,
    call = call
  )
}

# Abort because the key's weekly quota is spent: a 429 marked QUOTA_EXCEEDED
# (see scopus_quota_exceeded()). It is a subclass of scopus_error_rate_limit,
# so a handler written for the rate limit still catches it, and it is not
# retried, since the quota resets only days later.
scopus_abort_quota_exceeded <- function(quota, call = rlang::caller_env()) {
  rlang::abort(
    message = paste(
      "The 'Scopus' API key's weekly quota is used up (HTTP 429, QUOTA_EXCEEDED).",
      scopus_quota_reset_sentence(quota),
      "Cells and identifiers already retrieved are kept when `cache_dir` is set,",
      "so resume after the reset."
    ),
    class = c("scopus_error_quota_exceeded", "scopus_error_rate_limit", "scopus_error"),
    status = 429L,
    quota = quota,
    call = call
  )
}

# "It resets at <time> UTC.", from a parsed quota, or a sentence saying the
# response gave no reset time.
scopus_quota_reset_sentence <- function(quota) {
  reset <- quota$reset
  if (length(reset) != 1L || is.na(reset)) {
    return("The response did not say when it resets.")
  }
  sprintf("It resets at %s UTC.", format(reset, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
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

# Abort because the host is unreachable (offline / DNS failure), or because it
# did not answer within the transfer timeout set by scopus_req_timeout(). A
# timeout keeps the offline class, so a handler written for that still catches
# it, but its message no longer suggests the caller is offline.
scopus_abort_offline <- function(parent = NULL, call = rlang::caller_env()) {
  if (scopus_is_timeout(parent)) {
    rlang::abort(
      message = sprintf(
        "The 'Scopus' API did not respond within %s seconds (option scopusflow.timeout).",
        format(getOption("scopusflow.timeout", 60))
      ),
      class = c("scopus_error_timeout", "scopus_error_offline", "scopus_error"),
      parent = parent,
      call = call
    )
  }
  rlang::abort(
    message = "Could not reach the 'Scopus' API. The service may be unavailable, or you may be offline.",
    class = c("scopus_error_offline", "scopus_error"),
    parent = parent,
    call = call
  )
}

# Whether a transport failure, or a condition it wraps, is curl's timeout. The
# curl package raises it as curl_error_operation_timedout, with libcurl's
# message "Timeout was reached", which is also matched in case the class
# changes.
scopus_is_timeout <- function(cnd) {
  while (inherits(cnd, "condition")) {
    if (inherits(cnd, "curl_error_operation_timedout") ||
        grepl("Timeout was reached", conditionMessage(cnd), fixed = TRUE)) {
      return(TRUE)
    }
    cnd <- cnd$parent
  }
  FALSE
}
