# Combine record sets into one

Binds several
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
objects into a single one, renumbering `entry_number` across the result
and, optionally, dropping duplicates. This is the safe way to merge
separate fetches: plain [`rbind()`](https://rdrr.io/r/base/cbind.html)
would leave duplicate entry numbers, and
[`c()`](https://rdrr.io/r/base/c.html) would return a list.

## Usage

``` r
scopus_combine(..., dedupe = FALSE)

# S3 method for class 'scopus_records'
c(x, ...)
```

## Arguments

- ...:

  Two or more
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  objects, or a single list of them.

- dedupe:

  Logical. When `TRUE`, records sharing a 'Scopus' identifier, or
  failing that a DOI (compared case-insensitively), are kept once.

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  object (for the [`c()`](https://rdrr.io/r/base/c.html) method).

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble. Per-retrieval attributes such as `total_results` are not carried
over, since they describe a single fetch.

## See also

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
which combines plan cells the same way.

## Examples

``` r
# Merging a set with itself and de-duplicating recovers the distinct records.
scopus_combine(example_records, example_records, dedupe = TRUE)
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
```
