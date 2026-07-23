# Compare two DOI retrievals

Identifies which DOIs were added, removed or unchanged between an
earlier and a later retrieval. This supports change tracking: re-running
a search later and seeing exactly what is new.

## Usage

``` r
scopus_diff_dois(old, new)
```

## Arguments

- old, new:

  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  objects or character vectors of DOIs, representing the earlier (`old`)
  and later (`new`) retrievals.

## Value

A tibble of class `scopus_doi_diff` with columns `doi` and `status`,
where `status` is an ordered factor with levels `"added"` (in `new`
only), `"removed"` (in `old` only) and `"unchanged"` (in both). Rows are
sorted by status then DOI, and printing shows the counts in each
category.

## See also

[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)

## Examples

``` r
# A baseline retrieval and the same search re-run a year later, both taken
# from the bundled corpus of real articles: the second pull has gained the
# 2024 records and lost the first one to re-indexing.
baseline <- example_records[example_records$year <= 2023, ]
later <- example_records[-1, ]
scopus_diff_dois(old = baseline, new = later)
#> <scopus_doi_diff> 14 added, 1 removed, 112 unchanged
#> # A tibble: 127 × 2
#>    doi                            status
#>    <chr>                          <fct> 
#>  1 10.1002/adfm.202315137         added 
#>  2 10.1002/asia.202400548         added 
#>  3 10.1002/slct.202302535         added 
#>  4 10.1016/j.cej.2024.148822      added 
#>  5 10.1016/j.diamond.2024.110842  added 
#>  6 10.1016/j.isci.2024.111696     added 
#>  7 10.1016/j.jallcom.2024.175000  added 
#>  8 10.1016/j.jallcom.2024.177248  added 
#>  9 10.1016/j.jpowsour.2024.234127 added 
#> 10 10.1016/j.jpowsour.2024.236149 added 
#> # ℹ 117 more rows
```
