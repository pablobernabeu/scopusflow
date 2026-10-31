#' Combine record sets into one
#'
#' Binds several [scopus_records] objects into a single one, renumbering
#' `entry_number` across the result and, optionally, dropping duplicates. This is
#' the safe way to merge separate fetches: plain `rbind()` would leave duplicate
#' entry numbers. `c()` on record sets calls `scopus_combine()`, so it renumbers
#' in the same way and, unless it is given `dedupe`, keeps every row.
#'
#' @param ... One or more [scopus_records] objects, or a single list of them. A
#'   single set can be passed to de-duplicate it.
#' @param dedupe Whether, and by which rule, to keep once the records that are
#'   one record. `FALSE`, the default, keeps every row. `TRUE`, also spelled
#'   `"id_or_shared_doi"`, treats records as one when they share a 'Scopus'
#'   identifier, or when they share a DOI and one of them lacks an identifier.
#'   `"id_or_doi"` also merges records with different identifiers that share a
#'   DOI, and `"id_then_doi"` applies the rule of the 0.4.0 release and earlier.
#'   See Details.
#' @return A [scopus_records] tibble. Per-retrieval attributes such as
#'   `total_results` and `plan` are not carried over, since they describe a
#'   single fetch. The provenance a merge leaves true is kept, as
#'   [scopus_fetch_plan()] keeps it for plan cells. When every input records
#'   its retrieval time, `retrieved_at` is the earliest of the inputs' times and
#'   `retrieved_until` the latest, so a baseline merged with its update is dated
#'   from one to the other. Every contributing `scopusflow_version` is listed
#'   when every input records one. Each is omitted when any input cannot supply
#'   it, as a set read back from a `.csv` file cannot, since a value drawn from
#'   the other inputs alone would misreport the set. The merge
#'   itself is recorded in the `combined` attribute, a list of `n_in`
#'   (records supplied), `n_out` (records kept), `n_removed`, `deduplicated`,
#'   `rule` (the rule applied, `NA` when none was) and `doi_conflicts` (how
#'   many DOIs records with different identifiers share, `NA` when no rule was
#'   applied). It is what lets [scopus_search_report()] state how many
#'   duplicates were removed and how, so the PRISMA-S item is answered.
#' @details
#' De-duplication compares DOIs as [scopus_extract_dois()] does, without
#' resolver prefixes such as `https://doi.org/` or `doi:` and ignoring case. It
#' keeps the first record of each group, in the order the sets were given, and
#' a record with neither an identifier nor a DOI cannot be matched and is kept.
#'
#' Under the default rule, records with the same 'Scopus' identifier are one
#' record, and a record without an identifier joins the identified record that
#' carries its DOI. Records with different identifiers are never merged, even
#' when they share a DOI. 'Scopus' holds duplicate records of one paper
#' (Valderrama-Zurián et al., 2015), but it also gives one DOI to distinct
#' papers (Franceschini et al., 2015), and a review loses a wrongly removed
#' record for good where a surviving duplicate is caught at screening. Such
#' DOIs are counted in `doi_conflicts`, which the search record reports, so
#' that they can be checked by hand. A record without an identifier whose DOI
#' two identified records carry is kept once, apart from both. Records without
#' an identifier that share a DOI no identified record carries are one record.
#'
#' `"id_or_doi"` merges every record linked to another by a shared identifier
#' or a shared DOI, directly or through a chain of such links. It suits a set
#' whose shared DOIs have been checked and found to be duplicates.
#' `"id_then_doi"` keys each record on its identifier, failing that on its DOI
#' lower-cased but not otherwise cleaned, and so reproduces a set
#' de-duplicated by the 0.4.0 release or earlier.
#' @references
#' Franceschini, F., Maisano, D., & Mastrogiacomo, L. (2015). Errors in DOI
#' indexing by bibliometric databases. *Scientometrics*, *102*(3), 2181–2186.
#' \doi{10.1007/s11192-014-1503-4}
#'
#' Valderrama-Zurián, J.-C., Aguilar-Moya, R., Melero-Fuentes, D., &
#' Aleixandre-Benavent, R. (2015). A systematic analysis of duplicate records
#' in Scopus. *Journal of Informetrics*, *9*(3), 570–576.
#' \doi{10.1016/j.joi.2015.05.002}
#' @seealso [scopus_fetch_plan()], which combines plan cells the same way.
#' @examples
#' # A baseline retrieval and a later one, merged into a cumulative set. The
#' # bundled corpus of real articles stands in for both, since 'Scopus'
#' # records may not be redistributed.
#' baseline <- example_records[example_records$year <= 2023, ]
#' later <- example_records
#' combined <- scopus_combine(baseline, later, dedupe = TRUE)
#' nrow(combined)
#'
#' # Those records carry no 'Scopus' identifier, so de-duplication falls back
#' # to the DOI. The eleven that arrived without one cannot be matched, and so
#' # survive in both copies, which is why 138 distinct articles come back as
#' # 149 rows.
#' sum(is.na(example_records$doi))
#' @export
scopus_combine <- function(..., dedupe = FALSE) {
  rule <- scopus_dedupe_rule(dedupe)
  sets <- list(...)
  if (length(sets) == 1L && is.list(sets[[1]]) && !is_scopus_records(sets[[1]])) {
    sets <- sets[[1]]
  }
  if (length(sets) == 0L || !all(vapply(sets, is_scopus_records, logical(1)))) {
    scopus_abort_bad_input(
      "All inputs to `scopus_combine()` must be `scopus_records` objects."
    )
  }
  out <- scopus_bind_records(sets)
  n_in <- nrow(out)
  conflicts <- NA_integer_
  if (!is.na(rule)) {
    groups <- scopus_dedupe_groups(out$scopus_id, out$doi, rule)
    out <- scopus_keep_records(out, !duplicated(groups$key))
    conflicts <- groups$doi_conflicts
  }
  # De-duplication is a PRISMA-S item in its own right (item 16), and the count
  # only exists at the moment the merge happens: afterwards nothing in the
  # result says how many rows went in. Recorded whether or not `dedupe` ran, so
  # a report can distinguish "no duplicates were removed" from "nobody looked".
  # The rule is recorded beside it, since the search record has to say how
  # records were matched, and a set merged by 0.4.0 records none.
  attr(out, "combined") <- list(
    n_in = n_in,
    n_out = nrow(out),
    n_removed = n_in - nrow(out),
    deduplicated = !is.na(rule),
    rule = rule,
    doi_conflicts = conflicts
  )
  out
}

