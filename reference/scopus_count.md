# Count 'Scopus' results for a query

Retrieves only the total number of records matching a query, without
downloading them. This is the inexpensive way to size a retrieval before
committing quota. The count can guide how to partition a
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
or simply report how large a topic is.

## Usage

``` r
scopus_count(
  query,
  years = NULL,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  api_key = NULL,
  inst_token = NULL
)
```

## Arguments

- query:

  Character scalar. The base search expression.

- years:

  Optional integer vector of publication years to restrict to.

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

## Value

A single number giving the total number of matching records, or `NA`
when the API reports no total. It is returned as a double so that very
large totals are represented exactly rather than overflowing, with the
parsed quota (see
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md))
attached as the `quota` attribute so a workflow can pace itself off a
count.

## API access

This function performs a network request and therefore requires a valid
API key and internet access. When no key is configured it raises a
`scopus_error_no_key` condition, and other failures raise typed
`scopus_error` subclasses such as `scopus_error_rate_limit`. A
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) around the call
lets a workflow handle these gracefully.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
scopus_count("CRISPR", years = 2015:2020, field = "TITLE-ABS-KEY")
}
```
