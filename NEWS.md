# scopusflow (development version)

## New features

* `scopus_fetch_plan()` gains `cursor`, so a plan cell matching more than 5000
  records can be retrieved whole and still be checkpointed. The default,
  `cursor = FALSE`, keeps the offset paging plans have always used. Checkpoints
  now record the paging mode and serve only a request in the same mode, and one
  written before the mode was recorded counts as offset-paged. A checkpoint in
  the other mode is refetched with a warning that names both modes. Inside a
  plan, the warning for a cell that stops at the offset ceiling now names
  `scopus_fetch_plan(plan, cursor = TRUE)`. It used to advise partitioning by
  year, which a year-partitioned plan already does. The search record's
  reproduction snippet passes `cursor = TRUE` when the records were paged by
  cursor. The Python twin's `fetch_plan()` gains `cursor` too, and keeps the
  cursor paging it has always used unless given `cursor=False`.
* `scopus_fetch()`, `scopus_fetch_plan()` and `scopus_records()` gain
  `fields = "extended"`, adding the document type, source type, volume, issue,
  pages, ISSN, PubMed identifier and open-access status the Search API already
  returns, and the abstract under the `COMPLETE` view, at no extra quota.
  `summary()` reports how many records 'Scopus' labels errata or retracted, and
  the help pages explain why those labels do not screen a set for retractions.
  Checkpoints record their fields. An extended checkpoint serves a core request
  with the extra columns dropped. A core checkpoint is a miss for an extended
  request and is refetched with a warning. `read_scopus_records()` keeps the
  extended columns of a `.csv` file, as text apart from the integer
  `open_access`, so an ISSN keeps its leading zeros. The default,
  `fields = "core"`, returns the columns it always has. The Python twin's
  `fetch_plan()` and `to_records()` gain `fields` too.
* With `fields = "extended"`, `as_ris()` and `as_bibtex()` type conference
  papers, conference reviews, chapters and books by the document type 'Scopus'
  gives them (RIS `CPAPER`, `CONF`, `CHAP` and `BOOK`, BibTeX `@inproceedings`,
  `@incollection` and `@book`), where every record used to be a journal
  article. The entries carry the volume, issue, pages, ISSN and document type,
  and under `view = "COMPLETE"` the abstract, which screening and
  de-duplication tools read. A `COMPLETE` set also exports its author keywords,
  one RIS `KW` line each, with or without the extended fields. A value the
  record lacks is left out. The Python twin's `to_ris()` and `to_bibtex()` do
  the same, held to a shared golden file.
* `scopus_abstract(include = "index_terms")` returns the index keywords
  'Scopus' assigns, in an `idxterms` column joined by `"; "`, under
  `view = "FULL"`. `scopus_corpus()` can use them, alone or with the author
  keywords, through its new `keywords` argument, `"index"` or `"both"`, and
  refuses either under `view = "REF"` before any request. The default,
  `keywords = "author"`, keeps the author keywords alone. 'Scopus' chooses
  index keywords from standard vocabularies, so they give different
  co-occurrence results from author keywords, and whether they arrive depends
  on the key's entitlement. In development testing, they arrived on a key whose
  author keywords came back empty. The Python twin's `scopus_abstract()` and
  `corpus()` gain the same options.
* `write_scopus_corpus()` writes a `scopus_corpus()` result in theoryforge's
  corpus schema, keying cited works on the 'Scopus' identifier so the same
  work is one node however its DOI is written. `as_theoryforge_corpus()`
  returns the same document as a list. A reference that carries only a DOI
  takes the identifier that another document or reference in the corpus pairs
  with that DOI, and one with neither is dropped with a warning. Keywords are
  trimmed, lower-cased and made unique, and a missing year is written as
  `null`. Keyed on the DOI wherever there was one, as theoryforge's own recipe
  did, two documents citing the same two works gave no co-citation edge. A
  `provenance` block records the search expression, when the search ran, the
  kind of keyword and how many references were dropped and records came
  without keywords. The Python twin's `write_corpus()` and
  `to_theoryforge_corpus()` write the same bytes, held to a shared golden file
  and validated against a copy of theoryforge's schema.
* `scopus_diff_records()` compares two harvests record by record, matching on
  the 'Scopus' identifier and, where a record lacks one, on the DOI, as
  `scopus_combine(dedupe = TRUE)` matches records. Each row gives the record's
  citation counts in both harvests beside its status, identifier, DOI, title
  and year. A record in one harvest only whose DOI the other harvest gives to
  a different record is marked `conflict` for you to check, since it may have
  been re-indexed under a new identifier or may be a distinct paper sharing
  the DOI. Records with neither key are counted and left out. The Python
  twin's `diff_records()` returns the same rows, held to a shared fixture.

## Changed behaviour

* `scopus_corpus()` now reports the requests it made and the quota left, in
  the `n_requests` and `quota` attributes, as the Python twin does, and both
  twins return each document's 'Scopus' identifier in a new `scopus_id`
  column, the second. It comes from Abstract Retrieval, or from the records
  where the lookup failed. Code that selects the corpus's columns by position
  needs updating. The result also carries the search expression, when the
  search ran and the kind of keyword, as the attributes `query`,
  `retrieved_at` and `keywords`, which `write_scopus_corpus()` records.

