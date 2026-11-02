# scopusflow 0.5.0

A release about retrieving more of a search and about the accuracy of what it
returns. Cursor paging retrieves plan cells of more than 5000 records whole, and
`fields = "extended"` adds document metadata at no extra quota. New functions
compare two harvests and export a corpus for theoryforge. Many fixes change
results, and the upgrading notes below say what was wrong in each case.

## Upgrading from the previous release (0.4.0)

### Changed results

* `scopus_compare_topics()` sends each comparison as `(reference) AND (term)`,
  where, without `field`, it joined them without brackets, so a reference with a
  top-level AND NOT took the term into its negation and shares could pass 100%.
  Re-run such comparisons made without `field`. Given `field`, only the `query`
  column differs.
* `scopus_query()` brackets each term of several words, other than a quoted or
  braced phrase or a bracketed or field-tagged group, when it joins terms
  without `.field`, so
  `scopus_query("machine learning", "deep learning", .op = "OR")` gives
  `(machine learning) OR (deep learning)`, where 'Scopus' read the unbracketed
  join as `machine AND (learning OR deep) AND learning`. It also trims each
  term.
* Under `view = "COMPLETE"`, the `authors` column lists every author, up to the
  API's 100, as `"Surname, Given"` joined by `"; "`, where it held the first
  author alone. `COMPLETE` checkpoints from 0.4.0 are fetched again once, each
  with a `scopus_warning_cache_mismatch` warning.
* `scopus_abstract(view = "REF", include = "references")` and
  `scopus_corpus(view = "REF")` return the whole reference list, at one request
  per 40 references, where they returned about the first 40. The title and
  source of each reference are read, where both were `NA`. REF checkpoints from
  0.4.0 are fetched again once.
* `scopus_fetch()` and `scopus_fetch_plan()` advance by the records each page
  returns, where a page shorter than requested made them skip records.
  `STANDARD` plan checkpoints from 0.4.0 are served as before, so re-run with
  `resume = FALSE` a plan that warned of a shortfall.
* Requests are retried after a transport failure, such as a timeout or a reset
  connection, where, under httr2 1.0.4 or later, `scopus_abstract()` and
  `scopus_corpus()` gave the identifier an `NA` row with a warning and other
  functions stopped with an error.
* `scopus_combine(dedupe = TRUE)` matches DOIs without resolver prefixes and
  joins a record without a 'Scopus' identifier, a blank one included, to the
  identified record with its DOI, where 0.4.0 kept them apart and merged all
  records with a blank identifier. `dedupe = "id_then_doi"` restores the 0.4.0
  rule.
* `scopus_abstract()` requests `view = "META_ABS"` by default, where it sent no
  view, which Elsevier documents as giving no abstract, although the API has
  returned one. With a key not entitled to that view, the call stops with
  `scopus_error_forbidden` (HTTP 403). `view = NULL` restores the 0.4.0 request
  and reads its checkpoints.
* `scopus_top(by = "author")`, `as_bibtex()` and `as_ris()` split an author
  list at a semicolon with or without a space after it, where a list joined
  with `";"` alone, as version 0.3.0 of the Python twin wrote it, counted as one
  author.
* `as_bibliometrix()` gives `AU` names as surname and initials joined by `";"`,
  such as `"ZHANG F;LI X"`, where it upper-cased the `authors` string, and `UT`
  as the upper-cased EID, where it gave the bare identifier. A set carrying
  author keywords gains `DE`.
* `read_scopus_records()` reads a `.csv` file as UTF-8 in every locale and a
  blank field as `NA`, where it followed the locale's encoding and read a blank
  field as an empty string.
* The app's 'Author' choice under 'Search in' sends `AUTH`, where it sent
  `AUTHLASTNAME`, which searches surnames alone.
* `run_app()` leaves its 'Max records per cell' field blank, where the field,
  labelled 'Max records per year' in 0.4.0, capped at 200 records each year or,
  with 'Partition by year' off, the whole search. Entering 200 restores that
  cap.
* `run_app()` opens its year slider on 2015 to 2024, where it opened on the last
  six years.
