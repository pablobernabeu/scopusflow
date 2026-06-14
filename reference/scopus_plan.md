# Build a reproducible 'Scopus' search plan

A *plan* is a fully specified, inspectable description of one or more
'Scopus' queries to run. Splitting the act of *describing* a search from
*executing* it makes workflows reproducible (the plan can be saved,
reviewed and version controlled) and lets large retrievals be
partitioned, for example one cell per year, so they can be cached and
resumed.

## Usage

``` r
scopus_plan(
  query,
  years = NULL,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  page_size = NULL,
  partition = c("none", "year")
)

is_scopus_plan(x)
```

## Arguments

- query:

  Character scalar. The base search expression, without field tags or
  year filters (these are added through `field` and `years`).

- years:

  Optional integer vector of publication years to restrict to, for
  example `2015:2020`. When `partition = "year"`, one plan cell is
  created for each distinct year. Otherwise the minimum and maximum
  define a single date range.

- field:

  Optional character scalar naming a 'Scopus' field tag to wrap the
  query in, for example `"TITLE-ABS-KEY"`, `"TITLE"`, `"AUTH"` or
  `"AFFIL"`. When `NULL`, the query is used verbatim. See
  [`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)
  for the common tags.

- view:

  Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` returns more fields
  but requires a subscriber entitlement and is limited to a smaller page
  size.

- page_size:

  Integer number of records to request per page, or `NULL` (the default)
  to use the largest page the view allows. The 'Scopus' Search API
  permits up to 200 records per page for the `STANDARD` view but only 25
  for `COMPLETE`. Because the weekly quota is charged per request,
  requesting the maximum page size keeps the number of requests, and so
  the quota, as low as possible for a given result set. Lower it only
  where you have a reason to.

- partition:

  Either `"none"` (a single query cell) or `"year"` (one cell per year
  in `years`). Partitioning by year is the recommended way to stay under
  the API's hard limit of `start < 5000`.

- x:

  An object to test or print.

## Value

A tibble of class `scopus_plan`, one row per cell, with columns `cell`,
`query` (field-wrapped), `date` (year range string or `NA`), `year`
(integer or `NA`), `view` and `page_size`. Plan-level settings are
stored as attributes.

`is_scopus_plan()` returns a length-one logical.

## See also

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
to execute a plan,
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
to size it.

## Examples

``` r
scopus_plan("quantum computing", years = 2015:2022, field = "TITLE-ABS-KEY")
#> <scopus_plan> (1 cell, view "STANDARD", partition "none")
#> # A tibble: 1 × 6
#>    cell query                            date       year view     page_size
#> * <int> <chr>                            <chr>     <int> <chr>        <int>
#> 1     1 TITLE-ABS-KEY(quantum computing) 2015-2022    NA STANDARD       200
scopus_plan("immunotherapy", years = 2010:2020, partition = "year")
#> <scopus_plan> (11 cells, view "STANDARD", partition "year")
#> # A tibble: 11 × 6
#>     cell query         date   year view     page_size
#>  * <int> <chr>         <chr> <int> <chr>        <int>
#>  1     1 immunotherapy 2010   2010 STANDARD       200
#>  2     2 immunotherapy 2011   2011 STANDARD       200
#>  3     3 immunotherapy 2012   2012 STANDARD       200
#>  4     4 immunotherapy 2013   2013 STANDARD       200
#>  5     5 immunotherapy 2014   2014 STANDARD       200
#>  6     6 immunotherapy 2015   2015 STANDARD       200
#>  7     7 immunotherapy 2016   2016 STANDARD       200
#>  8     8 immunotherapy 2017   2017 STANDARD       200
#>  9     9 immunotherapy 2018   2018 STANDARD       200
#> 10    10 immunotherapy 2019   2019 STANDARD       200
#> 11    11 immunotherapy 2020   2020 STANDARD       200
```
