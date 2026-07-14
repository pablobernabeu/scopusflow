# Changelog

## scopusflow 0.2.1

A documentation release. The vignettes now demonstrate several features
that 0.2.0 shipped but did not show.

- [`vignette("designing-queries")`](https://pablobernabeu.github.io/scopusflow/articles/designing-queries.md)
  shows the `AND NOT` operator in
  \[[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)\],
  excluding a dominant homonym from a search.
- [`vignette("analysing-a-literature")`](https://pablobernabeu.github.io/scopusflow/articles/analysing-a-literature.md)
  passes
  \[[`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)\]
  a concept that is already a complete field-tagged expression and so is
  used as given, letting a concept be a synonym set rather than a single
  term.
- [`vignette("scopusflow")`](https://pablobernabeu.github.io/scopusflow/articles/scopusflow.md)
  introduces
  \[[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)\]
  on a record set, and points to the analysis article for the plots and
  trends built on it.
- [`vignette("plans-and-quota")`](https://pablobernabeu.github.io/scopusflow/articles/plans-and-quota.md)
  covers `verbose = TRUE` in
  \[[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)\],
  which reports a line as each cell is fetched or loaded from cache.
- [`vignette("building-a-reference-set")`](https://pablobernabeu.github.io/scopusflow/articles/building-a-reference-set.md)
  shows
  \[[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)\]
  on a plain vector of DOIs, both with the default deduplication (which
  ignores case and resolver prefixes) and with `dedupe = FALSE`.
- [`vignette("keywords-and-references")`](https://pablobernabeu.github.io/scopusflow/articles/keywords-and-references.md)
  tallies author keywords across a
  \[[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)\]
  result, the per-keyword document count the article is named for.
- \[[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)\]’s
  help page no longer describes the Python twin’s reference fields.

## scopusflow 0.2.0

This release reaches further into the API, adds an analysis and export
layer on top of a retrieval, and introduces a local, code-free app.

### Deeper retrieval

- \[[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)\]
  gains `cursor = TRUE`, cursor-based pagination that retrieves a whole
  large query without the 5000-record ceiling of offset paging. The
  warning on a query that exceeds the ceiling suggests this alongside
  partitioning with
  \[[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)\].
- \[[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)\]
  and
  \[[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)\]
  add an `authkeywords` column when `view = "COMPLETE"` is requested, at
  no cost beyond that view’s own smaller page size; `view = "STANDARD"`
  output is unchanged, and
  \[[`read_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)\]
  keeps the column across a CSV round-trip.
- \[[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)\]
  retrieves the abstract and fuller metadata for one or many records
  from the ‘Scopus’ Abstract Retrieval API, resilient to an identifier
  that cannot be found. Through `view` and
  `include = c("references", "keywords")` it also retrieves a document’s
  own reference list (as a structured, per-citation data frame, not a
  joined string) and author keywords, with per-identifier caching keyed
  by the requested view and extras, an `n_requests`/`quota` attribute,
  and a clear, actionable error on an entitlement 403 that stops the
  batch rather than repeating the same failure for every identifier.
  `include = "keywords"` without `view = "FULL"` is rejected up front,
  since the `REF` response carries no author keywords.
- \[[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)\]
  combines a search result with abstract retrieval into a minimal
  `id`/`title`/`year`/`keywords`/`references` shape for downstream tools
  such as keyword co-occurrence or citation-network analysis, without
  replacing
  \[[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)\].
  A new vignette, *Author keywords and references*, walks through all of
  this with real DOIs.
- \[[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)\]
  compares each checkpoint’s recorded query with the plan cell before
  loading it, refetching and overwriting the checkpoint on a mismatch,
  so two different plans pointed at the same `cache_dir` cannot serve
  each other’s records. A checkpoint that carries no query information
  (a zero-row cell, or one written by scopusflow 0.1.0) loads as before,
  and a cache directory is still best kept to a single plan.

### Analysis and plots

- \[[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)\]
  reports annual record counts for a query (the size of a literature
  over time), with
  \[[`plot_scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md)\].
- \[[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)\]
  tallies the most frequent sources or authors in a record set, with
  \[[`plot_scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md)\],
  which draws whole-number axis breaks (so a tally of small counts shows
  no fractional ticks) and derives the count axis’s headroom from the
  widest end-of-bar label (so a wide count, say five figures on a
  top-authors bar, does not clip at the panel edge). An `autoplot()`
  method draws a record set’s publications per year.
- \[[`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)\]
  counts a named set of concepts and any requested intersections of
  them, sizing where a study or a niche sits within the surrounding
  literature at one count request per row. Concept values that are
  already complete field-tagged expressions are used as given rather
  than wrapped again.
  \[[`plot_scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_intersections.md)\]
  draws the result as a lollipop chart on a log-scale axis, with an
  `autoplot()` method and an optional highlight (for example the niche
  itself) whose legend label is derived from what is highlighted: “Focal
  intersection” for intersections, “Focal concept” for concepts and
  “Focal set” for a mixture. An explicit `highlight_label` still wins.
- \[[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)\]
  gains `legend_inside`. When set, and a legend is drawn, it is placed
  inside the panel in whichever corner has the most free space, on a
  small semi-transparent background, rather than above the panel. The
  default keeps the previous behaviour.
- \[[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)\]
  now spreads the direct line labels vertically so topics that converge
  near the final year no longer overlap, and falls back to a legend when
  there are too many topics to label legibly. The labels are spread when
  the figure is drawn, against the rendered text height, so they stay
  legible at any figure size, including a short panel such as the app’s
  result card. They carry no leader lines: the labels are colour-matched
  to their lines and spread in the same order as the line ends, so the
  link is clear without a leader that would otherwise cut across
  neighbouring labels.

### Export

- \[[`as_bibtex()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)\]
  and
  \[[`as_ris()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)\]
  export a record set to the BibTeX and RIS interchange formats, so a
  search can be carried into Zotero, EndNote, Mendeley or a LaTeX
  bibliography.

### A code-free app

- \[[`run_app()`](https://pablobernabeu.github.io/scopusflow/reference/run_app.md)\]
  launches a local, code-free Shiny app for building a search,
  retrieving records with a live progress terminal, and exporting them.
  A panel mirrors every choice as a runnable R script, so the app is an
  on-ramp to the package. It runs on your own machine, so the API key
  never leaves it. The app also has a *Compare topics* tab (with
  highlight, stability-band and counts-in-label controls, a per-term
  progress indicator, a quota estimate and a CSV export) and a *Demo
  mode*, on by default, that synthesises records and a comparison so the
  whole workflow can be explored with no key and no network. A new
  vignette, *Using the code-free app*, walks through every panel.
- The app holds steady under stress. It refuses to start a comparison
  while a harvest is running, surfaces any comparison failure as a
  notification rather than a crash, floors a fractional maximum-records
  entry, drops duplicate comparison terms, and tells you when there is
  nothing to cancel.

### Other improvements

- The no-key error renders its guidance (the option name, the `api_key`
  argument and the key-request URL) through cli instead of leaking raw
  markup.

## scopusflow 0.1.0

CRAN release: 2026-06-20

First release.

- Reproducible search plans with
  \[[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)\],
  and cheap sizing with
  \[[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)\].
- Quota-aware, paginated retrieval through
  \[[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)\],
  with the largest page each view allows requested by default to keep
  request counts low, and resumable, cached, partitioned retrieval
  through
  \[[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)\].
- A stable normalised record schema from
  \[[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)\],
  with a [`summary()`](https://rdrr.io/r/base/summary.html) method that
  gives a quick overview.
- DOI extraction and change tracking with
  \[[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)\]
  and
  \[[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)\].
- Topic-trend comparison with
  \[[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)\],
  and a plot from
  \[[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)\]
  or `autoplot()`.
- Interoperability and I/O through
  \[[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)\],
  \[[`write_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)\]
  and
  \[[`read_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)\].
- A reference to the common ‘Scopus’ field tags in
  \[[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)\],
  a safe query composer in
  \[[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)\],
  and a bundled \[`example_records`\] dataset for offline exploration.
- Safe merging of record sets with
  \[[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)\]
  (and a [`c()`](https://rdrr.io/r/base/c.html) method), plus
  `as_tibble()` and
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  coercion.
- A typed condition system (`scopus_error` and its subclasses) and
  quota-header parsing with
  \[[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md)\].
- The comparison plot uses whole-number year breaks, a colour-blind-safe
  palette, direct line labels, an optional `highlight` argument and a
  shaded Wilson stability band (an illustrative range, switchable with
  `interval`).
- The bundled `example_records` spans several disciplines, and the
  examples and five workflow vignettes draw on a wide range of fields.
- Multiple authors are retained in the `authors` column rather than
  truncated to the first; very large result totals are handled without
  overflow; and DOI cleaning copes with `www.doi.org` hosts and `DOI:`
  labels.
