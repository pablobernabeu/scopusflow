# Changelog

## scopusflow 0.4.0

CRAN release: 2026-08-21

A release about reporting a search and about trusting the cache. The
package now writes a search up as the reproducible record a systematic
review has to publish, and a family of silent cache defects that served
the wrong records is fixed.

### Writing up a search

- [`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
  assembles the reproducible search-strategy record a systematic review
  has to report, from a harvest or from a plan not yet run. It prints as
  a readable report, formats as a methods paragraph fit to paste into a
  manuscript (`format(report, style = "paragraph")`), and writes as
  Markdown when `file` is supplied. It carries the database and
  platform, the field-wrapped query of every cell, the year limits,
  view, page size and paging mode, the date searched, the records
  retrieved against the number the API reported as matching, per-cell
  completeness, duplicates removed, the software versions, a runnable
  snippet that rebuilds the plan, and an explicit map of which PRISMA-S
  items the package can supply and which only you can. The reporting
  standard is PRISMA-S (Rethlefsen et al., 2021, Systematic Reviews, 10,
  39), with the identification counts of the PRISMA 2020 flow diagram.

  Because the output is written for a published methods section, the
  report states only what the objects record. An absent retrieval time
  is never replaced by the current one, a completeness figure is never
  given for a harvest whose reported total is unknown, duplicates are
  counted only where a merge recorded removing them, and every
  unverifiable field says it is unrecorded, in words. Ten of the sixteen
  PRISMA-S items, among them peer review of the strategy, grey
  literature and any other database searched, are listed as yours to
  supply, since the package has no evidence for them.

- [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  now carries the per-cell accounting onto its result, as the
  `cell_totals` attribute, and sums it into `total_results` when (and
  only when) every cell reported a total. A cell that comes back shorter
  than the API said it should now warns, which the Python twin has done
  since 0.3.0, and the warning text is byte-identical between the two. A
  cell stopped by `max_results` is short by request and does not warn.

- [`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
  records the merge in the `combined` attribute: how many records went
  in, how many were kept, how many were removed and whether
  de-duplication ran. That count exists only at the moment of the merge,
  and PRISMA-S asks for it.

- A retrieval also records how it was paged, as the `paging` attribute,
  since an offset-paged query stops at the API’s ceiling where a
  cursor-paged one does not.

### Cache defects that returned the wrong records

All were silent, and all are fixed.

- A year-partitioned plan could be served another plan’s years, because
  checkpoints were keyed by the cell’s position alone and every cell of
  such a plan carries the same query (the year travels separately, as
  the API’s `date` parameter), so the guard meant to reject a foreign
  checkpoint could not tell 2015’s from 2016’s. A plan over 2016:2017
  pointed at a cache written by a plan over 2015:2016 returned the 2015
  records and reported “loaded from cache”. Checkpoints are now named
  `cell-NNN-YYYY.rds` and carry a manifest (query, date, view, page size
  and record cap) that resume compares against. Existing caches become
  invisible and refetch once, which spends a little quota to buy back
  correctness.
- A cell cached under a `max_results` cap was served to a later request
  asking for more. The manifest now records the cap and whether it
  actually bit, so a truncated checkpoint is a miss for a wider request
  while an untruncated one stays usable for any request. The Shiny app’s
  cache key gained the record cap and now hashes the query, where it
  used to truncate it at 80 characters, so two long queries sharing a
  prefix no longer share a directory.
- A zero-row checkpoint answered for any query. The guard that
  recognises a foreign checkpoint reads the cached rows’ `query` column,
  which an empty cell has no rows to carry, and the manifest comparison
  never consulted its own copy of the query, so a plan that legitimately
  found nothing left a checkpoint that a different plan pointed at the
  same `cache_dir` would load as its own empty result. The manifest’s
  query must now match as well.
- A failed abstract retrieval was checkpointed as if it were data. A
  rate-limited, server-error or offline attempt in
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
  degrades to an all-NA row so the batch survives, but that row was
  written to the cache, so a resumed run read the failure back from disk
  and never retried it. Only rows parsed from successful responses are
  checkpointed now.
- Two identifiers could share one abstract checkpoint, because the cache
  filename reduces every non-alphanumeric character to `_`, so distinct
  identifiers such as `10.1/a.b` and `10.1/a-b` collide on the same
  file, and resume never asked which identifier a cached row belonged
  to. The cached row’s own id must now match, and a collision warns and
  refetches.
- A checkpoint holding more records than the current `max_results` asks
  for is now served trimmed to that cap, with the fuller set left on
  disk for a later, wider request. The opposite direction, a checkpoint
  truncated below what is asked for, already refetched with a warning.

A rejected or damaged checkpoint now warns, where it used to be
mentioned only under `verbose`, and checkpoints are written to a sibling
temporary file and renamed into place, so an interrupted run can no
longer leave a half-written file that breaks every later resume.

### Other fixes

- [`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
  handed the merged set one input’s own retrieval attributes.
  [`rbind()`](https://rdrr.io/r/base/cbind.html) keeps those of its
  first argument, so the result inherited that harvest’s `plan`,
  `cell_totals` and `total_results` even though it held the rows of
  several, contradicting the documented promise that per-retrieval
  attributes are not carried over. A search record read off the
  inherited total then called the union of two harvests complete against
  a figure belonging to one of them. Only what survives a merge is kept
  now: the earliest retrieval time, every contributing version, the
  paging mode where the inputs agree, and the merge counts themselves.
- The PRISMA 2020 identification block counted the records identified
  after de-duplication, so the two figures it gives could not both be
  right: the diagram subtracts the duplicates removed from the records
  identified to reach the records screened, and 138 identified less 11
  removed is not the 138 rows the set holds. Where a merge recorded how
  many records went into it, that is now the identification count.
- A plan not yet run was described in the past tense, and its date line
  said the set did not carry a retrieval time, when the truth was that
  no retrieval had happened.
- `average_comparison_percentage` summed the numerator over years the
  denominator excluded, so a year with a missing reference count
  inflated it, giving a figure that contradicted the per-year shares
  printed beside it and that drives the topic ordering in
  [`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md).
  It is now computed over the years where both counts are available.
- `scopus_abstract(include = "references")` aborted the whole batch when
  one document’s response omitted its reference-count attribute. Because
  that arrived as a bare base error, untyped and so outside the
  `scopus_error` hierarchy, the per-identifier handler could not catch
  it, defeating the documented promise that one bad identifier does not
  lose a batch.
- The app’s demo banner still called the demo data synthetic, which was
  true of the six invented rows that shipped before 0.3.0. Demo mode has
  replayed 138 real published articles since then, and only the topic
  comparison is simulated, so the banner now says which is which.
- A record count past 2^31 was coerced to `NA` at three points, each of
  which accepted any finite whole number and then reached for a 32-bit
  integer. `scopus_top(n = )` left `head.data.frame()` raising an
  untyped error about its own argument; `scopus_fetch(max_results = )`
  and `scopus_fetch_plan(max_results = )` turned every later
  `n >= max_results` into `NA`, so the retrieval died on a bare “missing
  value where TRUE/FALSE needed”; and the app’s reproducible-code panel
  wrote `max_results = NA` into a script it promises is runnable. All
  three now carry the value as a double, so a cap wider than the result
  set simply never bites, which is what the Python twin has always done.
  A cap that fits stays an integer.
- The 5000-record cap warning fired even when `max_results` had already
  asked for fewer records than the ceiling, advising a remedy for a
  problem the caller did not have.
- [`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
  carries its counts as doubles, matching
  [`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)
  and
  [`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md),
  so billion-scale totals no longer coerce to `NA`.
- Every request carries a 60-second transfer timeout, tunable through
  `getOption("scopusflow.timeout")`, so a stalled connection cannot hang
  a session.
- Retrievals record when they were taken and by which package version,
  as the `retrieved_at` and `scopusflow_version` attributes, preserved
  through the `.rds` round trip. Both are attributes, so the documented
  schema and the CSV round trip are unchanged.
- Every text file the package writes now carries LF line endings on all
  platforms: the BibTeX and RIS exports, the DOI and record CSVs, and
  the app’s script and comparison downloads previously arrived with CRLF
  endings when written on Windows.
- Every [`print()`](https://rdrr.io/r/base/print.html) method now sends
  its whole output to standard output. The header line went through cli,
  which writes to the message stream, so
  [`capture.output()`](https://rdrr.io/r/utils/capture.output.html)
  returned the table without its header, and a knitted document showed
  one printed object as two separate blocks.

### Continuous integration and metadata

- The dependency canary could finish green having exercised nothing,
  when no development head was actually installed. It now says so, in a
  warning and in the step summary, and it installs the ggplot2
  development head alongside the Imports.
- The declared dependency floors are now installed and tested by a
  `min-deps` job, and the check matrix reaches back to roughly R 4.3.
- `rlang`’s floor is corrected to 1.1.0. The evidence for it is httr2
  1.0.0’s own DESCRIPTION, which requires `rlang (>= 1.1.0)`, so the old
  floor described a combination no user could have installed. It is
  CRAN-visible metadata.
- The live API check’s documented request cost, the cache guard’s
  description in the documentation and vignette, and the path to the
  Python twin’s copy of the example records were all corrected.

## scopusflow 0.3.0

A data and documentation release. The bundled corpus becomes a real
harvest, and every example and article is rebuilt on it.

### The bundled example records

The dataset the package ships for offline work was replaced outright.

- `example_records` is now a worked example harvest of 138 real journal
  articles on graphene supercapacitors published between 2015 and 2024,
  carrying their real titles, DOIs, source titles, first authors and
  citation counts. It replaces the six invented records shipped
  previously.
- The records are not a ‘Scopus’ harvest and are not described as one.
  The Elsevier API terms do not permit redistributing retrieved records,
  so they come from OpenAlex, whose metadata is released under CC0,
  reshaped into the schema
  \[[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)\]
  returns. The reasoning is recorded in the design notes.
- The harvest is complete, so the rows per year are the real
  publications per year for that query. Eleven records carry no DOI and
  two no source title, kept as they arrive because a real harvest has
  such gaps.
- `scopus_id` is empty throughout, these records not having come from
  ‘Scopus’, so de-duplication falls back to the DOI as it does for any
  record whose identifier is missing.

### Documentation

The material a reader meets was rebuilt on the new corpus, and one
misleading fixture was replaced.

- Every vignette and example runs on that corpus, paired with the
  key-gated live call a reader would write, and the figures quoted in
  the prose were recomputed against the new data.
- The demo mode of
  [`run_app()`](https://pablobernabeu.github.io/scopusflow/reference/run_app.md)
  draws on the same corpus, so a first look at the app opens on real
  articles, where it used to show invented rows.
- The parser fixture in `inst/extdata` moves onto the reserved 10.5555
  example prefix. It previously paired genuine, resolving DOIs with
  invented titles and authors, so a reader who checked one found a real
  paper mislabelled.
- Every vignette now turns console colour off and fixes the console
  width while it renders. pkgdown enables colour for its own build, and
  the escape sequences were reaching the reader as literal text in the
  middle of the tables.
- [`vignette("comparing-topics")`](https://pablobernabeu.github.io/scopusflow/articles/comparing-topics.md)
  shows one year of its illustrative comparison across every topic, in
  place of the whole table, and leaves out the `query` column, which in
  a real comparison holds the whole query string and so reads badly in a
  table.
- The README no longer opens with a link to the documentation site,
  which on the site’s own home page pointed the reader at the page in
  front of them.

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
  used as given, letting a concept be a whole synonym set.
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

A search now reaches further into the API, past the offset ceiling and
beyond the fields the Search endpoint returns.

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
  no cost beyond that view’s own smaller page size. The
  `view = "STANDARD"` output is unchanged, and
  \[[`read_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)\]
  keeps the column across a CSV round-trip.
