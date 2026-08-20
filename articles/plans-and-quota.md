# Search plans and quota-aware retrieval

``` r

library(scopusflow)
```

The Elsevier Scopus Search API is generous but bounded. A weekly quota
limits how many requests you may make, a short-term rate limit caps how
fast you may make them, and under the ordinary offset paging no single
query will return more than its first 5000 records. This article shows
how scopusflow works within those bounds so that a large retrieval is
reproducible, efficient and resumable. The steps that contact the API
need a key and are not run here. Everything else runs offline.

## A query, built safely

Most queries combine a few terms under a field tag.
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
assembles them without the bracket and tag mistakes that creep in when
fragments are pasted together by hand.

``` r

q <- scopus_query("language learning", "effect size", .field = "TITLE-ABS-KEY")
q
```

    [1] "TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size)"

The recognised field tags, and what each one searches, are listed by
[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md).

``` r

scopus_field_tags()
```

| tag                | searches                                   |
|:-------------------|:-------------------------------------------|
| TITLE              | Words in the document title                |
| TITLE-ABS-KEY      | Title, abstract and keywords               |
| TITLE-ABS-KEY-AUTH | Title, abstract, keywords and author names |
| ABS                | Abstract text                              |
| KEY                | Indexed and author keywords                |
| AUTH               | Author names                               |
| AUTHKEY            | Author-supplied keywords                   |
| AFFIL              | Affiliation, any part                      |
| AFFILORG           | Affiliation organisation name              |
| SRCTITLE           | Source (publication) title                 |
| DOI                | Digital Object Identifier                  |
| ALL                | All available fields                       |

## Describing the search as a plan

A plan records exactly what will be fetched, so it can be saved,
reviewed and re-run. Partitioning by year is the recommended way to stay
under the 5000-record ceiling, since each year becomes its own cell.

``` r

plan <- scopus_plan(q, years = 2010:2020, partition = "year")
plan
```

| cell | query | date | year | view | page_size |
|---:|:---|:---|---:|:---|---:|
| 1 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2010 | 2010 | STANDARD | 200 |
| 2 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2011 | 2011 | STANDARD | 200 |
| 3 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2012 | 2012 | STANDARD | 200 |
| 4 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2013 | 2013 | STANDARD | 200 |
| 5 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2014 | 2014 | STANDARD | 200 |
| 6 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2015 | 2015 | STANDARD | 200 |
| 7 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2016 | 2016 | STANDARD | 200 |
| 8 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2017 | 2017 | STANDARD | 200 |
| 9 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2018 | 2018 | STANDARD | 200 |
| 10 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2019 | 2019 | STANDARD | 200 |
| 11 | TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size) | 2020 | 2020 | STANDARD | 200 |

Each cell carries the query, the year, the view and the page size. The
page size deserves a moment’s attention, because it is where quota is
won or lost.

## Why page size is a quota decision

Scopus charges quota by the request, whatever a request brings back. A
page may hold up to 200 records under the `STANDARD` view, or 25 under
`COMPLETE`, so retrieving a thousand records in pages of 200 costs five
requests where pages of 25 would cost forty. For that reason `page_size`
defaults to the largest the view allows, which is the same efficiency
`rscopus` relies on, and is in no sense an evasion of the quota. Every
request is counted, and the 5000-record ceiling still holds.

``` r

scopus_plan(q, view = "STANDARD")$page_size[1]
```

    [1] 200

``` r

scopus_plan(q, view = "COMPLETE")$page_size[1]
```

    [1] 25

## Sizing before spending

Counting is cheap and does not download records, so it is worth doing
first. The count comes back with the parsed quota attached, which lets a
workflow decide whether it has the allowance to proceed.

``` r

n <- scopus_count(q, years = 2010:2020)
n
attr(n, "quota")
```

That allowance is parsed from the response headers by
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md).
To show its shape without a network call, apply it to a constructed
response.

``` r

resp <- httr2::response(
  status_code = 200,
  headers = list(
    `X-RateLimit-Limit`     = "20000",
    `X-RateLimit-Remaining` = "19987",
    `X-RateLimit-Reset`     = "1700000000"
  )
)
scopus_quota(resp)
```

    $limit
    [1] 20000

    $remaining
    [1] 19987

    $reset
    [1] "2023-11-14 22:13:20 UTC"

    $status
    [1] NA

    $retry_after
    [1] NA

## Fetching, with caching and resume

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
runs each cell in turn. Given a cache directory it writes each cell to
disk as it completes, so a run interrupted halfway, or stopped by the
quota, resumes from where it left off and never pays twice for the same
cell.

``` r

records <- scopus_fetch_plan(
  plan,
  cache_dir = scopus_cache_dir(),
  resume = TRUE
)
records
```

