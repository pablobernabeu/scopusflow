# Pure, offline helpers behind the Shiny app (run_app()). Kept separate from the
# reactive code so the script generation, progress parsing and log rendering can
# be unit-tested without launching a server.

# A checkpoint directory for one browser session, under the shared `base`.
# Every open tab of one app runs in the same R process and so shares the base, so
# a session may only ever remove its own subdirectory when it ends: removing the
# base itself would delete another session's checkpoints mid-harvest. The
# subdirectory is keyed by a hash of the process, the moment and a fresh
# temporary name, so two tabs opened at once cannot collide and the user's own
# random stream is left alone.
app_session_dir <- function(base) {
  file.path(base, rlang::hash(list(Sys.getpid(), Sys.time(), tempfile(""))))
}

# Quote a string for insertion into generated R code.
app_quote <- function(x) {
  encodeString(x, quote = "\"")
}

# Render an integer year vector as a compact R expression: a contiguous run
# becomes "2015:2022", anything else "c(2015, 2018, 2020)". NULL/empty -> NULL,
# meaning "omit the years argument".
app_years_code <- function(years) {
  years <- years[!is.na(years)]
  if (length(years) == 0L) {
    return(NULL)
  }
  years <- sort(unique(as.integer(years)))
  if (length(years) >= 2L && identical(years, seq(years[1], years[length(years)]))) {
    sprintf("%d:%d", years[1], years[length(years)])
  } else if (length(years) == 1L) {
    as.character(years)
  } else {
    sprintf("c(%s)", paste(years, collapse = ", "))
  }
}

# Build the reproducible R script that mirrors the user's GUI choices. The script
# is the teaching artefact, so it is assembled by hand (not shinymeta) to stay
# exactly runnable and to keep the key out of it: the generated fetch reads the
# key from the environment, never from a literal.
#
# Every script opens with the version that wrote it, so a downloaded file records
# which release its behaviour belongs to. With `demo` true it also says that the
# records on screen were replayed from the bundled corpus and that what follows
# is the live equivalent; without that, a panel headed "Reproducible code" hands
# a demo session a script for a retrieval it never ran.
app_code_mirror <- function(query,
                            years = NULL,
                            field = NULL,
                            view = "STANDARD",
                            partition = "year",
                            max_results = Inf,
                            by = "source",
                            compare_terms = NULL,
                            compare_years = NULL,
                            highlight = NULL,
                            interval = TRUE,
                            pub_count_in_legend = TRUE,
                            demo = FALSE) {
  query <- if (is.null(query) || !nzchar(trimws(query))) "your query" else trimws(query)
  years_code <- app_years_code(years)
  has_field <- !is.null(field) && nzchar(field)

  plan_args <- app_quote(query)
  if (!is.null(years_code)) plan_args <- c(plan_args, sprintf("years = %s", years_code))
  if (has_field) plan_args <- c(plan_args, sprintf("field = %s", app_quote(field)))
  if (identical(view, "COMPLETE")) plan_args <- c(plan_args, "view = \"COMPLETE\"")
  if (identical(partition, "year") && !is.null(years_code)) {
    plan_args <- c(plan_args, "partition = \"year\"")
  }

  count_args <- app_quote(query)
  if (!is.null(years_code)) count_args <- c(count_args, sprintf("years = %s", years_code))
  if (has_field) count_args <- c(count_args, sprintf("field = %s", app_quote(field)))

  fetch_args <- "plan"
  if (is.finite(max_results)) {
    # format(), never sprintf("%d"): a cap past the 32-bit ceiling coerces to NA
    # there, and the panel would then hand over a script reading
    # `max_results = NA`, which is the one thing this mirror promises never to
    # do. scientific = FALSE keeps 1e10 out of the literal as well.
    fetch_args <- c(fetch_args, sprintf(
      "max_results = %s", format(max_results, scientific = FALSE, trim = TRUE)
    ))
  }
  fetch_args <- c(fetch_args, "cache_dir = scopus_cache_dir()", "resume = TRUE")

  header <- sprintf("# scopusflow %s", utils::packageVersion("scopusflow"))
  if (isTRUE(demo)) {
    header <- c(
      header,
      "# Demo mode was on, so the records shown in the app were replayed from",
      "# example_records, the bundled corpus of real published articles. Nothing",
      "# was retrieved. What follows is the live equivalent: it harvests from",
      "# Scopus and needs a key."
    )
  }

  lines <- c(
    header,
    "",
    "library(scopusflow)",
    "",
    "# Describe the search as an inspectable, reproducible plan.",
    sprintf("plan <- scopus_plan(%s)", app_args(plan_args)),
    "",
    "# Check the size before spending any quota.",
    sprintf("scopus_count(%s)", app_args(count_args)),
    "",
    "# Retrieve, caching each cell so an interrupted run resumes. The key is read",
    "# from the SCOPUS_API_KEY environment variable, never written into this script.",
    sprintf("records <- scopus_fetch_plan(%s)", app_args(fetch_args)),
    "",
    "# Inspect the most frequent values and the records per year.",
    sprintf("scopus_top(records, by = %s)", app_quote(by)),
    "ggplot2::autoplot(records)",
    "",
    "# Save the records and a clean, de-duplicated DOI list.",
    "write_scopus_records(records, \"scopus-records.rds\")",
    "scopus_extract_dois(records, file = \"scopus-dois.csv\")",
    "",
    "# Or export for a reference manager (Zotero, EndNote) or LaTeX.",
    "as_bibtex(records, file = \"scopus-records.bib\")",
    "",
    "# Write the search up for the methods section, to the PRISMA-S standard.",
    "scopus_search_report(records, file = \"scopus-search-record.md\")"
  )

  # When comparison terms are set (and a year span is available), append a
  # runnable topic-comparison block reflecting the chosen terms and toggles. A
  # comparison always counts over some span, so `compare_years` carries the one
  # the app resolved: with the year partition off the plan has no years of its
  # own, and the block would otherwise be left out of the script for a
  # comparison the user had just run.
  terms <- if (is.null(compare_terms)) character() else trimws(compare_terms)
  terms <- terms[nzchar(terms)]
  cmp_years_code <- app_years_code(compare_years)
  if (is.null(cmp_years_code)) cmp_years_code <- years_code
  if (length(terms) > 0L && !is.null(cmp_years_code)) {
    cmp_args <- c(
      app_quote(query),
      sprintf("comparison_terms = c(%s)",
              paste(vapply(terms, app_quote, character(1)), collapse = ", ")),
      sprintf("years = %s", cmp_years_code)
    )
    if (has_field) cmp_args <- c(cmp_args, sprintf("field = %s", app_quote(field)))
    if (identical(view, "COMPLETE")) cmp_args <- c(cmp_args, "view = \"COMPLETE\"")
    plot_args <- "cmp"
    if (!is.null(highlight) && nzchar(highlight)) {
      plot_args <- c(plot_args, sprintf("highlight = %s", app_quote(highlight)))
    }
    if (!isTRUE(interval)) plot_args <- c(plot_args, "interval = FALSE")
    if (!isTRUE(pub_count_in_legend)) {
      plot_args <- c(plot_args, "pub_count_in_legend = FALSE")
    }
    lines <- c(
      lines,
      "",
      "# Compare how sub-topics co-occur with the search over time, as a share",
      "# of it (one count request per term per year, plus one per year for the",
      "# reference topic).",
      sprintf("cmp <- scopus_compare_topics(%s)", app_args(cmp_args)),
      sprintf("plot_scopus_comparison(%s)", paste(plot_args, collapse = ", "))
    )
  }
  paste(lines, collapse = "\n")
}

