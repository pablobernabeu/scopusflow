#' Execute a 'Scopus' search plan, with optional caching and resume
#'
#' Runs every cell of a [scopus_plan()] in turn, optionally caching each cell's
#' result so that an interrupted or quota-limited retrieval can resume without
#' re-spending quota on the cells already fetched. Results are accumulated and
#' bound once into a single [scopus_records] tibble.
#'
#' @param plan A `scopus_plan` object from [scopus_plan()].
#' @param max_results Maximum records to retrieve per cell (default `Inf`).
#' @param cache_dir Optional directory for per-cell cache files. The default of
#'   `NULL` performs no caching. Pass an explicit path you control, or
#'   `scopus_cache_dir()` to use a managed, clearable cache under
#'   [tools::R_user_dir()]. Caching happens only when you opt in through this
#'   argument. A cache directory serves one plan: cells are checkpointed by
#'   their position in the plan, so give each distinct plan its own directory.
#'   As a safeguard, a checkpoint whose records carry a different query than
#'   the plan cell is treated as a cache miss, refetched and overwritten; a
#'   checkpoint written by an older scopusflow that carries no query
#'   information is loaded as before.
#' @param resume Logical. When `TRUE` and `cache_dir` is set, a cell whose cache
#'   file already exists is loaded from disk rather than fetched again.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical. When `TRUE`, per-cell progress is reported.
#' @return A [scopus_records] tibble combining all cells, with the originating
#'   `plan` attached as the `plan` attribute.
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
                              verbose = FALSE) {
  if (!is_scopus_plan(plan)) {
    rlang::abort(
      "`plan` must be a `scopus_plan` object from scopus_plan().",
      class = "scopus_error_bad_input"
    )
  }
  max_results <- scopus_check_max_results(max_results)
  if (!is.null(cache_dir)) {
    if (!is.character(cache_dir) || length(cache_dir) != 1L || is.na(cache_dir)) {
      rlang::abort(
        "`cache_dir` must be `NULL` or a single directory path.",
        class = "scopus_error_bad_input"
      )
    }
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  results <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    cell <- plan[i, ]
    cache_file <- if (is.null(cache_dir)) {
      NULL
    } else {
      file.path(cache_dir, sprintf("cell-%03d.rds", cell$cell))
    }

    if (!is.null(cache_file) && resume && file.exists(cache_file)) {
      cached <- readRDS(cache_file)
      if (scopus_cell_cache_matches(cached, cell$query)) {
        if (verbose) cli::cli_inform("Cell {i}/{nrow(plan)}: loaded from cache.")
        results[[i]] <- cached
        next
      }
      if (verbose) {
        cli::cli_inform(
          "Cell {i}/{nrow(plan)}: checkpoint holds a different query; refetching."
        )
      }
    }

    if (verbose) {
      cli::cli_inform("Cell {i}/{nrow(plan)}: fetching {.val {cell$query}} ({cell$date}).")
    }
    date <- if (is.na(cell$date)) NULL else cell$date
    recs <- scopus_fetch_core(
      wrapped = cell$query, date = date, view = cell$view,
      page_size = cell$page_size, max_results = max_results,
      api_key = api_key, inst_token = inst_token, verbose = verbose
    )
    if (!is.null(cache_file)) saveRDS(recs, cache_file)
    results[[i]] <- recs
  }

  combined <- scopus_bind_records(results)
  attr(combined, "plan") <- plan
  combined
}

# Whether a cached checkpoint can serve a plan cell. Records written by
# scopus_fetch_core() carry the wrapped query in their `query` column, so a
# checkpoint left behind by a different plan sharing the same cache_dir is
# recognised and treated as a cache miss: the cell is refetched and the
# checkpoint overwritten. A checkpoint that carries no query information (a
# zero-row cell, or one written by an older scopusflow) is loaded as before.
# The Python twin applies the same query comparison on resume.
scopus_cell_cache_matches <- function(cached, query) {
  q <- if (is.data.frame(cached)) cached[["query"]] else NULL
  if (is.null(q)) {
    return(TRUE)
  }
  q <- unique(q[!is.na(q)])
  if (length(q) == 0L) {
    return(TRUE)
  }
  length(q) == 1L && identical(q, query)
}

# Bind a list of scopus_records tibbles into one, re-numbering entries. Cells
# can differ in columns, for example when resuming a cache written by an
# older package version without the `authkeywords` column, so the union of
# columns is taken and any cell missing one is filled with NA rather than
# letting rbind() error on a column mismatch.
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
  tibble::new_tibble(as.list(bound), nrow = nrow(bound), class = "scopus_records")
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
