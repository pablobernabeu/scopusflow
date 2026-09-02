#' Read and write 'Scopus' record sets
#'
#' Save a [scopus_records] tibble to disk and read it back, with a stable
#' round-trip. The file extension selects the format. An `.rds` file preserves
#' the types and class exactly, while a `.csv` file is portable plain text.
#' The optional `authkeywords` column a `view = "COMPLETE"` retrieval adds
#' (see [scopus_records()]) round-trips through both formats. The attributes a
#' live retrieval carries, including `retrieved_at` and `scopusflow_version`
#' (see [scopus_fetch()]), survive the `.rds` form only: `.csv` is a table of
#' columns and cannot hold them, so save as `.rds` when a set is a baseline to
#' be compared against later.
#'
#' A `.csv` written by another tool reads back too. It is taken as UTF-8
#' whatever the session's locale, and a blank field is read as missing, which is
#' how pandas, 'Excel' and the Python twin write one. A file carrying none of
#' `doi`, `title` and `year` is refused rather than read as a set of empty
#' records, and one carrying only part of the schema warns.
#'
#' @param x A [scopus_records] tibble to write.
#' @param path Explicit file path. The functions read from, or write to, exactly
#'   this path and leave the working directory alone. Parent directories are
#'   assumed to exist already.
#' @return `write_scopus_records()` returns `x` invisibly. `read_scopus_records()`
#'   returns a [scopus_records] tibble.
#' @examples
#' # A round trip on the bundled corpus of real articles, which stands in for
#' # a retrieval of your own because 'Scopus' records may not be redistributed.
#' # The .rds form restores the object exactly.
#' rds <- tempfile(fileext = ".rds")
#' write_scopus_records(example_records, rds)
#' identical(read_scopus_records(rds), example_records)
#'
#' # The .csv form is portable plain text and reads back to the same schema.
#' csv <- tempfile(fileext = ".csv")
#' write_scopus_records(example_records, csv)
#' head(read_scopus_records(csv))
#' @export
write_scopus_records <- function(x, path) {
  if (!is_scopus_records(x)) {
    rlang::abort(
      "`x` must be a `scopus_records` object.",
      class = c("scopus_error_bad_input", "scopus_error")
    )
  }
  scopus_check_path(path)
  switch(
    scopus_path_format(path),
    rds = saveRDS(x, path),
    csv = scopus_write_csv(as.data.frame(x), path)
  )
  invisible(x)
}

# Text artifacts carry LF line endings and UTF-8 bytes on every platform.
# Written through a text-mode connection on Windows, each "\n" would be
# translated to CRLF, so the connection is opened in binary mode, where no
# translation happens. `useBytes = TRUE` stops R translating the string to the
# session's native encoding first, which in a C or single-byte locale replaces
# every non-ASCII character with the literal text <U+00ED>.
scopus_write_lines <- function(text, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(enc2utf8(text), con, sep = "\n", useBytes = TRUE)
  invisible(path)
}

# write.csv() counterpart of scopus_write_lines(): the line endings come from
# the connection, not from write.csv() itself, so a binary-mode connection
# keeps CSV output LF-terminated on Windows too.
scopus_write_csv <- function(x, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  utils::write.csv(scopus_utf8_bytes(x), file = con, row.names = FALSE)
  invisible(path)
}

# write.csv() has no `useBytes`, so the columns are converted to UTF-8 and then
# declared native: R writes a native string's bytes out untouched, which is the
# only way to keep accented and Cyrillic names intact in a C or single-byte
# locale. The formatting write.csv() applies is unchanged.
scopus_utf8_bytes <- function(x) {
  for (nm in names(x)) {
    if (is.character(x[[nm]])) {
      col <- enc2utf8(x[[nm]])
      Encoding(col) <- "unknown"
      x[[nm]] <- col
    }
  }
  x
}