* `scopus_abstract()` and `scopus_corpus()` give no keyword for a lone
  author-keyword entry without text, where they gave the keyword `"true"`.
  Checkpoints from 0.4.0 keep that keyword, so re-run such a batch with
  `resume = FALSE`.
* The app trims the query before every request, so it sends the query the script
  panel shows, where 'Check size', 'Compare topics' and 'Fetch records' sent it
  as typed.

### Changed interface

* `scopus_plan()`, `scopus_count()`, `scopus_fetch()`, `scopus_trend()`,
  `scopus_compare_topics()` and `scopus_intersections()` refuse with
  `scopus_error_bad_input`, before any request, unbalanced brackets, quotation
  marks or braces and the `LIMIT-TO()` and `EXCLUDE()` refinements that the
  Search API ignores, with which a search ran unfiltered.
* `scopus_plan()` given `field` refuses with `scopus_error_bad_input` a query,
  and `scopus_query()` given `.field` a term, that already opens with a field
  tag, where they nested the tags, which the API rejects. `scopus_count()`,
  `scopus_fetch()`, `scopus_trend()` and `scopus_compare_topics()` refuse such a
  query before the request.
* `scopus_error_bad_input` inherits `scopus_error`, so a handler for
  `scopus_error` catches input errors, and an invalid `view`, `partition`, `by`,
  `.op` or `style` raises it too. A retry loop on `scopus_error` should not
  retry this subclass.
* scopusflow requires httr2 1.0.4 or later, and its app shiny 1.6.0 or later.
* `scopus_corpus()` returns a `scopus_id` column in second place, so code that
  selects its columns by position needs updating.
* A logical argument such as `cursor`, `resume`, `verbose`, `dedupe` in
  `scopus_extract_dois()` or `create` in `scopus_cache_dir()` must be `TRUE` or
  `FALSE`, where `cursor`, `dedupe` and `create` read `"TRUE"`, `1` and `NA` as
  `FALSE`.
* `scopus_combine()` refuses any `dedupe` but `TRUE`, `FALSE` or a rule name,
  where `NA` or another value meant no de-duplication.
* `scopus_trend()`, `scopus_compare_topics()` and
  `scopus_plan(partition = "year")` refuse an empty `years` with
  `scopus_error_bad_input`, as they refuse `years = NULL`, where
  `scopus_trend()` returned an empty trend,
  `scopus_compare_topics()` stopped with an untyped error and `scopus_plan()`
  built a plan without cells.
* `scopus_fetch_plan()`, `scopus_abstract()` and `scopus_corpus()` refuse with
  `scopus_error_bad_input`, before any request, a `cache_dir` in which no file
  can be created, where 0.4.0 read its checkpoints and lost any records it
  fetched to an error. Copy a read-only cache to a writable directory.
* The options `scopusflow.base_url` and `scopusflow.abstract_url` accept only an
  `https` URL on `api.elsevier.com` or another host under `elsevier.com`, so the
  API key goes to Elsevier alone. Any other value is refused before a request.

### Changed output

* `scopus_search_report()` dates a harvest from its first retrieval to its last,
  where it gave the first alone, lists year cells with gaps separately, where it
  gave one span, names a `max_results` cap and supplies PRISMA-S item 2.
* For a set without a plan, `scopus_search_report()` calls the year limit
  unrecorded, where it said that no year limit was applied, and leaves PRISMA-S
  item 8 to the author.
* `scopus_fetch()` attaches the plan it ran, so the search record of its result
  states the field tag and years and gives a reproduction snippet.
* Given a one-cell `plan` for a set without per-cell counts,
  `scopus_search_report()` reports the set's own counts, where it called them
  unrecorded.
* PRISMA-S item 16 of `scopus_search_report()` names the de-duplication rule and
  the number of DOIs that records with different identifiers share, which
  `scopus_combine()` records in its `combined` attribute as `rule` and
  `doi_conflicts`.
* In demo mode, the app's search record names no search expression and says that
  the records were replayed and that it describes no search that was run, where
  it gave the bundled corpus's phrase as the search expression.
* `as_bibtex()` and `as_ris()` write a name ending in initials as 'Surname, I.',
  where BibTeX read the initials as the family name and Zotero kept each RIS
  author as one field. Citation keys are unchanged.
