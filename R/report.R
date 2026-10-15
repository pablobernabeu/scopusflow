# A reproducible search-strategy record, assembled from what a harvest already
# carries and rendered for a methods section.
#
# The one rule this file exists to keep: nothing here may be inferred from the
# running session. No Sys.time() stands in for an absent retrieval stamp, no
# total is guessed from the row count, no duplicate count is reported unless a
# de-duplication step recorded one, and no PRISMA-S item is claimed without
# evidence in the object. The output is destined for a published methods
# section, where a plausible figure nobody can check is worse than an admitted
# gap, so every field the objects cannot vouch for says so in words.

# The 16 PRISMA-S items, in the order and under the names the checklist gives
# them (Rethlefsen et al., 2021). Which side of the map an item falls on is
# decided per report from the evidence, so this table holds only the names.
scopus_prisma_names <- function() {
  c(
    "Database name", "Multi-database searching", "Study registries",
    "Online resources and browsing", "Citation searching", "Contacts",
    "Other methods", "Full search strategies", "Limits and restrictions",
    "Search filters", "Prior work", "Updates", "Dates of searches",
    "Peer review", "Total records", "Deduplication"
  )
}

# English month names, spelled out here and never read from the locale: the
# paragraph is compared byte for byte against the Python twin's, and
# format(date, "%B") returns whatever the machine's locale says.
scopus_report_months <- function() {
  c("January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December")
}

#' Assemble a reproducible record of a 'Scopus' search
#'
#' Turns a harvest, or a plan not yet run, into the search-strategy record a
#' systematic review has to report: what was searched, exactly how, when, how
#' much came back, and how much the API said there was. The record prints as a
#' readable report, formats as a methods paragraph fit to paste into a
#' manuscript, and writes as Markdown. The reporting standard it follows is
#' PRISMA-S (Rethlefsen et al., 2021), together with the identification counts
#' of the PRISMA 2020 flow diagram.
#'
#' @param x A [scopus_records] object, which supplies the counts and the
#'   retrieval provenance and, through its `plan` attribute, the plan; or a bare
#'   [scopus_plan()] for a search that has not been run yet. For `format()` and
#'   `print()`, the report object itself.
#' @param plan Optional [scopus_plan()] describing `x`. Supply it when a record
#'   set does not carry one, for example one read back from a `.csv`, a merged
#'   set, or one saved by [scopus_fetch()] in scopusflow 0.4.0 or earlier,
#'   which attached none. An explicit plan takes precedence over the one `x`
#'   carries. A one-cell plan supplied for a set without per-cell counts takes
#'   the set's own row count and `total_results`.
#' @param file Optional path at which to write the record as Markdown. A file is
#'   written only when this argument is supplied, and only to the exact path
#'   given, so the package leaves the working directory untouched unless asked.
#'   Parent directories are assumed to exist already.
#' @return A list of class `scopus_search_report`, returned invisibly when
#'   `file` is written. Its elements are the fields the record is built from:
#'   `database`, `platform`, `query` (the base query), `field`, `expression`
#'   (the field-wrapped query of each cell), `view`, `page_size`, `paging`,
#'   `max_results` (the cap on records per cell), `partition`, `n_cells`,
#'   `years`, `years_run` (the years of the cells a stopped harvest ran),
#'   `cells` (a tibble of `cell`, `limit`, `n_records` and `reported_total`),
#'   `searched_at` and `searched_until` (the earliest and latest retrieval
#'   times), `version`, `n_records`, `n_with_doi`, `reported_total`,
#'   `cells_reported` (how many cells reported a total), `stopped_early`,
#'   `cells_planned`, `cells_run`, `not_run` (the cells a
#'   stopped harvest never reached), `records_combined`, `duplicates_removed`,
#'   `deduplicated`, `dedupe_rule` and `doi_conflicts` (the rule
#'   [scopus_combine()] matched records by, and the DOIs it left shared across
#'   identifiers), `snippet` and `prisma` (a tibble of `item`, `name`,
#'   `source` and `note`). A field the objects do not record is `NA`.
#' @details
#' Everything in the record comes from the objects handed to it. The dates of
#' the search are the `retrieved_at` and `retrieved_until` attributes
#' [scopus_fetch()] attaches, never the current time. A harvest resumed over
#' several days, or a baseline merged with its update, is dated from its first
#' retrieval to its last. PRISMA-S item 13 then gives the date of the last
#' search, as the checklist asks. Stamps that fall on one UTC day give that
#' single date. The years are those the cells' limits sent, and years with gaps
#' between them are listed, since a span would claim years no cell searched.
#' The number of records the API reported as matching is what the
#' cells recorded (the `cell_totals` attribute [scopus_fetch_plan()] attaches,
#' or, for a set from a single search, its `total_results`), never an inference
#' from the number of rows, and it is given overall only when every cell
#' reported one; and the duplicates removed are those [scopus_combine()]
#' recorded removing, matched by the rule it recorded. Where
#' an attribute is absent, as it is for a set read back from a `.csv`, for the
#' bundled corpus, and for a cell resumed from a checkpoint written before these
#' attributes existed, the record says the field is unrecorded and fills
#' nothing in. This matters most for completeness: a harvest whose reported
#' total is unknown is never described as exhaustive.
#'
#' A harvest capped by `max_results` says so. A cell that holds as many
#' records as the cap allowed, where the API reported more or reported
#' nothing, reads "stopped at the requested cap". The completeness line puts
#' the shortfall down to the cap when every cell that fell short stopped at it,
#' and otherwise counts the cells that did. Item 9 names the cap, or says that
#' it did not bind, and the reproduction snippet passes it. The Python twin's
#' `fetch_plan()` can also be stopped between cells, as its app's Cancel stops
#' it. Its record then says how many of the planned cells ran, the years they
#' covered and that the harvest is incomplete, and it marks the rest "not run".
#' This package's harvests cannot stop part-way, but a set carrying those
#' attributes is described the same way, so that the two records stay one
#' rendering.
#'
#' The PRISMA-S map is decided the same way. Items the package holds evidence
#' for (the database and platform, that Scopus was searched on its own, the
#' full strategy and the limits where a plan records them, the date, the
#' totals, and de-duplication where it was performed) are listed as supplied.
#' Without a plan, the year limit is unrecorded, not absent, and the record says
#' so. The rest, among them peer review of the strategy, grey literature and
#' citation searching, are listed as the author's to supply, because the
#' package has no way to know them.
#' @references
#' Rethlefsen, M. L., Kirtley, S., Waffenschmidt, S., Ayala, A. P., Moher, D.,
#' Page, M. J., & Koffel, J. B. (2021). PRISMA-S: an extension to the PRISMA
#' Statement for Reporting Literature Searches in Systematic Reviews.
#' *Systematic Reviews*, *10*, 39. \doi{10.1186/s13643-020-01542-z}
#' @seealso [scopus_plan()], [scopus_fetch_plan()], [scopus_combine()]
#' @examples
#' # A search described but not yet run. The record says so throughout rather
#' # than implying figures it cannot have.
#' plan <- scopus_plan('"graphene supercapacitor"', years = 2015:2024,
#'                     field = "TITLE-ABS-KEY", partition = "year")
#' scopus_search_report(plan)
#'
#' # The same search after a harvest. The bundled corpus of real articles
#' # stands in for one, since 'Scopus' records may not be redistributed, so the
#' # attributes a live retrieval records are set here by hand. Their values are
#' # illustrative, and the records came from OpenAlex, so the record below
#' # describes no search that was run.
#' recs <- example_records
#' attr(recs, "plan") <- plan
#' attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
#' attr(recs, "scopusflow_version") <- "0.3.0"
#' report <- scopus_search_report(recs)
#' report
#'
#' # The methods paragraph, and the Markdown record for a supplementary file.
#' cat(format(report, style = "paragraph"))
#' path <- tempfile(fileext = ".md")
#' scopus_search_report(recs, file = path)
#' @export
scopus_search_report <- function(x, plan = NULL, file = NULL) {
  if (!is.null(plan) && !is_scopus_plan(plan)) {
    scopus_abort_bad_input("The plan must be a search plan.")
  }
  if (is_scopus_plan(x)) {
    records <- NULL
    plan <- plan %||% x
  } else if (is_scopus_records(x)) {
    records <- x
    plan <- plan %||% attr(x, "plan")
    if (!is.null(plan) && !is_scopus_plan(plan)) plan <- NULL
  } else {
    scopus_abort_bad_input("A search report needs a record set or a search plan.")
  }

  report <- scopus_report_build(records, plan)

  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
      scopus_abort_bad_input("The file must be a single non-empty path.")
    }
    scopus_write_lines(format(report, style = "markdown"), file)
    return(invisible(report))
  }
  report
}

