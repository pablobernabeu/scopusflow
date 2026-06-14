#' Combine record sets into one
#'
#' Binds several [scopus_records] objects into a single one, renumbering
#' `entry_number` across the result and, optionally, dropping duplicates. This is
#' the safe way to merge separate fetches: plain `rbind()` would leave duplicate
#' entry numbers, and `c()` would return a list.
#'
#' @param ... Two or more [scopus_records] objects, or a single list of them.
#' @param dedupe Logical. When `TRUE`, records sharing a 'Scopus' identifier, or
#'   failing that a DOI (compared case-insensitively), are kept once.
#' @return A [scopus_records] tibble. Per-retrieval attributes such as
#'   `total_results` are not carried over, since they describe a single fetch.
#' @seealso [scopus_fetch_plan()], which combines plan cells the same way.
#' @examples
#' # Merging a set with itself and de-duplicating recovers the distinct records.
#' scopus_combine(example_records, example_records, dedupe = TRUE)
#' @export
scopus_combine <- function(..., dedupe = FALSE) {
  sets <- list(...)
  if (length(sets) == 1L && is.list(sets[[1]]) && !is_scopus_records(sets[[1]])) {
    sets <- sets[[1]]
  }
  if (length(sets) == 0L || !all(vapply(sets, is_scopus_records, logical(1)))) {
    rlang::abort(
      "All inputs to `scopus_combine()` must be `scopus_records` objects.",
      class = "scopus_error_bad_input"
    )
  }
  out <- scopus_bind_records(sets)
  if (isTRUE(dedupe)) {
    out <- scopus_dedupe_records(out)
  }
  out
}

#' @rdname scopus_combine
#' @param x A [scopus_records] object (for the `c()` method).
#' @export
c.scopus_records <- function(x, ...) {
  scopus_combine(x, ...)
}

# Keep one record per Scopus id, then per DOI; records with neither are all kept.
scopus_dedupe_records <- function(x) {
  key <- ifelse(
    !is.na(x$scopus_id), paste0("id:", x$scopus_id),
    ifelse(!is.na(x$doi), paste0("doi:", tolower(x$doi)),
           paste0("row:", seq_len(nrow(x))))
  )
  sub <- as.data.frame(x)[!duplicated(key), , drop = FALSE]
  sub$entry_number <- seq_len(nrow(sub))
  tibble::new_tibble(as.list(sub), nrow = nrow(sub), class = "scopus_records")
}

#' @rdname scopus_records
#' @param ... Ignored, for S3 compatibility.
#' @return The coercion methods return a plain [tibble][tibble::tibble] or data
#'   frame with the same columns and the `scopus_records` class removed.
#' @exportS3Method tibble::as_tibble
as_tibble.scopus_records <- function(x, ...) {
  tibble::new_tibble(as.list(x), nrow = nrow(x))
}

#' @rdname scopus_records
#' @exportS3Method base::as.data.frame
as.data.frame.scopus_records <- function(x, ...) {
  class(x) <- setdiff(class(x), "scopus_records")
  NextMethod()
}