* `as_bibtex()` spaces run-together initials, which BibTeX read as one given
  name, and protects words such as DNA in titles from lower-casing.
* `as_ris()` gives the source title as `T2` in place of `JO` and adds
  `DB  - Scopus` and the EID as `AN`.
* `as_ris()` and `as_bibtex()` export an `authkeywords` or `abstract` column, as
  a `COMPLETE` harvest (the abstract with `fields = "extended"`) or
  `scopus_abstract()` gives, where they wrote neither.
* Every file the package writes is UTF-8 in every locale, where a C or
  single-byte locale wrote a character it could not encode as text such as
  `<U+00ED>`.
* `autoplot()` of a record set, a `scopus_fetch()` result included, draws a bar,
  zero if need be, for each year its plan searched, where its bars ran from the
  first year in the records to the last.
* When the `max_results` cap stopped a cell, `autoplot()` of a record set says
  that the bars count retrieved records.
* When the years plotted reach the year of retrieval, `plot_scopus_trend()` and
  `autoplot()` of a trend or a record set add a caption line saying that it and
  any later year were incomplete when retrieved. They read the year from
  `retrieved_at`, which `scopus_trend()` also records.
* `scopus_fetch()` warns with `scopus_warning_shortfall`, as plan cells do, when
  it retrieves fewer records than the API reported, unless `max_results` or the
  offset ceiling stopped it.
* `scopus_plan()`, `scopus_count()`, `scopus_fetch()`, `scopus_trend()`,
  `scopus_compare_topics()` and `scopus_intersections()` warn with
  `scopus_warning_query_syntax` for `INDEXTERMS()`, which pybliometrics
  documents as not working through the Search API.
* `scopus_top(by = "author")` and `as_bibliometrix()` warn once per session
  (`scopus_warning_first_author_only`) that a set recorded as retrieved under
  `STANDARD` names first authors only. Sets retrieved by 0.4.0 record no view
  and do not warn.
* An HTTP 429 marked `QUOTA_EXCEEDED` raises `scopus_error_quota_exceeded`, a
  subclass of `scopus_error_rate_limit`, and is not retried. `scopus_abstract()`
  and `scopus_corpus()` stop requesting at a spent quota and give the remaining
  identifiers their `NA` rows with one `scopus_warning_quota_exceeded` warning,
  where they tried each three times and warned for each.
* The message for HTTP 403 no longer blames the quota, and a timeout raises
  `scopus_error_timeout`, a subclass of `scopus_error_offline`, with a message
  naming the time limit, where it said that the API could not be reached.
* The script the app generates keeps each plan's checkpoints in a directory of
  its own under `scopus_cache_dir()`, where plans shared one and overwrote each
  other's checkpoints. A script generated now does not resume from the
  checkpoints of one generated by 0.4.0.
* The script the app generates records the scopusflow version, notes when demo
  mode was on, saves the records before plotting, plots only where ggplot2 is
  installed and includes a comparison run with 'Partition by year' off, which it
  left out.
* The app's cost note for a topic comparison and the generated script's comment
  on that cost give (terms + 1) × years requests, where they gave terms × years.
  The note's advice to use fewer terms or years applies above 80 such requests.
* `scopus_diff_dois()` orders its rows in byte order on every machine, where it
  followed the locale's collation, and its printed line counts the records it
  could not compare for want of a DOI.
* `plot_scopus_comparison()` writes each count in its labels without padding,
  where it padded the smaller counts to the width of the largest.
* Inside a plan, the warning for a cell stopped at the offset ceiling advises
  `scopus_fetch_plan(plan, cursor = TRUE)`, where it advised
  `scopus_fetch(cursor = TRUE)` or partitioning by year.
* `citation("scopusflow")` gives the DOI that CRAN registered,
  <https://doi.org/10.32614/CRAN.package.scopusflow>, where it gave the Zenodo
  concept DOI, <https://doi.org/10.5281/zenodo.21252669>.

## New features

* `scopus_fetch_plan()` gains `cursor`, so a plan cell matching more than 5000
  records can be retrieved whole and checkpointed. The default,
  `cursor = FALSE`, keeps offset paging, and a checkpoint serves only a request
  in its own paging mode.
