# Tracking how a literature changes between retrievals

``` r

library(scopusflow)
```

A literature is a moving target. Run the same search a few months apart
and the result will have grown, and perhaps lost a record that was
re-indexed. This article shows how to see exactly what changed and how
to merge retrievals safely. It runs offline on the bundled
`example_records`, a corpus of 138 real journal articles the package
ships because ‘Scopus’ records may not be redistributed. That corpus is
a complete harvest of one query from 2015 to 2024, so a pull that
stopped at 2023 and a later one that reaches 2024 are both genuine
slices of the same search.

## The baseline

The first retrieval ran at the end of 2023 and returned everything
published up to then.

``` r

baseline <- example_records[example_records$year <= 2023, ]
nrow(baseline)
#> [1] 124
```

## A later retrieval

A year on, the search is repeated. It now picks up the 2024 papers, and
one record that was present the first time has since been re-indexed and
no longer matches.

``` r

later <- example_records[-1, ]
nrow(later)
#> [1] 137
```

## What changed

[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
reports which DOIs were added, removed or unchanged between the two
retrievals, and prints the counts in each category.

``` r

changes <- scopus_diff_dois(old = baseline, new = later)
print(changes)
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

The newly indexed papers come back as `added`, the records present both
times as `unchanged`, and anything dropped from the later pull as
`removed`. The counts work out at fourteen added, one removed and 112
unchanged: fourteen because that is how many of the 2024 papers carry a
DOI, and 112 rather than 113 because the re-indexed record is no longer
among them. Records without a DOI cannot be tracked this way at all,
which is one reason to prefer the ‘Scopus’ identifier when there is one.

To act on one category, filter the table, which is an ordinary tibble.

``` r

head(changes[changes$status == "added", ])
```

| doi                           | status |
|:------------------------------|:-------|
| 10.1002/adfm.202315137        | added  |
| 10.1002/asia.202400548        | added  |
| 10.1002/slct.202302535        | added  |
| 10.1016/j.cej.2024.148822     | added  |
| 10.1016/j.diamond.2024.110842 | added  |
| 10.1016/j.isci.2024.111696    | added  |

## Merging without duplicates

To keep a cumulative set across retrievals, combine them.
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
renumbers the records and, with `dedupe = TRUE`, keeps each one once by
‘Scopus’ identifier or DOI, so the records the two pulls share are not
doubled.

``` r

combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
#> [1] 149
```

That is 149 rows for 138 distinct articles, and the gap is instructive.
These records carry no ‘Scopus’ identifier, not having come from
‘Scopus’, so de-duplication falls back to the DOI. The eleven that
arrived without one have no key to match on, and so survive in both
copies. A live harvest carries an identifier on every record, so the
same call on two real pulls returns each article once.

The base [`c()`](https://rdrr.io/r/base/c.html) method concatenates
record sets directly, renumbering but without de-duplicating, so it is
the building block that
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
adds the duplicate handling to.

``` r

stacked <- c(baseline, later)
nrow(stacked)
#> [1] 261
```

## Keeping a record of each pull

Saving each retrieval lets you compare against it next time. The `.rds`
form round-trips exactly.

``` r

path <- file.path(tempdir(), "baseline.rds")
write_scopus_records(baseline, path)
identical(read_scopus_records(path), baseline)
#> [1] TRUE
```

In a live setting the later retrieval would come from the API rather
than from a slice of the bundled corpus, with everything else unchanged.

``` r

later <- scopus_fetch("graphene supercapacitor", field = "TITLE-ABS-KEY")
scopus_diff_dois(old = read_scopus_records(path), new = later)
```
