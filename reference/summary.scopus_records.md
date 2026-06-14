# Summarise a set of 'Scopus' records

Gives a compact overview of a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
object, reporting how many records it holds, the span of publication
years they cover, how many distinct sources and Digital Object
Identifiers appear among them and how widely they have been cited. It is
a convenient way to take stock of a retrieval before any closer
analysis.

## Usage

``` r
# S3 method for class 'scopus_records'
summary(object, ...)
```

## Arguments

- object:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble.

- ...:

  Ignored, present for compatibility with the
  [`summary()`](https://rdrr.io/r/base/summary.html) generic.

## Value

A list of class `scopus_records_summary`, with elements `n_records`,
`years` (the earliest and latest year present, each `NA` when no year is
known), `n_sources`, `n_with_doi`, `total_citations`,
`median_citations`, `top_cited` (the title of the most-cited record) and
`top_source` (the most frequent source title). Printing it produces a
short readable report.

## Examples

``` r
summary(example_records)
#> <scopus_records> summary
#> 6 records, from 2016 to 2021.
#> 5 sources, 6 with a DOI.
#> Cited 5505 times in total, median 299 per record.
#> Most frequent source: Nature.
#> Most cited: Observation of gravitational waves from a binary black hole merger.
```
