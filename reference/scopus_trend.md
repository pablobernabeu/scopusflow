# Annual publication counts for a query

Counts how many records match a query in each year, giving the size of a
literature over time. It is the single-query companion to
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md):
where the comparison shows topics as a share of a reference, this shows
the absolute count.

## Usage

``` r
scopus_trend(
  query,
  years,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- query:

  Character scalar. The base search expression.

- years:

  Integer vector of publication years to count over, for example
  `2010:2020`.

- field:

  Optional 'Scopus' field tag to wrap the query in (see
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- view:

  Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` adds an `authkeywords`
  column to
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)/[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  output (see
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
  at no extra cost beyond `COMPLETE`'s own smaller page size, which
  already means more requests, and so more quota, for the same number of
  records.

- api_key, inst_token:

  Optional credentials, resolved by default from options or environment
  variables (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported.

## Value

A tibble of class `scopus_trend` with columns `query` (the field-wrapped
query), `year` (integer) and `n` (the count that year, as a double so
very large counts are exact). A year whose response omits a total is
recorded as `NA` (with a warning) and contributes nothing to the total
shown by [`print()`](https://rdrr.io/r/base/print.html).

## API access

This performs one count request per year, so it requires a valid API key
and internet access; see the *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md).

## See also

[`plot_scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md),
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
tr <- scopus_trend("graphene", years = 2010:2020, field = "TITLE-ABS-KEY")
tr
}
# The shape of the return value, built offline so it runs without a key.
years <- 2010:2020
tr <- tibble::tibble(
  query = "TITLE-ABS-KEY(graphene)",
  year = years,
  n = c(1900, 3400, 5200, 7100, 9000, 10400, 11800, 12600, 13500, 14100, 14800)
)
class(tr) <- c("scopus_trend", class(tr))
tr
#> <scopus_trend> (11 years, 103,800 records)
#> # A tibble: 11 × 3
#>    query                    year     n
#>    <chr>                   <int> <dbl>
#>  1 TITLE-ABS-KEY(graphene)  2010  1900
#>  2 TITLE-ABS-KEY(graphene)  2011  3400
#>  3 TITLE-ABS-KEY(graphene)  2012  5200
#>  4 TITLE-ABS-KEY(graphene)  2013  7100
#>  5 TITLE-ABS-KEY(graphene)  2014  9000
#>  6 TITLE-ABS-KEY(graphene)  2015 10400
#>  7 TITLE-ABS-KEY(graphene)  2016 11800
#>  8 TITLE-ABS-KEY(graphene)  2017 12600
#>  9 TITLE-ABS-KEY(graphene)  2018 13500
#> 10 TITLE-ABS-KEY(graphene)  2019 14100
#> 11 TITLE-ABS-KEY(graphene)  2020 14800
```
