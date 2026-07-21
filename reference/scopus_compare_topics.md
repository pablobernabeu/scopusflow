# Compare publication trends across topics

Compares how often a set of *comparison* topics co-occur with a
*reference* topic over time. For each year and each comparison term, the
number of records matching the reference combined with that term is
expressed as a percentage of the records matching the reference alone.
This reveals which sub-topics are growing or shrinking within a
literature.

## Usage

``` r
scopus_compare_topics(
  reference_query,
  comparison_terms,
  years,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- reference_query:

  Character scalar. The reference topic that anchors the comparison (for
  example `"language learning"`).

- comparison_terms:

  Character vector of topics to compare against the reference (for
  example `c("effect size", "Bayesian")`). Each is combined with the
  reference using a logical AND.

- years:

  Integer vector of publication years to span (for example `2015:2020`).

- field:

  Optional 'Scopus' field tag applied to every component of every query
  (see
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- view:

  Either `"STANDARD"` or `"COMPLETE"`.

- api_key, inst_token:

  Optional credentials (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported.

## Value

A tibble of class `scopus_comparison` with the columns `query` (the full
query used), `query_type` (`"reference"` or `"comparison"`),
`abridged_query` (the topic label for plotting), `year`, `n` (records
that year), `reference_n` (reference records that year),
`comparison_percentage` (`100 * n / reference_n`, or `NA` when
`reference_n` is 0) and `average_comparison_percentage` (the same ratio
computed on period totals). Comparison rows are sorted by descending
average percentage.

## API access

This performs one count request per term per year, so it requires a
valid API key and internet access. The *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
gives the details. A modest number of terms and years keeps the call
within quota.

## See also

[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
to visualise the result.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
cmp <- scopus_compare_topics(
  reference_query = "deep learning",
  comparison_terms = c("computer vision", "drug discovery"),
  years = 2018:2022,
  field = "TITLE-ABS-KEY"
)
cmp
}
# The shape of the return value, built offline so it runs without a key.
years <- 2018:2022
ref_n <- c(4200, 5600, 7100, 8600, 10200)
counts <- list(`computer vision` = c(1500, 2000, 2500, 3000, 3600),
               `drug discovery`  = c(180, 260, 370, 500, 660))
cmp <- tibble::tibble(
  query = "TITLE-ABS-KEY(deep learning)",
  query_type = c(rep("reference", length(years)),
                 rep("comparison", length(counts) * length(years))),
  abridged_query = c(rep("deep learning", length(years)),
                     rep(names(counts), each = length(years))),
  year = rep(years, length(counts) + 1),
  n = c(ref_n, unlist(counts, use.names = FALSE)),
  reference_n = rep(ref_n, length(counts) + 1),
  comparison_percentage = 100 * c(ref_n, unlist(counts, use.names = FALSE)) /
    rep(ref_n, length(counts) + 1),
  average_comparison_percentage = c(rep(100, length(years)),
                                    rep(c(35.3, 5.4), each = length(years)))
)
class(cmp) <- c("scopus_comparison", class(cmp))
cmp
#> <scopus_comparison> (3 topics)
#> # A tibble: 15 × 8
#>    query query_type abridged_query  year     n reference_n comparison_percentage
#>    <chr> <chr>      <chr>          <int> <dbl>       <dbl>                 <dbl>
#>  1 TITL… reference  deep learning   2018  4200        4200                100   
#>  2 TITL… reference  deep learning   2019  5600        5600                100   
#>  3 TITL… reference  deep learning   2020  7100        7100                100   
#>  4 TITL… reference  deep learning   2021  8600        8600                100   
#>  5 TITL… reference  deep learning   2022 10200       10200                100   
#>  6 TITL… comparison computer visi…  2018  1500        4200                 35.7 
#>  7 TITL… comparison computer visi…  2019  2000        5600                 35.7 
#>  8 TITL… comparison computer visi…  2020  2500        7100                 35.2 
#>  9 TITL… comparison computer visi…  2021  3000        8600                 34.9 
#> 10 TITL… comparison computer visi…  2022  3600       10200                 35.3 
#> 11 TITL… comparison drug discovery  2018   180        4200                  4.29
#> 12 TITL… comparison drug discovery  2019   260        5600                  4.64
#> 13 TITL… comparison drug discovery  2020   370        7100                  5.21
#> 14 TITL… comparison drug discovery  2021   500        8600                  5.81
#> 15 TITL… comparison drug discovery  2022   660       10200                  6.47
#> # ℹ 1 more variable: average_comparison_percentage <dbl>
```
