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
`median_citations`, `top_cited` (the title of the most-cited record),
`top_source` (the most frequent source title) and `doc_types`.
`doc_types` counts the records of each document-type code, most frequent
first, for a set retrieved with `fields = "extended"` (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)),
and is `NULL` for a set without the `doc_type` column. Printing it
produces a short readable report, which for such a set also says how
many records 'Scopus' labels errata (`er`) or retracted (`tb`). The
counts report the labels 'Scopus' assigns, which do not screen a set for
retractions. The *Extended fields* section of
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
explains why, and what to check a set against.

## Examples

``` r
# The bundled corpus of real articles stands in for a retrieval of your
# own, since 'Scopus' records may not be redistributed.
summary(example_records)
#> <scopus_records> summary
#> 138 records, from 2015 to 2024.
#> 90 sources, 127 with a DOI.
#> Cited 7015 times in total, median 24 per record.
#> Most frequent source: ACS Applied Materials & Interfaces.
#> Most cited: Graphene for batteries, supercapacitors and beyond.
```