* `scopus_fetch()`, `scopus_fetch_plan()` and `scopus_records()` gain
  `fields = "extended"`, adding the document type, source type, volume, issue,
  pages, ISSN, PubMed identifier, open-access status and, under `COMPLETE`, the
  abstract, at no extra quota.
* `summary()` of a set retrieved with `fields = "extended"` counts its document
  types and reports how many records 'Scopus' labels errata or retracted, and
  the help explains why those labels do not screen a set for retractions.
* With `fields = "extended"`, `as_ris()` and `as_bibtex()` type conference
  papers, conference reviews, chapters and books by their 'Scopus' document type
  and add the volume, issue, pages, ISSN and, in RIS, the document type as `M3`.
  `as_bibliometrix()` adds `DT`, `VL` and `IS`.
* `scopus_abstract(include = "index_terms")` returns the index keywords 'Scopus'
  assigns, in an `idxterms` column, under `view = "FULL"`. `scopus_corpus()`
  gains `keywords`, to use them alone (`"index"`) or with the author keywords
  (`"both"`). The default, `"author"`, is unchanged.
* `write_scopus_corpus()` writes, and `as_theoryforge_corpus()` returns, a
  `scopus_corpus()` result in theoryforge's corpus schema, with a `provenance`
  block, keying cited works on the 'Scopus' identifier so that a work is one
  node however its DOI is written.
* `scopus_diff_records()` compares two harvests record by record, matching
  records as `scopus_combine(dedupe = TRUE)` does. It gives each record's
  citation counts in both and marks as `conflict` a record whose DOI the other
  harvest gives to a different record.
* `scopus_combine()` gains `dedupe = "id_or_doi"`, which also merges records
  with different identifiers that share a DOI, and accepts `"id_or_shared_doi"`
  as the name of the rule `TRUE` applies.

## Minor improvements

* `scopus_corpus()` reports its requests and the quota left in the `n_requests`
  and `quota` attributes, and records the search expression, when the search
  that found the records ran and the kind of keyword as `query`, `retrieved_at`
  and `keywords`.
* `scopus_fetch()` and `scopus_fetch_plan()` record `retrieved_until` beside
  `retrieved_at`, their view as `view` and a finite cap as `max_results`.
  `scopus_combine()` records the latest of its inputs' times as
  `retrieved_until` and keeps their `view` where they agree.
* `scopus_search_report()` also returns the latest retrieval time as
  `searched_until`, the cap as `max_results`, the de-duplication rule as
  `dedupe_rule` and the number of DOIs that records with different identifiers
  share as `doi_conflicts`.
* `scopus_diff_dois()` counts the records it could not compare for want of a DOI
  in the attributes `n_old_without_doi` and `n_new_without_doi`.
* The app's 'Records' tab says how many records the harvest holds and that its
  table shows the first 25, and its 'Retrieval' panel says when the cap stopped
  a cell. A failed harvest is reported with the message of the error that
  stopped it, without the wrapper that callr adds, marked 'Scopus:' when the
  package raised the error, as in the other panels.
* The app's 'Top authors' tab notes that a `STANDARD` harvest names first
  authors only.
* In demo mode, the app's live terminal says when a year lies outside the
  bundled corpus and which year it is drawn from, and the app notes under a
  topic comparison that its counts are illustrative.
* The app's status text has the contrast that text needs, its progress bar has
  an accessible name and value and each figure has a text alternative.

## Fixes

* `scopus_plan(partition = "none")`, `scopus_count()`, `scopus_fetch()` and
  `scopus_intersections()` read an empty `years` as no year limit, as they read
  `NULL`, where they stopped with an untyped error.
* `scopus_abstract()` and `scopus_corpus()` read a reference list, or a cited
  work's author list, that holds one item, where such a list stopped the batch
  with an untyped error. A keyword or reference list in any other shape they
  cannot read leaves that identifier an `NA` row and a warning, as an unreadable
  response already did, and the identifier is retried on resume.
* `Retry-After` dates parse in any locale, where a German or French `LC_TIME`
  made every one `NA`.
