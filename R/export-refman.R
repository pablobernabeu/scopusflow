# Export a record set to the reference-manager interchange formats RIS and
# BibTeX, so a Scopus search can be carried straight into Zotero, EndNote,
# Mendeley or a LaTeX bibliography. The formatting is pure and offline.

# Split the semicolon-joined authors string of one record into a character
# vector, dropping empty pieces. Returns character(0) when the field is NA or
# blank. The separator is the bare semicolon, since the Python twin joins author
# names without the space this package puts after it.
scopus_refman_authors <- function(authors) {
  if (length(authors) != 1L || is.na(authors)) {
    return(character())
  }
  parts <- trimws(strsplit(authors, ";", fixed = TRUE)[[1]])
  parts[nzchar(parts)]
}

# Fold internal whitespace (including embedded newlines, which would break RIS
# line structure) to single spaces. Vectorised over a whole column, since an
# export of a few thousand records used to pay for one call per field.
scopus_refman_clean <- function(x) {
  x <- as.character(x)
  out <- trimws(gsub("[[:space:]]+", " ", x))
  out[is.na(out)] <- ""
  out
}

# Escape the characters that are special in a BibTeX field value, over a whole
# column at once. The order stands in for the single character-by-character
# pass this replaced: the backslash is parked on a control character first, the
# braces are escaped before the replacements that introduce braces of their
# own, and the parked backslashes are expanded last, so nothing a replacement
# introduces is escaped a second time. A field already holding the control
# character, which no 'Scopus' field does, is escaped one character at a time.
scopus_bibtex_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  odd <- grepl("\001", x, fixed = TRUE)
  if (any(odd)) {
    x[odd] <- vapply(x[odd], scopus_bibtex_escape_one, character(1),
                     USE.NAMES = FALSE)
  }
  y <- x[!odd]
  y <- gsub("\\", "\001", y, fixed = TRUE)
  for (ch in c("{", "}", "&", "%", "$", "#", "_")) {
    y <- gsub(ch, paste0("\\", ch), y, fixed = TRUE)
  }
  y <- gsub("~", "\\textasciitilde{}", y, fixed = TRUE)
  y <- gsub("^", "\\textasciicircum{}", y, fixed = TRUE)
  y <- gsub("\001", "\\textbackslash{}", y, fixed = TRUE)
  x[!odd] <- y
  x
}

# The character-by-character form, kept for the one input the vectorised pass
# cannot park a backslash on.
scopus_bibtex_escape_one <- function(x) {
  map <- c(
    "\\" = "\\textbackslash{}", "&" = "\\&", "%" = "\\%", "$" = "\\$",
    "#" = "\\#", "_" = "\\_", "{" = "\\{", "}" = "\\}",
    "~" = "\\textasciitilde{}", "^" = "\\textasciicircum{}"
  )
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  hit <- chars %in% names(map)
  chars[hit] <- map[chars[hit]]
  paste(chars, collapse = "")
}

# A base citation key for one record: first author surname plus year, reduced to
# alphanumerics, falling back to the Scopus identifier then a constant.
scopus_bibtex_key <- function(authors, year, scopus_id) {
  auth <- scopus_refman_authors(authors)
  surname <- if (length(auth) > 0L) {
    tolower(gsub("[^A-Za-z0-9]", "", strsplit(auth[1], "[ ,]")[[1]][1]))
  } else {
    ""
  }
  id <- if (length(scopus_id) == 1L && !is.na(scopus_id)) {
    gsub("[^A-Za-z0-9]", "", scopus_id)
  } else {
    ""
  }
  if (nzchar(surname)) {
    paste0(surname, if (!is.na(year)) as.character(year) else "")
  } else if (nzchar(id)) {
    paste0("scopus", id)
  } else {
    "scopusrecord"
  }
}

# Make a vector of base keys unique: the first use of a base is kept as-is, and
# later repeats gain a suffix, so a multi-record export never emits duplicate
# BibTeX keys (which biber rejects and bibtex silently drops).
scopus_disambiguate <- function(keys) {
  counts <- new.env(parent = emptyenv())
  vapply(keys, function(k) {
    n <- counts[[k]]
    n <- if (is.null(n)) 0L else n
    counts[[k]] <- n + 1L
    if (n == 0L) k else if (n <= 26L) paste0(k, letters[n]) else paste0(k, n)
  }, character(1), USE.NAMES = FALSE)
}

# Split each record's authors, escape them once across the whole export and
# join each record's own back together as a BibTeX `author` field line. Records
# with no authors get NA, which drops the line.
scopus_bibtex_author_lines <- function(authors) {
  parts <- lapply(authors, scopus_refman_authors)
  n <- lengths(parts)
  flat <- unlist(parts, use.names = FALSE)
  flat <- scopus_bibtex_escape(scopus_refman_clean(flat))
  ends <- cumsum(n)
  vapply(seq_along(parts), function(i) {
    if (n[i] == 0L) {
      return(NA_character_)
    }
    joined <- paste(flat[(ends[i] - n[i] + 1L):ends[i]], collapse = " and ")
    paste0("  author = {", joined, "},")
  }, character(1))
}

# One BibTeX field line per record, or NA where the record has nothing to put
# in the field. Emptiness is judged on the value as it arrived, so a field of
# whitespace alone is still written, as it was when each record was formatted
# on its own.
scopus_bibtex_lines <- function(name, value) {
  out <- rep(NA_character_, length(value))
  keep <- !is.na(value) & nzchar(as.character(value))
  out[keep] <- paste0(
    "  ", name, " = {",
    scopus_bibtex_escape(scopus_refman_clean(value[keep])), "},"
  )
  out
}

