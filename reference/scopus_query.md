# Build a field-tagged 'Scopus' query

Combines several terms into one 'Scopus' query string, optionally
wrapping each in a field tag and joining them with a boolean operator.
It is a tidier alternative to pasting query fragments together by hand,
which is where field-tag and bracket mistakes tend to creep in.

## Usage

``` r
scopus_query(..., .op = c("AND", "OR", "AND NOT"), .field = NULL)
```

## Arguments

- ...:

  Character terms to combine, for example `"language learning"` and
  `"effect size"`.

- .op:

  The boolean operator joining the terms, one of `"AND"`, `"OR"` or
  `"AND NOT"`.

- .field:

  Optional field tag applied to every term (see
  [`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)).

## Value

A length-one character string suitable for
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md),
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
or the `query` of
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md).

## See also

[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md),
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)

## Examples

``` r
scopus_query("language learning", "effect size", .field = "TITLE-ABS-KEY")
#> [1] "TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size)"
scopus_query("CRISPR", "Cas9", .op = "OR")
#> [1] "CRISPR OR Cas9"
```
