# Most frequent values in a record set

Tallies the most common sources or authors across a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
object. It works on records already in memory, so it makes no network
request.

## Usage

``` r
scopus_top(x, by = c("source", "author"), n = 10L)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble.

- by:

  What to tally: `"source"` (the publication titles) or `"author"`.
  Author strings holding several names separated by `"; "` are split, so
  each contributor is counted once per record.

- n:

  The number of rows to return (the top `n`).

## Value

A tibble of class `scopus_top` with columns `value` and `n`, sorted by
descending count, with ties broken by `value` in byte order so the
result is reproducible across platforms and locales. Exactly `n` rows
are returned (fewer if there are fewer distinct values), so values tied
at the `n`-th place may be cut. The `by` choice is stored in the `by`
attribute.

## See also

[`plot_scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md),
[`summary.scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/summary.scopus_records.md)

## Examples

``` r
scopus_top(example_records, by = "source")
#> # A tibble: 5 × 2
#>   value                       n
#> * <chr>                   <int>
#> 1 Nature                      2
#> 2 Advanced Materials          1
#> 3 Nature Climate Change       1
#> 4 Physical Review Letters     1
#> 5 The Lancet Oncology         1
scopus_top(example_records, by = "author", n = 5)
#> # A tibble: 5 × 2
#>   value         n
#> * <chr>     <int>
#> 1 Abbott B.     1
#> 2 Garcia M.     1
#> 3 Kumar S.      1
#> 4 Okafor N.     1
#> 5 Tanaka H.     1
```
