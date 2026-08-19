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

# English month names, spelled out rather than taken from the locale: the
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
#'   set does not carry one, for example one retrieved with [scopus_fetch()] or
#'   read back from a `.csv`. An explicit plan takes precedence over the one `x`
#'   carries.
#' @param file Optional path at which to write the record as Markdown. A file is
#'   written only when this argument is supplied, and only to the exact path
#'   given, so the package leaves the working directory untouched unless asked.
#'   Parent directories are assumed to exist already.
#' @return A list of class `scopus_search_report`, returned invisibly when
#'   `file` is written. Its elements are the fields the record is built from:
#'   `database`, `platform`, `query` (the base query), `field`, `expression`
#'   (the field-wrapped query of each cell), `view`, `page_size`, `paging`,
#'   `partition`, `n_cells`, `years`, `cells` (a tibble of `cell`, `limit`,
#'   `n_records` and `reported_total`), `searched_at`, `version`, `n_records`,
#'   `n_with_doi`, `reported_total`, `records_combined`, `duplicates_removed`,
#'   `deduplicated`, `snippet` and `prisma` (a tibble of `item`, `name`,
#'   `source` and `note`). A field the objects do not record is `NA`.
#' @details
#' Everything in the record comes from the objects handed to it. The date of the
#' search is the `retrieved_at` attribute [scopus_fetch()] attaches, never the
#' current time; the number of records the API reported as matching is what the
#' cells recorded (the `cell_totals` attribute [scopus_fetch_plan()] attaches,
#' or `total_results` for a set retrieved without a plan), never an inference
#' from the number of rows, and it is given overall only when every cell
#' reported one; and the duplicates removed are those [scopus_combine()]
#' recorded removing. Where
#' an attribute is absent, as it is for a set read back from a `.csv`, for the
#' bundled corpus, and for a cell resumed from a checkpoint written before these
#' attributes existed, the record says the field is unrecorded rather than
#' filling it. This matters most for completeness: a harvest whose reported
#' total is unknown is never described as exhaustive.
#'
#' The PRISMA-S map is decided the same way. Items the package holds evidence
#' for (the database and platform, the full strategy, the limits, the date, the
#' totals, and de-duplication where it was performed) are listed as supplied.
#' The rest, among them peer review of the strategy, grey literature, other
#' databases and citation searching, are listed as the author's to supply,
#' because the package has no way to know them.
#' @references
#' Rethlefsen, M. L., Kirtley, S., Waffenschmidt, S., Ayala, A. P., Moher, D.,
#' Page, M. J., & Koffel, J. B. (2021). PRISMA-S: an extension to the PRISMA
#' Statement for Reporting Literature Searches in Systematic Reviews.
#' *Systematic Reviews*, *10*, 39. \doi{10.1186/s13643-020-01542-z}
#' @seealso [scopus_plan()], [scopus_fetch_plan()], [scopus_combine()]
#' @examples
#' # A search described but not yet run. The record says so throughout rather
#' # than implying figures it cannot have.
#' plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
#'                     field = "TITLE-ABS-KEY", partition = "year")
#' scopus_search_report(plan)
#'
#' # The same search after a harvest. The bundled corpus of real articles
#' # stands in for one, since 'Scopus' records may not be redistributed, so the
#' # attributes a live retrieval records are set here by hand.
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
    rlang::abort("The plan must be a search plan.",
                 class = "scopus_error_bad_input")
  }
  if (is_scopus_plan(x)) {
    records <- NULL
    plan <- plan %||% x
  } else if (is_scopus_records(x)) {
    records <- x
    plan <- plan %||% attr(x, "plan")
    if (!is.null(plan) && !is_scopus_plan(plan)) plan <- NULL
  } else {
    rlang::abort("A search report needs a record set or a search plan.",
                 class = "scopus_error_bad_input")
  }

  report <- scopus_report_build(records, plan)

  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
      rlang::abort("The file must be a single non-empty path.",
                   class = "scopus_error_bad_input")
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
  style <- rlang::arg_match(style)
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
  # Named here rather than inside format(), so that the rendered record itself
  # stays free of language-specific instructions and can be compared with the
  # Python twin's line for line.
  cat("\nThe methods paragraph is format(x, style = \"paragraph\"); ",
      "pass file = to write the whole record as Markdown.\n", sep = "")
  invisible(x)
}