- \[[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)\]
  retrieves the abstract and fuller metadata for one or many records
  from the ‘Scopus’ Abstract Retrieval API, resilient to an identifier
  that cannot be found. Through `view` and
  `include = c("references", "keywords")` it also retrieves a document’s
  own reference list, as a structured, per-citation data frame, and
  author keywords, with per-identifier caching keyed by the requested
  view and extras, an `n_requests`/`quota` attribute, and a clear,
  actionable error on an entitlement 403 that stops the batch, so the
  same failure is not repeated for every identifier.
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

The package gains a layer for summarising a literature and drawing the
result.

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
  already complete field-tagged expressions are used exactly as given,
  with no second wrap.
  \[[`plot_scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_intersections.md)\]
  draws the result as a lollipop chart on a log-scale axis, with an
  `autoplot()` method and an optional highlight (for example the niche
  itself) whose legend label is derived from what is highlighted: ‘Focal
  intersection’ for intersections, ‘Focal concept’ for concepts and
  ‘Focal set’ for a mixture. An explicit `highlight_label` still wins.
- \[[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)\]
  gains `legend_inside`. When set, and a legend is drawn, it is placed
  inside the panel in whichever corner has the most free space, on a
  small semi-transparent background, where the default places it above
  the panel. That default is unchanged.
- \[[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)\]
  now spreads the direct line labels vertically so topics that converge
  near the final year no longer overlap, and falls back to a legend when
  there are too many topics to label legibly. The labels are spread when
  the figure is drawn, against the rendered text height, so they stay
  legible at any figure size, including a short panel such as the app’s
  result card. They carry no leader lines. The labels are colour-matched
  to their lines and spread in the same order as the line ends, so the
  link is clear without a leader that would otherwise cut across
  neighbouring labels.

### Export

A retrieval can now leave the package in the formats other tools read.

- \[[`as_bibtex()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)\]
  and
  \[[`as_ris()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)\]
  export a record set to the BibTeX and RIS interchange formats, so a
  search can be carried into Zotero, EndNote, Mendeley or a LaTeX
  bibliography.

### A code-free app

The whole workflow is now available without writing any R.

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
  while a harvest is running, turns any comparison failure into a
  notification, floors a fractional maximum-records entry, drops
  duplicate comparison terms, and tells you when there is nothing to
  cancel.

### Other improvements

One rough edge in the package’s messaging was smoothed.

- The no-key error renders its guidance (the option name, the `api_key`
  argument and the key-request URL) through cli, where it used to leak
  raw markup.

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
- The `authors` column retains every author a record lists. Very large
  result totals are handled without overflow, and DOI cleaning copes
  with `www.doi.org` hosts and `DOI:` labels.