#' @rdname scopus_search_report
#' @param style Which rendering to return: `"report"` for the readable record
#'   that `print()` shows, `"paragraph"` for the methods paragraph, or
#'   `"markdown"` for the whole record as Markdown, which is what `file` writes.
#' @param ... Ignored, present for compatibility with the generics.
#' @return `format()` returns a length-one character string.
#' @export
format.scopus_search_report <- function(x, style = c("report", "paragraph", "markdown"), ...) {
  style <- scopus_match_arg(style, c("report", "paragraph", "markdown"))
  switch(
    style,
    report = scopus_report_render(x),
    paragraph = scopus_report_paragraph(x),
    markdown = scopus_report_markdown(x)
  )
}

#' @rdname scopus_search_report
#' @export
print.scopus_search_report <- function(x, ...) {
  cat(scopus_report_render(x), "\n", sep = "")
  # Named here, and never inside format(), so that the rendered record itself
  # stays free of language-specific instructions and can be compared with the
  # Python twin's line for line.
  cat("\nThe methods paragraph is format(x, style = \"paragraph\"); ",
      "pass file = to write the whole record as Markdown.\n", sep = "")
  invisible(x)
}

# Field extraction ----------------------------------------------------------

scopus_report_build <- function(records, plan) {
  stoppage <- scopus_report_stop(records, plan)
  cells <- scopus_report_cells(records, plan, joined = stoppage$joined)
  reported <- cells$reported_total
  n_cells_reported <- sum(!is.na(reported))
  total <- if (nrow(cells) > 0L && n_cells_reported == nrow(cells)) {
    sum(reported)
  } else {
    NA_real_
  }

  combined <- if (is.null(records)) NULL else attr(records, "combined")
  stamp <- if (is.null(records)) NULL else attr(records, "retrieved_at")
  # The last search, read only beside a first one. A set written before
  # `retrieved_until` existed has the one stamp, and a latest time recorded
  # before the earliest cannot widen the span backwards.
  until <- if (is.null(stamp)) NULL else {
    max(c(as.POSIXct(stamp), as.POSIXct(attr(records, "retrieved_until") %||% stamp)))
  }
  version <- if (is.null(records)) NULL else attr(records, "scopusflow_version")
  paging <- if (is.null(records)) NA_character_ else (attr(records, "paging") %||% NA_character_)
  cap <- scopus_report_cap(records)
  # The years of the cells a stopped harvest ran, read from their limits as
  # the years of the plan are.
  years_run <- if (stoppage$joined) {
    scopus_report_years(cells[!(cells$cell %in% stoppage$not_run), ], plan)
  } else {
    NA_character_
  }

  out <- list(
    database = "Scopus",
    platform = "Elsevier Scopus Search API",
    query = if (is.null(plan)) NA_character_ else attr(plan, "base_query"),
    field = if (is.null(plan)) NA_character_ else (attr(plan, "field") %||% NA_character_),
    expression = scopus_report_expression(records, plan),
    view = if (is.null(plan)) NA_character_ else attr(plan, "view"),
    page_size = if (is.null(plan)) NA_integer_ else as.integer(attr(plan, "page_size")),
    paging = paging,
    max_results = cap,
    partition = if (is.null(plan)) NA_character_ else attr(plan, "partition"),
    n_cells = if (is.null(plan)) NA_integer_ else nrow(plan),
    years = scopus_report_years(cells, plan),
    years_run = years_run,
    cells = cells,
    searched_at = if (is.null(stamp)) NA else min(stamp),
    searched_until = if (is.null(until)) NA else until,
    version = if (is.null(version)) NA_character_ else paste(version, collapse = ", "),
    n_records = if (is.null(records)) NA_integer_ else nrow(records),
    n_with_doi = if (is.null(records)) NA_integer_ else sum(!is.na(records$doi)),
    reported_total = total,
    cells_reported = n_cells_reported,
    stopped_early = stoppage$stopped,
    cells_planned = stoppage$cells_planned,
    cells_run = stoppage$cells_run,
    not_run = stoppage$not_run,
    records_combined = scopus_report_combined(combined, "n_in"),
    duplicates_removed = scopus_report_combined(combined, "n_removed"),
    deduplicated = if (is.null(combined)) NA else isTRUE(combined$deduplicated),
    dedupe_rule = scopus_report_rule(combined),
    doi_conflicts = scopus_report_combined(combined, "doi_conflicts"),
    snippet = scopus_report_snippet(plan, paging, cap)
  )
  out$prisma <- scopus_report_prisma(out)
  structure(out, class = "scopus_search_report")
}

