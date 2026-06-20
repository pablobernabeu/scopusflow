# Changelog

## scopusflow 0.2.0

This release reaches further into the API and adds an analysis layer on
top of a retrieval.

- \[[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)\]
  gains `cursor = TRUE`, cursor-based pagination that retrieves a whole
  large query without the 5000-record ceiling of offset paging.
- \[[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)\]
  retrieves the abstract and fuller metadata for one or many records
  from the ‘Scopus’ Abstract Retrieval API, resilient to an identifier
  that cannot be found.
- \[[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)\]
  reports annual record counts for a query (the size of a literature
  over time), with
  \[[`plot_scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md)\].
- \[[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)\]
  tallies the most frequent sources or authors in a record set, with
  \[[`plot_scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md)\].
  An `autoplot()` method draws a record set’s publications per year.

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
