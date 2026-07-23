# Export a record set to the reference-manager interchange formats RIS and
# BibTeX, so a Scopus search can be carried straight into Zotero, EndNote,
# Mendeley or a LaTeX bibliography. The formatting is pure and offline.

# Split the "; "-joined authors string of one record into a character vector,
# dropping empty pieces. Returns character(0) when the field is NA or blank.
scopus_refman_authors <- function(authors) {
  if (length(authors) != 1L || is.na(authors)) {
    return(character())
  }
  parts <- trimws(strsplit(authors, "; ", fixed = TRUE)[[1]])
  parts[nzchar(parts)]
}

# Fold internal whitespace (including embedded newlines, which would break RIS
# line structure) to single spaces.
scopus_refman_clean <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return("")
  }
  trimws(gsub("[[:space:]]+", " ", as.character(x)))
}

# Escape the characters that are special in a BibTeX field value, in a SINGLE
# pass so the braces introduced by the backslash replacement are not themselves
# re-escaped.
scopus_bibtex_escape <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return("")
  }
  map <- c(
    "\\" = "\\textbackslash{}", "&" = "\\&", "%" = "\\%", "$" = "\\$",
    "#" = "\\#", "_" = "\\_", "{" = "\\{", "}" = "\\}",
    "~" = "\\textasciitilde{}", "^" = "\\textasciicircum{}"
  )
  chars <- strsplit(as.character(x), "", fixed = TRUE)[[1]]
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

# Build the BibTeX entry for one record (a one-row scopus_records), with a
# pre-disambiguated `key`.
scopus_bibtex_entry <- function(row, key) {
  fields <- character()
  add <- function(name, value) {
    if (length(value) == 1L && !is.na(value) && nzchar(as.character(value))) {
      fields[[name]] <<- scopus_bibtex_escape(scopus_refman_clean(value))
    }
  }
  auth <- scopus_refman_authors(row$authors)
  if (length(auth) > 0L) {
    fields[["author"]] <- paste(
      vapply(auth, function(a) scopus_bibtex_escape(scopus_refman_clean(a)), character(1)),
      collapse = " and "
    )
  }
  add("title", row$title)
  add("journal", row$publication)
  add("year", row$year)
  add("doi", row$doi)
  if (!is.na(row$scopus_id)) {
    fields[["note"]] <- scopus_bibtex_escape(paste0("Scopus ID: ", row$scopus_id))
  }

  body <- paste0("  ", names(fields), " = {", unlist(fields), "},", collapse = "\n")
  paste0("@article{", key, ",\n", body, "\n}")
}

# Build the RIS entry for one record.
scopus_ris_entry <- function(row) {
  lines <- "TY  - JOUR"
  ris_add <- function(tag, value) {
    if (length(value) == 1L && !is.na(value) && nzchar(as.character(value))) {
      lines <<- c(lines, paste0(tag, "  - ", scopus_refman_clean(value)))
    }
  }
  ris_add("TI", row$title)
  for (a in scopus_refman_authors(row$authors)) {
    lines <- c(lines, paste0("AU  - ", scopus_refman_clean(a)))
  }
  ris_add("PY", row$year)
  ris_add("JO", row$publication)
  ris_add("DO", row$doi)
  if (!is.na(row$scopus_id)) {
    lines <- c(lines, paste0("N1  - Scopus ID: ", scopus_refman_clean(row$scopus_id)))
  }
  lines <- c(lines, "ER  - ")
  paste(lines, collapse = "\n")
}

scopus_refman_write <- function(out, file) {
  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file)) {
      rlang::abort("`file` must be `NULL` or a single path.",
                   class = "scopus_error_bad_input")
    }
    writeLines(out, file)
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
                 class = "scopus_error_bad_input")
  }
  base <- vapply(seq_len(nrow(x)), function(i) {
    scopus_bibtex_key(x$authors[i], x$year[i], x$scopus_id[i])
  }, character(1))
  keys <- scopus_disambiguate(base)
  entries <- vapply(seq_len(nrow(x)), function(i) {
    scopus_bibtex_entry(x[i, ], keys[i])
  }, character(1))
  scopus_refman_write(paste(entries, collapse = "\n\n"), file)
}

#' @rdname as_bibtex
#' @export
as_ris <- function(x, file = NULL) {
  if (!is_scopus_records(x)) {
    rlang::abort("`x` must be a `scopus_records` object.",
                 class = "scopus_error_bad_input")
  }
  entries <- vapply(seq_len(nrow(x)), function(i) scopus_ris_entry(x[i, ]), character(1))
  scopus_refman_write(paste(entries, collapse = "\n\n"), file)
}
