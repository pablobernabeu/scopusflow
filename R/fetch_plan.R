#' Execute a 'Scopus' search plan, with optional caching and resume
#'
#' Runs every cell of a [scopus_plan()] in turn, optionally caching each cell's
#' result so that an interrupted or quota-limited retrieval can resume without
#' re-spending quota on the cells already fetched. Results are accumulated and
#' bound once into a single [scopus_records] tibble.
#'
#' @param plan A `scopus_plan` object from [scopus_plan()].
#' @param max_results Maximum records to retrieve per cell (default `Inf`). A
#'   finite cap is recorded on the result, and [scopus_search_report()] says
#'   which cells stopped at it.
#' @param cache_dir Optional directory for per-cell cache files. The default of
#'   `NULL` performs no caching. Pass an explicit path you control, or
#'   `scopus_cache_dir()` to use a managed, clearable cache under
#'   [tools::R_user_dir()]. Caching happens only when you opt in through this
#'   argument. A cache directory serves one plan: cells are checkpointed by
#'   their position in the plan and their year, so give each distinct plan its
#'   own directory. As a safeguard, a checkpoint is served only when the query,
#'   year, view, page size and paging mode it was fetched under all match the
#'   plan cell, and only when its own `max_results` did not truncate it below
#'   what is being asked for now; anything else is a cache miss, refetched and
#'   overwritten.
#'   A checkpoint holding more records than the current `max_results` asks for
#'   is served trimmed to that cap, the fuller set staying on disk. A
#'   checkpoint that cannot be read back, for example one left half-written by
#'   an interrupted run, is also treated as a miss, and never aborts the
#'   harvest. A `COMPLETE` checkpoint written by a release that read `authors`
#'   from the first author alone (0.4.0 and earlier) is a miss as well, and is
#'   refetched once with a warning. `STANDARD` checkpoints from those releases
#'   are served as before, since their authors were read correctly.
#'   Checkpoints also record their `fields`. One fetched with
#'   `fields = "extended"` serves a core request, with the extra columns
#'   dropped, while a core one is a miss for an extended request and is
#'   refetched with a warning. A checkpoint written before the fields were
#'   recorded counts as core.
#' @param resume Logical. When `TRUE` and `cache_dir` is set, a cell whose cache
#'   file already exists is loaded from disk, sparing a second request.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, per-cell progress is reported.
#' @param cursor Logical. When `TRUE`, each cell is retrieved with cursor-based
#'   pagination, which has no 5000-record ceiling, so a cell matching more
#'   records than that is retrieved whole and still checkpointed. The records
#'   then arrive in the API's deep-paging order (see [scopus_fetch()]). The
#'   default, `FALSE`, pages by offset, as plans always have, so a cell stops at
#'   its first 5000 records with a warning. Checkpoints record the paging mode
#'   and serve only requests made in the same mode. A checkpoint written before
#'   the mode was recorded counts as offset-paged. The Python twin's
#'   `fetch_plan()` pages by cursor unless told otherwise, the mode it has
#'   always used.
#' @param fields `"core"` (the default) or `"extended"`. `"extended"` also keeps
#'   the document type, source type, volume, issue, pages, ISSN, PubMed
#'   identifier and open-access status the Search API sends with every record,
#'   and the abstract under a `COMPLETE` plan. They arrive in the responses each
#'   cell already pays for, so they cost no extra quota. Like `cursor`, it is an
#'   argument of the fetch, since it changes how the records are read while the
#'   search returns the same records. See the *Extended fields* section of
#'   [scopus_records()].
#' @return A [scopus_records] tibble combining all cells, with the originating
#'   `plan` attached as the `plan` attribute and the per-cell accounting as
#'   `cell_totals`, a tibble of `cell`, `date`, `n_records` and
#'   `reported_total` (the count the API gave for that cell, `NA` where it gave
#'   none). `total_results` is their sum, and is `NA` unless every cell
#'   reported one, since a partial sum would understate the search while
#'   looking like a real figure. A cell that comes back shorter than the API
#'   said it should warns, because a truncated or refused download otherwise
#'   arrives as a merely small result set; a cell stopped by `max_results` is
#'   short by request and does not warn. A finite `max_results` is attached as
#'   the attribute of that name, the cap of this call: a checkpoint written
#'   under a wider cap is served trimmed to it, so no cell holds more.
#'   [scopus_search_report()] reads all of this back. The `retrieved_at`,
#'   `retrieved_until` and `scopusflow_version` attributes described in
#'   [scopus_fetch()] are carried across from the cells. `retrieved_at` is the
#'   earliest of their times, since a combined set is only as fresh as its
#'   oldest cell. `retrieved_until` is
#'   the latest, the last search, which the record of a harvest resumed over
#'   several days has to give. Every version that contributed is listed, since
#'   resuming an older cache means more than one did. Each is omitted when any
#'   cell cannot supply it, as a checkpoint written before these attributes
#'   existed cannot. Dating the whole from the part of it that can be dated
#'   would misreport the set. A cell written before `retrieved_until` existed
#'   counts by its `retrieved_at`. `paging` and `view` are kept where every
#'   cell records the same one.
#' @section API access:
#' Any cell not served from cache requires a valid API key and internet access.
#' The *API access* section of [scopus_count()] gives the details.
#' @seealso [scopus_cache_dir()], [scopus_cache_clear()]
#' @examplesIf scopusflow::scopus_has_key()
#' plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
#'                     field = "TITLE-ABS-KEY", partition = "year")
#' dir <- file.path(tempdir(), "graphene-cache")
#' # `max_results` caps each yearly cell, so the example stays small and
#' # quota-light; drop it to harvest every record in the plan.
#' recs <- scopus_fetch_plan(plan, max_results = 25, cache_dir = dir, resume = TRUE)
#' @examples
#' # The offline companion, which needs no key: a record set with the plan
#' # that describes it attached. 'Scopus' records may not be redistributed, so
#' # the bundled corpus of real articles stands in for the harvest, and the
#' # plan describes the same search, one cell per year.
#' plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
#'                     field = "TITLE-ABS-KEY", partition = "year")
#' recs <- example_records
#' attr(recs, "plan") <- plan
#' recs
#' attr(recs, "plan")
#' @export
scopus_fetch_plan <- function(plan,
                              max_results = Inf,
                              cache_dir = NULL,
                              resume = TRUE,
                              api_key = NULL,
                              inst_token = NULL,
                              verbose = FALSE,
                              cursor = FALSE,
                              fields = c("core", "extended")) {
  if (!is_scopus_plan(plan)) {
    scopus_abort_bad_input(
      "`plan` must be a `scopus_plan` object from scopus_plan()."
    )
  }
  max_results <- scopus_check_max_results(max_results)
  # The mode is part of every checkpoint's identity, and isTRUE() would read
  # a mistyped value as FALSE, fetching and checkpointing the plan in a mode
  # the caller never chose.
  if (!is.logical(cursor) || length(cursor) != 1L || is.na(cursor)) {
    scopus_abort_bad_input("`cursor` must be `TRUE` or `FALSE`.")
  }
  paging <- if (cursor) "cursor" else "offset"
  fields <- scopus_match_arg(fields, c("core", "extended"))
  if (!is.null(cache_dir)) {
    if (!is.character(cache_dir) || length(cache_dir) != 1L || is.na(cache_dir)) {
      scopus_abort_bad_input(
        "`cache_dir` must be `NULL` or a single directory path."
      )
    }
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  results <- vector("list", nrow(plan))
  reported <- rep(NA_real_, nrow(plan))
  for (i in seq_len(nrow(plan))) {
    cell <- plan[i, ]
    cache_file <- if (is.null(cache_dir)) {
      NULL
    } else {
      file.path(cache_dir, scopus_cell_cache_name(cell))
    }

    if (!is.null(cache_file) && resume && file.exists(cache_file)) {
      cached <- scopus_read_checkpoint(cache_file)
      if (is.null(cached)) {
        rlang::warn(
          sprintf(
            paste0("The checkpoint %s could not be read back, so it was ",
                   "discarded and the cell refetched. An interrupted run can ",
                   "leave a checkpoint half-written."),
            cache_file
          ),
          class = "scopus_warning_cache_unreadable"
        )
      } else if (scopus_cell_cache_matches(cached, cell, max_results, paging, fields)) {
        if (verbose) cli::cli_inform("Cell {i}/{nrow(plan)}: loaded from cache.")
        results[[i]] <- scopus_serve_checkpoint(cached, max_results, fields)
        reported[i] <- scopus_reported_total(results[[i]])
        next
      } else {
        # A checkpoint that fits the request in every other respect failed on
        # the way its records were built, which no choice of cache_dir avoids,
        # so the usual advice would mislead. The same holds for a checkpoint
        # this plan wrote with the core fields, or under the other paging mode,
        # which a caller who takes the capped warning's advice meets in every
        # cell.
        recorded <- scopus_cell_cache_paging(cached)
        text <- if (scopus_cell_cache_fits(cached, cell, max_results, paging, fields)) {
          paste0("The checkpoint %s was written before COMPLETE-view records ",
                 "carried the author list, so it was discarded and the cell ",
                 "refetched.")
        } else if (scopus_cell_cache_fits(cached, cell, max_results, paging)) {
          paste0("The checkpoint %s was fetched with the core fields, not the ",
                 "extended fields asked for, so it was discarded and the cell ",
                 "refetched.")
        } else if (isTRUE(recorded %in% c("offset", "cursor")) &&
                   scopus_cell_cache_fits(cached, cell, max_results, recorded)) {
          paste0("The checkpoint %s was fetched under ", recorded, " paging, ",
                 "not the ", paging, " paging asked for, so it was discarded ",
                 "and the cell refetched.")
        } else {
          paste0("The checkpoint %s was written under a different request ",
                 "(query, view, page size, max_results or paging mode), so it ",
                 "was discarded and the cell refetched. Give each plan its own ",
                 "cache_dir.")
        }
        rlang::warn(sprintf(text, cache_file),
                    class = "scopus_warning_cache_mismatch")
      }
    }

    if (verbose) {
      cli::cli_inform("Cell {i}/{nrow(plan)}: fetching {.val {cell$query}} ({cell$date}).")
    }
    date <- if (is.na(cell$date)) NULL else cell$date
    recs <- scopus_fetch_core(
      wrapped = cell$query, date = date, view = cell$view,
      page_size = cell$page_size, max_results = max_results, cursor = cursor,
      api_key = api_key, inst_token = inst_token, verbose = verbose,
      caller = "plan", fields = fields
    )
    if (!is.null(cache_file)) {
      attr(recs, "cache_meta") <- scopus_cell_cache_meta(cell, max_results, recs,
                                                         paging, fields)
      scopus_write_checkpoint(recs, cache_file)
    }
    reported[i] <- scopus_reported_total(recs)
    scopus_warn_shortfall(i, nrow(recs), reported[i], max_results)
    results[[i]] <- recs
  }

  combined <- scopus_bind_records(results)
  attr(combined, "plan") <- plan
  attr(combined, "cell_totals") <- tibble::tibble(
    cell = as.integer(plan$cell),
    date = as.character(plan$date),
    n_records = vapply(results, function(r) if (is.null(r)) NA_integer_ else nrow(r),
                       integer(1)),
    reported_total = reported
  )
  # An overall total is claimed only when every cell reported one. Summing the
  # cells that did would understate the search while looking like a real figure,
  # and the report built from this attribute is written for a methods section.
  attr(combined, "total_results") <- if (anyNA(reported)) NA_real_ else sum(reported)
  # One cap for the whole set, the one this call asked for. Binding drops the
  # cells' own copies, and a checkpoint written under a wider cap was served
  # trimmed to this one, so it holds for every cell.
  if (is.finite(max_results)) attr(combined, "max_results") <- max_results
  combined
}

# The total a cell's response reported, as a plain number, or NA when the cell
# never carried one (a checkpoint written before the attribute existed, or a
# response that omitted it).
scopus_reported_total <- function(recs) {
  total <- attr(recs, "total_results")
  if (is.null(total) || length(total) != 1L) NA_real_ else as.numeric(total)
}

# A cell that came back shorter than the API said it should have is the one
# failure mode a harvest cannot see for itself: a truncated or refused download
# arrives as a merely small result set. `max_results` is exempt, since a cell
# that stopped at a cap the caller set is short by request. The wording is
# byte-identical to the Python twin's, which has warned on this since 0.3.0.
scopus_warn_shortfall <- function(i, n, total, max_results) {
  if (is.na(total) || n >= total) {
    return(invisible(NULL))
  }
  if (is.finite(max_results) && n >= max_results) {
    return(invisible(NULL))
  }
  rlang::warn(
    sprintf(
      paste0("Cell %d retrieved %d record(s), but the Scopus API reports %s for ",
             "this query, so the harvest may be incomplete. Check the key's ",
             "remaining quota, and consider partitioning the plan by year so ",
             "each cell is smaller."),
      i, n, format(total, scientific = FALSE)
    ),
    class = "scopus_warning_shortfall"
  )
}

# The checkpoint filename for a plan cell. The cell's date is part of the name,
# not just its position: under partition = "year" every cell carries the same
# wrapped query and the year travels separately as the `date` parameter, so a
# name keyed on position alone would let one plan's 2015 checkpoint serve
# another plan's 2016 cell, and the query comparison below could never tell the
# two apart. The Python twin reaches the same end differently, by folding the
# year into the query it records (`_cell_query()`). pybliometrics would accept
# the year as a `date` parameter, but it keys its search cache on the query
# string and view alone, so one year's cached response would then answer
# another year's search. That twin now bypasses the cache by default, and
# dev/design-notes.md gives the reasoning in full.
scopus_cell_cache_name <- function(cell) {
  date <- if (is.na(cell$date)) "all" else cell$date
  sprintf("cell-%03d-%s.rds", cell$cell, date)
}

# The identity a checkpoint is written under, saved alongside the records so a
# later resume can tell whether they still answer the question being asked.
# `complete` records whether the cell ran to the end of its result set rather
# than stopping at `max_results`: a cap that never bit leaves the checkpoint
# usable however large a later request, while one that did truncate must be
# refetched when more is asked for. `records_schema` records how the records
# were built (see scopus_records_schema()). `paging` records the mode, since an
# offset-paged cell stops at the API's ceiling where a cursor-paged one does
# not. The mode is also why `complete` may stand on an offset cell cut short
# at the ceiling: it cannot serve a cursor request, and an offset refetch would
# stop at the same place. `fields` records which columns the records carry
# (see scopus_cell_cache_fields()).
scopus_cell_cache_meta <- function(cell, max_results, recs, paging,
                                   fields = "core") {
  total <- attr(recs, "total_results")
  complete <- is.infinite(max_results) || nrow(recs) < max_results ||
    (!is.na(total) && nrow(recs) >= total)
  list(
    query = cell$query,
    date = cell$date,
    view = cell$view,
    page_size = cell$page_size,
    max_results = max_results,
    complete = complete,
    records_schema = scopus_records_schema(),
    paging = paging,
    fields = fields
  )
}

# The version of the way records are built from a response. Version 2 reads
# `authors` from the COMPLETE view's author list, where every earlier release
# read dc:creator, the first author, under either view. Raise it when a change
# to the parsing makes earlier checkpoints wrong. scopus_cell_cache_current()
# then needs the views that change touches, since it judges COMPLETE
# checkpoints alone, and the warning in scopus_fetch_plan() needs its reason,
# since it names the author list.
scopus_records_schema <- function() 2L

# Whether a cached checkpoint can serve a plan cell: it must fit the request
# and hold records built the way this release builds them.
scopus_cell_cache_matches <- function(cached, cell, max_results, paging = "offset",
                                      fields = "core") {
  scopus_cell_cache_fits(cached, cell, max_results, paging, fields) &&
    scopus_cell_cache_current(cached, cell)
}

# Whether a checkpoint's records were built the way this release builds them.
# A COMPLETE checkpoint from before schema 2 holds first authors where the
# author list belongs, so it is refetched once, and one with no manifest at all
# is older still. A STANDARD checkpoint of any age was read correctly, since
# dc:creator is all that view carries, so it costs no quota.
scopus_cell_cache_current <- function(cached, cell) {
  if (!identical(cell$view, "COMPLETE")) {
    return(TRUE)
  }
  schema <- attr(cached, "cache_meta")$records_schema
  is.numeric(schema) && length(schema) == 1L && !is.na(schema) &&
    schema >= scopus_records_schema()
}

# Whether a cached checkpoint answers the request a plan cell makes. Records
# written by scopus_fetch_core() carry the wrapped query in their `query`
# column, so a checkpoint left behind by a different plan sharing the same
# cache_dir is recognised and treated as a cache miss: the cell is refetched
# and the checkpoint overwritten. The manifest written beside the records is
# compared as well, including its own copy of the query: a zero-row checkpoint
# has no query column values, so the record-column guard passes it vacuously,
# and without the manifest's copy an empty cell written under one query would
# serve any other. A checkpoint carrying neither query nor manifest (one
# written by an older scopusflow) fits an offset request as before, and
# scopus_cell_cache_current() then decides whether its records can be used.
# The paging mode must match too (see scopus_cell_cache_paging()). The fields
# need only cover the request, since an extended checkpoint can serve a core
# request with its extra columns dropped (see scopus_serve_checkpoint()).
scopus_cell_cache_fits <- function(cached, cell, max_results, paging = "offset",
                                   fields = "core") {
  q <- if (is.data.frame(cached)) cached[["query"]] else NULL
  if (!is.null(q)) {
    q <- unique(q[!is.na(q)])
    if (length(q) > 1L || (length(q) == 1L && !identical(q, cell$query))) {
      return(FALSE)
    }
  }
  if (!identical(scopus_cell_cache_paging(cached), paging)) {
    return(FALSE)
  }
  if (identical(fields, "extended") &&
      !identical(scopus_cell_cache_fields(cached), "extended")) {
    return(FALSE)
  }
  meta <- attr(cached, "cache_meta")
  if (is.null(meta)) {
    return(TRUE)
  }
  identical(meta$query, cell$query) &&
    identical(meta$date, cell$date) &&
    identical(meta$view, cell$view) &&
    identical(meta$page_size, cell$page_size) &&
    (isTRUE(meta$complete) || max_results <= meta$max_results)
}

# The paging mode a checkpoint was fetched under. A manifest that names no
# mode, and a checkpoint without a manifest, were written while offset was the
# only mode a plan had, so both count as offset. Serving either to a cursor
# request could hand back a cell cut short at the offset ceiling, under a
# request made to get past it.
scopus_cell_cache_paging <- function(cached) {
  attr(cached, "cache_meta")$paging %||% "offset"
}

# The fields a checkpoint was fetched with. The manifest is an attribute of the
# same .rds as the records, so the two cannot drift apart. A manifest that
# names no fields, and a checkpoint without a manifest, were written before
# fields existed, when every checkpoint held the core columns.
scopus_cell_cache_fields <- function(cached) {
  attr(cached, "cache_meta")$fields %||% "core"
}

# Serve a checkpoint at the cap and with the fields of the current request. A
# complete checkpoint matches any max_results, so it can hold more rows than
# are being asked for now; the surplus is trimmed from the served copy only,
# leaving the fuller set on disk for a later, wider request. An extended
# checkpoint serves a core request with the extended columns dropped from the
# served copy, which then holds what a core fetch returns. The provenance
# attributes are restated explicitly, since subsetting cannot be trusted to
# keep them. A checkpoint written before records carried their view still
# names it in its manifest, which scopus_cell_cache_fits() has checked against
# the cell, so the view is restored from there.
scopus_serve_checkpoint <- function(cached, max_results, fields = "core") {
  if (is.null(attr(cached, "view"))) {
    attr(cached, "view") <- attr(cached, "cache_meta")$view
  }
  extra <- if (identical(fields, "core")) {
    intersect(names(cached), scopus_extended_columns("COMPLETE"))
  } else {
    character()
  }
  trim <- is.finite(max_results) && nrow(cached) > max_results
  if (length(extra) == 0L && !trim) {
    return(cached)
  }
  out <- cached[setdiff(names(cached), extra)]
  if (trim) {
    out <- utils::head(out, max_results)
  }
  for (a in c("total_results", "quota", "retrieved_at", "retrieved_until",
              "scopusflow_version", "paging", "view")) {
    attr(out, a) <- attr(cached, a)
  }
  out
}

# Write a checkpoint so that it is either wholly there or not there at all.
# saveRDS() straight to the destination leaves a truncated file when the
# session dies mid-write, and the interruptions this cache exists to survive
# (Ctrl-C, a killed background worker, a full disk, a quota abort) are exactly
# what produces one. Renaming within a single directory is atomic on both POSIX
# and NTFS. file.rename() returns FALSE, and does not error, when the target is
# locked by another process, which happens on Windows, so a failed rename falls
# back to a direct write, so the cell just paid for is not lost.
scopus_write_checkpoint <- function(x, path) {
  tmp <- tempfile(pattern = "checkpoint-", tmpdir = dirname(path), fileext = ".rds")
  renamed <- tryCatch({
    saveRDS(x, tmp)
    isTRUE(suppressWarnings(file.rename(tmp, path)))
  }, error = function(e) FALSE)
  if (!renamed) {
    unlink(tmp)
    saveRDS(x, path)
  }
  invisible(path)
}

# Read a checkpoint back, returning NULL when it cannot be read. A damaged
# checkpoint must not be able to abort every subsequent resume: refetching one
# cell costs quota, whereas an unreadable file the caller has to find and
# delete by hand defeats the point of resuming at all.
scopus_read_checkpoint <- function(path) {
  tryCatch(readRDS(path), error = function(e) NULL)
}

# Bind a list of scopus_records tibbles into one, re-numbering entries. Cells
# can differ in columns, for example when resuming a cache written by an
# older package version without the `authkeywords` column, so the union of
# columns is taken and any cell missing one is filled with NA, where a plain
# rbind() would error on the column mismatch.
scopus_bind_records <- function(records_list) {
  records_list <- Filter(Negate(is.null), records_list)
  if (length(records_list) == 0L) {
    return(new_scopus_records(scopus_records_columns()))
  }
  all_cols <- Reduce(union, lapply(records_list, names))
  bound <- do.call(rbind, lapply(records_list, function(x) {
    class(x) <- setdiff(class(x), "scopus_records")
    for (col in setdiff(all_cols, names(x))) x[[col]] <- NA
    x[all_cols]
  }))
  bound$entry_number <- seq_len(nrow(bound))
  # The bound set starts with no attributes of its own. rbind() keeps those of
  # its first argument and as.list() keeps those of the frame, so without this
  # the result inherited one input's `plan`, `total_results` and `cell_totals`.
  # Those describe a single retrieval, and a set built from several is not that
  # retrieval: a search record read off the inherited total called the union
  # complete against a figure belonging to a part of it. What survives a merge
  # is added back by scopus_bind_provenance(), and what only the caller knows
  # (the plan, the per-cell accounting, the merge counts) by the caller.
  n <- nrow(bound)
  cols <- as.list(bound)
  attributes(cols) <- list(names = names(cols))
  bound <- tibble::new_tibble(cols, nrow = n, class = "scopus_records")
  scopus_bind_provenance(bound, records_list)
}

# Carry the cells' retrieval provenance onto the combined set. `retrieved_at`
# is the earliest of the cells' times, because a combined set is only as fresh
# as its oldest cell and a resumed harvest can span days. `retrieved_until` is
# the latest, since PRISMA-S item 13 asks for the date of the last search, and
# a cell written before that attribute existed counts by its one stamp. Every
# contributing version is kept, since resuming a cache written by an earlier
# scopusflow produces a set that more than one version built. The times are
# claimed only when every cell carries one, and the versions only when every
# cell carries one. A checkpoint written before these attributes existed has
# no time of its own, and taking the earliest of the rest would date the
# combined set later than one of the cells inside it, which is the one thing a
# provenance field must never do.
scopus_bind_provenance <- function(bound, records_list) {
  stamps <- lapply(records_list, attr, "retrieved_at")
  if (!any(vapply(stamps, is.null, logical(1)))) {
    attr(bound, "retrieved_at") <- min(do.call(c, stamps))
    latest <- lapply(records_list, function(r) {
      attr(r, "retrieved_until") %||% attr(r, "retrieved_at")
    })
    attr(bound, "retrieved_until") <- max(do.call(c, latest))
  }
  versions <- lapply(records_list, attr, "scopusflow_version")
  if (!any(vapply(versions, is.null, logical(1)))) {
    attr(bound, "scopusflow_version") <- sort(unique(unlist(versions)))
  }
  # The paging mode is claimed only when every cell agrees on it, for the same
  # reason as the time: one mode standing for a set that mixes two would be a
  # provenance field stating something untrue of part of what it describes.
  # The view follows the same rule, since a STANDARD part bound to a COMPLETE
  # one makes a set whose authors are neither all first authors nor all lists.
  for (a in c("paging", "view")) {
    values <- lapply(records_list, attr, a)
    if (!any(vapply(values, is.null, logical(1))) &&
        length(unique(unlist(values))) == 1L) {
      attr(bound, a) <- unique(unlist(values))
    }
  }
  bound
}

#' Managed cache directory for scopusflow
#'
#' Returns (and creates on request) a per-user cache directory under
#' [tools::R_user_dir()], suitable for passing to `cache_dir` in
#' [scopus_fetch_plan()]. The cache is entirely optional and can be cleared with
#' [scopus_cache_clear()].
#'
#' @param create Logical. When `TRUE`, the directory is created if it is absent.
#' @return The cache directory path, invisibly when `create = TRUE`.
#' @examples
#' scopus_cache_dir(create = FALSE)
#' @export
scopus_cache_dir <- function(create = FALSE) {
  path <- tools::R_user_dir("scopusflow", which = "cache")
  if (isTRUE(create)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
    return(invisible(path))
  }
  path
}

#' Clear the scopusflow managed cache
#'
#' Deletes the cache files written under [scopus_cache_dir()]. A cache you
#' created in a directory of your own is left untouched.
#'
#' @return Invisibly, `TRUE` once the managed cache directory is removed or found
#'   to be absent.
#' @examples
#' # Safe to call even when nothing is cached.
#' scopus_cache_clear()
#' @export
scopus_cache_clear <- function() {
  path <- scopus_cache_dir(create = FALSE)
  if (dir.exists(path)) {
    unlink(path, recursive = TRUE, force = TRUE)
  }
  invisible(TRUE)
}
