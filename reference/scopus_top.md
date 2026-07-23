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
at the cut-off rank may be dropped. The `by` choice is stored in the
`by` attribute.

## See also

[`plot_scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_top.md),
[`summary.scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/summary.scopus_records.md)

## Examples

``` r
# The bundled corpus of real articles stands in for a harvest of your own,
# since 'Scopus' records may not be redistributed.
scopus_top(example_records, by = "source")
#> # A tibble: 10 × 2
#>    value                                  n
#>  * <chr>                              <int>
#>  1 ACS Applied Materials & Interfaces     8
#>  2 Journal of Power Sources               5
#>  3 Synthetic Metals                       5
#>  4 Electrochimica Acta                    4
#>  5 Journal of Materials Chemistry A       4
#>  6 Scientific Reports                     4
#>  7 Journal of Alloys and Compounds        3
#>  8 Journal of Energy Storage              3
#>  9 Materials Chemistry and Physics        3
#> 10 Nanotechnology                         3

# That corpus names one author per article, so the author tally counts
# first authors; a live harvest lists every author and splits them.
scopus_top(example_records, by = "author", n = 5)
#> # A tibble: 5 × 2
#>   value                 n
#> * <chr>             <int>
#> 1 Hao Yang              3
#> 2 L. Ojeda              3
#> 3 R. Mendoza            3
#> 4 A.I. Mtz-Enríquez     2
#> 5 Bin Wang              2
```
