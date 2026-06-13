# Execute a 'Scopus' search plan, with optional caching and resume

Runs every cell of a
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
in turn, optionally caching each cell's result so that an interrupted or
quota-limited retrieval can resume without re-spending quota on the
cells already fetched. Results are accumulated and bound once into a
single
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble.

## Usage

``` r
scopus_fetch_plan(
  plan,
  max_results = Inf,
  cache_dir = NULL,
  resume = TRUE,
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- plan:

  A `scopus_plan` object from
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md).

- max_results:

  Maximum records to retrieve per cell (default `Inf`).

- cache_dir:

  Optional directory for per-cell cache files. The default of `NULL`
  performs no caching. Pass an explicit path you control, or
  [`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md)
  to use a managed, clearable cache under
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html). Caching
  happens only when you opt in through this argument.

- resume:

  Logical. When `TRUE` and `cache_dir` is set, a cell whose cache file
  already exists is loaded from disk rather than fetched again.

- api_key, inst_token:

  Optional credentials (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, per-cell progress is reported.

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble combining all cells, with the originating `plan` attached as the
`plan` attribute.

## API access

Any cell not served from cache requires a valid API key and internet
access. The *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
gives the details.

## See also

[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md),
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md)

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
plan <- scopus_plan("machine translation", years = 2018:2020, partition = "year")
dir <- file.path(tempdir(), "mt-cache")
recs <- scopus_fetch_plan(plan, cache_dir = dir, resume = TRUE)
}
```