# Field extraction ----------------------------------------------------------

scopus_report_build <- function(records, plan) {
  cells <- scopus_report_cells(records, plan)
  reported <- cells$reported_total
  n_cells_reported <- sum(!is.na(reported))
  total <- if (nrow(cells) > 0L && n_cells_reported == nrow(cells)) {
    sum(reported)
  } else {
    NA_real_
  }

  combined <- if (is.null(records)) NULL else attr(records, "combined")
  stamp <- if (is.null(records)) NULL else attr(records, "retrieved_at")
  version <- if (is.null(records)) NULL else attr(records, "scopusflow_version")

  out <- list(
    database = "Scopus",
    platform = "Elsevier Scopus Search API",
    query = if (is.null(plan)) NA_character_ else attr(plan, "base_query"),
    field = if (is.null(plan)) NA_character_ else (attr(plan, "field") %||% NA_character_),
    expression = scopus_report_expression(records, plan),
    view = if (is.null(plan)) NA_character_ else attr(plan, "view"),
    page_size = if (is.null(plan)) NA_integer_ else as.integer(attr(plan, "page_size")),
    paging = if (is.null(records)) NA_character_ else (attr(records, "paging") %||% NA_character_),
    partition = if (is.null(plan)) NA_character_ else attr(plan, "partition"),
    n_cells = if (is.null(plan)) NA_integer_ else nrow(plan),
    years = scopus_report_years(cells, plan),
    cells = cells,
    searched_at = if (is.null(stamp)) NA else min(stamp),
    version = if (is.null(version)) NA_character_ else paste(version, collapse = ", "),
    n_records = if (is.null(records)) NA_integer_ else nrow(records),
    n_with_doi = if (is.null(records)) NA_integer_ else sum(!is.na(records$doi)),
    reported_total = total,
    cells_reported = n_cells_reported,
    records_combined = scopus_report_combined(combined, "n_in"),
    duplicates_removed = scopus_report_combined(combined, "n_removed"),
    deduplicated = if (is.null(combined)) NA else isTRUE(combined$deduplicated),
    snippet = scopus_report_snippet(plan)
  )
  out$prisma <- scopus_report_prisma(out)
  structure(out, class = "scopus_search_report")
}

# The per-cell table. A plan supplies the cells and their year limits; the
# counts come from the `cell_totals` attribute scopus_fetch_plan() records, and
# stay NA when the set never carried one (a CSV round trip, the bundled corpus,
# a set assembled by hand). Without a plan the whole retrieval is treated as one
# cell, so the rest of the code has a single shape to render.
scopus_report_cells <- function(records, plan) {
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
    }
    return(out)
  }
  if (!is.null(records)) {
    total <- attr(records, "total_results")
    return(tibble::tibble(
      cell = 1L,
      limit = NA_character_,
      n_records = nrow(records),
      reported_total = if (is.null(total)) NA_real_ else as.numeric(total)
    ))
  }
  tibble::tibble(cell = integer(), limit = character(),
                 n_records = integer(), reported_total = numeric())
}

# The field-wrapped query of each cell. The plan holds it; failing that the
# records' own `query` column does, which is what a set fetched without a plan
# carries.
scopus_report_expression <- function(records, plan) {
  q <- if (!is.null(plan)) plan$query else if (!is.null(records)) records$query else NULL
  q <- unique(q[!is.na(q)])
  if (length(q) == 0L) NA_character_ else as.character(q)
}