# Join call arguments, wrapping onto indented lines when the one-line form would
# be long, so the emitted script stays readable.
app_args <- function(args) {
  one_line <- paste(args, collapse = ", ")
  if (nchar(one_line) <= 60L && length(args) <= 2L) {
    return(one_line)
  }
  paste0("\n  ", paste(args, collapse = ",\n  "), "\n")
}

# First and last year the bundled example harvest covers, as the Python app's
# _demo_year_span does. The app opens its year slider on this span, since demo
# mode is on from the start and a year outside it has nothing of its own to
# replay.
app_demo_year_span <- function() {
  range(example_records$year)
}

# Assemble the demo record set, so the whole app flow (table, plots, export)
# works offline with no key. It draws on the bundled `example_records`, as the
# Python app's _demo_rows does, so every panel is exercised on real titles,
# DOIs, journals and citation counts, and the by-year chart shows that query's
# real publication curve, where invented rows gave a row of identical bars.
# `max_per_year` caps each year exactly as `max_results` caps a real cell.
#
# The two engines part company on one edge, and deliberately. A requested year
# outside the corpus span is clamped into it here, then de-duplicated by the
# unique() below, so a demo run over 2025:2026 shows 2024 once; the Python
# _demo_rows instead returns nothing for such a year and logs that it did. Both
# avoid the double-counting that padding a missing year with a neighbour's rows
# would cause, and each half's app article states its own rule. Keep the two
# descriptions in step if either rule changes.
app_demo_records <- function(years, max_per_year = Inf) {
  span <- app_demo_year_span()
  years <- if (is.null(years) || length(years) == 0L) span[2L] else as.integer(years)
  years <- sort(unique(pmin(pmax(years, span[1L]), span[2L])))
  # Left as a double. head() takes one, and as.integer() would silently turn a
  # cap past the 32-bit ceiling into the NA that stands here for "no cap".
  n_max <- if (is.numeric(max_per_year) && length(max_per_year) == 1L &&
               is.finite(max_per_year) && max_per_year >= 1) {
    max_per_year
  } else {
    NA_real_
  }
  parts <- lapply(years, function(y) {
    cell <- example_records[example_records$year == y, , drop = FALSE]
    if (is.na(n_max)) cell else utils::head(cell, n_max)
  })
  df <- do.call(rbind, lapply(parts, as.data.frame))
  df$entry_number <- seq_len(nrow(df))
  cols <- c("entry_number", "scopus_id", "doi", "title", "authors", "year",
            "date", "publication", "citations", "query")
  tibble::new_tibble(as.list(df[cols]), nrow = nrow(df), class = "scopus_records")
}

