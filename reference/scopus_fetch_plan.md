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
  happens only when you opt in through this argument. A cache directory
  serves one plan: cells are checkpointed by their position in the plan,
  so give each distinct plan its own directory. As a safeguard, a
  checkpoint whose records carry a different query than the plan cell is
  treated as a cache miss, refetched and overwritten; a checkpoint
  written by an older scopusflow that carries no query information is
  loaded as before.

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
plan <- scopus_plan("renewable energy", years = 2015:2022, partition = "year")
dir <- file.path(tempdir(), "energy-cache")
# `max_results` caps each yearly cell, so the example stays small and
# quota-light; drop it to harvest every record in the plan.
recs <- scopus_fetch_plan(plan, max_results = 25, cache_dir = dir, resume = TRUE)
}
# The shape of the return value, assembled offline so it runs without a key:
# a record set with the plan that produced it attached.
plan <- scopus_plan("renewable energy", years = 2015:2022, partition = "year")
recs <- example_records
attr(recs, "plan") <- plan
recs
#> <scopus_records> 6 records
#> query: "illustrative multi-disciplinary sample"
#> # A tibble: 6 × 9
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… Geno… Zhang …  2019 2019… Nature            540
#> 2            2 85000000002 10.1… Deep… Kumar …  2020 2020… Nature            210
#> 3            3 85000000003 10.1… Clim… Okafor…  2018 2018… Nature Cli…       122
#> 4            4 85000000004 10.1… Grap… Tanaka…  2021 2021… Advanced M…        45
#> 5            5 85000000005 10.1… Chec… Garcia…  2020 2020… The Lancet…       388
#> 6            6 85000000006 10.1… Obse… Abbott…  2016 2016… Physical R…      4200
attr(recs, "plan")
#> <scopus_plan> (8 cells, view "STANDARD", partition "year")
#> # A tibble: 8 × 6
#>    cell query            date   year view     page_size
#> * <int> <chr>            <chr> <int> <chr>        <int>
#> 1     1 renewable energy 2015   2015 STANDARD       200
#> 2     2 renewable energy 2016   2016 STANDARD       200
#> 3     3 renewable energy 2017   2017 STANDARD       200
#> 4     4 renewable energy 2018   2018 STANDARD       200
#> 5     5 renewable energy 2019   2019 STANDARD       200
#> 6     6 renewable energy 2020   2020 STANDARD       200
#> 7     7 renewable energy 2021   2021 STANDARD       200
#> 8     8 renewable energy 2022   2022 STANDARD       200
```
