#' Build a field-tagged 'Scopus' query
#'
#' Combines several terms into one 'Scopus' query string, optionally wrapping
#' each in a field tag and joining them with a boolean operator. It is a tidier
#' alternative to pasting query fragments together by hand, which is where
#' field-tag and bracket mistakes tend to creep in.
#'
#' Each term is trimmed and, given `.field`, wrapped in that tag, whose
#' brackets hold the term together. Without a field tag, a term of several
#' words is put in brackets before two or more terms are joined, because
#' 'Scopus' joins the words of an unquoted term with AND. Joined bare,
#' `machine learning OR deep learning` would read as
#' `machine AND (learning OR deep) AND learning`. A term that is already one
#' operand is left as written: a quoted `"..."` phrase, a braced `{...}`
#' phrase, a bracketed group or a single field-tagged group such as
#' `TITLE(deep learning)`. Single words are never bracketed, so
#' `scopus_query("CRISPR", "Cas9", .op = "OR")` stays `CRISPR OR Cas9`, and a
#' query composed by an earlier call keeps its meaning when it is joined again.
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
#' scopus_query("climate change", "adaptation", .field = "TITLE-ABS-KEY")
#' scopus_query("graphene", "supercapacitor", .op = "AND")
#' scopus_query("CRISPR", "Cas9", "Cas12", .op = "OR")
#' # Without a field tag, multi-word terms are bracketed and phrases kept as written.
#' scopus_query("machine learning", "deep learning", .op = "OR")
#' scopus_query('"heart attack"', '"myocardial infarction"', .op = "OR")
#' @export
scopus_query <- function(..., .op = c("AND", "OR", "AND NOT"), .field = NULL) {
  .op <- scopus_match_arg(.op, c("AND", "OR", "AND NOT"))
  terms <- c(...)
  if (!is.character(terms) || length(terms) == 0L || anyNA(terms) ||
      !all(nzchar(scopus_trim(terms)))) {
    scopus_abort_bad_input(
      "`...` must be one or more non-empty character terms."
    )
  }
  .field <- scopus_check_field(.field)
  terms <- scopus_trim(terms)
  if (is.null(.field) && length(terms) > 1L) {
    terms <- vapply(terms, scopus_group_term, character(1), USE.NAMES = FALSE)
  }
  wrapped <- vapply(terms, function(t) scopus_wrap_field(t, .field), character(1))
  paste(wrapped, collapse = paste0(" ", .op, " "))
}

# The white space of the Python twin, the 29 characters its str.isspace()
# accepts, so that trimming and the test for a term of several words agree
# between the twins. trimws() on its own strips only spaces, tabs, carriage
# returns and line feeds, and "[[:space:]]" misses the no-break space on
# Windows. With either, a term pasted from a web page would be trimmed and
# bracketed in Python alone. The \u escapes make the pattern UTF-8, so R
# matches it by code point in every locale.
scopus_space <- "[\\t-\\r\\x{1c}-\\x{20}\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]"

# Trim a term as Python's str.strip() trims it.
scopus_trim <- function(x) {
  trimws(x, whitespace = scopus_space)
}

# Bracket a term of several words, so a join treats it as one operand. The rule
# is the Python twin's _group_term(), and the two are held to the same expected
# strings by tests/testthat/fixtures/query-grouping.json.
scopus_group_term <- function(term) {
  if (!grepl(scopus_space, term, perl = TRUE) || scopus_is_one_operand(term)) {
    return(term)
  }
  sprintf("(%s)", term)
}

# TRUE when `term` already binds as a single operand: one quoted or braced
# phrase, one bracketed group or one field-tagged group.
scopus_is_one_operand <- function(term) {
  chars <- strsplit(term, "", fixed = TRUE)[[1L]]
  n <- length(chars)
  if (chars[1L] %in% c("\"", "{")) {
    close <- if (chars[1L] == "\"") "\"" else "}"
    return(identical(match(close, chars[-1L]) + 1L, n))
  }
  # perl = TRUE reads the range by code point, as Python's re does. A
  # locale-dependent range could let a lower-case tag through in R alone.
  if (chars[1L] == "(" || grepl("^[A-Z][A-Z-]*\\(", term, perl = TRUE)) {
    return(identical(scopus_first_group_end(chars), n))
  }
  FALSE
}

# The position of the bracket closing the first opening bracket in `chars`, or
# NA when it never closes. Brackets inside a quoted or braced phrase are text,
# never syntax, and an unclosed phrase runs to the end of the string.
scopus_first_group_end <- function(chars) {
  n <- length(chars)
  depth <- 0L
  i <- 1L
  while (i <= n) {
    ch <- chars[i]
    if (ch == "\"" || ch == "{") {
      close <- if (ch == "\"") "\"" else "}"
      skip <- match(close, chars[i + seq_len(n - i)])
      if (is.na(skip)) {
        return(NA_integer_)
      }
      i <- i + skip + 1L
      next
    }
    if (ch == "(") {
      depth <- depth + 1L
    } else if (ch == ")" && depth > 0L) {
      depth <- depth - 1L
      if (depth == 0L) {
        return(i)
      }
    }
    i <- i + 1L
  }
  NA_integer_
}