# What the records say about a harvest stopped before its last cell. Only the
# Python twin's fetch_plan() stops part-way, when its should_stop callable
# returns TRUE, as the Cancel button of its app arranges, and it records
# `stopped_early`, `cells_planned` and `cells_run`. This twin's app cancels by
# killing its background worker, so no set this package builds carries them,
# and the branch is dormant here. It is kept so that the two renderings stay
# one function, pinned by a shared golden file.
#
# The recorded cells are placed on the plan's cells only when the plan is the
# one the harvest ran. It must hold as many cells as were planned, the recorded
# ones among them. A plan passed by hand that does not leaves the cells
# unrecorded, as before, while the set still says that it was stopped.
scopus_report_stop <- function(records, plan) {
  out <- list(stopped = FALSE, cells_planned = NA_integer_,
              cells_run = NA_integer_, joined = FALSE, not_run = integer())
  if (is.null(records) || !isTRUE(attr(records, "stopped_early"))) {
    return(out)
  }
  counts <- attr(records, "cell_totals")
  recorded <- if (is.data.frame(counts)) as.integer(counts$cell) else NULL
  run <- scopus_report_whole(attr(records, "cells_run"))
  if (is.na(run) && !is.null(recorded)) run <- length(recorded)
  planned <- scopus_report_whole(attr(records, "cells_planned"))
  if (is.na(planned) && !is.null(plan)) planned <- nrow(plan)
  if (is.na(run) || is.na(planned)) {
    return(out)
  }
  joined <- !is.null(plan) && !is.null(recorded) && nrow(plan) == planned &&
    !anyDuplicated(recorded) && all(recorded %in% as.integer(plan$cell))
  list(
    stopped = TRUE, cells_planned = planned, cells_run = run, joined = joined,
    not_run = if (joined) setdiff(as.integer(plan$cell), recorded) else integer()
  )
}

# Turns a count recorded as an attribute into an integer, giving NA for
# anything but one whole number.
scopus_report_whole <- function(x) {
  if (is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x)) {
    as.integer(x)
  } else {
    NA_integer_
  }
}

# The cap on records per cell a set was retrieved under, as scopus_fetch() and
# scopus_fetch_plan() record it when one was set, or NA. A plan not yet run
# has none to report. The cap is a whole number, as scopus_check_max_results()
# demands, and anything else is read as no cap, as the Python twin reads it.
scopus_report_cap <- function(records) {
  cap <- if (is.null(records)) NULL else attr(records, "max_results")
  if (is.numeric(cap) && length(cap) == 1L && is.finite(cap) && cap >= 1 &&
      cap == round(cap)) {
    as.numeric(cap)
  } else {
    NA_real_
  }
}

# Which cells stopped at the cap: those holding as many records as it allowed,
# where the API reported more or reported nothing. A cell holding all the
# records the API reported is complete, whatever the cap.
scopus_report_capped <- function(cells, cap) {
  n <- cells$n_records
  reported <- cells$reported_total
  !is.na(cap) & !is.na(n) & n >= cap & (is.na(reported) | reported > n)
}

# The cap a record set was retrieved under, with how many of its cells stopped
# at it and how many ran, or NULL when the set records no cap. autoplot() and
# the app read the cells as the search record does.
scopus_records_cap <- function(records) {
  cap <- scopus_report_cap(records)
  if (is.na(cap)) {
    return(NULL)
  }
  plan <- attr(records, "plan")
  if (!is_scopus_plan(plan)) plan <- NULL
  stoppage <- scopus_report_stop(records, plan)
  cells <- scopus_report_cells(records, plan, joined = stoppage$joined)
  list(cap = cap, capped = sum(scopus_report_capped(cells, cap)),
       cells = nrow(cells) - length(stoppage$not_run))
}

# The per-cell table. A plan supplies the cells and their year limits; the
# counts come from the `cell_totals` attribute scopus_fetch_plan() records, and
# stay NA when the set never carried one (a CSV round trip, the bundled corpus,
# a set assembled by hand). A set from a single search, as scopus_fetch()
# returns, carries no cell counts, only its own total, so a plan with one cell,
# which stands for that search, takes the set's figures. A harvest stopped
# part-way recorded only the cells it ran. When `joined` says the plan is the
# one it ran (see scopus_report_stop()), those cells take their counts and the
# rest stay NA, to be read as not run. Without a plan the whole retrieval is
# treated as one cell, so the rest of the code has a single shape to render.
scopus_report_cells <- function(records, plan, joined = FALSE) {
  counts <- if (is.null(records)) NULL else attr(records, "cell_totals")
  if (!is.null(plan)) {
    out <- tibble::tibble(
      cell = as.integer(plan$cell),
      limit = as.character(plan$date),
      n_records = NA_integer_,
      reported_total = NA_real_
    )
    if (is.data.frame(counts) && nrow(counts) == nrow(out) &&
        identical(as.integer(counts$cell), out$cell)) {
      out$n_records <- as.integer(counts$n_records)
      out$reported_total <- as.numeric(counts$reported_total)
    } else if (joined) {
      at <- match(as.integer(counts$cell), out$cell)
      out$n_records[at] <- as.integer(counts$n_records)
      out$reported_total[at] <- as.numeric(counts$reported_total)
    } else if (nrow(out) == 1L && !is.null(records)) {
      out$n_records <- nrow(records)
      out$reported_total <- scopus_report_total_results(records)
    }
    return(out)
  }
  if (!is.null(records)) {
    return(tibble::tibble(
      cell = 1L,
      limit = NA_character_,
      n_records = nrow(records),
      reported_total = scopus_report_total_results(records)
    ))
  }
  tibble::tibble(cell = integer(), limit = character(),
                 n_records = integer(), reported_total = numeric())
}

# The API's own count of matching records, as the set carries it.
scopus_report_total_results <- function(records) {
  total <- attr(records, "total_results")
  if (is.null(total)) NA_real_ else as.numeric(total)
}

# The field-wrapped query of each cell. The plan holds it; failing that the
# records' own `query` column does, which is what a set fetched without a plan
# carries.
scopus_report_expression <- function(records, plan) {
  q <- if (!is.null(plan)) plan$query else if (!is.null(records)) records$query else NULL
  q <- unique(q[!is.na(q)])
  if (length(q) == 0L) NA_character_ else as.character(q)
}

# The years actually searched, read back from the cells' date limits rather
# than from any year vector, because the limit is what reached the API. A range
# limit such as "2015-2025" covers every year in it, since the API takes the
# range inclusively, and a single-year limit covers that year.
scopus_report_years <- function(cells, plan) {
  covered <- scopus_report_covered(cells)
  if (length(covered) == 0L) {
    return(NA_character_)
  }
  scopus_report_year_list(covered)
}

# The years the cells' date limits cover, sorted, as scopus_report_years()
# reads them. Empty when no cell carries a limit.
scopus_report_covered <- function(cells) {
  limits <- cells$limit[!is.na(cells$limit)]
  covered <- unlist(lapply(limits, function(limit) {
    found <- as.integer(regmatches(limit, gregexpr("[0-9]{4}", limit))[[1]])
    if (length(found) == 0L) integer() else seq(min(found), max(found))
  }))
  sort(unique(as.integer(covered)))
}

