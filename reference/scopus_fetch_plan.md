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
plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
                    field = "TITLE-ABS-KEY", partition = "year")
dir <- file.path(tempdir(), "graphene-cache")
# `max_results` caps each yearly cell, so the example stays small and
# quota-light; drop it to harvest every record in the plan.
recs <- scopus_fetch_plan(plan, max_results = 25, cache_dir = dir, resume = TRUE)
}
# The offline companion, which needs no key: a record set with the plan
# that describes it attached. 'Scopus' records may not be redistributed, so
# the bundled corpus of real articles stands in for the harvest, and the
# plan describes the same search, one cell per year.
plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
                    field = "TITLE-ABS-KEY", partition = "year")
recs <- example_records
attr(recs, "plan") <- plan
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
attr(recs, "plan")
#> <scopus_plan> (10 cells, view "STANDARD", partition "year")
#> # A tibble: 10 × 6
#>     cell query                                  date   year view     page_size
#>  * <int> <chr>                                  <chr> <int> <chr>        <int>
#>  1     1 TITLE-ABS-KEY(graphene supercapacitor) 2015   2015 STANDARD       200
#>  2     2 TITLE-ABS-KEY(graphene supercapacitor) 2016   2016 STANDARD       200
#>  3     3 TITLE-ABS-KEY(graphene supercapacitor) 2017   2017 STANDARD       200
#>  4     4 TITLE-ABS-KEY(graphene supercapacitor) 2018   2018 STANDARD       200
#>  5     5 TITLE-ABS-KEY(graphene supercapacitor) 2019   2019 STANDARD       200
#>  6     6 TITLE-ABS-KEY(graphene supercapacitor) 2020   2020 STANDARD       200
#>  7     7 TITLE-ABS-KEY(graphene supercapacitor) 2021   2021 STANDARD       200
#>  8     8 TITLE-ABS-KEY(graphene supercapacitor) 2022   2022 STANDARD       200
#>  9     9 TITLE-ABS-KEY(graphene supercapacitor) 2023   2023 STANDARD       200
#> 10    10 TITLE-ABS-KEY(graphene supercapacitor) 2024   2024 STANDARD       200
```