#' @rdname write_scopus_records
#' @export
read_scopus_records <- function(path) {
  scopus_check_path(path)
  if (!file.exists(path)) {
    rlang::abort(
      sprintf("File not found: %s", path),
      class = c("scopus_error_bad_input", "scopus_error")
    )
  }
  fmt <- scopus_path_format(path)
  if (fmt == "rds") {
    obj <- readRDS(path)
    if (!is_scopus_records(obj)) {
      rlang::abort(
        "The .rds file does not contain a `scopus_records` object.",
        class = c("scopus_error_bad_input", "scopus_error")
      )
    }
    return(obj)
  }
  # A CSV written elsewhere (pandas, Excel, the Python twin) leaves a missing
  # value as an empty field rather than the token NA, and carries UTF-8 whatever
  # the session's locale says.
  raw <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    na.strings = c("NA", ""),
    encoding = "UTF-8"
  )
  scopus_check_record_csv(raw, path)
  scopus_coerce_records(raw)
}

# A CSV is taken for a record set only when it carries at least one of the
# columns a record is identified by. Without this, a DOI list, a spreadsheet or
# any other foreign file reads back as a well-formed set of empty records,
# since scopus_coerce_records() fills every absent column with NA.
scopus_check_record_csv <- function(raw, path, call = rlang::caller_env()) {
  if (!any(c("doi", "title", "year") %in% names(raw))) {
    found <- if (length(names(raw)) > 0L) {
      paste(names(raw), collapse = ", ")
    } else {
      "none"
    }
    rlang::abort(
      sprintf(
        paste0("%s does not hold a record set: none of `doi`, `title` or ",
               "`year` is present. Columns found: %s."),
        path, found
      ),
      class = c("scopus_error_bad_input", "scopus_error"),
      call = call
    )
  }
  cols <- scopus_records_columns()
  absent <- setdiff(cols, names(raw))
  if (length(absent) > 0L) {
    rlang::warn(
      sprintf(
        paste0("%s carries %d of the %d record columns; the rest are read ",
               "as missing: %s."),
        path, length(cols) - length(absent), length(cols),
        paste(absent, collapse = ", ")
      ),
      class = "scopus_warning_partial_schema"
    )
  }
  invisible(raw)
}

# Coerce a read-in data frame back to the typed scopus_records schema. A
# COMPLETE-view record set carries an extra authkeywords column beyond the
# standard schema; it is kept, so the CSV round-trip is stable for that view
# too, and the column is never silently dropped on read.
scopus_coerce_records <- function(raw) {
  cols <- scopus_records_columns()
  if ("authkeywords" %in% names(raw)) cols <- union(cols, "authkeywords")
  for (nm in cols) {
    if (is.null(raw[[nm]])) raw[[nm]] <- NA
  }
  int_cols <- c("entry_number", "year", "citations")
  for (nm in int_cols) {
    raw[[nm]] <- suppressWarnings(as.integer(raw[[nm]]))
  }
  char_cols <- setdiff(cols, int_cols)
  for (nm in char_cols) {
    value <- as.character(raw[[nm]])
    # A blank field is a missing field, whichever tool wrote it, so a frame that
    # reaches here by another route is keyed the same way as one read from disk.
    value[!is.na(value) & !nzchar(value)] <- NA_character_
    raw[[nm]] <- value
  }
  tibble::new_tibble(as.list(raw[cols]), nrow = nrow(raw), class = "scopus_records")
}

scopus_check_path <- function(path, call = rlang::caller_env()) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    rlang::abort(
      "`path` must be a single non-empty file path.",
      class = c("scopus_error_bad_input", "scopus_error"),
      call = call
    )
  }
  invisible(path)
}

scopus_path_format <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(
    ext,
    rds = "rds",
    csv = "csv",
    rlang::abort(
      sprintf("Unsupported file extension '.%s'. Use '.rds' or '.csv'.", ext),
      class = c("scopus_error_bad_input", "scopus_error")
    )
  )
}