#' @rdname scopus_combine
#' @param x A [scopus_records] object (for the `c()` method).
#' @export
c.scopus_records <- function(x, ...) {
  scopus_combine(x, ...)
}

scopus_dedupe_rules <- function() c("id_or_shared_doi", "id_or_doi", "id_then_doi")

# The rule `dedupe` names, or NA for none. TRUE is the default rule.
scopus_dedupe_rule <- function(dedupe, call = rlang::caller_env()) {
  if (is.logical(dedupe) && length(dedupe) == 1L && !is.na(dedupe)) {
    return(if (dedupe) "id_or_shared_doi" else NA_character_)
  }
  if (is.character(dedupe) && length(dedupe) == 1L &&
      dedupe %in% scopus_dedupe_rules()) {
    return(dedupe)
  }
  scopus_abort_bad_input(
    '`dedupe` must be TRUE, FALSE, "id_or_shared_doi", "id_or_doi" or "id_then_doi".',
    call = call
  )
}

# One group key per record under `rule`: records with the same key are one
# record, and the first of them is kept. `doi_conflicts` counts the DOIs that
# records with two or more different identifiers carry, which the default rule
# leaves unmerged and the search record reports. The Python twin's
# _record_groups() computes the same keys, so both twins keep the same rows.
scopus_dedupe_groups <- function(ids, dois, rule) {
  n <- length(ids)
  if (identical(rule, "id_then_doi")) {
    # The 0.4.0 key, unchanged, so that an earlier set is reproduced exactly.
    key <- ifelse(
      !is.na(ids), paste0("id:", ids),
      ifelse(!is.na(dois), paste0("doi:", tolower(dois)), paste0("row:", seq_len(n)))
    )
  }
  # A blank identifier is no identifier. A CSV written by the Python twin or by
  # a spreadsheet leaves the field empty, which read.csv() reads as "".
  ids <- trimws(as.character(ids))
  ids[!is.na(ids) & !nzchar(ids)] <- NA_character_
  dois <- tolower(scopus_tidy_dois(dois))
  both <- !is.na(ids) & !is.na(dois)
  owners <- lapply(split(ids[both], dois[both]), unique)
  conflicts <- sum(lengths(owners) > 1L)
  if (identical(rule, "id_or_shared_doi")) {
    key <- sprintf("row:%d", seq_len(n))
    has_doi <- !is.na(dois)
    key[has_doi] <- paste0("doi:", dois[has_doi])
    # An unidentified record whose DOI one identifier alone carries is that
    # identifier's record. Where two or more carry it, the record cannot be
    # assigned to either and stays under the DOI's own key.
    sole <- unlist(owners[lengths(owners) == 1L])
    join <- is.na(ids) & has_doi & dois %in% names(sole)
    if (any(join)) key[join] <- paste0("id:", sole[dois[join]])
    key[!is.na(ids)] <- paste0("id:", ids[!is.na(ids)])
  } else if (identical(rule, "id_or_doi")) {
    # Connected components over both keys. Each record takes the smallest row
    # number among the records it shares an identifier or a DOI with, until no
    # label changes, so a component is labelled by its first record.
    label <- seq_len(n)
    repeat {
      before <- label
      for (k in list(ids, dois)) {
        ok <- !is.na(k)
        if (any(ok)) label[ok] <- stats::ave(label[ok], k[ok], FUN = min)
      }
      if (identical(label, before)) break
    }
    key <- sprintf("set:%d", label)
  }
  list(key = key, doi_conflicts = conflicts)
}

# The records at `keep`, renumbered, with the attributes the merge gave them.
scopus_keep_records <- function(x, keep) {
  sub <- as.data.frame(x)[keep, , drop = FALSE]
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