* Input errors now inherit `scopus_error`, as the package has always documented.
  `scopus_error_bad_input` was raised on its own, so `tryCatch(scopus_error = ...)`
  let a blank query or an out-of-range year through. Invalid `view`, `partition`,
  `by`, `.op` and `style` values now raise `scopus_error_bad_input` too, where they
  were bare `rlang_error` conditions with the same message. A retry loop keyed on
  `scopus_error` should test the subclass, since an input error will not succeed on
  retry.
* `scopus_abstract()` now requests `view = "META_ABS"` by default, the view
  Elsevier documents as carrying the abstract, as the Python twin does. It used to
  send no view and so took the API's default, which Elsevier documents as META, a
  view without the abstract. A live request in October 2026 nonetheless returned
  the abstract without a view, so earlier default calls may well have carried it.
  The column no longer depends on behaviour the documentation contradicts. Pass
  `view = NULL` to send the old request. A default call's checkpoints are now
  keyed `META_ABS`. A cache written by 0.4.0 for a call without a view therefore
  serves only `view = NULL`, and a default call spends a request on each of its
  identifiers again.
* Queries are checked offline before any request. `LIMIT-TO()` and `EXCLUDE()`
  refinement syntax pasted from the web interface, a field tag wrapped around a
  query that already opens with one, and unbalanced brackets, quotation marks or
  braces now raise `scopus_error_bad_input` in `scopus_plan()`, `scopus_count()`,
  `scopus_fetch()`, `scopus_trend()`, `scopus_compare_topics()` and
  `scopus_intersections()`. The Search API ignores a refinement without an error,
  so such a search ran unfiltered. A nested field tag failed with HTTP 400 after
  spending a request, and unbalanced brackets reached the API unchecked.
  `INDEXTERMS()`, which pybliometrics documents as not working through the Search
  API, raises a `scopus_warning_query_syntax` warning. The messages match the
  Python twin's word for word. Given `.field`, `scopus_query()` now refuses a
  term that already opens with a field tag, where
  `scopus_query("TITLE(x)", .field = "ABS")` used to give `ABS(TITLE(x))`.
  `scopus_intersections()` uses a concept written as the web interface writes a
  tag, `TITLE-ABS-KEY ( x )`, as given, where it used to wrap it in `field` a
  second time.
* RIS records put the source title under `T2`, which reference managers read as
  the publication title, instead of `JO`, which Zotero reads as the journal
  abbreviation, and now carry `DB  - Scopus` and the EID as `AN`.
* `as_bibliometrix()` follows the conventions `bibliometrix::convert2df()`
  applies to a 'Scopus' export, so its frame describes a record as a 'Scopus'
  CSV import does. `AU` gives each author as the surname and initials without
  full stops (`"ZHANG F"`, where it held `"ZHANG F."`), joined by `";"`, and a
  `COMPLETE` name such as `"Tour, James M."` becomes `"TOUR JM"`. `UT` holds
  the upper-cased EID, `"2-S2.0-<scopus_id>"`, where it held the bare
  identifier, which `sub("^2-S2.0-", "", UT)` restores. A set carrying author
  keywords gains `DE`, and one retrieved with `fields = "extended"` gains `DT`,
  `VL` and `IS`.
* Requests are retried after transport failures such as timeouts and connection
  resets, which httr2 stopped doing by default in 1.0.4, so one such failure no
  longer aborts a harvest. scopusflow now requires httr2 1.0.4 or later. A
  timeout is reported as such, with the class `scopus_error_timeout` (a subclass
  of `scopus_error_offline`), and no longer as being offline.
* De-duplication in `scopus_combine()` now cleans DOIs as
  `scopus_extract_dois()` does (resolver prefixes, case) and matches a record
  without a 'Scopus' identifier to the identified record carrying the same DOI.
  Records with different identifiers and one DOI are still both kept, since
  'Scopus' also gives one DOI to distinct papers, and the merge now counts them
  for you to check. The `combined` attribute records the rule as `rule` and the
  DOIs such records share as `doi_conflicts`, and PRISMA-S item 16 of the search
  record names the rule and gives the count. `dedupe = "id_or_doi"` merges
  records with different identifiers that share a DOI, and
  `dedupe = "id_then_doi"` reproduces the earlier rule. A set merged by 0.4.0
  records no rule and keeps its item 16 wording. A blank identifier, which
  `read_scopus_records()` reads from a CSV file the Python twin wrote, now
  counts as none, where every record carrying one was merged into one record.
  `dedupe` refuses a value other than `TRUE`, `FALSE` or the name of a rule,
  where `NA` or any other value meant no de-duplication.

## Bug fixes

* The app's search record no longer gives the bundled corpus's own phrase as
  the search expression of a demo harvest, in a methods paragraph written to be
  pasted into a manuscript. In demo mode the record now names no expression,
  and it opens by saying that the records were replayed and that it describes
  no search that was run. Where the records came from is fixed when the harvest
  starts, so switching Demo mode afterwards does not change the record. The
  Python app does the same.