A cache directory serves one plan. Cells are checkpointed by their
position in the plan and their year, so a second plan pointed at the
same directory could otherwise be paired with the first plan’s
checkpoints. Before loading one,
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
checks that the query, year, view, page size and record cap it was
written under all match the cell being run, and refetches with a warning
when they do not. A checkpoint holding more records than the current
`max_results` asks for is served trimmed to that cap, with the fuller
set left on disk for a later, wider request. A checkpoint that stopped
at a smaller cap than is being asked for now is a mismatch, refetched
with a warning. One that ran to the end of its result set is not,
however few records that turned out to be, because there is nothing
further to fetch. The clean arrangement is still a separate directory
per plan.

The cache lives under
[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md).
To force a fresh retrieval, empty it with
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md).
Both are shown but not run, so the article does not touch a real cache.

``` r

scopus_cache_dir()    # where completed cells are written
scopus_cache_clear()  # remove them, so the next run re-fetches from scratch
```

The result is a `scopus_records` tibble, the same shape returned by
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
for a single query. Without a key, the bundled `example_records` stands
in for it: 138 real journal articles in that same schema, shipped
because Scopus records may not be redistributed.

``` r

head(example_records)
```

| entry_number | scopus_id | doi | title | authors | year | date | publication | citations | query |
|---:|:---|:---|:---|:---|---:|:---|:---|---:|:---|
| 1 | NA | 10.15541/jim20140527 | Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles | Jianhua Yu | 2015 | 2015-01-01 | Journal of Inorganic Materials | 1 | graphene supercapacitor |
| 2 | NA | NA | Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor | Patrick R Rice | 2015 | 2015-01-01 | DigitalCommons - CalPoly (California State Polytechnic University) | 0 | graphene supercapacitor |
| 3 | NA | 10.1021/am509065d | Flexible and Stackable Laser-Induced Graphene Supercapacitors | Zhiwei Peng | 2015 | 2015-01-13 | ACS Applied Materials & Interfaces | 469 | graphene supercapacitor |
| 4 | NA | 10.1016/j.electacta.2015.02.019 | Heavily nitrogen doped, graphene supercapacitor from silk cocoon | Vikrant Sahu | 2015 | 2015-02-04 | Electrochimica Acta | 195 | graphene supercapacitor |
| 5 | NA | 10.1002/smll.201403383 | Graphene-Based Integrated Photovoltaic Energy Harvesting/Storage Device | Chih-Tao Chien | 2015 | 2015-02-19 | Small | 108 | graphene supercapacitor |
| 6 | NA | 10.1016/j.jpowsour.2015.03.015 | Nanoporous graphene materials by low-temperature vacuum-assisted thermal process for electrochemical energy storage | Hao Yang | 2015 | 2015-03-05 | Journal of Power Sources | 47 | graphene supercapacitor |

## Watching progress

Per-cell progress is silent by default and switched on with
`verbose = TRUE`, worth doing for a harvest spanning many years.

``` r

records <- scopus_fetch_plan(
  plan,
  cache_dir = scopus_cache_dir(),
  verbose = TRUE
)
```

A line is reported as each cell is fetched or loaded from cache.

## Combining separate retrievals

