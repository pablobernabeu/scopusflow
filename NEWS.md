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
* [`plot_scopus_comparison()`] now spreads the direct line labels vertically and
  draws a leader from each label to its line, so topics that converge near the
  final year no longer overlap, and falls back to a legend when there are too
  many topics to label legibly.

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
