# Normalise raw 'Scopus' entries to a stable tidy schema

Converts the nested list returned by the 'Scopus' Search API into a
flat, predictable
[tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per record. This shape is the common currency of the package. Both
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
and
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
return it, and the DOI, comparison and export helpers all consume it.

## Usage

``` r
# S3 method for class 'scopus_records'
as_tibble(x, ...)

# S3 method for class 'scopus_records'
as.data.frame(x, ...)

scopus_records(x, query = NA_character_)

is_scopus_records(x)
```

## Arguments

- x:

  An object to test.

- ...:

  Ignored, for S3 compatibility.

- query:

  Optional character scalar recording the query that produced the
  entries, kept in the `query` column for provenance.

## Value

The coercion methods return a plain
[tibble](https://tibble.tidyverse.org/reference/tibble.html) or data
frame with the same columns and the `scopus_records` class removed.

A tibble of class `scopus_records` with the columns `entry_number`
(integer), `scopus_id` (character), `doi` (character), `title`
(character), `authors` (character, the creator names joined with `"; "`
when several are listed), `year` (integer, the leading four digits of
the cover date), `date` (character, the ISO cover date), `publication`
(character, the source title), `citations` (integer) and `query`
(character). A missing field becomes `NA`, and an empty result set
yields a zero-row tibble with the same columns.

`is_scopus_records()` returns a length-one logical.

## Details

The 'Scopus' API signals an empty result set with a single sentinel
entry that carries an `error` field and no identifier. This is detected
and turned into a zero-row result rather than a spurious record, while a
genuine record that also carries a per-entry `error` annotation is kept.

## Examples

``` r
# A minimal entry as the API would return it.
raw <- list(entry = list(
  list(
    `dc:identifier` = "SCOPUS_ID:1",
    `prism:doi` = "10.1000/abc",
    `dc:title` = "An example",
    `dc:creator` = "Doe J.",
    `prism:publicationName` = "Journal of Examples",
    `prism:coverDate` = "2020-05-01",
    `citedby-count` = "7"
  )
))
scopus_records(raw, query = "TITLE(example)")
#> <scopus_records> 1 record
#> query: "TITLE(example)"
#> # A tibble: 1 × 9
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 1         10.100… An e… Doe J.   2020 2020… Journal of…         7
```
