# Pure, offline helpers behind the Shiny app (run_app()). Kept separate from the
# reactive code so the script generation, progress parsing and log rendering can
# be unit-tested without launching a server.

# Where a browser session keeps its checkpoints, under the `root` that every
# session of one running app shares. The tabs of an app are sessions of one R
# process, so they share tempdir(). The session's token names a directory of
# its own, the one its onSessionEnded() handler removes, so closing a tab never
# deletes another tab's checkpoints mid-harvest, as removing the shared root
# did. Within it, `key` names the search, so fetching the same search again in
# the same tab, after Cancel or a failure, resumes from its own checkpoints.
# Without `key`, the session's own directory is returned.
app_session_cache_dir <- function(root, token, key = NULL) {
  base <- file.path(root, token)
  if (is.null(key)) base else file.path(base, key)
}

# The directory under scopus_cache_dir() in which the generated script keeps its
# plan's checkpoints. A cache directory serves one plan, since checkpoints are
# named by their cell's position and year. The script used to send every plan to
# the managed cache's root, where one plan overwrote another's cells and each
# rerun paid for them again. The name opens with the query's words and the
# years, so the directories can be told apart by eye. It ends with eight
# hexadecimal digits of a hash over the query, field, view, partition and years,
# which together shape the cells. The record cap stays out of it. A checkpoint
# records whether a cap stopped it, and one that ran to the end serves a later,
# wider request, so a rerun without the cap pays only for the cells it cut
# short.
app_plan_cache_name <- function(query, years = NULL, field = NULL,
                                view = "STANDARD", partition = "none") {
  years <- sort(unique(as.integer(years[!is.na(years)])))
  # ASCII letters and digits only, with everything else turned into hyphens, so
  # a name reads the same on every platform and in every locale. chartr()
  # lowers the ASCII capitals alone, where tolower() follows the locale, and a
  # Turkish one can lower a capital I to a dotless i.
  words <- gsub("[^A-Za-z0-9]+", "-", query, perl = TRUE)
  words <- chartr(paste(LETTERS, collapse = ""), paste(letters, collapse = ""),
                  words)
  words <- gsub("^-+|-+$", "", words)
  # At most 40 characters, cut between words where the query has more than one.
  if (nchar(words) > 40L) {
    cut <- substr(words, 1L, 40L)
    if (substr(words, 41L, 41L) != "-" && grepl("-", cut, fixed = TRUE)) {
      cut <- sub("-[^-]*$", "", cut)
    }
    words <- cut
  }
  span <- if (length(years) == 0L) {
    NULL
  } else if (length(years) == 1L) {
    as.character(years)
  } else {
    sprintf("%d-%d", years[1L], years[length(years)])
  }
  identity <- paste(c(query, field %||% "", view, partition,
                      paste(years, collapse = ",")), collapse = "\n")
  # Hashed as UTF-8 bytes, so the encoding a string happens to be marked with
  # cannot change the name.
  hash <- substr(rlang::hash(charToRaw(enc2utf8(identity))), 1L, 8L)
  paste(c(if (nzchar(words)) words, span, hash), collapse = "-")
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
# The script opens with the version that wrote it, so a downloaded file records
# which release its behaviour belongs to, as the Python twin's does. With `demo`
# true, it says next that the records on screen were replayed from the bundled
# corpus. A panel headed "Reproducible code" would otherwise hand a demo session
# the script of a harvest it never ran. `compare_years` is the span the app
# compares over, which it supplies when the partition is off and the plan has no
# years of its own.
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
  by_year <- identical(partition, "year") && !is.null(years_code)

  plan_args <- app_quote(query)
  if (!is.null(years_code)) plan_args <- c(plan_args, sprintf("years = %s", years_code))
  if (has_field) plan_args <- c(plan_args, sprintf("field = %s", app_quote(field)))
  if (identical(view, "COMPLETE")) plan_args <- c(plan_args, "view = \"COMPLETE\"")
  if (by_year) {
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
  cache_name <- app_plan_cache_name(
    query, years, field = if (has_field) field else NULL,
    view = if (identical(view, "COMPLETE")) "COMPLETE" else "STANDARD",
    partition = if (by_year) "year" else "none"
  )
  fetch_args <- c(
    fetch_args,
    sprintf("cache_dir = file.path(scopus_cache_dir(), %s)", app_quote(cache_name)),
    "resume = TRUE"
  )

  header <- sprintf("# scopusflow %s", utils::packageVersion("scopusflow"))
  if (isTRUE(demo)) {
    header <- c(
      header,
      "# Demo mode was on, so the records shown in the app were replayed from",
      "# example_records, the bundled corpus of real published articles.",
      "# Nothing was retrieved. The script below is the live equivalent, which",
      "# harvests from Scopus and needs a key."
    )
  }

  # Everything is saved before anything is plotted. autoplot() needs ggplot2,
  # which scopusflow only suggests, so a script that plotted first stopped on a
  # machine without it before saving the records it had paid for.
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
    "# The checkpoints go to a directory of this plan's own in the managed cache.",
    sprintf("records <- scopus_fetch_plan(%s)", app_args(fetch_args)),
    "",
    "# Save the records and a clean, de-duplicated DOI list.",
    "write_scopus_records(records, \"scopus-records.rds\")",
    "scopus_extract_dois(records, file = \"scopus-dois.csv\")",
    "",
    "# Or export for a reference manager (Zotero, EndNote) or LaTeX.",
    "as_bibtex(records, file = \"scopus-records.bib\")",
    "",
    "# Write the search up for the methods section, to the PRISMA-S standard.",
    "scopus_search_report(records, file = \"scopus-search-record.md\")",
    "",
    "# Inspect the most frequent values, and plot the records per year when",
    "# ggplot2 is installed.",
    sprintf("scopus_top(records, by = %s)", app_quote(by)),
    "if (requireNamespace(\"ggplot2\", quietly = TRUE)) ggplot2::autoplot(records)"
  )

  # When comparison terms are set and a span is available, append a runnable
  # topic-comparison block reflecting the chosen terms and toggles. The span is
  # the one the app compares over, so with the partition off the block still
  # appears, over `compare_years`.
  terms <- if (is.null(compare_terms)) character() else trimws(compare_terms)
  terms <- terms[nzchar(terms)]
  cmp_years_code <- app_years_code(compare_years) %||% years_code
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
#
# The corpus is read through `::`. A lazy-loaded dataset is found by its bare
# name only through the attached package, so scopusflow::run_app() in a fresh
# session, which loads the package without attaching it, stopped here with
# "object 'example_records' not found".
app_demo_records <- function(years, max_per_year = Inf) {
  corpus <- scopusflow::example_records
  span <- range(corpus$year)
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
    cell <- corpus[corpus$year == y, , drop = FALSE]
    if (is.na(n_max)) cell else utils::head(cell, n_max)
  })
  df <- do.call(rbind, lapply(parts, as.data.frame))
  df$entry_number <- seq_len(nrow(df))
  cols <- c("entry_number", "scopus_id", "doi", "title", "authors", "year",
            "date", "publication", "citations", "query")
  tibble::new_tibble(as.list(df[cols]), nrow = nrow(df), class = "scopus_records")
}

