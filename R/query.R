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
#' A term that already opens with a field tag is refused when `.field` is
#' given, because the API rejects one tag nested inside another.
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
  call <- rlang::current_env()
  wrapped <- vapply(terms, function(t) scopus_wrap_field(t, .field, call = call),
                    character(1))
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

# Offline query checks --------------------------------------------------------
#
# scopus_check_query() runs these before any request. Each one reports a query
# that cannot do what it appears to ask, so none fires on legitimate input. The
# Python twin's _query_problems() reports the same codes with the same
# messages, and both are held to tests/testthat/fixtures/query-checks.json.
# The messages name no function or argument, so they read the same in either
# language.
scopus_query_messages <- c(
  unbalanced = paste(
    "The query's brackets, quotation marks or braces do not balance.",
    "Every ( needs a matching ), and every \" or { needs a closing \" or }.",
    "Brackets inside a phrase are read as text."
  ),
  # rscopus issue #50 shows the Search API ignoring LIMIT-TO() without an
  # error: 55 records against 36 for the same limit written as SUBJAREA().
  refinement = paste(
    "The query contains LIMIT-TO() or EXCLUDE(), which belong to the Scopus",
    "web interface's refinement panel. The Search API does not apply them, so",
    "the search would run unfiltered (pybliometrics documents LIMIT-TO() as",
    "affecting the display only). Write the limit as a search field instead,",
    "such as DOCTYPE(ar), LANGUAGE(english), SUBJAREA(PSYC), SRCTYPE(j) or",
    "PUBYEAR > 2015."
  ),
  # A live request for TITLE-ABS-KEY(TITLE(x)) failed with HTTP 400 (see
  # dev/design-notes.md, "Concept and intersection sizing").
  double_field = paste(
    "The query already opens with a field tag, so wrapping it in another would",
    "nest one tag inside the other, which the API rejects. Choose no field tag",
    "to send the query as written."
  ),
  # A warning, since how the Search API treats INDEXTERMS() has not been
  # observed. pybliometrics' ScopusSearch documentation names it, with
  # LIMIT-TO(), as the only advanced-search fields that do not work.
  indexterms = paste(
    "The query uses INDEXTERMS(), which pybliometrics documents as not working",
    "through the Search API. KEY() can stand in for it, since it searches",
    "author keywords, index terms, trade names and chemical names together."
  )
)

# Matched against the query with its phrases blanked out and its ASCII letters
# upper-cased, so the operator is found in any case but never inside a phrase.
# The look-behind stands for \b at the start of a word. Both twins write it out
# in ASCII, because PCRE's \b and Python's differ on a letter such as an
# accented e.
scopus_refinement_pattern <- paste0(
  "(?<![A-Z0-9_])(?:LIMIT-TO|EXCLUDE)", scopus_space, "*\\(",
  scopus_space, "*[A-Z-]+", scopus_space, "*,"
)
scopus_indexterms_pattern <- paste0(
  "(?<![A-Z0-9_])INDEXTERMS", scopus_space, "*\\("
)

# TRUE when `query` opens with a field tag: a tag written against its bracket,
# as in TITLE(x), or one of the common tags of scopus_field_tags() followed by
# white space and a bracket, as the web interface writes TITLE-ABS-KEY ( x ).
# Any capitalised word could open a spaced group, as in HIV (prevention OR
# treatment), which is a search term and a bracketed group. The spaced form is
# therefore recognised only for the common tags.
scopus_opens_with_tag <- function(query) {
  spaced <- paste(scopus_field_tags()$tag, collapse = "|")
  pattern <- paste0(
    "^", scopus_space, "*(?:[A-Z][A-Z-]*\\(|(?:", spaced, ")",
    scopus_space, "+\\()"
  )
  grepl(pattern, query, perl = TRUE)
}

# The problems scopus_check_query() acts on, as a data frame with one row per
# problem found (columns `code`, `level` and `message`), in a fixed order. The
# walk is the one scopus_first_group_end() makes: a quoted or braced phrase is
# text, so its brackets are never counted, and an unclosed phrase runs to the
# end of the string.
scopus_query_problems <- function(query, field = NULL) {
  chars <- strsplit(query, "", fixed = TRUE)[[1L]]
  n <- length(chars)
  masked <- chars
  depth <- 0L
  balanced <- TRUE
  i <- 1L
  while (i <= n) {
    ch <- chars[i]
    if (ch == "\"" || ch == "{") {
      close <- if (ch == "\"") "\"" else "}"
      skip <- match(close, chars[i + seq_len(n - i)])
      if (is.na(skip)) {
        balanced <- FALSE
        end <- n
      } else {
        end <- i + skip
      }
      masked[i:end] <- " "
      i <- end + 1L
      next
    }
    if (ch == "(") {
      depth <- depth + 1L
    } else if (ch == ")") {
      if (depth == 0L) balanced <- FALSE else depth <- depth - 1L
    }
    i <- i + 1L
  }
  # chartr() leaves every character outside the two ASCII alphabets alone,
  # as the Python twin's translation table does.
  masked <- chartr(
    paste(letters, collapse = ""), paste(LETTERS, collapse = ""),
    paste(masked, collapse = "")
  )
  found <- c(
    unbalanced = !balanced || depth != 0L,
    refinement = grepl(scopus_refinement_pattern, masked, perl = TRUE),
    double_field = !is.null(field) && scopus_opens_with_tag(query),
    indexterms = grepl(scopus_indexterms_pattern, masked, perl = TRUE)
  )
  codes <- names(found)[found]
  data.frame(
    code = codes,
    level = c("error", "warning")[1L + (codes == "indexterms")],
    message = unname(scopus_query_messages[codes]),
    stringsAsFactors = FALSE
  )
}