# Sorted years as a methods section states them. One unbroken run reads as a
# span, "2015 to 2024". Years with gaps between them are listed, "2015, 2020
# and 2025", because a span over the gaps would claim years no cell searched.
# Within such a list, a run of three or more years is still written as a span,
# so that a decade is not spelled out year by year. A run of two is listed,
# since a span saves no words there. The Python twin renders the same years
# identically.
scopus_report_year_list <- function(years) {
  runs <- split(years, cumsum(c(1L, diff(years) != 1L)))
  span <- function(run) sprintf("%d to %d", run[1L], run[length(run)])
  if (length(runs) == 1L) {
    run <- runs[[1L]]
    return(if (length(run) == 1L) as.character(run) else span(run))
  }
  parts <- unlist(lapply(runs, function(run) {
    if (length(run) >= 3L) span(run) else as.character(run)
  }), use.names = FALSE)
  paste(paste(parts[-length(parts)], collapse = ", "), "and", parts[length(parts)])
}

scopus_report_combined <- function(combined, field) {
  if (is.null(combined) || is.null(combined[[field]])) NA_integer_ else {
    as.integer(combined[[field]])
  }
}

# The de-duplication rule a merge recorded, or NA where it recorded no rule this
# version knows. A set merged by 0.4.0 or earlier recorded none.
scopus_report_rule <- function(combined) {
  rule <- if (is.null(combined)) NULL else combined$rule
  if (is.character(rule) && length(rule) == 1L && rule %in% scopus_dedupe_rules()) {
    rule
  } else {
    NA_character_
  }
}

# PRISMA-S item 16 as the merge recorded it: how many records were removed and
# the rule that matched them. A set that records no rule was merged by 0.4.0,
# whose rule is "id_then_doi", so it keeps the wording it was written with.
# Where records with different identifiers share a DOI, the count is given, so
# that the reviewer knows how many to check by hand.
scopus_report_dedupe_note <- function(x) {
  rule <- if (is.na(x$dedupe_rule)) "id_then_doi" else x$dedupe_rule
  how <- switch(
    rule,
    id_or_shared_doi = "matched on a shared Scopus identifier, or on a shared DOI where one record lacks an identifier.",
    id_or_doi = "matched on a shared Scopus identifier or a shared DOI, even where the identifiers differ.",
    id_then_doi = "matched on the Scopus identifier and failing that the DOI."
  )
  note <- sprintf(
    "%s duplicate records removed by scopus_combine() from %s combined, %s",
    scopus_report_count(x$duplicates_removed), scopus_report_count(x$records_combined), how
  )
  conflicts <- x$doi_conflicts
  if (is.na(conflicts) || conflicts < 1L) {
    return(note)
  }
  n <- scopus_report_count(conflicts)
  noun <- if (conflicts == 1L) "DOI" else "DOIs"
  paste(note, if (identical(rule, "id_or_doi")) {
    sprintf("Records with different Scopus identifiers were merged under %s shared %s.",
            n, noun)
  } else {
    sprintf("Records with different Scopus identifiers that share a DOI were kept, which leaves %s %s to check by hand.",
            n, noun)
  })
}

# The runnable reproduction. Built from what the plan records, so that
# evaluating it returns a plan identical to the one the report describes; the
# package's test suite asserts exactly that over a grid of plans. Without a
# plan there is nothing to reproduce and the snippet is NA. The paging mode is
# settled by the fetch, not the plan, and scopus_fetch_plan() pages by offset
# unless told otherwise, so a harvest the records say was paged by cursor is
# reproduced with cursor = TRUE. A cap is an argument of the fetch too, passed
# whenever the set records one, whether or not it stopped a cell, since the
# harvest was run under it.
scopus_report_snippet <- function(plan, paging = NA_character_,
                                  max_results = NA_real_) {
  if (is.null(plan)) {
    return(NA_character_)
  }
  years <- app_years_code(plan$year)
  if (is.null(years)) {
    # Under partition = "none" the years survive only as the cell's date range,
    # which is all the plan needs back: only its endpoints reach the API.
    limits <- plan$date[!is.na(plan$date)]
    yrs <- as.integer(unlist(regmatches(limits, gregexpr("[0-9]{4}", limits))))
    years <- if (length(yrs) == 0L) NULL else app_years_code(seq(min(yrs), max(yrs)))
  }
  args <- sprintf("  query = %s", app_quote(attr(plan, "base_query")))
  if (!is.null(years)) args <- c(args, sprintf("  years = %s", years))
  field <- attr(plan, "field")
  if (!is.null(field)) args <- c(args, sprintf("  field = %s", app_quote(field)))
  args <- c(
    args,
    sprintf("  view = %s", app_quote(attr(plan, "view"))),
    sprintf("  page_size = %d", as.integer(attr(plan, "page_size"))),
    sprintf("  partition = %s", app_quote(attr(plan, "partition")))
  )
  fetch_args <- "plan"
  if (!is.na(max_results)) {
    # format(), as in the app's code mirror, so a cap past 2^31 is written out
    # in full and never as NA or in scientific notation.
    fetch_args <- c(fetch_args, sprintf(
      "max_results = %s", format(max_results, scientific = FALSE, trim = TRUE)
    ))
  }
  if (identical(paging, "cursor")) fetch_args <- c(fetch_args, "cursor = TRUE")
  fetch <- sprintf("records <- scopus_fetch_plan(%s)", paste(fetch_args, collapse = ", "))
  paste(
    c(
      "library(scopusflow)",
      "",
      sprintf("plan <- scopus_plan(\n%s\n)", paste(args, collapse = ",\n")),
      "",
      fetch
    ),
    collapse = "\n"
  )
}