# The year span actually sent, read back from the cells' date limits rather
# than from any year vector, because the limit is what reached the API.
scopus_report_years <- function(cells, plan) {
  limits <- cells$limit[!is.na(cells$limit)]
  if (length(limits) == 0L) {
    return(NA_character_)
  }
  years <- as.integer(unlist(regmatches(limits, gregexpr("[0-9]{4}", limits))))
  if (length(years) == 0L) {
    return(NA_character_)
  }
  if (min(years) == max(years)) as.character(min(years)) else {
    sprintf("%d to %d", min(years), max(years))
  }
}

scopus_report_combined <- function(combined, field) {
  if (is.null(combined) || is.null(combined[[field]])) NA_integer_ else {
    as.integer(combined[[field]])
  }
}

# The runnable reproduction. Built from what the plan records, so that
# evaluating it returns a plan identical to the one the report describes; the
# package's test suite asserts exactly that over a grid of plans. Without a
# plan there is nothing to reproduce and the snippet is NA.
scopus_report_snippet <- function(plan) {
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
  paste(
    c(
      "library(scopusflow)",
      "",
      sprintf("plan <- scopus_plan(\n%s\n)", paste(args, collapse = ",\n")),
      "",
      "records <- scopus_fetch_plan(plan)"
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

  notes[2] <- "Whether any database besides Scopus was searched, and how the strategy was translated for it."
  notes[3] <- "Any trial or study registry searched."
  notes[4] <- "Any web site, table of contents or other source searched or browsed by hand."
  notes[5] <- "Any backward or forward citation searching."
  notes[6] <- "Any authors or organisations contacted for studies."
  notes[7] <- "Any further method used to identify records."

  if (!anyNA(x$expression)) {
    notes[8] <- "The search expression, field tag and year limit of every cell, as the plan sends them."
    supplied <- c(supplied, 8L)
  } else {
    notes[8] <- "The exact strategy, which this set does not record."
  }

  if (!is.na(x$partition)) {
    notes[9] <- if (is.na(x$years)) {
      "No year limit was applied, and scopusflow applies no document type, language or subject area limit of its own."
    } else {
      sprintf(
        "Publication years %s. scopusflow applies no document type, language or subject area limit of its own.",
        x$years
      )
    }
    supplied <- c(supplied, 9L)
  } else {
    notes[9] <- "Any limit applied to the search, which this set does not record."
  }

  notes[10] <- "Any published or validated search filter used, and where it came from. scopusflow applies none of its own."
  notes[11] <- "Any earlier review or strategy this search was adapted from."
  notes[12] <- "Whether the search was re-run or updated, and when."

  if (!is.na(x$searched_at)) {
    notes[13] <- sprintf("%s.", scopus_report_stamp(x$searched_at))
    supplied <- c(supplied, 13L)
  } else if (is.na(x$n_records)) {
    notes[13] <- "The date of each search, which this plan has not been run to produce."
  } else {
    notes[13] <- "The date of each search, which this set does not carry."
  }

  notes[14] <- "Whether the strategy was peer reviewed, and by whom."

  if (!is.na(x$n_records)) {
    notes[15] <- if (is.na(x$reported_total)) {
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
    notes[16] <- sprintf(
      "%s duplicate records removed by scopus_combine() from %s combined, matched on the Scopus identifier and failing that the DOI.",
      scopus_report_count(x$duplicates_removed), scopus_report_count(x$records_combined)
    )
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
# reads the same in the R report and the Python one. Rounded rather than coerced
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

scopus_report_run <- function(x) !is.na(x$n_records)

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
  years <- if (!is.na(x$years)) x$years else if (!is.na(x$partition)) {
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
  } else if (is.na(x$searched_at)) {
    "unrecorded, this set does not carry the time it was retrieved"
  } else {
    scopus_report_stamp(x$searched_at)
  }
  software <- if (is.na(x$version)) "unrecorded" else paste("scopusflow", x$version)

  retrieved <- if (!run) "none, this plan has not been run" else {
    scopus_report_count(x$n_records)
  }
  missing_cells <- nrow(x$cells) - x$cells_reported
  reported <- if (!run) {
    not_run
  } else if (!is.na(x$reported_total)) {
    scopus_report_count(x$reported_total)
  } else if (x$cells_reported > 0L) {
    sprintf("unrecorded for %s of %s cells, so no overall figure is given",
            scopus_report_count(missing_cells), scopus_report_count(nrow(x$cells)))
  } else {
    "unrecorded, the API's own count did not travel with this set"
  }
  completeness <- if (!run) {
    not_run
  } else if (is.na(x$reported_total)) {
    "unrecorded, since the number of records the API reported as matching is not known"
  } else if (x$n_records >= x$reported_total) {
    "every record the API reported as matching was retrieved"
  } else {
    sprintf("%s of the %s records reported as matching were retrieved",
            scopus_report_count(x$n_records), scopus_report_count(x$reported_total))
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

# One line per cell for the readable record.
scopus_report_cell_lines <- function(x) {
  cells <- x$cells
  vapply(seq_len(nrow(cells)), function(i) {
    limit <- if (is.na(cells$limit[i])) "no year limit" else cells$limit[i]
    n <- cells$n_records[i]
    reported <- cells$reported_total[i]
    tail <- if (is.na(n)) {
      "retrieved records unrecorded"
    } else if (is.na(reported)) {
      sprintf("%s retrieved, reported total unrecorded", scopus_report_count(n))
    } else if (n >= reported) {
      sprintf("%s retrieved, %s reported, complete", scopus_report_count(n),
              scopus_report_count(reported))
    } else {
      sprintf("%s retrieved, %s reported, incomplete", scopus_report_count(n),
              scopus_report_count(reported))
    }
    sprintf("  %s (%s): %s", scopus_report_count(cells$cell[i]), limit, tail)
  }, character(1))
}

# The same cells as a Markdown table.
scopus_report_cell_table <- function(x) {
  cells <- x$cells
  rows <- vapply(seq_len(nrow(cells)), function(i) {
    limit <- if (is.na(cells$limit[i])) "no year limit" else cells$limit[i]
    n <- cells$n_records[i]
    reported <- cells$reported_total[i]
    complete <- if (is.na(n) || is.na(reported)) {
      "unrecorded"
    } else if (n >= reported) "yes" else "no"
    sprintf(
      "| %s | %s | %s | %s | %s |",
      scopus_report_count(cells$cell[i]), limit,
      if (is.na(n)) "unrecorded" else scopus_report_count(n),
      if (is.na(reported)) "unrecorded" else scopus_report_count(reported),
      complete
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
  sentences <- character()

  opening <- if (!run) {
    "The search described here has not been run."
  } else if (is.na(x$searched_at)) {
    "The literature was searched in Scopus, on the Elsevier Scopus Search API, on a date this record does not carry."
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
    retrieval_verb <- if (run) "was" else "would be"
    partitioned <- identical(x$partition, "year")
    how <- if (partitioned) {
      sprintf("It %s partitioned into %s cells, one per year",
              retrieval_verb, scopus_report_count(x$n_cells))
    } else {
      sprintf("It %s retrieved as a single search", retrieval_verb)
    }
    through <- if (partitioned) ", each retrieved through" else " through"
    if (known && !is.na(x$paging)) {
      how <- sprintf("%s%s the %s view in pages of %s records under %s paging.",
                     how, through, x$view, scopus_report_count(x$page_size), x$paging)
    } else if (known) {
      # A plan has no paging mode to be missing: the mode is settled by the
      # fetch, so an unrun plan is told what will decide it rather than
      # accused of having lost it.
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
    counts <- if (!is.na(x$reported_total) && x$n_records >= x$reported_total) {
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
    # Named rather than "of these", which in the branches above ends up next to
    # the cells or the matching records and so points at the wrong noun.
    sentences <- c(
      sentences, counts,
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
