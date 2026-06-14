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
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- query:

  Character scalar. The base search expression.

- max_results:

  Maximum number of records to retrieve. Defaults to `Inf`, meaning all
  available records up to the API ceiling. The 'Scopus' Search API
  refuses offsets of 5000 or more, so a single query yields at most 5000
  records. To go beyond that, partition the search by year with
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md).

- view:

  Either `"STANDARD"` or `"COMPLETE"`.

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

  Optional integer vector of publication years to restrict to.

- api_key, inst_token:

  Optional credentials, resolved by default from options or environment
  variables (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported as the retrieval proceeds.

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble. The reported total and the most recent parsed quota are attached
as the `total_results` and `quota` attributes.

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
recs <- scopus_fetch("graphene", field = "TITLE-ABS-KEY", max_results = 50)
recs
}
```
