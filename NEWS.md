# scopusflow 0.3.0

This release adds a code-free app and reference-manager export.

* [`run_app()`] launches a local, code-free Shiny app for building a search,
  retrieving records with a live progress terminal, and exporting them. A panel
  mirrors every choice as a runnable R script, so the app is an on-ramp to the
  package. It runs on your own machine, so the API key never leaves it. The app
  also has a *Compare topics* tab (with highlight, stability-band and
  counts-in-label controls, a per-term progress indicator, a quota estimate and a
  CSV export) and a *Demo mode*, on by default, that synthesises records and a
  comparison so the whole workflow can be explored with no key and no network. A
  new vignette, *Using the code-free app*, walks through every panel.
* [`as_bibtex()`] and [`as_ris()`] export a record set to the BibTeX and RIS
  interchange formats, so a search can be carried into Zotero, EndNote, Mendeley
  or a LaTeX bibliography.
* [`scopus_intersections()`] counts a named set of concepts and any requested
  intersections of them, sizing where a study or a niche sits within the
  surrounding literature at one count request per row, and
  [`plot_scopus_intersections()`] draws the result as a lollipop chart on a
  log-scale axis, with an optional highlight (for example the niche itself)
  and an `autoplot()` method. Concept values that are already complete
  field-tagged expressions are used as given rather than wrapped again.
* [`plot_scopus_top()`] draws whole-number axis breaks for its counts, so a
  tally of small counts no longer shows fractional ticks.
* [`plot_scopus_comparison()`] gains `legend_inside`. When set, and a legend is
  drawn, it is placed inside the panel in whichever corner has the most free
  space, on a small semi-transparent background, rather than above the panel.
  The default keeps the previous behaviour.
* [`plot_scopus_comparison()`] now spreads the direct line labels vertically so
  topics that converge near the final year no longer overlap, and falls back to
  a legend when there are too many topics to label legibly. The labels are
  spread when the figure is drawn, against the rendered text height, so they
  stay legible at any figure size, including a short panel such as the app's
  result card. They carry no leader lines: the labels are colour-matched to
  their lines and spread in the same order as the line ends, so the link is
  clear without a leader that would otherwise cut across neighbouring labels.
* The app is steadier under stress. It refuses to start a comparison while a
  harvest is running, surfaces any comparison failure as a notification rather
  than a crash, floors a fractional maximum-records entry, drops duplicate
  comparison terms, and tells you when there is nothing to cancel.
* [`scopus_fetch()`] and [`scopus_fetch_plan()`] add an `authkeywords` column
  when `view = "COMPLETE"` is requested, at no cost beyond that view's own
  smaller page size; `view = "STANDARD"` output is unchanged.
  [`scopus_abstract()`] gains `view` and `include = c("references",
  "keywords")`, retrieving a document's own reference list (as a structured,
  per-citation data frame, not a joined string) and author keywords via
  Abstract Retrieval, with per-identifier caching, a `n_requests`/`quota`
  attribute, and a clear, actionable error on an entitlement 403 that stops
  the batch rather than repeating the same failure for every identifier. A
  new [`scopus_corpus()`] combines a search result with this step into a
  minimal `id`/`title`/`year`/`keywords`/`references` shape for downstream
  tools such as keyword co-occurrence or citation-network analysis, without
  replacing [`as_bibliometrix()`]. A new vignette, *Author keywords and
  references*, walks through all of this with real DOIs.
* [`scopus_fetch_plan()`] compares each checkpoint's recorded query with the
  plan cell before loading it, refetching and overwriting the checkpoint on a
  mismatch, so two different plans pointed at the same `cache_dir` cannot
  serve each other's records. A checkpoint that carries no query information
  (a zero-row cell, or one written by an older scopusflow) loads as before,
  and a cache directory is still best kept to a single plan.
* [`scopus_abstract()`] keys its per-identifier cache by the requested
  `include` set as well as the view, so a resumed run that asks for different
  extras refetches rather than being served a cached row missing the
  requested columns. Rows whose columns differ, as with a cache written by an
  older scopusflow, are filled to the union of columns instead of failing to
  bind.
* [`scopus_abstract()`] rejects `include = "keywords"` without `view =
  "FULL"` up front, since the `REF` response carries no author keywords;
  previously the request was accepted and yielded `NA` silently.
  [`scopus_corpus()`] requests only references under `view = "REF"`
  accordingly, with empty `keywords`.
* [`read_scopus_records()`] keeps the `authkeywords` column a
  `COMPLETE`-view record set carries, so the CSV round-trip is stable for
  that view too.
* The warning on a query that exceeds the 5000-record offset ceiling suggests
  `scopus_fetch(cursor = TRUE)` as well as partitioning with
  [`scopus_plan()`].
* The no-key error renders its guidance (the option name, the `api_key`
  argument and the key-request URL) through cli instead of leaking raw
  markup.

# scopusflow 0.2.0

This release reaches further into the API and adds an analysis layer on top of a
retrieval.

* [`scopus_fetch()`] gains `cursor = TRUE`, cursor-based pagination that retrieves
  a whole large query without the 5000-record ceiling of offset paging.
* [`scopus_abstract()`] retrieves the abstract and fuller metadata for one or many
  records from the 'Scopus' Abstract Retrieval API, resilient to an identifier
  that cannot be found.
* [`scopus_trend()`] reports annual record counts for a query (the size of a
  literature over time), with [`plot_scopus_trend()`].
* [`scopus_top()`] tallies the most frequent sources or authors in a record set,
  with [`plot_scopus_top()`]. An `autoplot()` method draws a record set's
  publications per year.

# scopusflow 0.1.0

First release.

* Reproducible search plans with [`scopus_plan()`], and cheap sizing with
  [`scopus_count()`].
* Quota-aware, paginated retrieval through [`scopus_fetch()`], with the largest
  page each view allows requested by default to keep request counts low, and
  resumable, cached, partitioned retrieval through [`scopus_fetch_plan()`].
* A stable normalised record schema from [`scopus_records()`], with a
  `summary()` method that gives a quick overview.
* DOI extraction and change tracking with [`scopus_extract_dois()`] and
  [`scopus_diff_dois()`].
* Topic-trend comparison with [`scopus_compare_topics()`], and a plot from
  [`plot_scopus_comparison()`] or `autoplot()`.
* Interoperability and I/O through [`as_bibliometrix()`],
  [`write_scopus_records()`] and [`read_scopus_records()`].
* A reference to the common 'Scopus' field tags in [`scopus_field_tags()`], a
  safe query composer in [`scopus_query()`], and a bundled [`example_records`]
  dataset for offline exploration.
* Safe merging of record sets with [`scopus_combine()`] (and a `c()` method), plus
  `as_tibble()` and `as.data.frame()` coercion.
* A typed condition system (`scopus_error` and its subclasses) and quota-header
  parsing with [`scopus_quota()`].
* The comparison plot uses whole-number year breaks, a colour-blind-safe palette,
  direct line labels, an optional `highlight` argument and a shaded Wilson
  stability band (an illustrative range, switchable with `interval`).
* The bundled `example_records` spans several disciplines, and the examples and
  workflow vignettes draw on a wide range of fields.
* Multiple authors are retained in the `authors` column rather than truncated to
  the first. Very large result totals are handled without overflow. DOI cleaning
  copes with `www.doi.org` hosts and `DOI:` labels.
