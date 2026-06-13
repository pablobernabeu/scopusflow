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

A tibble with columns `doi` and `status`, where `status` is one of
`"added"` (in `new` only), `"removed"` (in `old` only) or `"unchanged"`
(in both), sorted by status then DOI.

## See also

[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)

## Examples

``` r
old <- c("10.1/a", "10.1/b")
new <- c("10.1/b", "10.1/c")
scopus_diff_dois(old, new)
#> # A tibble: 3 × 2
#>   doi    status   
#>   <chr>  <chr>    
#> 1 10.1/c added    
#> 2 10.1/a removed  
#> 3 10.1/b unchanged
```
