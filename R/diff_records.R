#' Compare two retrievals record by record
#'
#' Identifies which records were added, removed or unchanged between an earlier
#' and a later retrieval, and gives each record's citation count in both.
#' [scopus_diff_dois()] compares DOIs alone, and this function compares the
#' records themselves, matched as `scopus_combine(dedupe = TRUE)` matches them.
#' A record without a DOI is therefore still tracked by its 'Scopus'
#' identifier, and two records under one DOI are not taken for one.
#'
#' @param old,new [scopus_records] objects, or data frames with a `scopus_id`
#'   or a `doi` column, representing the earlier (`old`) and later (`new`)
#'   retrievals. The `title`, `year` and `citations` columns are read where
#'   present.
#' @return A tibble of class `scopus_record_diff`, one row per record, with the
#'   columns `status`, `scopus_id`, `doi`, `title`, `year`, `citations_old` and
#'   `citations_new`. `status` is a factor with levels `"added"` (in `new`
#'   only), `"removed"` (in `old` only), `"conflict"` (see Details) and
#'   `"unchanged"` (in both). Rows are sorted by status, then DOI, identifier
#'   and title, in byte order, so the order is the same under every locale and
#'   in the Python twin. The integer attributes `n_old_without_id_or_doi` and
#'   `n_new_without_id_or_doi` count the records on each side that carried
#'   neither key and so were not compared. Printing shows the counts in each
#'   category, and those records where there are any.
#' @details
#' Two records are one record when they share a 'Scopus' identifier, or when
#' they share a DOI and one of them lacks an identifier. DOIs are compared as
#' [scopus_extract_dois()] compares them, without resolver prefixes and
#' ignoring case. Records with different identifiers are never matched, even
#' under one DOI, since 'Scopus' gives one DOI to distinct papers as well as
#' holding duplicate records of one paper ([scopus_combine()] gives the
#' sources).
#'
#' A record found in one retrieval only is a `"conflict"` where the other
#' retrieval gives its DOI to a different record. It may have been re-indexed
#' under a new identifier, or it may be a distinct paper sharing the DOI. Only
#' the two records themselves can tell, so it is counted neither as added nor
#' as removed. A record without an identifier whose DOI two identified
#' records carry is in the same position. A record with neither an identifier
#' nor a DOI cannot be matched at all, and is left out of the rows and counted.
#'
#' `scopus_id` is the identifier the record was matched on, missing for a
#' record matched on its DOI alone. `doi` is the DOI without its resolver
#' prefix, in the case the record gives it. `doi`, `title` and `year` come from
#' the later retrieval where it holds the record and gives a value, and from
#' the earlier one otherwise, while `citations_old` and `citations_new` come
#' from each retrieval in turn. Where one retrieval holds a record more than
#' once, the first value it gives is used.
#' @seealso [scopus_diff_dois()] to compare DOIs alone, [scopus_combine()] to
#'   merge the retrievals.
#' @examples
#' # The bundled corpus carries no 'Scopus' identifiers, so its records are
#' # matched on their DOIs, and the eleven in each pull without one cannot be
#' # compared at all.
#' baseline <- example_records[example_records$year <= 2023, ]
#' later <- example_records[-1, ]
#' scopus_diff_records(old = baseline, new = later)
#'
#' # Two pulls of three records each, with identifiers as a live harvest
#' # carries them. 10.5555 is the DOI prefix reserved for tests, so none of
#' # these resolve. The later pull holds 10.5555/c under a new identifier,
#' # which makes both records under it a conflict to check, and a record from
#' # another source, without an identifier, that is new.
#' old <- data.frame(
#'   scopus_id = c("85000000001", "85000000002", "85000000003"),
#'   doi = c("10.5555/a", "10.5555/b", "10.5555/c"),
#'   citations = c(5L, 3L, 8L)
#' )
#' new <- data.frame(
#'   scopus_id = c("85000000001", "85000000033", NA),
#'   doi = c("10.5555/a", "10.5555/c", "https://doi.org/10.5555/D"),
#'   citations = c(9L, 10L, NA)
#' )
#' scopus_diff_records(old, new)
#' @export
scopus_diff_records <- function(old, new) {
  old <- scopus_diff_frame(old, "old")
  new <- scopus_diff_frame(new, "new")
  both <- rbind(old, new)
  later <- rep(c(FALSE, TRUE), c(nrow(old), nrow(new)))

  # The default de-duplication rule, applied across the two retrievals, so
  # the diff and a merge of the same two sets agree on which records are one.
  key <- scopus_dedupe_groups(both$scopus_id, both$doi, "id_or_shared_doi")$key
  keyed <- !startsWith(key, "row:")
  doi <- scopus_tidy_dois(both$doi)
  doi_key <- tolower(doi)

  groups <- unique(key[keyed])
  in_old <- groups %in% key[keyed & !later]
  in_new <- groups %in% key[keyed & later]
  status <- ifelse(in_old & in_new, "unchanged", ifelse(in_new, "added", "removed"))
  # A record in one retrieval only whose DOI the other retrieval gives to a
  # record of its own. That record is a different one, or the two would share
  # a key and the first would be in both.
  elsewhere <- keyed & !is.na(doi_key) &
    ifelse(later, doi_key %in% doi_key[!later], doi_key %in% doi_key[later])
  status[!(in_old & in_new) & groups %in% key[elsewhere]] <- "conflict"

  # The first value each group's rows give on one side, NA where none does.
  first_value <- function(values, side) {
    given <- keyed & side & !is.na(values)
    if (is.character(values)) given <- given & nzchar(trimws(values))
    values[given][match(groups, key[given])]
  }
  # The later retrieval's value where it gives one, the earlier one's if not.
  latest_value <- function(values) {
    out <- first_value(values, later)
    missing <- is.na(out)
    out[missing] <- first_value(values, !later)[missing]
    out
  }

  # The identifier a record was matched on, which its group key carries.
  scopus_id <- rep(NA_character_, length(groups))
  identified <- startsWith(groups, "id:")
  scopus_id[identified] <- substring(groups[identified], 4L)

  out <- tibble::tibble(
    status = factor(status, levels = c("added", "removed", "conflict", "unchanged")),
    scopus_id = scopus_id,
    doi = latest_value(doi),
    title = latest_value(both$title),
    year = latest_value(both$year),
    citations_old = first_value(both$citations, !later),
    citations_new = first_value(both$citations, later)
  )
  # Byte order, as the Python twin sorts, whatever the locale's collation.
  out <- out[order(out$status, out$doi, out$scopus_id, out$title, method = "radix"), ,
             drop = FALSE]
  out <- tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_record_diff")
  attr(out, "n_old_without_id_or_doi") <- sum(!keyed & !later)
  attr(out, "n_new_without_id_or_doi") <- sum(!keyed & later)
  out
}

