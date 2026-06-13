#' Execute a 'Scopus' search plan, with optional caching and resume
#'
#' Runs every cell of a [scopus_plan()] in turn, optionally caching each cell's
#' result so an interrupted or quota-limited retrieval can be resumed without
#' re-spending quota on cells already fetched. Results are accumulated and bound
#' once into a single [scopus_records] tibble.
#'
#' @param plan A `scopus_plan` object from [scopus_plan()].
#' @param max_results Maximum records to retrieve *per cell* (default `Inf`).
#' @param cache_dir Optional directory for per-cell cache files. When `NULL`
#'   (the default) no caching is performed. Pass an explicit path you control, or
#'   `scopus_cache_dir()` to use a managed, clearable cache under
#'   [tools::R_user_dir()]. The package never writes to the cache unless you opt
#'   in here.
#' @param resume Logical; when `TRUE` (and `cache_dir` is set) cells whose cache
#'   file already exists are loaded from disk instead of re-fetched.
#' @param api_key,inst_token Optional credentials (see [scopus_has_key()]).
#' @param verbose Logical; report per-cell progress when `TRUE`.
#' @return A [scopus_records] tibble combining all cells, with the originating
#'   `plan` attached as the `plan` attribute.
#' @section API access:
#' Requires a valid API key and internet access for any cell not served from
#' cache; see the *API access* section of [scopus_count()].
#' @seealso [scopus_cache_dir()], [scopus_cache_clear()]
#' @examplesIf scopusflow::scopus_has_key()
#' plan <- scopus_plan("machine translation", years = 2018:2020, partition = "year")
#' dir <- file.path(tempdir(), "mt-cache")
#' recs <- scopus_fetch_plan(plan, cache_dir = dir, resume = TRUE)
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
      if (verbose) cli::cli_inform("Cell {i}/{nrow(plan)}: loaded from cache.")
      results[[i]] <- readRDS(cache_file)
      next
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

# Bind a list of scopus_records tibbles into one, re-numbering entries.
scopus_bind_records <- function(records_list) {
  records_list <- Filter(Negate(is.null), records_list)
  if (length(records_list) == 0L) {
    return(new_scopus_records(scopus_records_columns()))
  }
  bound <- do.call(rbind, lapply(records_list, function(x) {
    class(x) <- setdiff(class(x), "scopus_records")
    x
  }))
  bound$entry_number <- seq_len(nrow(bound))
  tibble::new_tibble(as.list(bound), nrow = nrow(bound), class = "scopus_records")
}

#' Managed cache directory for scopusflow
#'
#' Returns (and creates on request) a per-user cache directory under
#' [tools::R_user_dir()], suitable for passing to `cache_dir` in
#' [scopus_fetch_plan()]. The cache is entirely optional and clearable with
#' [scopus_cache_clear()].
#'
#' @param create Logical; create the directory if it does not exist.
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
#' Deletes cache files written under [scopus_cache_dir()]. Has no effect on
#' caches you created in your own directories.
#'
#' @return Invisibly, `TRUE` if the cache directory was removed (or absent).
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
