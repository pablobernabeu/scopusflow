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
```