#' @export
print.scopus_record_diff <- function(x, ...) {
  counts <- table(factor(x$status, levels = c("added", "removed", "conflict", "unchanged")))
  untracked <- scopus_not_compared(
    attr(x, "n_old_without_id_or_doi"), attr(x, "n_new_without_id_or_doi"),
    "without an identifier or a DOI"
  )
  scopus_print_line(
    "{.cls scopus_record_diff} {counts[['added']]} added, ",
    "{counts[['removed']]} removed, {counts[['conflict']]} in conflict, ",
    "{counts[['unchanged']]} unchanged{untracked}"
  )
  print(tibble::as_tibble(x), ...)
  invisible(x)
}

# The columns scopus_diff_records() reads, from a record set or a data frame
# of records, with NA for any the input lacks.
scopus_diff_frame <- function(x, arg, call = rlang::caller_env()) {
  if (!is.data.frame(x)) {
    scopus_abort_bad_input(
      sprintf("`%s` must be a `scopus_records` object or a data frame of records.", arg),
      call = call
    )
  }
  if (!any(c("scopus_id", "doi") %in% names(x))) {
    scopus_abort_bad_input(
      sprintf("`%s` must have a `scopus_id` or a `doi` column.", arg),
      call = call
    )
  }
  column <- function(name, missing) {
    if (name %in% names(x)) x[[name]] else rep(missing, nrow(x))
  }
  data.frame(
    scopus_id = as.character(column("scopus_id", NA_character_)),
    doi = as.character(column("doi", NA_character_)),
    title = as.character(column("title", NA_character_)),
    year = column("year", NA_integer_),
    citations = column("citations", NA_integer_),
    stringsAsFactors = FALSE
  )
}
