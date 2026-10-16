# Fetch 'Scopus' records for a query

Retrieves records page by page, accumulating them and returning a single
normalised
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble. Pagination, the API's hard `start < 5000` ceiling, rate-limit
handling and retry with back-off are all managed for you.

## Usage

``` r
scopus_fetch(
  query,
  max_results = Inf,
  view = c("STANDARD", "COMPLETE"),
  page_size = NULL,
  field = NULL,
  years = NULL,
  cursor = FALSE,
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE,
  fields = c("core", "extended")
)
```

## Arguments

- query:

  Character scalar. The base search expression, checked offline before
  any request (see the *Query checks* section of
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- max_results:

  Maximum number of records to retrieve. Defaults to `Inf`, meaning all
  available records up to the API ceiling. With the default offset-based
  paging the 'Scopus' Search API refuses offsets of 5000 or more, so a
  single query yields at most 5000 records; set `cursor = TRUE`, or
  partition the search by year with
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
  to go beyond that.

- view:

  Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` adds an `authkeywords`
  column to
  `scopus_fetch()`/[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  output (see
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
  at no extra cost beyond `COMPLETE`'s own smaller page size, which
  already means more requests, and so more quota, for the same number of
  records.

- page_size:

  Integer records per page, or `NULL` (default) to use the most
  quota-efficient page the view allows (200 for `STANDARD`, 25 for
  `COMPLETE`). See
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  for why larger pages cost less quota.

- field:

  Optional 'Scopus' field tag to wrap the query in (see
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- years:

  Optional integer vector of publication years.
  [`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md),
  `scopus_fetch()` and
  [`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)
  send one inclusive range from the earliest year to the latest, as a
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  with `partition = "none"` does, so `c(2015, 2020)` covers every year
  from 2015 to 2020.
  [`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md),
  [`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
  and a plan with `partition = "year"` take each listed year. An empty
  vector places no year restriction, as `NULL` does, where the years
  form a range, and is refused where each year is counted.

- cursor:

  Logical. When `TRUE`, retrieve the result set with cursor-based
  pagination, which has no 5000-record ceiling, so an entire large query
  can be harvested in one call. The records then arrive in the API's
  deep-paging order, which is no longer relevance order. As a safeguard
  against a non-conforming server that never signals the end, cursor
  paging stops after `getOption("scopusflow.max_cursor_pages", 1e5)`
  pages with a warning; set that option to `Inf` to remove the ceiling.

- api_key, inst_token:

  Optional credentials, resolved by default from options or environment
  variables (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported as the retrieval proceeds.

- fields:

  `"core"` (the default) or `"extended"`. `"extended"` also keeps the
  document type, source type, volume, issue, pages, ISSN, PubMed
  identifier and open-access status the Search API sends with every
  record, and the abstract under `view = "COMPLETE"`. They arrive in the
  same responses, so they cost no extra quota. See the *Extended fields*
  section of
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md).

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble. The reported total and the most recent parsed quota are attached
as the `total_results` and `quota` attributes, the harvest is dated by
`retrieved_at` (a `POSIXct`) and `scopusflow_version`, and `paging`
records whether it was retrieved by offset or by cursor.
`retrieved_until` gives the same time as `retrieved_at` for a single
search. A set combined from several keeps the earliest of their times as
`retrieved_at` and the latest as `retrieved_until`. The date and version
matter because `citations` is a snapshot value that keeps moving, so two
saved sets are only comparable if each records when it was taken, and
[`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
reads all of them back. `view` records the view, which decides what
`authors` holds: the first author under `STANDARD` and the author list
under `COMPLETE` (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)).
`max_results` records the cap the call was given, when it was given one,
so the search record can say whether the retrieval stopped at it. `plan`
is the one-cell plan the call ran,
`scopus_plan(query, years, field, view, page_size, partition = "none")`,
so the search record states the field tag and the year limit the request
carried. These attributes survive a `.rds` round trip through
[`write_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)
but not a `.csv` one, which carries columns only. A retrieval that comes
back with fewer records than the API reported warns with a
`scopus_warning_shortfall`, as each cell of
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
does, unless `max_results` or the offset ceiling stopped it.

## API access

Requires a valid API key and internet access. The *API access* section
of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
lists the conditions that may be raised.

## See also

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
for cached, resumable, partitioned retrieval.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
recs <- scopus_fetch('"graphene supercapacitor"', field = "TITLE-ABS-KEY",
                     max_results = 50)
recs
}
# The offline companion, which needs no key. 'Scopus' records may not be
# redistributed, so the package bundles a corpus of real articles in this
# same schema; a live harvest returns exactly this shape.
recs <- example_records
recs
#> <scopus_records> 138 records
#> query: "graphene supercapacitor"
#> # A tibble: 138 × 9
#>    entry_number scopus_id doi    title authors  year date  publication citations
#>           <int> <chr>     <chr>  <chr> <chr>   <int> <chr> <chr>           <int>
#>  1            1 NA        10.15… Enha… Jianhu…  2015 2015… Journal of…         1
#>  2            2 NA        NA     Fabr… Patric…  2015 2015… DigitalCom…         0
#>  3            3 NA        10.10… Flex… Zhiwei…  2015 2015… ACS Applie…       469
#>  4            4 NA        10.10… Heav… Vikran…  2015 2015… Electrochi…       195
#>  5            5 NA        10.10… Grap… Chih-T…  2015 2015… Small             108
#>  6            6 NA        10.10… Nano… Hao Ya…  2015 2015… Journal of…        47
#>  7            7 NA        10.11… Capa… Maxwel…  2015 2015… Physical R…        32
#>  8            8 NA        10.13… Grap… Nurbek…  2015 2015… Optics Let…        48
#>  9            9 NA        10.10… Ultr… Zhong-…  2015 2015… Advanced M…       275
#> 10           10 NA        10.10… Etch… Matthe…  2015 2015… Nanotechno…        24
#> # ℹ 128 more rows
nrow(recs)
#> [1] 138
is_scopus_records(recs)
#> [1] TRUE
```