# The PRISMA-S search record the Search record button downloads, as Markdown.
# Replayed demo records are the bundled corpus, whose `query` column holds the
# phrase of the OpenAlex search that produced it, which is neither what the
# user typed nor a search sent to 'Scopus'. Carried into the record, it became
# the search expression of a methods paragraph written to be pasted into a
# manuscript. A copy with that column blanked goes to the report, so the
# expression is unrecorded like the retrieval time beside it, and a note opens
# the file. Mirrors the Python app's _search_record(), note and all.
app_search_record <- function(records, replayed = FALSE) {
  if (!isTRUE(replayed)) {
    return(format(scopus_search_report(records), style = "markdown"))
  }
  records$query <- NA_character_
  note <- paste(
    "> Demo mode: these records were replayed from the bundled example harvest,",
    "which came from OpenAlex, and were not retrieved from Scopus. The record",
    "below describes no search that was run."
  )
  paste0(note, "\n\n", format(scopus_search_report(records), style = "markdown"))
}

# The note shown above the authors plot, or NULL when none is needed. A
# STANDARD harvest names the first author of each record alone, so its tally
# counts first authorships and would otherwise be read as a tally of every
# author. The demo replays the bundled corpus, which records no view, so it
# shows no note.
app_authors_note <- function(records) {
  if (!identical(attr(records, "view"), "STANDARD")) {
    return(NULL)
  }
  "STANDARD view: first authors only. Choose COMPLETE under Detail to tally every author."
}

# The note shown after a harvest whose record cap stopped at least one cell, or
# NULL when none is needed. A capped cell holds only the first records the API
# returned, so the By year chart counts what was retrieved. The search record
# and autoplot() say the same from the same attributes. The demo replays the
# bundled corpus without recording a cap, so it shows no note, even where a
# cap entered in demo mode trims a year. Clearing the cap lifts it, but a cell
# above the offset ceiling still stops at 5000 records, so the note promises
# no more than that.
app_cap_note <- function(records) {
  cap <- if (is.null(records)) NULL else scopus_records_cap(records)
  if (is.null(cap) || cap$capped == 0L) {
    return(NULL)
  }
  amount <- scopus_report_count(cap$cap)
  sprintf(
    paste("The cap of %s records per cell stopped %s of %s. Each capped cell",
          "holds only its first %s matches, so By year counts the records",
          "retrieved, not publications per year. Clear Max records per cell and",
          "fetch again to lift the cap."),
    amount, scopus_report_count(cap$capped), scopus_report_cells_text(cap$cells),
    amount
  )
}

# The count requests a topic comparison makes. scopus_compare_topics() counts
# the reference in every year as well as each term, so `n_terms` terms over
# `n_years` years cost (n_terms + 1) * n_years requests.
app_comparison_cost <- function(n_terms, n_years) {
  (n_terms + 1L) * n_years
}

# The cost note on the Compare topics tab, with advice to trim once the count
# passes 80 requests. The note used to multiply the terms by the years alone,
# so it understated every comparison by a year's worth of requests and gave
# its advice late.
app_comparison_note <- function(n_terms, n_years) {
  n <- app_comparison_cost(n_terms, n_years)
  sprintf(
    "(%d term%s + the reference) x %d year%s = %d count requests.%s",
    n_terms, if (n_terms == 1L) "" else "s",
    n_years, if (n_years == 1L) "" else "s", n,
    if (n > 80L) " Consider fewer terms or years." else ""
  )
}

# The notification for a harvest whose background worker failed. callr wraps
# the worker's error in one of its own, whose message opens with "in callr
# subprocess" and a deparsed call, and keeps the worker's condition as its
# parent. That condition's message is the one worth reading, marked "Scopus:"
# when it is one of the package's own, as the size check and the comparison
# mark theirs.
app_fetch_failure_message <- function(err) {
  cond <- if (inherits(err$parent, "condition")) err$parent else err
  if (inherits(cond, "scopus_error")) {
    paste("Scopus:", conditionMessage(cond))
  } else {
    paste("Retrieval did not complete:", conditionMessage(cond))
  }
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
      query = sprintf("(%s) AND (%s)", reference, terms[i]), query_type = "comparison",
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
