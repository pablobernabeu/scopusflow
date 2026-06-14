#' Build a field-tagged 'Scopus' query
#'
#' Combines several terms into one 'Scopus' query string, optionally wrapping
#' each in a field tag and joining them with a boolean operator. It is a tidier
#' alternative to pasting query fragments together by hand, which is where
#' field-tag and bracket mistakes tend to creep in.
#'
#' @param ... Character terms to combine, for example `"language learning"` and
#'   `"effect size"`.
#' @param .op The boolean operator joining the terms, one of `"AND"`, `"OR"` or
#'   `"AND NOT"`.
#' @param .field Optional field tag applied to every term (see
#'   [scopus_field_tags()]).
#' @return A length-one character string suitable for [scopus_count()],
#'   [scopus_fetch()] or the `query` of [scopus_plan()].
#' @seealso [scopus_field_tags()], [scopus_plan()]
#' @examples
#' scopus_query("language learning", "effect size", .field = "TITLE-ABS-KEY")
#' scopus_query("CRISPR", "Cas9", .op = "OR")
#' @export
scopus_query <- function(..., .op = c("AND", "OR", "AND NOT"), .field = NULL) {
  .op <- rlang::arg_match(.op)
  terms <- c(...)
  if (!is.character(terms) || length(terms) == 0L || anyNA(terms) ||
      !all(nzchar(trimws(terms)))) {
    rlang::abort(
      "`...` must be one or more non-empty character terms.",
      class = "scopus_error_bad_input"
    )
  }
  .field <- scopus_check_field(.field)
  wrapped <- vapply(terms, function(t) scopus_wrap_field(t, .field), character(1))
  paste(wrapped, collapse = paste0(" ", .op, " "))
}
