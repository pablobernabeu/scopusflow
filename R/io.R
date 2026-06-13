#' Read and write 'Scopus' record sets
#'
#' Save a [scopus_records] tibble to disk and read it back, with a stable
#' round-trip. The format is chosen from the file extension: `.rds` (preserving
#' types and class exactly) or `.csv` (portable plain text).
#'
#' @param x A [scopus_records] tibble to write.
#' @param path Explicit file path. The functions write to (or read from) exactly
#'   this path and never the working directory implicitly; parent directories are
#'   not created.
#' @return `write_scopus_records()` returns `x` invisibly. `read_scopus_records()`
#'   returns a [scopus_records] tibble.
#' @examples
#' recs <- scopus_records(list(entry = list(
#'   list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
#'        `dc:title` = "A study", `prism:coverDate` = "2020-01-01")
#' )))
#' path <- tempfile(fileext = ".csv")
#' write_scopus_records(recs, path)
#' read_scopus_records(path)
#' @export
write_scopus_records <- function(x, path) {
  if (!is_scopus_records(x)) {
    rlang::abort(
      "`x` must be a `scopus_records` object.",
      class = "scopus_error_bad_input"
    )
  }
  scopus_check_path(path)
  switch(
    scopus_path_format(path),
    rds = saveRDS(x, path),
    csv = utils::write.csv(as.data.frame(x), file = path, row.names = FALSE)
  )
  invisible(x)
}

#' @rdname write_scopus_records
#' @export
read_scopus_records <- function(path) {
  scopus_check_path(path)
  if (!file.exists(path)) {
    rlang::abort(
      sprintf("File not found: %s", path),
      class = "scopus_error_bad_input"
    )
  }
  fmt <- scopus_path_format(path)
  if (fmt == "rds") {
    obj <- readRDS(path)
    if (!is_scopus_records(obj)) {
      rlang::abort(
        "The .rds file does not contain a `scopus_records` object.",
        class = "scopus_error_bad_input"
      )
    }
    return(obj)
  }
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  scopus_coerce_records(raw)
}

# Coerce a read-in data frame back to the typed scopus_records schema.
scopus_coerce_records <- function(raw) {
  cols <- scopus_records_columns()
  for (nm in cols) {
    if (is.null(raw[[nm]])) raw[[nm]] <- NA
  }
  int_cols <- c("entry_number", "year", "citations")
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
    rlang::abort(
      "`path` must be a single non-empty file path.",
      class = "scopus_error_bad_input",
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
      sprintf("Unsupported file extension '.%s'; use '.rds' or '.csv'.", ext),
      class = "scopus_error_bad_input"
    )
  )
}