Results gathered in separate runs combine safely with
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md),
which renumbers the records and can drop duplicates by Scopus identifier
or DOI. This is preferable to
[`rbind()`](https://rdrr.io/r/base/cbind.html), which would leave
duplicate entry numbers. Here a baseline retrieval that stopped at 2023
is merged with a later one covering the whole period.

``` r

baseline <- example_records[example_records$year <= 2023, ]
combined <- scopus_combine(baseline, example_records, dedupe = TRUE)
nrow(combined)
```

    [1] 149

The 138 distinct articles come back as 149 rows, which is worth
understanding before reaching for a workaround. De-duplication needs
something to match on. These records carry no Scopus identifier, never
having come from Scopus, so it falls back to the DOI, and the eleven
that arrived without one cannot be matched to their own copies. A live
Scopus harvest carries an identifier on every record, so the same call
would return 138.

## Writing the search up

A harvest is rarely the end of the work. A systematic review has to
report the search itself, in enough detail that a reader can repeat it,
and the reporting standard for that is PRISMA-S (Rethlefsen et al.,
2021).
[`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
assembles the record from what the plan and the harvest already carry,
so the methods section is written from the objects and never from
memory.

A plan on its own can be reported before it is run, which is useful when
a protocol has to be registered in advance. The plan below describes the
search that produced the bundled corpus, so that the record and the
records match.

``` r

graphene <- scopus_plan("graphene supercapacitor", years = 2015:2024,
                        field = "TITLE-ABS-KEY", partition = "year")
report <- scopus_search_report(graphene)
report
```

    Search strategy record (PRISMA-S)

    Database: Scopus, on the Elsevier Scopus Search API
    Search expression: TITLE-ABS-KEY(graphene supercapacitor)
    Field tag: TITLE-ABS-KEY
    Years: 2015 to 2024
    Partition: one cell per year, 10 cells
    View: STANDARD
    Page size: 200 records per request
    Paging: unrecorded
    Date searched: unrecorded, this plan has not been run
    Software: unrecorded
    Records retrieved: none, this plan has not been run
    Records reported as matching: unrecorded, this plan has not been run
    Completeness: unrecorded, this plan has not been run
    Duplicates removed: unrecorded, this plan has not been run
    Records carrying a DOI: unrecorded, this plan has not been run

    Cells
      1 (2015): retrieved records unrecorded
      2 (2016): retrieved records unrecorded
      3 (2017): retrieved records unrecorded
      4 (2018): retrieved records unrecorded
      5 (2019): retrieved records unrecorded
      6 (2020): retrieved records unrecorded
      7 (2021): retrieved records unrecorded
      8 (2022): retrieved records unrecorded
      9 (2023): retrieved records unrecorded
      10 (2024): retrieved records unrecorded

    PRISMA 2020 identification
      Records identified from Scopus: unrecorded, this plan has not been run
      Duplicate records removed before screening: unrecorded, this plan has not been run

    PRISMA-S items this record supplies
      1 Database name. Scopus, searched on the Elsevier Scopus Search API.
      8 Full search strategies. The search expression, field tag and year limit of every cell, as the plan sends them.
      9 Limits and restrictions. Publication years 2015 to 2024. scopusflow applies no document type, language or subject area limit of its own.

    PRISMA-S items only you can supply
      2 Multi-database searching. Whether any database besides Scopus was searched, and how the strategy was translated for it.
      3 Study registries. Any trial or study registry searched.
      4 Online resources and browsing. Any web site, table of contents or other source searched or browsed by hand.
      5 Citation searching. Any backward or forward citation searching.
      6 Contacts. Any authors or organisations contacted for studies.
      7 Other methods. Any further method used to identify records.
      10 Search filters. Any published or validated search filter used, and where it came from. scopusflow applies none of its own.
      11 Prior work. Any earlier review or strategy this search was adapted from.
      12 Updates. Whether the search was re-run or updated, and when.
      13 Dates of searches. The date of each search, which this plan has not been run to produce.
      14 Peer review. Whether the strategy was peer reviewed, and by whom.
      15 Total records. The number of records identified, which this plan has not been run to produce.
      16 Deduplication. How duplicate records were removed, which this plan has not been run to produce.

    The reporting standard is PRISMA-S (Rethlefsen et al., 2021, Systematic Reviews, 10, 39, https://doi.org/10.1186/s13643-020-01542-z), with the identification counts of the PRISMA 2020 flow diagram.

    The methods paragraph is format(x, style = "paragraph"); pass file = to write the whole record as Markdown.

Notice how much of it says “unrecorded”. Nothing has been retrieved yet,
so there is nothing to state, and the report says so in words, since a
blank there would be read as a zero. That is the governing rule
throughout: the record states only what the objects hold. It never
substitutes the current time for a retrieval that did not record one,
never gives a completeness figure for a harvest whose reported total is
unknown, and never counts duplicates unless a merge recorded removing
them.

After a harvest the picture fills in.
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
attaches the plan, the retrieval time, the version, the paging mode and
the per-cell accounting, so the report has everything it needs and you
never set any of it yourself. The bundled corpus stands in for a harvest
here, since Scopus records may not be redistributed, so those attributes
are written out below to show what each one contributes.

``` r

records <- example_records
attr(records, "plan") <- graphene
attr(records, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
attr(records, "scopusflow_version") <- "0.3.0"
attr(records, "paging") <- "offset"
per_year <- as.integer(table(example_records$year))
attr(records, "cell_totals") <- tibble::tibble(
  cell = 1:10, date = as.character(2015:2024),
  n_records = per_year, reported_total = as.numeric(per_year)
)

report <- scopus_search_report(records)
report
```

    Search strategy record (PRISMA-S)

    Database: Scopus, on the Elsevier Scopus Search API
    Search expression: TITLE-ABS-KEY(graphene supercapacitor)
    Field tag: TITLE-ABS-KEY
    Years: 2015 to 2024
    Partition: one cell per year, 10 cells
    View: STANDARD
    Page size: 200 records per request
    Paging: offset
    Date searched: 2026-07-22 09:15:00 UTC
    Software: scopusflow 0.3.0
    Records retrieved: 138
    Records reported as matching: 138
    Completeness: every record the API reported as matching was retrieved
    Duplicates removed: unrecorded, no de-duplication step was recorded for this set
    Records carrying a DOI: 127 of 138

    Cells
      1 (2015): 15 retrieved, 15 reported, complete
      2 (2016): 9 retrieved, 9 reported, complete
      3 (2017): 10 retrieved, 10 reported, complete
      4 (2018): 15 retrieved, 15 reported, complete
      5 (2019): 19 retrieved, 19 reported, complete
      6 (2020): 13 retrieved, 13 reported, complete
      7 (2021): 13 retrieved, 13 reported, complete
      8 (2022): 15 retrieved, 15 reported, complete
      9 (2023): 15 retrieved, 15 reported, complete
      10 (2024): 14 retrieved, 14 reported, complete

    PRISMA 2020 identification
      Records identified from Scopus: 138
      Duplicate records removed before screening: unrecorded, no de-duplication step was recorded for this set

    PRISMA-S items this record supplies
      1 Database name. Scopus, searched on the Elsevier Scopus Search API.
      8 Full search strategies. The search expression, field tag and year limit of every cell, as the plan sends them.
      9 Limits and restrictions. Publication years 2015 to 2024. scopusflow applies no document type, language or subject area limit of its own.
      13 Dates of searches. 2026-07-22 09:15:00 UTC.
      15 Total records. 138 records retrieved from Scopus, of 138 the API reported as matching.

    PRISMA-S items only you can supply
      2 Multi-database searching. Whether any database besides Scopus was searched, and how the strategy was translated for it.
      3 Study registries. Any trial or study registry searched.
      4 Online resources and browsing. Any web site, table of contents or other source searched or browsed by hand.
      5 Citation searching. Any backward or forward citation searching.
      6 Contacts. Any authors or organisations contacted for studies.
      7 Other methods. Any further method used to identify records.
      10 Search filters. Any published or validated search filter used, and where it came from. scopusflow applies none of its own.
      11 Prior work. Any earlier review or strategy this search was adapted from.
      12 Updates. Whether the search was re-run or updated, and when.
      14 Peer review. Whether the strategy was peer reviewed, and by whom.
      16 Deduplication. How duplicate records were removed, which this set does not record.

    The reporting standard is PRISMA-S (Rethlefsen et al., 2021, Systematic Reviews, 10, 39, https://doi.org/10.1186/s13643-020-01542-z), with the identification counts of the PRISMA 2020 flow diagram.

    The methods paragraph is format(x, style = "paragraph"); pass file = to write the whole record as Markdown.

The completeness lines are worth a moment. Each cell is shown against
the number of records the API reported for it, so a cell that came back
short stays visible where a total would have hidden it, and the overall
figure is given only because every cell reported one. Drop any of those
attributes and the corresponding line says so instead.

The methods paragraph is the same record as prose, ready to paste into a
manuscript and edit.

``` r

cat(format(report, style = "paragraph"))
```

    The literature was searched in Scopus, on the Elsevier Scopus Search API, on 22 July 2026. The search expression was TITLE-ABS-KEY(graphene supercapacitor), limited to publication years 2015 to 2024. It was partitioned into 10 cells, one per year, each retrieved through the STANDARD view in pages of 200 records under offset paging. The search retrieved 138 records, matching the 138 the API reported, so every reported record was retrieved. Of the records retrieved, 127 carry a DOI. No de-duplication step was recorded for this set. The search was run with scopusflow 0.3.0. The PRISMA-S items this record cannot supply, among them peer review of the strategy, grey literature and any other database searched, remain yours to report.

Supplying a `file` writes the whole record as Markdown, including a
runnable snippet that rebuilds the plan, which makes a natural
supplementary file.

``` r

scopus_search_report(records, file = "search-record.md")
```

Five of the sixteen PRISMA-S items are answered here from the objects,
and a sixth, de-duplication, would be too had these records been merged
with
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md).
The rest, among them peer review of the strategy, grey literature and
any other database searched, are listed as yours to supply, because the
package has no way to know them.

## When the ceiling bites

Under offset paging, a query matching more than 5000 records cannot be
retrieved in full from a single call.
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns the first 5000 and warns. One remedy is to split the search by
year, or by any other facet, so that each cell stays under the ceiling,
and
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
tells you in advance whether a split is needed. The other is
`scopus_fetch(cursor = TRUE)`, which follows the API’s cursor in place
of an offset and retrieves the whole set in one call, with the records
arriving in deep-paging order. The *Analysing a literature* article
weighs the two. A plan gives cached, resumable cells, the cursor a
complete set in a single pass.

## Handling interruptions

Network and API problems are raised as typed conditions, all inheriting
from `scopus_error`, so a long retrieval can catch them and carry on.

``` r

result <- tryCatch(
  scopus_fetch_plan(plan, cache_dir = scopus_cache_dir()),
  scopus_error_rate_limit = function(e) {
    message("Rate limited; the cached cells are safe. Try again later.")
    NULL
  }
)
```

Because each completed cell is already cached, resuming after such a
pause costs nothing for the work already done.