* The app's Check size button no longer closes the session on a blank query. The
  handler caught `scopus_error` alone, so the input error escaped it and Shiny
  ended the session. Check size and Fetch now refuse a blank query with a
  notification, as Compare and the Python app already did, and any other failure
  in Check size is shown as a notification.
* `scopus_compare_topics()` joined the reference and each comparison term
  without brackets, so a reference containing OR or AND NOT was regrouped by the
  operator precedence of 'Scopus'. Under the documented order, which applies AND
  NOT last, an AND NOT reference took the term into its negation, so the
  comparison set could exceed the reference and shares passed 100%. The join is
  now `(reference) AND (term)`, as `scopus_intersections()` already wrote it.
  Re-run comparisons whose reference contains OR or AND NOT.
* `scopus_query()` now brackets each term of several words when it joins two or
  more terms without a field tag, since 'Scopus' joins the words of an unquoted
  term with AND. `scopus_query("machine learning", "deep learning", .op = "OR")`
  used to give `machine learning OR deep learning`, which reads as
  `machine AND (learning OR deep) AND learning`. Quoted and braced phrases,
  bracketed groups and single field-tagged groups are left as written, and
  single words are never bracketed, so
  `scopus_query("CRISPR", "Cas9", .op = "OR")` is unchanged. Terms are also
  trimmed of the white space the Python twin trims, no-break spaces included.
* A reference list that arrives as a single bare object, which is how
  Elsevier's JSON sends a one-item array, no longer aborts the whole
  `scopus_abstract()` or `scopus_corpus()` batch, and every resume of it, with an
  untyped "subscript out of bounds" error. Neither does a cited work whose
  author list arrives that way. Any other shape the keyword or reference parser
  cannot read is now handled as a malformed response (`scopus_error_malformed`).
  That identifier gets a row of `NA`s and a warning and is retried on resume,
  while the rest of the batch completes. A lone author-keyword entry that carries
  no text, such as `{"@_fa": "true"}`, no longer becomes the keyword "true".
