# scopusflow 0.1.0

* Initial release.
* Reproducible search plans with [`scopus_plan()`], cheap sizing with
  [`scopus_count()`].
* Quota-aware, paginated retrieval via [`scopus_fetch()`] and resumable,
  cached, partitioned retrieval via [`scopus_fetch_plan()`].
* A stable normalised record schema via [`scopus_records()`].
* DOI extraction and change tracking with [`scopus_extract_dois()`] and
  [`scopus_diff_dois()`].
* Topic-trend comparison with [`scopus_compare_topics()`] and
  [`plot_scopus_comparison()`] / `autoplot()`.
* Interoperability and I/O: [`as_bibliometrix()`], [`write_scopus_records()`],
  [`read_scopus_records()`].
* Typed condition system (`scopus_error` and subclasses) and quota-header
  parsing with [`scopus_quota()`].