* A checkpoint that `scopus_fetch_plan()`, `scopus_abstract()` or
  `scopus_corpus()` fails to write, as on a full disk, gives a
  `scopus_warning_cache_unwritable` warning, and its records are kept, where
  they were lost to an error.
* `scopus_intersections()` uses as given a concept that opens with a tag of
  `scopus_field_tags()` written with a space before the bracket, as the web
  interface writes `TITLE-ABS-KEY ( x )`, where it wrapped it in `field` again
  and the API refused it.
* The app's 'Check size' button shows any error in a notification, where an
  error that was not a `scopus_error`, such as the one a blank query raised,
  closed the session. 'Check size' and 'Fetch records' refuse a blank query
  with a notification.
* Each app session keeps its checkpoints in a directory of its own, so closing
  one tab no longer deletes another's mid-harvest.
* Demo mode works when the app is launched as `scopusflow::run_app()` without
  attaching the package, where 'Check size' and 'Fetch records' failed.
* The app's size note clears when the search whose size it gave changes, where
  it stayed on screen for a different search. It writes counts in full, and
  'Check size' refuses with a notification while a harvest runs.
* The app's export buttons appear once there is something to write, where a
  click with nothing to write failed without a message.
* The app's 'By year', 'Top sources' and 'Top authors' panels say when there is
  nothing to show, where they showed a plotting error, and a highlighted topic
  whose counts are all missing is drawn without the highlight. The live terminal
  of a demo harvest over every year no longer labels it with the year 0.

## Documentation

* The designing-queries article describes the offline query checks and gives a
  recipe for testing a strategy's relative recall against records known to be
  relevant, following Sampson et al. (2006) and Bramer et al. (2018). It also
  explains loose and exact phrases and why a query mixing operators needs
  brackets.
* The help for `scopus_count()`, `scopus_fetch()` and `scopus_intersections()`
  says that `years` is sent as one inclusive range, so `c(2015, 2020)` covers
  every year from 2015 to 2020, where it called them 'publication years to
  restrict to'. `?scopus_compare_topics` says that each year is counted on its
  own, where it called `years` a span.
* The worked examples no longer present the bundled corpus as the result of an
  unquoted search. It came from an exact-phrase search in OpenAlex, and the
  demonstration plan and live searches quote the phrase, since 'Scopus' joins
  the words of an unquoted phrase with AND.
* The help for `scopus_compare_topics()` and two articles give a topic
  comparison's cost as (terms + 1) × years requests, where they gave one count
  request per term per year.
* The app article no longer promises that a run stopped by the quota resumes in
  a later session, and points to the generated script for a harvest that has to
  continue after the session ends.
* `?scopus_fetch_plan`, `?scopus_cache_dir`, the README and the articles give
  each plan a checkpoint directory of its own under `scopus_cache_dir()`, where
  they used `scopus_cache_dir()` itself, in which plans overwrite each other's
  checkpoints.
* The `scopus_cache_clear()` example points the cache at a temporary directory
  first, where running it deleted the managed cache.
* The keywords-and-references article shows its calls without output and builds
  the shapes they return from `example_records`, where it printed invented
  keywords, references and quota.
* The *API access* section of `?scopus_count` names the condition class each
  HTTP status raises and documents the options `scopusflow.max_tries` and
  `scopusflow.retry_backoff`. The README says that, of the server errors, only
  500, 502, 503 and 504 are retried, where it said that the whole 5xx range was.
* The README writes the call for reference lists with `view = "FULL"`, since
  `scopus_abstract()` refuses `include = "references"` under its default view.
* The analysing-a-literature article and `?scopus_top` say that a harvest under
  the default `STANDARD` view names the first author of each record alone, so an
  author tally counts first authorships, and that `view = "COMPLETE"` gives the
  author list, where they said that a live harvest returned every author.
* `?scopus_combine` says that `c()` on record sets calls `scopus_combine()`, so
  it renumbers them and keeps every row unless given `dedupe`, where it said
  that `c()` returned a list.
* `?scopus_corpus` says that `records` needs the identifier column that `by`
  names, `?summary.scopus_records` that `n_with_doi` counts the records carrying
  a DOI and `?scopus_quota` that `reset` is when the key's quota resets.
  `?scopus_diff_dois` no longer calls `status` an ordered factor.

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
