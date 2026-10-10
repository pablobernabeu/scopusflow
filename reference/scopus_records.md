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

# S3 method for class 'scopus_records'
autoplot(object, ...)

scopus_records(x, query = NA_character_, view = NULL)

is_scopus_records(x)
```

## Arguments

- x:

  An object to test.

- ...:

  Ignored, for S3 compatibility.

- object:

  A scopus_records object (for the `autoplot()` method).

- query:

  Optional character scalar recording the query that produced the
  entries, kept in the `query` column for provenance.

- view:

  Optional character scalar naming the Search API view the entries came
  from. Pass `"COMPLETE"` to read `authors` from the author list that
  view carries and to add an `authkeywords` column (see below). Any
  other value, including the default `NULL`, reads the first author and
  reproduces the original columns exactly, so existing callers that
  never mention `view` see no change at all.
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  and
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  pass this through automatically.

## Value

The coercion methods return a plain
[tibble](https://tibble.tidyverse.org/reference/tibble.html) or data
frame with the same columns and the `scopus_records` class removed.

The `autoplot()` method returns a
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
of the records per year.

A tibble of class `scopus_records` with the columns `entry_number`
(integer), `scopus_id` (character), `doi` (character), `title`
(character), `authors` (character, the author list under
`view = "COMPLETE"` and the first author otherwise, as *Details*
explains), `year` (integer, the leading four digits of the cover date),
`date` (character, the ISO cover date), `publication` (character, the
source title), `citations` (integer) and `query` (character). A missing
field becomes `NA`, and an empty result set yields a zero-row tibble
with the same columns. When `view = "COMPLETE"`, an `authkeywords`
column is added: the author-supplied keywords the 'Scopus' Search API
returns under that view, as a single string in 'Scopus' own
`" | "`-delimited form (`NA` when the document has none, or when the API
omits the field for a given key's entitlement; see *Details*).

`is_scopus_records()` returns a length-one logical.

## Details

The 'Scopus' API signals an empty result set with a single sentinel
entry that carries an `error` field and no identifier. This is detected
and turned into a zero-row result, with no spurious record in it, while
a genuine record that also carries a per-entry `error` annotation is
kept.

What `authors` holds depends on the view. The Search API's `dc:creator`
field is the first author alone under either view, in the indexed form
'Scopus' uses (`"Zhang F."`). The author list arrives only under
`view = "COMPLETE"`, as the `author` objects Elsevier's views table
lists for that view alone. A `STANDARD` record therefore names its first
author, and a tally of `STANDARD` authors counts first authorships. A
harvest records its view in the `view` attribute (see
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)),
and
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
and
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)
say once per session that a set retrieved under `STANDARD` names first
authors only. Under `COMPLETE`, each author is written as
`"Surname, Given"`, as the surname alone when the given name is missing
or empty, or as the indexed name when the surname is missing. Exact
duplicates are dropped. The API lists at most 100 authors per record,
and its `author-count` field gives the total. A record whose list names
nobody falls back to `dc:creator`. The Python twin builds the same
string from pybliometrics' `author_names` in the common case, and parts
company at two edges. Where an author object lacks a `surname` or
`given-name` key, pybliometrics builds no list, so that twin keeps the
first author while this one lists every author. Where a surname is null
or empty, pybliometrics writes the given name after a bare comma, and
this package uses the indexed name.

Author keywords are only ever present under `view = "COMPLETE"`; the
`STANDARD` view (the default throughout the package) never includes
them, and `authkeywords` is not added to the output at all in that case,
so existing code that inspects the column names of a `STANDARD`-view
result is unaffected. Even under `COMPLETE` view, some 'Scopus' API keys
do not return populated author keywords (this was observed directly
against a live, otherwise fully-entitled key during development, on
documents that do carry author keywords in 'Scopus' itself); if your own
keywords come back all `NA`, the field is most likely gated by your
account's entitlement rather than genuinely absent, and is worth raising
with your 'Scopus'/Elsevier account contact.

## Examples

``` r
# An entry in the shape the Search API returns it. The fields are those of
# a real article, taken from the bundled `example_records`, which stands in
# for a harvest because 'Scopus' records may not be redistributed. It
# carries no 'Scopus' identifier, so `dc:identifier` is absent and
# `scopus_id` comes back NA, as it does for any unidentified record.
raw <- list(entry = list(
  list(
    `prism:doi` = "10.1021/am509065d",
    `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
    `dc:creator` = "Zhiwei Peng",
    `prism:publicationName` = "ACS Applied Materials & Interfaces",
    `prism:coverDate` = "2015-01-13",
    `citedby-count` = "469"
  )
))
scopus_records(raw, query = "TITLE-ABS-KEY(graphene supercapacitor)")
#> <scopus_records> 1 record
#> query: "TITLE-ABS-KEY(graphene supercapacitor)"
#> # A tibble: 1 × 9
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 NA        10.102… Flex… Zhiwei…  2015 2015… ACS Applie…       469

# Under COMPLETE view an entry may also carry author keywords, which the
# Search API returns in its own " | "-delimited form. The bundled corpus
# holds no keywords, so the ones below are illustrative.
raw_complete <- list(entry = list(
  list(
    `prism:doi` = "10.1021/am509065d",
    `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
    authkeywords = "graphene | supercapacitor | energy storage"
  )
))
scopus_records(raw_complete, view = "COMPLETE")
#> <scopus_records> 1 record
#> # A tibble: 1 × 11
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 NA        10.102… Flex… NA         NA NA    NA                 NA
#> # ℹ 2 more variables: query <chr>, authkeywords <chr>

# An object already in this schema is returned unchanged.
identical(scopus_records(example_records), example_records)
#> [1] TRUE
```
