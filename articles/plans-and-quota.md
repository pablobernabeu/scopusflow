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
#> [1] "TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size)"
```

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

Scopus charges quota per request, not per record. A page may hold up to
200 records under the `STANDARD` view, or 25 under `COMPLETE`.
Retrieving a thousand records in pages of 200 therefore costs five
requests, where pages of 25 would cost forty. For that reason
`page_size` defaults to the largest the view allows, which is the same
efficiency `rscopus` relies on, and is in no sense an evasion of the
quota: every request is counted, and the 5000-record ceiling still
holds.

``` r

scopus_plan(q, view = "STANDARD")$page_size[1]
#> [1] 200
scopus_plan(q, view = "COMPLETE")$page_size[1]
#> [1] 25
```

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
response:

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
#> $limit
#> [1] 20000
#> 
#> $remaining
#> [1] 19987
#> 
#> $reset
#> [1] "2023-11-14 22:13:20 UTC"
#> 
#> $status
#> [1] NA
#> 
#> $retry_after
#> [1] NA
```

## Fetching, with caching and resume

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
runs each cell in turn. Given a cache directory it writes each cell to
disk as it completes, so a run interrupted halfway, or stopped by the
quota, resumes from where it left off rather than paying for the same
cells again.

``` r

records <- scopus_fetch_plan(
  plan,
  cache_dir = scopus_cache_dir(),
  resume = TRUE
)
records
```

A cache directory serves one plan. Cells are checkpointed by their
position in the plan, so pointing a second, different plan at the same
directory would pair its cells with the first plan’s checkpoints.
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
compares each checkpoint’s recorded query with the plan cell before
loading it and refetches on a mismatch, but the clean arrangement is a
separate directory per plan.

The cache lives under
[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md).
To force a fresh retrieval, empty it with
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md).
Both are shown but not run, so the article does not touch a real cache:

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

records <- scopus_fetch_plan(plan, cache_dir = scopus_cache_dir(), verbose = TRUE)
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
#> [1] 149
```

The 138 distinct articles come back as 149 rows, which is worth
understanding rather than working around. De-duplication needs something
to match on. These records carry no Scopus identifier, not having come
from Scopus, so it falls back to the DOI, and the eleven that arrived
without one cannot be matched to their own copies. A live Scopus harvest
carries an identifier on every record, so the same call would return
138.

## When the ceiling bites

Under offset paging, a query matching more than 5000 records cannot be
retrieved in full from a single call.
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns the first 5000 and warns. One remedy is to split the search by
year, or by any other facet, so that each cell stays under the ceiling;
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
tells you in advance whether a split is needed. The other is
`scopus_fetch(cursor = TRUE)`, which follows the API’s cursor instead of
an offset and retrieves the whole set in one call, at the price of
deep-paging rather than relevance order. The *Analysing a literature*
article weighs the two: a plan gives cached, resumable cells, the cursor
a complete set in a single pass.

## Handling interruptions

Network and API problems are raised as typed conditions, all inheriting
from `scopus_error`, so a long retrieval can respond to them rather than
stopping dead.

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
