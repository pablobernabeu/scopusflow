# Tracking how a literature changes between retrievals

``` r

library(scopusflow)
```

A literature is a moving target. Run the same search a few months apart
and the result will have grown, and perhaps lost a record that was
re-indexed. This article shows how to see exactly what changed and how
to merge retrievals safely. It runs offline: the baseline is the bundled
`example_records`, and the later retrieval is built from a synthetic
entry list of the same shape the API returns.

## The baseline

``` r

baseline <- example_records
nrow(baseline)
#> [1] 6
```

## A later retrieval

Months on, the search is repeated. Here we mimic that second pull: it
keeps most of the original records, drops one that was re-indexed and
adds two new papers.

``` r

later_raw <- list(entry = list(
  # carried over from the baseline
  list(`dc:identifier` = "SCOPUS_ID:85000000001", `prism:doi` = "10.1038/s41586-019-0001-1",
       `dc:title` = "Genome editing with CRISPR-Cas9: principles and applications",
       `prism:coverDate` = "2019-04-12"),
  list(`dc:identifier` = "SCOPUS_ID:85000000002", `prism:doi` = "10.1038/s41586-020-0002-2",
       `dc:title` = "Deep learning for medical image analysis: a review",
       `prism:coverDate` = "2020-02-20"),
  list(`dc:identifier` = "SCOPUS_ID:85000000006", `prism:doi` = "10.1103/PhysRevLett.116.061102",
       `dc:title` = "Observation of gravitational waves from a binary black hole merger",
       `prism:coverDate` = "2016-02-11"),
  # newly indexed since the baseline
  list(`dc:identifier` = "SCOPUS_ID:85000000007", `prism:doi` = "10.1126/science.abc1234",
       `dc:title` = "A room-temperature superconductor candidate",
       `prism:coverDate` = "2023-03-08"),
  list(`dc:identifier` = "SCOPUS_ID:85000000008", `prism:doi` = "10.1038/s41586-023-0008-8",
       `dc:title` = "Large language models for scientific discovery",
       `prism:coverDate` = "2023-06-01")
))
later <- scopus_records(later_raw, query = "illustrative later retrieval")
nrow(later)
#> [1] 5
```

## What changed

[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
reports which DOIs were added, removed or unchanged between the two
retrievals, and prints the counts in each category.

``` r

changes <- scopus_diff_dois(old = baseline, new = later)
changes
```

| doi                            | status    |
|:-------------------------------|:----------|
| 10.1038/s41586-023-0008-8      | added     |
| 10.1126/science.abc1234        | added     |
| 10.1002/adma.202100001         | removed   |
| 10.1016/S1470-2045(20)30013-9  | removed   |
| 10.1038/s41558-018-0085-1      | removed   |
| 10.1038/s41586-019-0001-1      | unchanged |
| 10.1038/s41586-020-0002-2      | unchanged |
| 10.1103/PhysRevLett.116.061102 | unchanged |

The newly indexed papers come back as `added`, the records present both
times as `unchanged`, and anything dropped from the later pull as
`removed`. To act on one category, filter the table.

``` r

changes[changes$status == "added", ]
```

| doi                       | status |
|:--------------------------|:-------|
| 10.1038/s41586-023-0008-8 | added  |
| 10.1126/science.abc1234   | added  |

## Merging without duplicates

To keep a cumulative set across retrievals, combine them.
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
renumbers the records and, with `dedupe = TRUE`, keeps each one once by
‘Scopus’ identifier or DOI, so the records the two pulls share are not
doubled.

``` r

combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
#> [1] 8
```

The base [`c()`](https://rdrr.io/r/base/c.html) method concatenates
record sets directly, renumbering but without de-duplicating, so it is
the building block that
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
adds the duplicate handling to.

``` r

stacked <- c(baseline, later)
nrow(stacked)
#> [1] 11
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
than a synthetic list, with everything else unchanged.

``` r

later <- scopus_fetch("CRISPR", field = "TITLE-ABS-KEY")
scopus_diff_dois(old = read_scopus_records(path), new = later)
```
