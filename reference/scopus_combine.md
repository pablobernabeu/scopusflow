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
# A baseline retrieval and a later one, merged into a cumulative set. The
# bundled corpus of real articles stands in for both, since 'Scopus'
# records may not be redistributed.
baseline <- example_records[example_records$year <= 2023, ]
later <- example_records
combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
#> [1] 149

# Those records carry no 'Scopus' identifier, so de-duplication falls back
# to the DOI. The eleven that arrived without one cannot be matched, and so
# survive in both copies, which is why 138 distinct articles come back as
# 149 rows.
sum(is.na(example_records$doi))
#> [1] 11
```