# The PRISMA-S map. An item is listed as supplied only where the objects hold
# the evidence for it; everything else, including items the package could in
# principle support but has no record of here, is the author's.
scopus_report_prisma <- function(x) {
  names_16 <- scopus_prisma_names()
  supplied <- integer()
  notes <- character(16)

  notes[1] <- sprintf("%s, searched on the %s.", x$database, x$platform)
  supplied <- c(supplied, 1L)

  # Item 2 asks which databases were searched together on one platform, as
  # Ovid searches several at once. The API searches Scopus alone, which the
  # record can state, as it states the platform for item 1. Any other database
  # a review searched is named under item 1, by the author. A plan not yet run
  # is described in the present, as the paragraph describes it.
  notes[2] <- sprintf(
    "Scopus %s searched on its own, not as one of several databases searched together on one platform.",
    if (scopus_report_run(x)) "was" else "is"
  )
  supplied <- c(supplied, 2L)
  notes[3] <- "Any trial or study registry searched."
  notes[4] <- "Any web site, table of contents or other source searched or browsed by hand."
  notes[5] <- "Any backward or forward citation searching."
  notes[6] <- "Any authors or organisations contacted for studies."
  notes[7] <- "Any further method used to identify records."

  # Without a plan, the expression is the one the records carry. The field tag
  # and year limit it was sent with are recorded nowhere, the year having
  # travelled as the request's date parameter, so the full strategy is not here.
  if (anyNA(x$expression)) {
    notes[8] <- "The exact strategy, which this set does not record."
  } else if (is.na(x$partition)) {
    notes[8] <- "The search expression is recorded, but no plan records the limits it was sent with."
  } else {
    notes[8] <- "The search expression, field tag and year limit of every cell, as the plan sends them."
    supplied <- c(supplied, 8L)
  }

  if (!is.na(x$partition)) {
    # A cap and a stop are limits on what was retrieved, so each is named
    # between the year limit and the limits scopusflow never applies.
    own <- "scopusflow applies no document type, language or subject area limit of its own."
    stop_clause <- scopus_report_stop_clause(x)
    extra <- c(scopus_report_cap_sentence(x),
               if (!is.null(stop_clause)) paste0(stop_clause, "."))
    notes[9] <- if (!is.na(x$years)) {
      paste(c(sprintf("Publication years %s.", x$years), extra, own), collapse = " ")
    } else if (length(extra) > 0L) {
      paste(c("No year limit was applied.", extra, own), collapse = " ")
    } else {
      "No year limit was applied, and scopusflow applies no document type, language or subject area limit of its own."
    }
    supplied <- c(supplied, 9L)
  } else {
    notes[9] <- "Any limit applied to the search, which this set does not record."
  }

  notes[10] <- "Any published or validated search filter used, and where it came from. scopusflow applies none of its own."
  notes[11] <- "Any earlier review or strategy this search was adapted from."
  notes[12] <- "Whether the search was re-run or updated, and when."

  # PRISMA-S item 13 asks for the date of the last search. Records, not
  # cells, in the span, since a merged set mixes searches.
  if (scopus_report_spans_days(x)) {
    notes[13] <- sprintf(
      "Last searched on %s; the records were retrieved between %s and %s.",
      scopus_report_stamp(x$searched_until), scopus_report_stamp(x$searched_at),
      scopus_report_stamp(x$searched_until)
    )
    supplied <- c(supplied, 13L)
  } else if (!is.na(x$searched_at)) {
    notes[13] <- sprintf("%s.", scopus_report_stamp(x$searched_at))
    supplied <- c(supplied, 13L)
  } else if (is.na(x$n_records)) {
    notes[13] <- "The date of each search, which this plan has not been run to produce."
  } else {
    notes[13] <- "The date of each search, which this set does not carry."
  }

  notes[14] <- "Whether the strategy was peer reviewed, and by whom."

  if (!is.na(x$n_records)) {
    notes[15] <- if (isTRUE(x$stopped_early)) {
      sprintf("%s records retrieved from Scopus before %s.",
              scopus_report_count(x$n_records), scopus_report_stop_phrase(x))
    } else if (is.na(x$reported_total)) {
      sprintf("%s records retrieved from Scopus. The API's own count of matching records is unrecorded.",
              scopus_report_count(x$n_records))
    } else {
      sprintf("%s records retrieved from Scopus, of %s the API reported as matching.",
              scopus_report_count(x$n_records), scopus_report_count(x$reported_total))
    }
    supplied <- c(supplied, 15L)
  } else {
    notes[15] <- "The number of records identified, which this plan has not been run to produce."
  }

  if (isTRUE(x$deduplicated) && !is.na(x$duplicates_removed)) {
    notes[16] <- scopus_report_dedupe_note(x)
    supplied <- c(supplied, 16L)
  } else if (is.na(x$n_records)) {
    notes[16] <- "How duplicate records were removed, which this plan has not been run to produce."
  } else {
    notes[16] <- "How duplicate records were removed, which this set does not record."
  }

  item <- seq_len(16)
  tibble::tibble(
    item = as.integer(item),
    name = names_16,
    source = ifelse(item %in% supplied, "record", "author"),
    note = notes
  )
}

# Rendering -----------------------------------------------------------------

# Counts are grouped for readability in both engines, so a five-figure total
# reads the same in the R report and the Python one. Rounded, never coerced
# with as.integer(), which returns NA above 2^31: the reported totals come back
# from the API as doubles, and a report that printed NA for a very large search
# would be worse than one that printed a long number.
scopus_report_count <- function(n) {
  format(round(as.numeric(n)), big.mark = ",", scientific = FALSE, trim = TRUE)
}

# An instant, always shown in UTC. A retrieval stamp is an absolute time, and a
# methods section that says when a search ran should not depend on the reader's
# machine to interpret it.
scopus_report_stamp <- function(t) {
  paste(format(as.POSIXct(t), tz = "UTC", format = "%Y-%m-%d %H:%M:%S"), "UTC")
}

scopus_report_date <- function(t) {
  lt <- as.POSIXlt(as.POSIXct(t), tz = "UTC")
  sprintf("%d %s %d", lt$mday, scopus_report_months()[lt$mon + 1L], lt$year + 1900L)
}

# Whether the earliest and latest retrieval times fall on different UTC days.
# Only then is the search dated as a span. Stamps a few hours apart on one day
# give that day, as a single stamp always has, so the record of a one-day
# harvest, compared byte for byte with the Python twin's, is unchanged.
scopus_report_spans_days <- function(x) {
  if (is.na(x$searched_at) || is.na(x$searched_until)) {
    return(FALSE)
  }
  day <- function(t) format(as.POSIXct(t), tz = "UTC", format = "%Y-%m-%d")
  !identical(day(x$searched_at), day(x$searched_until))
}

scopus_report_run <- function(x) !is.na(x$n_records)

# A number of cells, as the record states it.
scopus_report_cells_text <- function(n) {
  sprintf("%s %s", scopus_report_count(n), if (n == 1) "cell" else "cells")
}

# How far a stopped harvest got, for the completeness line and item 15.
scopus_report_stop_phrase <- function(x) {
  sprintf("the harvest was stopped after %s of %s",
          scopus_report_count(x$cells_run), scopus_report_cells_text(x$cells_planned))
}

# The cells a stopped harvest planned and retrieved, and the years those
# covered, as one clause that item 9 and the paragraph each finish in their
# own way. NULL when the harvest ran every cell. The years are given only
# where the cells could be placed on the plan the harvest ran.
scopus_report_stop_clause <- function(x) {
  if (!isTRUE(x$stopped_early)) {
    return(NULL)
  }
  k <- x$cells_run
  if (x$cells_planned == 1L && k == 0L) {
    return("The single cell planned was not retrieved before the harvest was stopped")
  }
  retrieved <- if (k == 0L) {
    "none was"
  } else {
    paste(scopus_report_count(k), if (k == 1L) "was" else "were")
  }
  sprintf("Of the %s planned, %s retrieved before the harvest was stopped%s",
          scopus_report_cells_text(x$cells_planned), retrieved,
          if (is.na(x$years_run)) "" else sprintf(" (%s)", x$years_run))
}

# How many cells stopped at the cap, and how many fell short of the total the
# API reported for them. A capped cell with a known total counts in both.
scopus_report_cap_counts <- function(x) {
  n <- x$cells$n_records
  reported <- x$cells$reported_total
  list(capped = sum(scopus_report_capped(x$cells, x$max_results)),
       short = sum(!is.na(n) & !is.na(reported) & n < reported))
}