# One RIS tag line per record, or NA where there is nothing to write.
scopus_ris_lines <- function(tag, value) {
  out <- rep(NA_character_, length(value))
  keep <- !is.na(value) & nzchar(as.character(value))
  out[keep] <- paste0(tag, "  - ", scopus_refman_clean(value[keep]))
  out
}

# The AU lines of each record, already newline-joined, or NA for a record with
# no authors.
scopus_ris_author_lines <- function(authors) {
  parts <- lapply(authors, scopus_refman_authors)
  n <- lengths(parts)
  flat <- scopus_refman_clean(unlist(parts, use.names = FALSE))
  ends <- cumsum(n)
  vapply(seq_along(parts), function(i) {
    if (n[i] == 0L) {
      return(NA_character_)
    }
    paste0("AU  - ", flat[(ends[i] - n[i] + 1L):ends[i]], collapse = "\n")
  }, character(1))
}

# Assemble the per-record lines, dropping the fields a record does not carry.
# `lines` is a list of character vectors, one per line of the entry, each as
# long as the record set.
scopus_refman_assemble <- function(lines) {
  mat <- do.call(cbind, lines)
  vapply(seq_len(nrow(mat)), function(i) {
    row <- mat[i, ]
    paste(row[!is.na(row)], collapse = "\n")
  }, character(1))
}

scopus_refman_write <- function(out, file) {
  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file)) {
      rlang::abort("`file` must be `NULL` or a single path.",
                   class = c("scopus_error_bad_input", "scopus_error"))
    }
    scopus_write_lines(out, file)
    return(invisible(out))
  }
  out
}

#' Export records to BibTeX or RIS
#'
#' Turns a [scopus_records] set into a BibTeX or RIS string, the interchange
#' formats that reference managers (Zotero, EndNote, Mendeley) and LaTeX
#' bibliographies import. Each record becomes one entry, with its authors split
#' out and the 'Scopus' identifier kept as a note. Records are treated as journal
#' articles, the dominant 'Scopus' content type. BibTeX citation keys are made
#' unique within the export, and special characters are escaped.
#'
#' @param x A [scopus_records] tibble.
#' @param file Optional path to write to. With the default `NULL` the formatted
#'   string is returned; with a path it is written there and returned invisibly.
#'   Nothing is written unless a path is given.
#' @return A length-one character string of the formatted records (returned
#'   invisibly when `file` is supplied).
#' @seealso [as_bibliometrix()], [write_scopus_records()], [scopus_extract_dois()]
#' @examples
#' # On the bundled corpus of real articles, which stands in for a retrieval
#' # of your own because 'Scopus' records may not be redistributed. Only the
#' # opening of each export is shown; pass `file` to write the whole set.
#' cat(substr(as_bibtex(example_records), 1, 200))
#' cat(substr(as_ris(example_records), 1, 200))
#' @export
as_bibtex <- function(x, file = NULL) {
  if (!is_scopus_records(x)) {
    rlang::abort("`x` must be a `scopus_records` object.",
                 class = c("scopus_error_bad_input", "scopus_error"))
  }
  base <- vapply(seq_len(nrow(x)), function(i) {
    scopus_bibtex_key(x$authors[i], x$year[i], x$scopus_id[i])
  }, character(1))
  keys <- scopus_disambiguate(base)
  # The fields are cleaned and escaped a column at a time rather than a record
  # at a time: a reference set of a few thousand records is exported from a
  # download handler, where the per-field work was what the reader waited on.
  has_id <- !is.na(x$scopus_id)
  note <- rep(NA_character_, nrow(x))
  note[has_id] <- paste0(
    "  note = {",
    scopus_bibtex_escape(paste0("Scopus ID: ", x$scopus_id[has_id])), "},"
  )
  body <- scopus_refman_assemble(list(
    scopus_bibtex_author_lines(x$authors),
    scopus_bibtex_lines("title", x$title),
    scopus_bibtex_lines("journal", x$publication),
    scopus_bibtex_lines("year", x$year),
    scopus_bibtex_lines("doi", x$doi),
    note
  ))
  # paste0() recycles a zero-length vector to "", which would turn an empty
  # record set into one empty entry.
  entries <- if (nrow(x) == 0L) {
    character()
  } else {
    paste0("@article{", keys, ",\n", body, "\n}")
  }
  scopus_refman_write(paste(entries, collapse = "\n\n"), file)
}

#' @rdname as_bibtex
#' @export
as_ris <- function(x, file = NULL) {
  if (!is_scopus_records(x)) {
    rlang::abort("`x` must be a `scopus_records` object.",
                 class = c("scopus_error_bad_input", "scopus_error"))
  }
  has_id <- !is.na(x$scopus_id)
  note <- rep(NA_character_, nrow(x))
  note[has_id] <- paste0(
    "N1  - Scopus ID: ", scopus_refman_clean(x$scopus_id[has_id])
  )
  entries <- scopus_refman_assemble(list(
    rep("TY  - JOUR", nrow(x)),
    scopus_ris_lines("TI", x$title),
    scopus_ris_author_lines(x$authors),
    scopus_ris_lines("PY", x$year),
    scopus_ris_lines("JO", x$publication),
    scopus_ris_lines("DO", x$doi),
    note,
    rep("ER  - ", nrow(x))
  ))
  scopus_refman_write(paste(entries, collapse = "\n\n"), file)
}
