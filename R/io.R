#' Read and write 'Scopus' record sets
#'
#' Save a [scopus_records] tibble to disk and read it back, with a stable
#' round-trip. The file extension selects the format. An `.rds` file preserves
#' the types and class exactly, while a `.csv` file is portable plain text.
#' The optional `authkeywords` column a `view = "COMPLETE"` retrieval adds
#' (see [scopus_records()]) round-trips through both formats, and so do the
#' columns `fields = "extended"` adds. A `.csv` file reads them back as text,
#' apart from the integer `open_access`, so an ISSN keeps its leading zeros.
#' The attributes a live retrieval carries, including `retrieved_at` and
#' `scopusflow_version` (see [scopus_fetch()]), survive the `.rds` form only:
#' `.csv` is a table of columns and cannot hold them, so save as `.rds` when a
#' set is a baseline to be compared against later.
#'
#' A `.csv` file is written and read as UTF-8 in every locale. One written by
#' another tool reads back as well, and a blank field in it reads as missing,
#' since pandas, the Python twin and spreadsheet software write a missing value
#' that way, where R writes `NA`.
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
    scopus_abort_bad_input(
      "`x` must be a `scopus_records` object."
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
# translation happens. `useBytes = TRUE` stops writeLines() translating the
# text to the session's native encoding first, which in a C or single-byte
# locale writes each character it cannot encode as the text <U+00ED>.
scopus_write_lines <- function(text, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(enc2utf8(text), con, sep = "\n", useBytes = TRUE)
  invisible(path)
}

# write.csv() counterpart of scopus_write_lines(): the line endings come from
# the connection, not from write.csv() itself, so a binary-mode connection
# keeps CSV output LF-terminated on Windows too. write.csv() has no
# `useBytes`, so the text columns are converted to UTF-8 and then marked as
# native, whose bytes it writes untouched in any locale.
scopus_write_csv <- function(x, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  utils::write.csv(scopus_utf8_bytes(x), file = con, row.names = FALSE)
  invisible(path)
}

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
    scopus_abort_bad_input(
      sprintf("File not found: %s", path)
    )
  }
  fmt <- scopus_path_format(path)
  if (fmt == "rds") {
    obj <- readRDS(path)
    if (!is_scopus_records(obj)) {
      scopus_abort_bad_input(
        "The .rds file does not contain a `scopus_records` object."
      )
    }
    return(obj)
  }
  # pandas, and with it the Python twin, and spreadsheet software write a
  # missing value as an empty field, where R writes NA, so both read as
  # missing. Read as "", a blank identifier was an identifier to the rule of
  # scopusflow 0.4.0, which merged every such record into one. The file is
  # UTF-8 whatever the session's locale.
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character",
                         na.strings = c("NA", ""), encoding = "UTF-8")
  scopus_coerce_records(raw)
}

# Coerce a read-in data frame back to the typed scopus_records schema. A
# COMPLETE-view record set carries an extra authkeywords column beyond the
# standard schema, and a set retrieved with fields = "extended" carries the
# extended columns. Each one present is kept, in the order the records put it,
# so the CSV round-trip is stable for every view and set of fields, and no
# column is silently dropped on read. The file is read as text throughout, so
# an ISSN or a PubMed identifier keeps any leading zeros.
scopus_coerce_records <- function(raw) {
  cols <- scopus_records_columns()
  if ("authkeywords" %in% names(raw)) cols <- union(cols, "authkeywords")
  cols <- union(cols, intersect(scopus_extended_columns("COMPLETE"), names(raw)))
  for (nm in cols) {
    if (is.null(raw[[nm]])) raw[[nm]] <- NA
  }
  int_cols <- intersect(c("entry_number", "year", "citations", "open_access"), cols)
  for (nm in int_cols) {
    raw[[nm]] <- suppressWarnings(as.integer(raw[[nm]]))
  }
  char_cols <- setdiff(cols, int_cols)
  for (nm in char_cols) {
    raw[[nm]] <- as.character(raw[[nm]])
  }
  tibble::new_tibble(as.list(raw[cols]), nrow = nrow(raw), class = "scopus_records")
}

scopus_check_path <- function(path, call = rlang::caller_env()) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    scopus_abort_bad_input(
      "`path` must be a single non-empty file path.",
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
    scopus_abort_bad_input(
      sprintf("Unsupported file extension '.%s'. Use '.rds' or '.csv'.", ext)
    )
  )
}