# Synthesise a plausible topic comparison so the compare flow works offline,
# mirroring the Python app's _demo_comparison. Each term is given a different base
# share and growth rate; the rows are built and sorted exactly as
# scopus_compare_topics() does, so the demo object is indistinguishable in shape
# from a real one.
app_demo_comparison <- function(reference, terms, years) {
  reference <- trimws(reference %||% "")
  if (!nzchar(reference)) reference <- "reference topic"
  terms <- trimws(terms)
  terms <- terms[nzchar(terms)]
  if (length(terms) == 0L) terms <- "comparison term"
  years <- sort(unique(as.integer(years)))
  if (length(years) == 0L) years <- 2020L
  span <- max(length(years) - 1L, 1L)
  y0 <- years[1]
  ref_n <- 1000 + (years - y0) * 120
  names(ref_n) <- as.character(years)

  rows <- list()
  rows[[1]] <- scopus_comparison_block(
    query = reference, query_type = "reference",
    abridged = reference, years = years, n = ref_n, ref_n = ref_n
  )
  for (i in seq_along(terms)) {
    base <- 0.06 + 0.07 * (i - 1L)
    growth <- 0.03 * i
    cmp_n <- as.integer(ref_n * (base + growth * (years - y0) / span))
    rows[[length(rows) + 1L]] <- scopus_comparison_block(
      query = paste(reference, "AND", terms[i]), query_type = "comparison",
      abridged = terms[i], years = years, n = cmp_n, ref_n = ref_n
    )
  }
  out <- do.call(rbind, rows)
  ord <- order(
    out$query_type != "reference",
    -out$average_comparison_percentage,
    out$abridged_query,
    out$year
  )
  out <- out[ord, ]
  rownames(out) <- NULL
  tibble::new_tibble(as.list(out), nrow = nrow(out), class = "scopus_comparison")
}

# Find the most recent "Cell k/N:" marker in the streamed verbose log and return
# the (done, total) counts that drive the progress bar, or NULL. The trailing
# colon (which scopus_fetch_plan always emits, e.g. "Cell 2/8: fetching ...")
# anchors the match so a "k/N" pattern inside the echoed query is far less likely
# to be mistaken for progress; a marker with done > total is rejected too.
app_parse_cell_progress <- function(lines) {
  if (length(lines) == 0L) {
    return(NULL)
  }
  re <- "Cell\\s+([0-9]+)\\s*/\\s*([0-9]+):"
  hits <- lines[grepl(re, lines)]
  if (length(hits) == 0L) {
    return(NULL)
  }
  m <- regmatches(hits[length(hits)], regexec(re, hits[length(hits)]))[[1]]
  done <- as.integer(m[2])
  total <- as.integer(m[3])
  if (is.na(done) || is.na(total) || done > total) {
    return(NULL)
  }
  list(done = done, total = total)
}

# Escape the HTML-special characters in plain text.
app_escape_html <- function(text) {
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  gsub(">", "&gt;", text, fixed = TRUE)
}

# Render captured terminal output (which may carry ANSI colour) as HTML. Uses
# fansi when available to keep cli's colours; otherwise strips the escapes and
# escapes the HTML. Lone carriage returns from cli progress bars are collapsed so
# the panel does not jitter.
app_ansi_to_html <- function(lines) {
  text <- paste(lines, collapse = "\n")
  text <- gsub("[^\n]*\r", "", text)
  # Escape HTML first, in BOTH branches, so a query echoed into the log can never
  # be injected as live HTML into the terminal panel. fansi still recognises the
  # ANSI SGR escapes after escaping, since those bytes are untouched.
  if (requireNamespace("fansi", quietly = TRUE)) {
    return(fansi::sgr_to_html(app_escape_html(text), warn = FALSE))
  }
  app_escape_html(gsub("\033\\[[0-9;]*m", "", text))
}