# Whether the cap stopped any cell ("bound") or stopped none of the cells that
# ran, every one of them counted ("unbound"). It cannot be judged ("unknown")
# where a cell's count is unrecorded or no cell ran. A harvest stopped before
# its first cell retrieved nothing under the cap, and saying that the cap did
# not bind would describe a retrieval that never happened. NA when no cap was
# set.
scopus_report_cap_status <- function(x) {
  if (is.na(x$max_results)) {
    return(NA_character_)
  }
  ran <- !(x$cells$cell %in% x$not_run)
  if (scopus_report_cap_counts(x)$capped > 0L) {
    "bound"
  } else if (any(ran) && !anyNA(x$cells$n_records[ran])) {
    "unbound"
  } else {
    "unknown"
  }
}

# The cap as item 9 states it, a limit on the search like the years. NULL when
# no cap was set.
scopus_report_cap_sentence <- function(x) {
  status <- scopus_report_cap_status(x)
  if (is.na(status)) {
    return(NULL)
  }
  cap <- scopus_report_count(x$max_results)
  switch(
    status,
    bound = sprintf("Records per cell were capped at %s.", cap),
    unbound = sprintf("A cap of %s records per cell was set and did not bind.", cap),
    unknown = sprintf("A cap of %s records per cell was set.", cap)
  )
}

# The cap as the paragraph states it. A cap that stopped a cell is set beside
# the shortfall. It explains the shortfall in full only when every cell that
# fell short stopped at it.
scopus_report_cap_paragraph <- function(x) {
  status <- scopus_report_cap_status(x)
  if (is.na(status)) {
    return(NULL)
  }
  if (!identical(status, "bound")) {
    return(scopus_report_cap_sentence(x))
  }
  cap <- scopus_report_count(x$max_results)
  counts <- scopus_report_cap_counts(x)
  if (!is.na(x$reported_total) && x$n_records < x$reported_total &&
      counts$capped == counts$short) {
    sprintf("Records per cell were capped at %s, which accounts for the whole shortfall.", cap)
  } else {
    sprintf("Records per cell were capped at %s, and %s of %s stopped at that cap.",
            cap, scopus_report_count(counts$capped),
            scopus_report_cells_text(nrow(x$cells) - length(x$not_run)))
  }
}

# The label/value pairs the readable record and the Markdown share, so the two
# renderings can never drift apart in substance.
scopus_report_pairs <- function(x) {
  not_run <- "unrecorded, this plan has not been run"
  run <- scopus_report_run(x)

  expression <- if (anyNA(x$expression)) "unrecorded" else {
    paste(x$expression, collapse = "; ")
  }
  field <- if (is.na(x$field)) {
    if (is.na(x$partition)) "unrecorded" else "none was applied"
  } else {
    x$field
  }
  stopped <- isTRUE(x$stopped_early)
  # A stopped harvest searched only the years of the cells it ran. The line
  # gives those first, beside the years the plan set.
  years <- if (!is.na(x$years) && length(x$not_run) > 0L) {
    sprintf("%s, of %s planned", if (is.na(x$years_run)) "none" else x$years_run,
            x$years)
  } else if (!is.na(x$years)) {
    x$years
  } else if (!is.na(x$partition)) {
    "no year limit was applied"
  } else {
    "unrecorded"
  }
  partition <- if (is.na(x$partition)) {
    "unrecorded"
  } else if (identical(x$partition, "year")) {
    sprintf("one cell per year, %s cells", scopus_report_count(x$n_cells))
  } else {
    "a single cell"
  }
  view <- if (is.na(x$view)) "unrecorded" else x$view
  page_size <- if (is.na(x$page_size)) "unrecorded" else {
    sprintf("%s records per request", scopus_report_count(x$page_size))
  }
  paging <- if (is.na(x$paging)) "unrecorded" else x$paging
  searched <- if (!run) {
    not_run
  } else if (stopped && identical(x$cells_run, 0L)) {
    "none, the harvest was stopped before its first cell"
  } else if (is.na(x$searched_at)) {
    "unrecorded, this set does not carry the time it was retrieved"
  } else if (scopus_report_spans_days(x)) {
    sprintf("%s to %s", scopus_report_stamp(x$searched_at),
            scopus_report_stamp(x$searched_until))
  } else {
    scopus_report_stamp(x$searched_at)
  }
  software <- if (is.na(x$version)) "unrecorded" else paste("scopusflow", x$version)

  retrieved <- if (!run) "none, this plan has not been run" else {
    scopus_report_count(x$n_records)
  }
  missing_cells <- nrow(x$cells) - x$cells_reported
  # The cells a stopped harvest never reached were never counted, which is not
  # the same as a count that failed to travel.
  reported <- if (!run) {
    not_run
  } else if (stopped) {
    sprintf("not counted for the %s not run, so no overall figure is given",
            scopus_report_cells_text(x$cells_planned - x$cells_run))
  } else if (!is.na(x$reported_total)) {
    scopus_report_count(x$reported_total)
  } else if (x$cells_reported > 0L) {
    sprintf("unrecorded for %s of %s cells, so no overall figure is given",
            scopus_report_count(missing_cells), scopus_report_count(nrow(x$cells)))
  } else {
    "unrecorded, the API's own count did not travel with this set"
  }
  # A cap explains the shortfall in full only when every cell that fell short
  # stopped at it. Otherwise, the cells that did are counted, so the rest of
  # the shortfall stays visible.
  cap <- scopus_report_count(x$max_results)
  cap_counts <- scopus_report_cap_counts(x)
  capped_cells <- sprintf("%s of %s stopped at the requested cap of %s",
                          scopus_report_count(cap_counts$capped),
                          scopus_report_cells_text(nrow(x$cells)), cap)
  completeness <- if (!run) {
    not_run
  } else if (stopped) {
    paste("incomplete,", scopus_report_stop_phrase(x))
  } else if (is.na(x$reported_total)) {
    unknown <- "unrecorded, since the number of records the API reported as matching is not known"
    if (cap_counts$capped > 0L) paste0(unknown, ", and ", capped_cells) else unknown
  } else if (x$n_records >= x$reported_total) {
    "every record the API reported as matching was retrieved"
  } else {
    short <- sprintf("%s of the %s records reported as matching were retrieved",
                     scopus_report_count(x$n_records), scopus_report_count(x$reported_total))
    if (cap_counts$capped > 0L && cap_counts$capped == cap_counts$short) {
      sprintf("%s, a shortfall due to the requested cap of %s records per cell", short, cap)
    } else if (cap_counts$capped > 0L) {
      paste0(short, ", and ", capped_cells)
    } else {
      short
    }
  }
  duplicates <- if (!run) {
    not_run
  } else if (isTRUE(x$deduplicated) && !is.na(x$duplicates_removed)) {
    sprintf("%s of %s combined records",
            scopus_report_count(x$duplicates_removed),
            scopus_report_count(x$records_combined))
  } else if (isFALSE(x$deduplicated)) {
    "none, the sets were combined without de-duplication"
  } else {
    "unrecorded, no de-duplication step was recorded for this set"
  }
  doi <- if (!run) not_run else {
    sprintf("%s of %s", scopus_report_count(x$n_with_doi), scopus_report_count(x$n_records))
  }

  rbind(
    c("Database", sprintf("%s, on the %s", x$database, x$platform)),
    c("Search expression", expression),
    c("Field tag", field),
    c("Years", years),
    c("Partition", partition),
    c("View", view),
    c("Page size", page_size),
    c("Paging", paging),
    c("Date searched", searched),
    c("Software", software),
    c("Records retrieved", retrieved),
    c("Records reported as matching", reported),
    c("Completeness", completeness),
    c("Duplicates removed", duplicates),
    c("Records carrying a DOI", doi)
  )
}