* The `authors` column held only the first author. The Search API's
  `dc:creator` field is the first author alone, and the author list exists only
  under `view = "COMPLETE"`, where scopusflow ignored it. Under `COMPLETE` the
  column now lists the authors as `"Surname, Given"`, joined by `"; "` (up to the
  API's 100 per record), so author tallies, `as_bibliometrix()` and the BibTeX
  and RIS exports see every author. Under `STANDARD` it still holds the first
  author, and `scopus_top(by = "author")` and `as_bibliometrix()` now say so once
  per session, as a note on the app's Top authors tab does. Retrievals record
  their view as the `view` attribute, which a combined set keeps where its parts
  agree. `COMPLETE`-view checkpoints written by earlier versions are refetched
  once, and `STANDARD` ones are served as before. This corrects the 0.1.0 entry,
  which said the column retained every author a record lists.
* Under `view = "REF"`, `scopus_abstract()` returned only the first page of a
  reference list, about 40 references, which the documentation blamed on the API.
  It now follows `startref` until the list is complete, as pybliometrics does, at a
  cost of one request per 40 references, and `n_requests` counts each page. A
  REF reference's title and source are now read, where both were always `NA`.
  REF cache files are keyed `REF-paged`, so truncated ones written by 0.4.0 are
  refetched once. This reaches `scopus_corpus(view = "REF")` too.
* BibTeX and RIS exports wrote names in the 'Scopus' form "Surname I.", with no
  comma, so BibTeX and biber took the initials for the family name and sorted
  bibliographies by them, and Zotero kept each RIS author as a single field.
  This touched every export of records retrieved outside `COMPLETE`. A name
  ending in initials is now written "Surname, I.", and BibTeX titles protect
  words such as CRISPR-Cas9 and DNA from lower-casing. BibTeX also spaces
  run-together initials ("J. R."), which it would otherwise read as one given
  name. The `authors` column and the citation keys are unchanged.
* A spent weekly quota is no longer treated as a transient rate limit. Elsevier
  answers both with HTTP 429, and a response marked `QUOTA_EXCEEDED` now raises
  `scopus_error_quota_exceeded` (a subclass of `scopus_error_rate_limit`) naming
  the reset time, and is not retried. It stops a `scopus_abstract()` or
  `scopus_corpus()` batch with the rows already retrieved kept, an `NA` row for
  each identifier not retrieved and one `scopus_warning_quota_exceeded`
  warning. Every remaining identifier used to be tried three times and become an
  `NA` row with a warning of its own. The 403 message no longer blames the
  quota, and `Retry-After` dates parse in any locale, where a German or French
  `LC_TIME` made every one `NA`. `scopus_quota()` documents `reset` as the time
  the key's quota resets, not a rate-limit window.
* The search record dated a harvest by its earliest cell, although PRISMA-S
  item 13 asks for the date of the last search. Retrievals now carry
  `retrieved_until` beside `retrieved_at`. For the harvest of a plan, or a set
  from `scopus_combine()`, it holds the latest of its parts' times, as
  `retrieved_at` holds the earliest. A search run over several sessions, or a
  baseline merged with its update, is now dated from its first retrieval to
  its last, item 13 gives the date of the last search, and the methods
  paragraph says the literature was searched between the two dates. Stamps on
  one UTC day give the single date they always gave.
* A set without a plan no longer says "no year limit" when its limit is only
  unrecorded, and no longer lists item 8 of PRISMA-S as supplied.
  `scopus_fetch()` now attaches the one-cell plan it ran, so its record states
  the field tag and the years. A one-cell plan supplied for a set without
  per-cell counts keeps the set's own counts, which the record used to call
  unrecorded. Year cells with gaps between them are listed, as in "2015, 2020
  and 2025", where the record gave one span that claimed the years between.
  Item 2, on databases searched together on one platform, is now supplied,
  since the API searches Scopus alone.
* A harvest capped by `max_results` is now recorded as capped: the search
  record names the cap in the cells, the completeness line and item 9, the
  reproduction snippet passes it, and `autoplot()` says the bars count
  retrieved records. The app no longer caps live harvests at 200 records per
  year by default. Its field, now labelled "Max records per cell", starts
  blank, and a note in the Retrieval panel says when the cap stopped a cell.
  `scopus_fetch()` and `scopus_fetch_plan()` keep a finite cap as the
  `max_results` attribute, which the record reads.
* Closing one tab of the app deleted every other tab's checkpoints
  mid-harvest, because the app kept its checkpoints by search alone and each
  session's end removed the directory all sessions shared. Each session now
  keeps them in a temporary directory of its own, removed when that session
  ends, and a search fetched again in the same tab, after Cancel or a failure,
  resumes from them. The app article no longer promises that a quota-limited
  run picks up where it left off, which the temporary directory never allowed
  across sessions, and points to the generated script for a harvest that has
  to outlast the session.
* The script the app writes passed `scopus_cache_dir()` itself to every plan,
  so one plan's checkpoints overwrote another's and each rerun paid for them
  again. It now keeps each plan's checkpoints in a directory of their own
  under `scopus_cache_dir()`, named from the query and the years with a short
  hash added. The script opens with the scopusflow version that wrote it,
  notes when demo mode was on, saves the records before it plots and plots
  only where ggplot2 is installed. A comparison run with Partition by year off,
  which covers the last six years, was left out of the script and is now
  written over those years. The README and the articles likewise give each
  plan a directory of its own under `scopus_cache_dir()`.
* The request count of a topic comparison was understated in the help for
  `scopus_compare_topics()`, the app, the generated script and two articles.
  It is (terms + 1) × years, since the reference is counted in every year
  too, so the app's default of two terms over six years makes 18 requests,
  where its note said 12. The app's advice to use fewer terms or years now
  applies above 80 requests counted this way.
* The app's Records tab now says how many records the harvest holds and that
  its table shows the first 25 of them. A failed harvest is reported in the
  worker's own words, where the notification opened with the "in callr
  subprocess" wrapper of the background process, and an error raised by
  scopusflow is marked "Scopus:", as the other panels mark theirs. The year
  slider opens on 2015 to 2024, the span of the bundled corpus that demo mode
  replays, as the Python app's slider does. The app reads that corpus as
  `scopusflow::example_records`, so demo mode works when the app is launched
  as `scopusflow::run_app()` without attaching the package, where Check size
  and Fetch records failed with "object 'example_records' not found".
* `scopus_diff_dois()` now says how many records it could not compare for want
  of a DOI, in the attributes `n_old_without_doi` and `n_new_without_doi` and
  on its printed line. Such records, 11 of the 138 in the bundled corpus, used
  to vanish from the diff without a count. It also orders its rows the same
  way on every machine, in byte order as the Python twin does, where it
  followed the locale's collation and an English locale put `10.1016/j.cell`
  before `10.1016/S0140`. The tracking article advised preferring the 'Scopus'
  identifier, which no function supported, and now points to
  `scopus_diff_records()`.
* A `cache_dir` that cannot be written is now refused with
  `scopus_error_bad_input` before any request, in `scopus_fetch_plan()`,
  `scopus_abstract()` and `scopus_corpus()`. A checkpoint that cannot be
  written all the same, for example on a full disk, gives a
  `scopus_warning_cache_unwritable` warning, and its records are kept in the
  result. Both used to spend the cell's quota and then lose its records to an
  untyped "cannot open the connection" error. The `scopus_cache_clear()`
  example no longer deletes a real managed cache when the examples are run,
  since it now points the cache at a temporary directory first.

## Documentation

* The help for `scopus_count()`, `scopus_fetch()`, `scopus_intersections()`
  and `scopus_plan()` now says how `years` is sent. These functions, and a plan
  with `partition = "none"`, send one inclusive range from the earliest year to
  the latest, so `c(2015, 2020)` covers every year from 2015 to 2020.
  `scopus_trend()`, `scopus_compare_topics()` and a plan with
  `partition = "year"` take each listed year.
* `citation("scopusflow")`, the website and `CITATION.cff` give the DOI that
  CRAN assigned to the package,
  <https://doi.org/10.32614/CRAN.package.scopusflow>, in place of the Zenodo
  concept DOI. It names the R package across all its versions, and it is the
  DOI that the CRAN page and the citation R generates for a CRAN package
  already gave, so the package no longer circulates under two. Zenodo still
  archives every GitHub release, and `CITATION.cff` lists both identifiers.
  The CRAN DOI and the Zenodo DOI are shown as full links on the website and in
  the README, and the sidebar of the home page shows the CRAN DOI once: the DOI
  badge in the README no longer appears there a second time.
* The README no longer names the version CRAN carries. The README inside the 0.4.0
  tarball said CRAN carried 0.1.0, because the figure was typed by hand and a README
  is built before CRAN accepts a submission. The installation section now points to
  NEWS for what each release added.
* The spelling test now fails a check run with `NOT_CRAN` set, as in
  `devtools::check()` and on GitHub Actions, where an unknown word used to surface
  only as a NOTE that left the run green. CRAN and a plain `R CMD check` still skip
  the test. The word list gains the twelve names and terms that had slipped past it.
* The designing-queries article explains loose and exact phrases, and replaces
  its spelling-variant example, which 'Scopus' matches without help, with two
  phrases naming one condition. It also shows why a query written by hand that
  mixes operators needs brackets, under both the documented operator order and
  the one Elsevier has announced.
* The designing-queries article describes the offline query checks and gives a
  recipe for testing a strategy's relative recall against records known to be
  relevant, with two searches per chain of DOIs (Sampson et al., 2006; Bramer et
  al., 2018). The recipe contacts the API and is not run in the article.
* The worked examples no longer present `TITLE-ABS-KEY(graphene supercapacitor)`
  as the search behind the bundled corpus. The corpus came from OpenAlex's
  exact-phrase search for "graphene supercapacitor" in titles and abstracts,
  limited to journal articles. 'Scopus' joins the words of an unquoted phrase
  with AND, so that query is far broader, and in OpenAlex the unquoted words
  match about a hundred times as many records. The demonstration plan and the
  live searches shown beside the corpus now quote the phrase, and the help for
  `example_records` names the query the examples send. The tracking article
  says that a live comparison needs a baseline of your own, since the bundled
  one came from OpenAlex. The PRISMA-S demonstrations label their hand-set
  attributes, the reported totals among them, as illustrative and say that the
  paragraph they print describes no search that was run.
* The keywords-and-references article no longer prints invented author
  keywords, four references for a paper that cites 103 works, authors in a form
  the parser never writes and an invented quota beneath real calls on a real
  DOI. The calls are shown without output, the shapes they return are built in
  view from `example_records`, and keyword stand-ins drawn from its 138 titles
  are counted in pairs, as in the Python guide.

# scopusflow 0.4.0

A release about reporting a search and about trusting the cache. The package now
writes a search up as the reproducible record a systematic review has to publish,
and a family of silent cache defects that served the wrong records is fixed.

## Writing up a search

* `scopus_search_report()` assembles the reproducible search-strategy record a
  systematic review has to report, from a harvest or from a plan not yet run. It
  prints as a readable report, formats as a methods paragraph fit to paste into a
  manuscript (`format(report, style = "paragraph")`), and writes as Markdown when
  `file` is supplied. It carries the database and platform, the field-wrapped
  query of every cell, the year limits, view, page size and paging mode, the date
  searched, the records retrieved against the number the API reported as matching,
  per-cell completeness, duplicates removed, the software versions, a runnable
  snippet that rebuilds the plan, and an explicit map of which PRISMA-S items the
  package can supply and which only you can. The reporting standard is PRISMA-S
  (Rethlefsen et al., 2021, Systematic Reviews, 10, 39), with the identification
  counts of the PRISMA 2020 flow diagram.

  Because the output is written for a published methods section, the report states
  only what the objects record. An absent retrieval time is never replaced by the
  current one, a completeness figure is never given for a harvest whose reported
  total is unknown, duplicates are counted only where a merge recorded removing
  them, and every unverifiable field says it is unrecorded, in words. Ten of the
  sixteen PRISMA-S items, among them peer review of the strategy, grey literature
  and any other database searched, are listed as yours to supply, since the
  package has no evidence for them.

* `scopus_fetch_plan()` now carries the per-cell accounting onto its result, as
  the `cell_totals` attribute, and sums it into `total_results` when (and only
  when) every cell reported a total. A cell that comes back shorter than the API
  said it should now warns, which the Python twin has done since 0.3.0, and the
  warning text is byte-identical between the two. A cell stopped by `max_results`
  is short by request and does not warn.

* `scopus_combine()` records the merge in the `combined` attribute: how many
  records went in, how many were kept, how many were removed and whether
  de-duplication ran. That count exists only at the moment of the merge, and
  PRISMA-S asks for it.

* A retrieval also records how it was paged, as the `paging` attribute, since an
  offset-paged query stops at the API's ceiling where a cursor-paged one does not.

## Cache defects that returned the wrong records

All were silent, and all are fixed.

* A year-partitioned plan could be served another plan's years, because checkpoints
  were keyed by the cell's position alone and every cell of such a plan carries the
  same query (the year travels separately, as the API's `date` parameter), so the guard
  meant to reject a foreign checkpoint could not tell 2015's from 2016's. A plan over
  2016:2017 pointed at a cache written by a plan over 2015:2016 returned the 2015
  records and reported "loaded from cache". Checkpoints are now named
  `cell-NNN-YYYY.rds` and carry a manifest (query, date, view, page size and record
  cap) that resume compares against. Existing caches become invisible and refetch once,
  which spends a little quota to buy back correctness.
* A cell cached under a `max_results` cap was served to a later request asking for
  more. The manifest now records the cap and whether it actually bit, so a truncated
  checkpoint is a miss for a wider request while an untruncated one stays usable for any
  request. The Shiny app's cache key gained the record cap and now hashes the query,
  where it used to truncate it at 80 characters, so two long queries sharing a prefix no
  longer share a directory.
* A zero-row checkpoint answered for any query. The guard that recognises a foreign
  checkpoint reads the cached rows' `query` column, which an empty cell has no rows to
  carry, and the manifest comparison never consulted its own copy of the query, so a
  plan that legitimately found nothing left a checkpoint that a different plan pointed
  at the same `cache_dir` would load as its own empty result. The manifest's query must
  now match as well.
* A failed abstract retrieval was checkpointed as if it were data. A rate-limited,
  server-error or offline attempt in `scopus_abstract()` degrades to an all-NA row so
  the batch survives, but that row was written to the cache, so a resumed run read the
  failure back from disk and never retried it. Only rows parsed from successful
  responses are checkpointed now.
* Two identifiers could share one abstract checkpoint, because the cache filename
  reduces every non-alphanumeric character to `_`, so distinct identifiers such as
  `10.1/a.b` and `10.1/a-b` collide on the same file, and resume never asked which
  identifier a cached row belonged to. The cached row's own id must now match, and a
  collision warns and refetches.
* A checkpoint holding more records than the current `max_results` asks for is now
  served trimmed to that cap, with the fuller set left on disk for a later, wider
  request. The opposite direction, a checkpoint truncated below what is asked for,
  already refetched with a warning.

A rejected or damaged checkpoint now warns, where it used to be mentioned only under
`verbose`, and checkpoints are written to a sibling temporary file and renamed into
place, so an interrupted run can no longer leave a half-written file that breaks every
later resume.

## Other fixes

* `scopus_combine()` handed the merged set one input's own retrieval attributes.
  `rbind()` keeps those of its first argument, so the result inherited that harvest's
  `plan`, `cell_totals` and `total_results` even though it held the rows of several,
  contradicting the documented promise that per-retrieval attributes are not carried
  over. A search record read off the inherited total then called the union of two
  harvests complete against a figure belonging to one of them. Only what survives a
  merge is kept now: the earliest retrieval time, every contributing version, the
  paging mode where the inputs agree, and the merge counts themselves.
* The PRISMA 2020 identification block counted the records identified after
  de-duplication, so the two figures it gives could not both be right: the diagram
  subtracts the duplicates removed from the records identified to reach the records
  screened, and 138 identified less 11 removed is not the 138 rows the set holds. Where
  a merge recorded how many records went into it, that is now the identification count.
* A plan not yet run was described in the past tense, and its date line said the set did
  not carry a retrieval time, when the truth was that no retrieval had happened.
* `average_comparison_percentage` summed the numerator over years the denominator
  excluded, so a year with a missing reference count inflated it, giving a figure that
  contradicted the per-year shares printed beside it and that drives the topic ordering
  in `plot_scopus_comparison()`. It is now computed over the years where both counts are
  available.
* `scopus_abstract(include = "references")` aborted the whole batch when one document's
  response omitted its reference-count attribute. Because that arrived as a bare base
  error, untyped and so outside the `scopus_error` hierarchy, the per-identifier handler
  could not catch it, defeating the documented promise that one bad identifier does not
  lose a batch.
* The app's demo banner still called the demo data synthetic, which was true of the
  six invented rows that shipped before 0.3.0. Demo mode has replayed 138 real
  published articles since then, and only the topic comparison is simulated, so the
  banner now says which is which.
* A record count past 2^31 was coerced to `NA` at three points, each of which
  accepted any finite whole number and then reached for a 32-bit integer. `scopus_top(n = )`
  left `head.data.frame()` raising an untyped error about its own argument;
  `scopus_fetch(max_results = )` and `scopus_fetch_plan(max_results = )` turned every
  later `n >= max_results` into `NA`, so the retrieval died on a bare "missing value
  where TRUE/FALSE needed"; and the app's reproducible-code panel wrote
  `max_results = NA` into a script it promises is runnable. All three now carry the
  value as a double, so a cap wider than the result set simply never bites, which is
  what the Python twin has always done. A cap that fits stays an integer.
* The 5000-record cap warning fired even when `max_results` had already asked for fewer
  records than the ceiling, advising a remedy for a problem the caller did not have.
* `scopus_compare_topics()` carries its counts as doubles, matching `scopus_trend()` and
  `scopus_intersections()`, so billion-scale totals no longer coerce to `NA`.
* Every request carries a 60-second transfer timeout, tunable through
  `getOption("scopusflow.timeout")`, so a stalled connection cannot hang a session.
* Retrievals record when they were taken and by which package version, as the
  `retrieved_at` and `scopusflow_version` attributes, preserved through the `.rds` round
  trip. Both are attributes, so the documented schema and the CSV round trip are
  unchanged.
* Every text file the package writes now carries LF line endings on all platforms: the
  BibTeX and RIS exports, the DOI and record CSVs, and the app's script and comparison
  downloads previously arrived with CRLF endings when written on Windows.
* Every `print()` method now sends its whole output to standard output. The header line
  went through cli, which writes to the message stream, so `capture.output()` returned
  the table without its header, and a knitted document showed one printed object as two
  separate blocks.

## Continuous integration and metadata

* The dependency canary could finish green having exercised nothing, when no
  development head was actually installed. It now says so, in a warning and in the step
  summary, and it installs the ggplot2 development head alongside the Imports.
* The declared dependency floors are now installed and tested by a `min-deps` job, and
  the check matrix reaches back to roughly R 4.3.
* `rlang`'s floor is corrected to 1.1.0. The evidence for it is httr2 1.0.0's own
  DESCRIPTION, which requires `rlang (>= 1.1.0)`, so the old floor described a
  combination no user could have installed. It is CRAN-visible metadata.
* The documented request cost of the live API check, the cache guard's description in
  the documentation and vignette, and the path to the Python twin's copy of the example
  records were all corrected.

# scopusflow 0.3.0

A data and documentation release. The bundled corpus becomes a real harvest, and
every example and article is rebuilt on it.

## The bundled example records

The dataset the package ships for offline work was replaced outright.

* `example_records` is now a worked example harvest of 138 real journal articles
  on graphene supercapacitors published between 2015 and 2024, carrying their
  real titles, DOIs, source titles, first authors and citation counts. It
  replaces the six invented records shipped previously.
* The records are not a 'Scopus' harvest and are not described as one. The
  Elsevier API terms do not permit redistributing retrieved records, so they come
  from OpenAlex, whose metadata is released under CC0, reshaped into the schema
  [`scopus_fetch()`] returns. The reasoning is recorded in the design notes.
* The harvest is complete, so the rows per year are the real publications per year
  for that query. Eleven records carry no DOI and two no source title, kept as they
  arrive because a real harvest has such gaps.
* `scopus_id` is empty throughout, these records not having come from 'Scopus',
  so de-duplication falls back to the DOI as it does for any record whose
  identifier is missing.

## Documentation

The material a reader meets was rebuilt on the new corpus, and one misleading
fixture was replaced.

* Every vignette and example runs on that corpus, paired with the key-gated live
  call a reader would write, and the figures quoted in the prose were
  recomputed against the new data.
* The demo mode of `run_app()` draws on the same corpus, so a first look at the
  app opens on real articles, where it used to show invented rows.
* The parser fixture in `inst/extdata` moves onto the reserved 10.5555 example
  prefix. It previously paired genuine, resolving DOIs with invented titles and
  authors, so a reader who checked one found a real paper mislabelled.
* Every vignette now turns console colour off and fixes the console width while
  it renders. pkgdown enables colour for its own build, and the escape sequences
  were reaching the reader as literal text in the middle of the tables.
* `vignette("comparing-topics")` shows one year of its illustrative comparison
  across every topic, in place of the whole table, and leaves out the `query`
  column, which in a real comparison holds the whole query string and so reads
  badly in a table.
* The README no longer opens with a link to the documentation site, which on the
  site's own home page pointed the reader at the page in front of them.

# scopusflow 0.2.1

A documentation release. The vignettes now demonstrate several features that
0.2.0 shipped but did not show.

* `vignette("designing-queries")` shows the `AND NOT` operator in
  [`scopus_query()`], excluding a dominant homonym from a search.
* `vignette("analysing-a-literature")` passes [`scopus_intersections()`] a
  concept that is already a complete field-tagged expression and so is used as
  given, letting a concept be a whole synonym set.
* `vignette("scopusflow")` introduces [`scopus_top()`] on a record set, and
  points to the analysis article for the plots and trends built on it.
* `vignette("plans-and-quota")` covers `verbose = TRUE` in
  [`scopus_fetch_plan()`], which reports a line as each cell is fetched or
  loaded from cache.
* `vignette("building-a-reference-set")` shows [`scopus_extract_dois()`] on a
  plain vector of DOIs, both with the default deduplication (which ignores case
  and resolver prefixes) and with `dedupe = FALSE`.
* `vignette("keywords-and-references")` tallies author keywords across a
  [`scopus_corpus()`] result, the per-keyword document count the article is
  named for.
* [`scopus_abstract()`]'s help page no longer describes the Python twin's
  reference fields.

# scopusflow 0.2.0

This release reaches further into the API, adds an analysis and export layer on
top of a retrieval, and introduces a local, code-free app.

## Deeper retrieval

A search now reaches further into the API, past the offset ceiling and beyond
the fields the Search endpoint returns.

* [`scopus_fetch()`] gains `cursor = TRUE`, cursor-based pagination that
  retrieves a whole large query without the 5000-record ceiling of offset
  paging. The warning on a query that exceeds the ceiling suggests this
  alongside partitioning with [`scopus_plan()`].
* [`scopus_fetch()`] and [`scopus_fetch_plan()`] add an `authkeywords` column
  when `view = "COMPLETE"` is requested, at no cost beyond that view's own
  smaller page size. The `view = "STANDARD"` output is unchanged, and
  [`read_scopus_records()`] keeps the column across a CSV round-trip.
* [`scopus_abstract()`] retrieves the abstract and fuller metadata for one or
  many records from the 'Scopus' Abstract Retrieval API, resilient to an
  identifier that cannot be found. Through `view` and `include =
  c("references", "keywords")` it also retrieves a document's own reference
  list, as a structured, per-citation data frame, and author keywords, with
  per-identifier caching keyed by the requested view and extras, an
  `n_requests`/`quota` attribute, and a clear, actionable error on an
  entitlement 403 that stops the batch, so the same failure is not repeated for
  every identifier. `include = "keywords"` without `view = "FULL"` is rejected
  up front, since the `REF` response carries no author keywords.
* [`scopus_corpus()`] combines a search result with abstract retrieval into a
  minimal `id`/`title`/`year`/`keywords`/`references` shape for downstream
  tools such as keyword co-occurrence or citation-network analysis, without
  replacing [`as_bibliometrix()`]. A new vignette, *Author keywords and
  references*, walks through all of this with real DOIs.
* [`scopus_fetch_plan()`] compares each checkpoint's recorded query with the
  plan cell before loading it, refetching and overwriting the checkpoint on a
  mismatch, so two different plans pointed at the same `cache_dir` cannot
  serve each other's records. A checkpoint that carries no query information
  (a zero-row cell, or one written by scopusflow 0.1.0) loads as before, and a
  cache directory is still best kept to a single plan.

## Analysis and plots

The package gains a layer for summarising a literature and drawing the result.

* [`scopus_trend()`] reports annual record counts for a query (the size of a
  literature over time), with [`plot_scopus_trend()`].
* [`scopus_top()`] tallies the most frequent sources or authors in a record
  set, with [`plot_scopus_top()`], which draws whole-number axis breaks (so a
  tally of small counts shows no fractional ticks) and derives the count
  axis's headroom from the widest end-of-bar label (so a wide count, say five
  figures on a top-authors bar, does not clip at the panel edge). An
  `autoplot()` method draws a record set's publications per year.
* [`scopus_intersections()`] counts a named set of concepts and any requested
  intersections of them, sizing where a study or a niche sits within the
  surrounding literature at one count request per row. Concept values that are
  already complete field-tagged expressions are used exactly as given, with no
  second wrap. [`plot_scopus_intersections()`] draws the result as a
  lollipop chart on a log-scale axis, with an `autoplot()` method and an
  optional highlight (for example the niche itself) whose legend label is
  derived from what is highlighted: 'Focal intersection' for intersections,
  'Focal concept' for concepts and 'Focal set' for a mixture. An explicit
  `highlight_label` still wins.
* [`plot_scopus_comparison()`] gains `legend_inside`. When set, and a legend is
  drawn, it is placed inside the panel in whichever corner has the most free
  space, on a small semi-transparent background, where the default places it
  above the panel. That default is unchanged.
* [`plot_scopus_comparison()`] now spreads the direct line labels vertically so
  topics that converge near the final year no longer overlap, and falls back to
  a legend when there are too many topics to label legibly. The labels are
  spread when the figure is drawn, against the rendered text height, so they
  stay legible at any figure size, including a short panel such as the app's
  result card. They carry no leader lines. The labels are colour-matched to
  their lines and spread in the same order as the line ends, so the link is
  clear without a leader that would otherwise cut across neighbouring labels.

## Export

A retrieval can now leave the package in the formats other tools read.

* [`as_bibtex()`] and [`as_ris()`] export a record set to the BibTeX and RIS
  interchange formats, so a search can be carried into Zotero, EndNote,
  Mendeley or a LaTeX bibliography.

## A code-free app

The whole workflow is now available without writing any R.

* [`run_app()`] launches a local, code-free Shiny app for building a search,
  retrieving records with a live progress terminal, and exporting them. A panel
  mirrors every choice as a runnable R script, so the app is an on-ramp to the
  package. It runs on your own machine, so the API key never leaves it. The app
  also has a *Compare topics* tab (with highlight, stability-band and
  counts-in-label controls, a per-term progress indicator, a quota estimate and
  a CSV export) and a *Demo mode*, on by default, that synthesises records and
  a comparison so the whole workflow can be explored with no key and no
  network. A new vignette, *Using the code-free app*, walks through every
  panel.
* The app holds steady under stress. It refuses to start a comparison while a
  harvest is running, turns any comparison failure into a notification, floors a
  fractional maximum-records entry, drops duplicate comparison terms, and tells
  you when there is nothing to cancel.

## Other improvements

One rough edge in the package's messaging was smoothed.

* The no-key error renders its guidance (the option name, the `api_key`
  argument and the key-request URL) through cli, where it used to leak raw
  markup.

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
  five workflow vignettes draw on a wide range of fields.
* The `authors` column retains every author a record lists. Very large result
  totals are handled without overflow, and DOI cleaning copes with `www.doi.org`
  hosts and `DOI:` labels.
