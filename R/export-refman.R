# Export a record set to the reference-manager interchange formats RIS and
# BibTeX, so a Scopus search can be carried straight into Zotero, EndNote,
# Mendeley or a LaTeX bibliography. The formatting is pure and offline.

# Split the "; "-joined authors string of one record into a character vector,
# dropping empty pieces. Returns character(0) when the field is NA or blank.
# The split is at the semicolon, with or without the space, as the Python
# twin's is: scopusflow-py 0.3.0 joined the authors with ";" alone.
scopus_refman_authors <- function(authors) {
  if (length(authors) != 1L || is.na(authors)) {
    return(character())
  }
  parts <- trimws(strsplit(authors, ";", fixed = TRUE)[[1]])
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

# TRUE when a field carries a usable value. A record set read back from CSV
# holds "" where a live one holds NA, and neither is an identifier.
scopus_refman_present <- function(x) {
  length(x) == 1L && !is.na(x) && nzchar(trimws(as.character(x)))
}

# The STANDARD view's dc:creator, and so the authors column of every R record
# outside COMPLETE, gives a name as "Surname I." with no comma. BibTeX reads a
# comma-free name as given name first (Patashnik, 1988), so "Zhang F." became
# family name "F.", and RIS readers keep it as a single field. A comma-free name
# whose final run is initials therefore gains a comma before them. An initial
# is one upper-case letter, optionally followed by one lower-case letter (Yu.,
# Ch.), then a full stop, and initials may be joined by a hyphen or a space.
# Unicode classes extend the rule to accented and Cyrillic initials, which an
# ASCII class would miss. Names with a comma (the COMPLETE view's "Surname,
# Given") and names given first are left alone. The Python twin applies the
# same rule, and both are held to tests/testthat/fixtures/author-names.json.
# Input is already cleaned, so its only whitespace is single spaces.
scopus_refman_name <- function(name) {
  if (grepl(",", name, fixed = TRUE)) {
    return(name)
  }
  sub(
    "^(.+?) +(\\p{Lu}\\p{Ll}?\\.(?:[- ]?\\p{Lu}\\p{Ll}?\\.)*)$",
    "\\1, \\2", name, perl = TRUE
  )
}

# BibTeX reads run-together initials ("J.R.") as one given name and abbreviates
# them to "J.", so the BibTeX form spaces them ("J. R.") after the comma. A
# hyphen is kept ("J.-P."). RIS keeps Scopus's spelling.
scopus_bibtex_name <- function(name) {
  name <- scopus_refman_name(name)
  pos <- regexpr(",", name, fixed = TRUE)
  if (pos < 0L) {
    return(name)
  }
  paste0(
    substr(name, 1L, pos),
    gsub("\\.(?=\\p{Lu})", ". ", substring(name, pos + 1L), perl = TRUE)
  )
}

# BibTeX styles lower-case a title's letters unless they are braced, so plain.bst
# printed "crispr-cas9" and "dna". Each word with an upper-case letter after its
# first character is braced whole, leaving an opening bracket before it and
# closing punctuation after it outside the braces ("({DNA})", "{mRNA}:"). A word
# capitalised only at its start ("Bayesian") is left to the style. The input is
# already escaped. The brackets and punctuation peeled off include no backslash
# or brace, so an escape such as \& is never split. A word that opens with an
# escape (\#MeToo) is braced twice, because BibTeX takes a brace group opening
# with a backslash for a special character and changes the case of the letters
# inside it, so plain.bst printed "{\#metoo}".
scopus_bibtex_protect <- function(title) {
  words <- strsplit(title, " ", fixed = TRUE)[[1]]
  parts <- regmatches(words, regexec("^([(\\[]*)(.*?)([.,:;!?)\\]]*)$", words, perl = TRUE))
  out <- vapply(seq_along(words), function(i) {
    p <- parts[[i]]
    core <- p[3]
    if (nchar(core) > 1L && grepl("\\p{Lu}", substring(core, 2L), perl = TRUE)) {
      if (startsWith(core, "\\")) core <- paste0("{", core, "}")
      paste0(p[2], "{", core, "}", p[4])
    } else {
      words[i]
    }
  }, character(1))
  paste(out, collapse = " ")
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

# A column of one record, or NA when the set does not carry the column. Only a
# set retrieved with fields = "extended" has the document type, volume, issue,
# pages and ISSN. Only a COMPLETE one has the author keywords, and only one
# that is both has the abstract.
scopus_refman_field <- function(row, name) {
  if (name %in% names(row)) row[[name]] else NA_character_
}

# The 'Scopus' document-type code of one record, lower-cased, or NA.
scopus_refman_doc_type <- function(row) {
  code <- scopus_refman_field(row, "doc_type")
  if (scopus_refman_present(code)) tolower(scopus_refman_clean(code)) else NA_character_
}

# The RIS and BibTeX types of the 'Scopus' codes that are not journal content:
# a conference paper (cp), a conference review (cr), a book chapter (ch) and a
# book (bk). Every other code, and a record with none, is a journal article.
# Zotero's RIS import reads CPAPER and CONF as a conference paper, so both map
# to @inproceedings, where a conference review is an item in the proceedings.
scopus_ris_types <- c(cp = "CPAPER", cr = "CONF", ch = "CHAP", bk = "BOOK")
scopus_bibtex_types <- c(
  cp = "inproceedings", cr = "inproceedings", ch = "incollection", bk = "book"
)

scopus_refman_type <- function(code, types, default) {
  if (!is.na(code) && code %in% names(types)) types[[code]] else default
}

# TRUE when a book's source title names a series. 'Scopus' gives a book in a
# book series that series as its source, and a book outside a series itself,
# which would repeat the title. Zotero reads a book's T2 as its series, and
# BibTeX's @book has a series field, so only the first is written.
scopus_refman_book_series <- function(row) {
  type <- scopus_refman_field(row, "source_type")
  scopus_refman_present(type) && identical(tolower(scopus_refman_clean(type)), "book series")
}

# The author keywords of one record. The Search API's COMPLETE view joins them
# with " | ", and scopus_abstract() joins its own with "; ". The split is at
# either, so one rule serves keywords from both endpoints.
scopus_refman_keywords <- function(x) {
  if (!scopus_refman_present(x)) {
    return(character())
  }
  parts <- trimws(strsplit(scopus_refman_clean(x), "[|;]")[[1]])
  parts[nzchar(parts)]
}

# A 'Scopus' page range ("101-117") as its first and last page, or a page that
# is no range ("e0123456") on its own. Returns character(0) when there are no
# pages.
scopus_refman_pages <- function(x) {
  if (!scopus_refman_present(x)) {
    return(character())
  }
  pages <- scopus_refman_clean(x)
  ends <- regmatches(pages, regexec("^([^-]+)-([^-]+)$", pages))[[1]]
  if (length(ends) == 3L) {
    ends <- trimws(ends[2:3])
    if (all(nzchar(ends))) return(ends)
  }
  pages
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
  type <- scopus_refman_type(scopus_refman_doc_type(row), scopus_bibtex_types, "article")
  auth <- scopus_refman_authors(row$authors)
  if (length(auth) > 0L) {
    fields[["author"]] <- paste(
      vapply(auth, function(a) {
        scopus_bibtex_escape(scopus_bibtex_name(scopus_refman_clean(a)))
      }, character(1)),
      collapse = " and "
    )
  }
  add("title", row$title)
  if ("title" %in% names(fields)) {
    fields[["title"]] <- scopus_bibtex_protect(fields[["title"]])
  }
  # The source goes in the field each entry type reads: the proceedings or the
  # book a paper or chapter appears in, a book's series, or a journal.
  if (type %in% c("inproceedings", "incollection")) {
    add("booktitle", row$publication)
    if ("booktitle" %in% names(fields)) {
      fields[["booktitle"]] <- scopus_bibtex_protect(fields[["booktitle"]])
    }
  } else if (type == "book") {
    if (scopus_refman_book_series(row)) add("series", row$publication)
  } else {
    add("journal", row$publication)
  }
  add("year", row$year)
  add("volume", scopus_refman_field(row, "volume"))
  add("number", scopus_refman_field(row, "issue"))
  pages <- scopus_refman_pages(scopus_refman_field(row, "pages"))
  if (length(pages) > 0L) add("pages", paste(pages, collapse = "--"))
  add("issn", scopus_refman_field(row, "issn"))
  add("doi", row$doi)
  add("abstract", scopus_refman_field(row, "abstract"))
  keywords <- scopus_refman_keywords(scopus_refman_field(row, "authkeywords"))
  if (length(keywords) > 0L) {
    fields[["keywords"]] <- paste(
      vapply(keywords, scopus_bibtex_escape, character(1), USE.NAMES = FALSE),
      collapse = ", "
    )
  }
  if (scopus_refman_present(row$scopus_id)) {
    fields[["note"]] <- scopus_bibtex_escape(paste0("Scopus ID: ", row$scopus_id))
  }

  body <- paste0("  ", names(fields), " = {", unlist(fields), "},", collapse = "\n")
  paste0("@", type, "{", key, ",\n", body, "\n}")
}

# Build the RIS entry for one record.
scopus_ris_entry <- function(row) {
  code <- scopus_refman_doc_type(row)
  type <- scopus_refman_type(code, scopus_ris_types, "JOUR")
  lines <- paste0("TY  - ", type)
  ris_add <- function(tag, value) {
    if (length(value) == 1L && !is.na(value) && nzchar(as.character(value))) {
      lines <<- c(lines, paste0(tag, "  - ", scopus_refman_clean(value)))
    }
  }
  ris_add("TI", row$title)
  for (a in scopus_refman_authors(row$authors)) {
    lines <- c(lines, paste0("AU  - ", scopus_refman_name(scopus_refman_clean(a))))
  }
  ris_add("PY", row$year)
  # T2 is the tag Scopus's own RIS export uses for the source title, and the one
  # reference managers read as the publication title. Zotero reads JO, which
  # this function wrote before, as the journal abbreviation.
  if (type != "BOOK" || scopus_refman_book_series(row)) {
    ris_add("T2", row$publication)
  }
  ris_add("VL", scopus_refman_field(row, "volume"))
  ris_add("IS", scopus_refman_field(row, "issue"))
  pages <- scopus_refman_pages(scopus_refman_field(row, "pages"))
  if (length(pages) > 0L) ris_add("SP", pages[1])
  if (length(pages) > 1L) ris_add("EP", pages[2])
  ris_add("SN", scopus_refman_field(row, "issn"))
  ris_add("DO", row$doi)
  ris_add("AB", scopus_refman_field(row, "abstract"))
  for (k in scopus_refman_keywords(scopus_refman_field(row, "authkeywords"))) {
    lines <- c(lines, paste0("KW  - ", k))
  }
  ris_add("M3", scopus_refman_field(row, "doc_type_description"))
  id <- if (scopus_refman_present(row$scopus_id)) scopus_refman_clean(row$scopus_id) else NA
  if (!is.na(id)) {
    lines <- c(lines, paste0("AN  - 2-s2.0-", id))
  }
  lines <- c(lines, "DB  - Scopus")
  if (!is.na(id)) {
    lines <- c(lines, paste0("N1  - Scopus ID: ", id))
  }
  lines <- c(lines, "ER  - ")
  paste(lines, collapse = "\n")
}

scopus_refman_write <- function(out, file) {
  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file)) {
      scopus_abort_bad_input("`file` must be `NULL` or a single path.")
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
#' out and the 'Scopus' identifier kept as a note. BibTeX citation keys are made
#' unique within the export, and special characters are escaped.
#'
#' A set retrieved with `fields = "extended"` (see [scopus_records()]) carries
#' each record's 'Scopus' document type, and the entry is typed by it. A
#' conference paper (`cp`) becomes an RIS `CPAPER` and a BibTeX
#' `@inproceedings`, and a conference review (`cr`) an RIS `CONF` and a BibTeX
#' `@inproceedings`. A book chapter (`ch`) becomes an RIS `CHAP` and a BibTeX
#' `@incollection`, and a book (`bk`) an RIS `BOOK` and a BibTeX `@book`. Every
#' other record, and every record of a set retrieved with the core fields, is
#' a journal article (`JOUR`, `@article`). In BibTeX, the source title of a
#' conference paper or chapter goes under `booktitle`, braced as the title is,
#' and a journal article's under `journal`. A book in a book series gives the
#' series under `series`, and a book outside a series, whose source title
#' 'Scopus' gives as the book's own, names no source. RIS gives the source
#' under `T2` except for such a book, since Zotero reads a book's `T2` as its
#' series. The entries also carry the volume, issue, pages, ISSN and document
#' type (RIS `M3`), and under `view = "COMPLETE"` the abstract. The entries of
#' a set retrieved under `view = "COMPLETE"`, with the core fields or the
#' extended ones, also carry the author keywords, one `KW` line each in RIS and
#' joined by commas in BibTeX.
#' Keywords are split at the `" | "` the Search API joins them with and at the
#' `"; "` [scopus_abstract()] joins its own with. A value the record lacks is
#' left out, never filled in.
#'
#' Names are written family name first, with a comma. Under the `STANDARD`
#' view, the `authors` column holds 'Scopus' names in the form `Zhang F.`,
#' which BibTeX would read as given name "Zhang" and family name "F.", so a
#' name ending in initials is exported as `Zhang, F.`. BibTeX entries also
#' space run-together initials (`Kitchin, J. R.`), which BibTeX otherwise
#' takes for a single given name. Names that already carry a comma, as under
#' `COMPLETE`, and names given first are written as they stand. The `authors`
#' column itself and the citation keys are unchanged. In a BibTeX title, every
#' word with a capital after its first letter is braced (`{DNA}`,
#' `{CRISPR-Cas9}`), so bibliography styles cannot lower-case it.
#'
#' An RIS entry gives the source title under `T2`, the tag 'Scopus' itself
#' uses and reference managers read as the publication title, records the
#' database as `DB  - Scopus` and, when the record has an identifier, gives the
#' EID as the accession number (`AN  - 2-s2.0-<scopus_id>`).
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
    scopus_abort_bad_input("`x` must be a `scopus_records` object.")
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
    scopus_abort_bad_input("`x` must be a `scopus_records` object.")
  }
  entries <- vapply(seq_len(nrow(x)), function(i) scopus_ris_entry(x[i, ]), character(1))
  scopus_refman_write(paste(entries, collapse = "\n\n"), file)
}