# A cell's year limit as the record shows it. A plan that sets no limit has
# none, but a set without a plan only fails to record one: its limit may have
# travelled as the request's date parameter, which the records never see.
scopus_report_limit <- function(x, limit) {
  if (!is.na(limit)) {
    limit
  } else if (is.na(x$partition)) {
    "year limit unrecorded"
  } else {
    "no year limit"
  }
}

# One line per cell for the readable record. A cell a stopped harvest never
# reached reads "not run". One that stopped at the cap names it where it would
# read "incomplete", since the cap is why it holds fewer records.
scopus_report_cell_lines <- function(x) {
  cells <- x$cells
  capped <- scopus_report_capped(cells, x$max_results)
  vapply(seq_len(nrow(cells)), function(i) {
    limit <- scopus_report_limit(x, cells$limit[i])
    n <- cells$n_records[i]
    reported <- cells$reported_total[i]
    counted <- function() {
      if (is.na(reported)) {
        sprintf("%s retrieved, reported total unrecorded", scopus_report_count(n))
      } else {
        sprintf("%s retrieved, %s reported", scopus_report_count(n),
                scopus_report_count(reported))
      }
    }
    tail <- if (cells$cell[i] %in% x$not_run) {
      "not run"
    } else if (is.na(n)) {
      "retrieved records unrecorded"
    } else if (capped[i]) {
      sprintf("%s, stopped at the requested cap of %s", counted(),
              scopus_report_count(x$max_results))
    } else if (is.na(reported)) {
      counted()
    } else if (n >= reported) {
      paste0(counted(), ", complete")
    } else {
      paste0(counted(), ", incomplete")
    }
    sprintf("  %s (%s): %s", scopus_report_count(cells$cell[i]), limit, tail)
  }, character(1))
}

# The same cells as a Markdown table.
scopus_report_cell_table <- function(x) {
  cells <- x$cells
  capped <- scopus_report_capped(cells, x$max_results)
  rows <- vapply(seq_len(nrow(cells)), function(i) {
    limit <- scopus_report_limit(x, cells$limit[i])
    n <- cells$n_records[i]
    reported <- cells$reported_total[i]
    unrun <- cells$cell[i] %in% x$not_run
    complete <- if (unrun) {
      "no"
    } else if (capped[i]) {
      sprintf("capped at %s", scopus_report_count(x$max_results))
    } else if (is.na(n) || is.na(reported)) {
      "unrecorded"
    } else if (n >= reported) "yes" else "no"
    shown <- function(v) {
      if (unrun) "not run" else if (is.na(v)) "unrecorded" else scopus_report_count(v)
    }
    sprintf(
      "| %s | %s | %s | %s | %s |",
      scopus_report_count(cells$cell[i]), limit, shown(n), shown(reported), complete
    )
  }, character(1))
  c("| Cell | Limit | Retrieved | Reported | Complete |",
    "|---|---|---|---|---|", rows)
}

# The identification counts of the PRISMA 2020 flow diagram, which asks for the
# records identified per database and the duplicates removed before screening.
# Identification is counted before duplicates are taken out, so where a merge
# recorded how many records went into it, that is the figure. Giving the
# surviving row count instead would put two numbers in the box that cannot both
# be right: the diagram subtracts the duplicates removed from the records
# identified to get the records screened, and 138 identified less 11 removed is
# not the 138 rows the set holds.
scopus_report_identification <- function(x) {
  identified <- if (!scopus_report_run(x)) {
    "unrecorded, this plan has not been run"
  } else if (!is.na(x$records_combined)) {
    scopus_report_count(x$records_combined)
  } else {
    scopus_report_count(x$n_records)
  }
  removed <- if (!scopus_report_run(x)) {
    "unrecorded, this plan has not been run"
  } else if (isTRUE(x$deduplicated) && !is.na(x$duplicates_removed)) {
    scopus_report_count(x$duplicates_removed)
  } else if (isFALSE(x$deduplicated)) {
    "none, the sets were combined without de-duplication"
  } else {
    "unrecorded, no de-duplication step was recorded for this set"
  }
  rbind(
    c("Records identified from Scopus", identified),
    c("Duplicate records removed before screening", removed)
  )
}

scopus_report_prisma_lines <- function(x, source, bullet) {
  rows <- x$prisma[x$prisma$source == source, , drop = FALSE]
  sprintf("%s%d %s. %s", bullet, rows$item, rows$name, rows$note)
}

scopus_report_reference <- function() {
  paste0(
    "The reporting standard is PRISMA-S (Rethlefsen et al., 2021, Systematic ",
    "Reviews, 10, 39, https://doi.org/10.1186/s13643-020-01542-z), with the ",
    "identification counts of the PRISMA 2020 flow diagram."
  )
}

scopus_report_render <- function(x) {
  pairs <- scopus_report_pairs(x)
  ident <- scopus_report_identification(x)
  paste(c(
    "Search strategy record (PRISMA-S)",
    "",
    sprintf("%s: %s", pairs[, 1], pairs[, 2]),
    "",
    "Cells",
    scopus_report_cell_lines(x),
    "",
    "PRISMA 2020 identification",
    sprintf("  %s: %s", ident[, 1], ident[, 2]),
    "",
    "PRISMA-S items this record supplies",
    scopus_report_prisma_lines(x, "record", "  "),
    "",
    "PRISMA-S items only you can supply",
    scopus_report_prisma_lines(x, "author", "  "),
    "",
    scopus_report_reference()
  ), collapse = "\n")
}

scopus_report_markdown <- function(x) {
  pairs <- scopus_report_pairs(x)
  ident <- scopus_report_identification(x)
  snippet <- if (is.na(x$snippet)) {
    c(paste0("The plan that produced this set is not attached to it, so no ",
             "reproduction snippet can be written. Attach the plan, or pass it ",
             "as the plan argument."))
  } else {
    c(paste0("The plan below rebuilds the search exactly as it was described. ",
             "Running the harvest again contacts the API and spends quota."),
      "",
      "```r", x$snippet, "```")
  }
  paste(c(
    "# Search strategy record",
    "",
    paste0("Assembled by scopusflow from the search plan and the records it ",
           "produced. Every figure below is taken from those objects. Anything ",
           "they do not record is marked unrecorded, and is yours to supply."),
    "",
    "## The search",
    "",
    sprintf("- %s: %s", pairs[, 1], pairs[, 2]),
    "",
    "## Cells",
    "",
    scopus_report_cell_table(x),
    "",
    "## Methods paragraph",
    "",
    scopus_report_paragraph(x),
    "",
    "## Reproducing this search",
    "",
    snippet,
    "",
    "## PRISMA 2020 identification",
    "",
    sprintf("- %s: %s", ident[, 1], ident[, 2]),
    "",
    "## PRISMA-S coverage",
    "",
    "Supplied by this record.",
    "",
    scopus_report_prisma_lines(x, "record", "- "),
    "",
    "Yours to supply.",
    "",
    scopus_report_prisma_lines(x, "author", "- "),
    "",
    scopus_report_reference()
  ), collapse = "\n")
}

