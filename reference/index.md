# Package index

## Plan and size

- [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  [`is_scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  : Build a reproducible 'Scopus' search plan
- [`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
  : Build a field-tagged 'Scopus' query
- [`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
  : Count 'Scopus' results for a query
- [`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)
  : Recognised 'Scopus' field tags

## Retrieve

- [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  : Fetch 'Scopus' records for a query
- [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  : Execute a 'Scopus' search plan, with optional caching and resume
- [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
  : Retrieve abstracts and richer metadata
- [`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
  : Assemble a minimal, cross-tool corpus with keywords and references
- [`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md)
  : Managed cache directory for scopusflow
- [`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md)
  : Clear the scopusflow managed cache

## Records

- [`as_tibble(`*`<scopus_records>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  [`as.data.frame(`*`<scopus_records>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  [`autoplot(`*`<scopus_records>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  [`is_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  : Normalise raw 'Scopus' entries to a stable tidy schema
- [`summary(`*`<scopus_records>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/summary.scopus_records.md)
  : Summarise a set of 'Scopus' records
- [`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
  [`c(`*`<scopus_records>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
  : Combine record sets into one
- [`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md)
  : Parse 'Scopus' quota and rate-limit headers

## DOIs and change tracking

- [`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
  : Extract, clean and optionally export DOIs
- [`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
  : Compare two DOI retrievals

## Analyse and visualise

- [`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)
  : Annual publication counts for a query
- [`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
  : Most frequent values in a record set
- [`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
  : Compare publication trends across topics
- [`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)
  : Count a set of concepts and their intersections
- [`plot_scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md)
  [`autoplot(`*`<scopus_trend>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md)
  : Plot a publication trend
- [`plot_scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md)
  [`autoplot(`*`<scopus_top>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md)
  : Plot the most frequent values in a record set
- [`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
  [`autoplot(`*`<scopus_comparison>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
  : Plot a topic comparison
- [`plot_scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_intersections.md)
  [`autoplot(`*`<scopus_intersections>`*`)`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_intersections.md)
  : Plot concept and intersection sizes

## Export and I/O

- [`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)
  : Convert records to a bibliometrix-compatible data frame
- [`as_bibtex()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)
  [`as_ris()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)
  : Export records to BibTeX or RIS
- [`write_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)
  [`read_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)
  : Read and write 'Scopus' record sets

## App

- [`run_app()`](https://pablobernabeu.github.io/scopusflow/reference/run_app.md)
  : Launch the scopusflow app

## Keys

- [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)
  : Locate the 'Scopus' API key and institutional token

## Data

- [`example_records`](https://pablobernabeu.github.io/scopusflow/reference/example_records.md)
  : Example set of normalised 'Scopus' records
