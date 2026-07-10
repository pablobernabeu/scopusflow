# Count a set of concepts and their intersections

Counts how many records match each of a named set of concepts, and each
requested intersection of those concepts. This gives a size-of-field
snapshot that shows where a study or a niche sits within a wider
literature: one field may hold thousands of records and another
hundreds, while their intersection holds a dozen. Where
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
tracks topics' shares of a reference over time, this sizes a set of
concepts and their overlap at a single point. Like
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md),
it retrieves totals only, never records, so a whole landscape costs one
request per row of the result.

## Usage

``` r
scopus_intersections(
  concepts,
  intersections = NULL,
  abbrev = NULL,
  sep = " × ",
  years = NULL,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- concepts:

  Named character vector. The names are display labels and the values
  are search terms (wrapped in `field` when one is given) or complete
  field-tagged query expressions (used as-is). The labels must be
  unique.

- intersections:

  Optional list of character vectors, each naming two or more distinct
  concept labels whose intersection should be counted, for example
  `list(c("A", "B"), c("A", "B", "C"))`. A single character vector is
  taken as one intersection.

- abbrev:

  Optional named character vector of short labels, keyed by concept
  label and used only when composing intersection labels, so those rows
  stay readable while the concept rows keep their full names.

- sep:

  Separator joining the member labels in an intersection label. Defaults
  to a multiplication sign between spaces.

- years:

  Optional integer vector of publication years to restrict to.

- field:

  Optional 'Scopus' field tag wrapped around each concept value that is
  not already a complete field-tagged expression (see
  [`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)).

- view:

  Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` adds an `authkeywords`
  column to
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)/[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  output (see
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
  at no extra cost beyond `COMPLETE`'s own smaller page size, which
  already means more requests, and so more quota, for the same number of
  records.

- api_key, inst_token:

  Optional credentials, resolved by default from options or environment
  variables (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported.

## Value

A tibble of class `scopus_intersections` with one row per concept and
per intersection: `label` (the display label), `query` (the exact query
counted), `n` (the count, as a double so very large totals are exact),
`type` (`"concept"` or `"intersection"`), `size` (the number of member
concepts) and `members` (the member labels, joined by `"; "`). A row
whose response omits a total is recorded as `NA`, with a warning. The
`years` restriction, when given, is stored in the `years` attribute.

## Details

A concept value that already reads as a complete field-tagged
expression, such as `"TITLE(virtual reality)"`, is used exactly as
given, so `field` never wraps it a second time, which the API would
reject as malformed. Any other value is treated as a bare term and
wrapped in `field` when one is supplied. An intersection is counted by
joining its members' queries with `AND`, each part in parentheses.

## API access

This performs one count request per concept and per intersection, so it
requires a valid API key and internet access; see the *API access*
section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md).

## See also

[`plot_scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_intersections.md)
to visualise the result, and
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
for a single query.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
sets <- scopus_intersections(
  concepts = c(
    "semantic priming"  = "semantic priming",
    "mental simulation" = "mental simulation"
  ),
  intersections = list(c("semantic priming", "mental simulation")),
  field = "TITLE-ABS-KEY"
)
sets
}
```