# The methods paragraph. Every sentence is conditioned on the evidence, so the
# paragraph never asserts a figure the record does not hold; the suite recomputes
# each of its numerals from the object independently.
scopus_report_paragraph <- function(x) {
  run <- scopus_report_run(x)
  stopped <- isTRUE(x$stopped_early)
  sentences <- character()

  # A harvest stopped before its first cell searched nothing, so the opening
  # says what was to be searched and the stop is explained below.
  opening <- if (!run) {
    "The search described here has not been run."
  } else if (stopped && identical(x$cells_run, 0L)) {
    "The literature was to be searched in Scopus, on the Elsevier Scopus Search API."
  } else if (is.na(x$searched_at)) {
    "The literature was searched in Scopus, on the Elsevier Scopus Search API, on a date this record does not carry."
  } else if (scopus_report_spans_days(x)) {
    sprintf("The literature was searched in Scopus, on the Elsevier Scopus Search API, between %s and %s.",
            scopus_report_date(x$searched_at), scopus_report_date(x$searched_until))
  } else {
    sprintf("The literature was searched in Scopus, on the Elsevier Scopus Search API, on %s.",
            scopus_report_date(x$searched_at))
  }
  sentences <- c(sentences, opening)

  expression <- if (anyNA(x$expression)) NA_character_ else {
    paste(x$expression, collapse = "; ")
  }
  # Past tense only where there is a completed search to describe. A plan that
  # has not run is described in the present, or the sentence contradicts the
  # opening; the same rule governs the retrieval sentence below.
  verb <- if (run) "was" else "is"
  strategy <- if (is.na(expression)) {
    "The search expression is unrecorded in this set."
  } else if (!is.na(x$years)) {
    sprintf("The search expression %s %s, limited to publication years %s.",
            verb, expression, x$years)
  } else if (!is.na(x$partition)) {
    sprintf("The search expression %s %s, with no year limit.", verb, expression)
  } else {
    sprintf("The search expression %s %s, and its year limit is unrecorded.",
            verb, expression)
  }
  sentences <- c(sentences, strategy)

  known <- !is.na(x$view) && !is.na(x$page_size)
  if (!is.na(x$partition)) {
    # A record of a completed search reads in the past tense, while a plan that has
    # not run describes what it would do, or this sentence contradicts the opening.
    # "each" distributes over cells, so it belongs only to the partitioned form.
    # A stopped harvest was partitioned all the same, but its cells were only
    # to be retrieved, since some of them never were.
    plan_verb <- if (run) "was" else "would be"
    partitioned <- identical(x$partition, "year")
    how <- if (partitioned) {
      sprintf("It %s partitioned into %s cells, one per year",
              plan_verb, scopus_report_count(x$n_cells))
    } else {
      sprintf("It %s retrieved as a single search", if (stopped) "was to be" else plan_verb)
    }
    through <- if (!partitioned) {
      " through"
    } else if (stopped) {
      ", each to be retrieved through"
    } else {
      ", each retrieved through"
    }
    if (known && !is.na(x$paging)) {
      how <- sprintf("%s%s the %s view in pages of %s records under %s paging.",
                     how, through, x$view, scopus_report_count(x$page_size), x$paging)
    } else if (known) {
      # A plan has no paging mode to be missing: the mode is settled by the
      # fetch, so an unrun plan is told what will decide it, where the wording
      # for a harvest would accuse it of having lost it.
      unpaged <- if (run) {
        "a paging mode this record does not carry"
      } else {
        "a paging mode chosen when the search is run"
      }
      how <- sprintf("%s%s the %s view in pages of %s records, under %s.",
                     how, through, x$view, scopus_report_count(x$page_size), unpaged)
    } else {
      how <- sprintf("%s, and the view and page size of the retrieval are unrecorded.", how)
    }
    sentences <- c(sentences, how)
  }

  if (run) {
    # How far a stopped harvest got comes before what it retrieved, which then
    # needs no word on completeness.
    if (stopped) {
      sentences <- c(sentences,
                     paste0(scopus_report_stop_clause(x), ", so the harvest is incomplete."))
    }
    counts <- if (stopped) {
      sprintf("The search retrieved %s records.", scopus_report_count(x$n_records))
    } else if (!is.na(x$reported_total) && x$n_records >= x$reported_total) {
      sprintf("The search retrieved %s records, matching the %s the API reported, so every reported record was retrieved.",
              scopus_report_count(x$n_records), scopus_report_count(x$reported_total))
    } else if (!is.na(x$reported_total)) {
      sprintf("The search retrieved %s records of the %s the API reported as matching, so the harvest is incomplete.",
              scopus_report_count(x$n_records), scopus_report_count(x$reported_total))
    } else if (x$cells_reported > 0L) {
      sprintf("The search retrieved %s records. The API's count of matching records is missing for %s of the %s cells, so no overall total is given.",
              scopus_report_count(x$n_records),
              scopus_report_count(nrow(x$cells) - x$cells_reported),
              scopus_report_count(nrow(x$cells)))
    } else {
      sprintf("The search retrieved %s records. The API's own count of matching records was not recorded, so the harvest cannot be shown to be complete.",
              scopus_report_count(x$n_records))
    }
    # Named outright. "Of these" would, in the branches above, end up next to
    # the cells or the matching records and so point at the wrong noun.
    sentences <- c(
      sentences, counts, scopus_report_cap_paragraph(x),
      sprintf("Of the records retrieved, %s carry a DOI.",
              scopus_report_count(x$n_with_doi))
    )
    dedupe <- if (isTRUE(x$deduplicated) && !is.na(x$duplicates_removed)) {
      sprintf("De-duplication removed %s records from the %s combined.",
              scopus_report_count(x$duplicates_removed),
              scopus_report_count(x$records_combined))
    } else if (isFALSE(x$deduplicated)) {
      "The retrievals were combined without de-duplication."
    } else {
      "No de-duplication step was recorded for this set."
    }
    sentences <- c(sentences, dedupe)
    sentences <- c(sentences, if (is.na(x$version)) {
      "The version of scopusflow that produced this set is unrecorded."
    } else {
      sprintf("The search was run with scopusflow %s.", x$version)
    })
  }

  sentences <- c(
    sentences,
    paste0("The PRISMA-S items this record cannot supply, among them peer ",
           "review of the strategy, grey literature and any other database ",
           "searched, remain yours to report.")
  )
  paste(sentences, collapse = " ")
}
