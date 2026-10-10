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

## Details

Each term is trimmed and, given `.field`, wrapped in that tag, whose
brackets hold the term together. Without a field tag, a term of several
words is put in brackets before two or more terms are joined, because
'Scopus' joins the words of an unquoted term with AND. Joined bare,
`machine learning OR deep learning` would read as
`machine AND (learning OR deep) AND learning`. A term that is already
one operand is left as written: a quoted `"..."` phrase, a braced
`{...}` phrase, a bracketed group or a single field-tagged group such as
`TITLE(deep learning)`. Single words are never bracketed, so
`scopus_query("CRISPR", "Cas9", .op = "OR")` stays `CRISPR OR Cas9`, and
a query composed by an earlier call keeps its meaning when it is joined
again. A term that already opens with a field tag is refused when
`.field` is given, because the API rejects one tag nested inside
another.

## See also

[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md),
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)

## Examples

``` r
scopus_query("climate change", "adaptation", .field = "TITLE-ABS-KEY")
#> [1] "TITLE-ABS-KEY(climate change) AND TITLE-ABS-KEY(adaptation)"
scopus_query("graphene", "supercapacitor", .op = "AND")
#> [1] "graphene AND supercapacitor"
scopus_query("CRISPR", "Cas9", "Cas12", .op = "OR")
#> [1] "CRISPR OR Cas9 OR Cas12"
# Without a field tag, multi-word terms are bracketed and phrases kept as written.
scopus_query("machine learning", "deep learning", .op = "OR")
#> [1] "(machine learning) OR (deep learning)"
scopus_query('"heart attack"', '"myocardial infarction"', .op = "OR")
#> [1] "\"heart attack\" OR \"myocardial infarction\""
```
