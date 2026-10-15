# Assemble a minimal, cross-tool corpus with keywords and references

Takes a
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble, such as the output of
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
or
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
and enriches it with keywords (the author keywords by default, or the
index keywords 'Scopus' assigns) and structured references via Abstract
Retrieval, returning a minimal, uniform shape close to what OpenAlex's
`works` API already returns: an `id`, `title`, `year`, `keywords` (a
list-column of character vectors) and `references` (a list-column of
data frames). This is meant for downstream tools that want to consume
'Scopus' output without writing their own parsing layer, for example for
keyword co-occurrence or citation-network analysis. It does not replace
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md),
which keeps its own established field-mapping convention for users who
want bibliometrix's tag names instead.

## Usage

``` r
scopus_corpus(
  records,
  by = c("doi", "scopus_id"),
  view = c("FULL", "REF"),
  cache_dir = NULL,
  resume = TRUE,
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE,
  keywords = c("author", "index", "both")
)
```

## Arguments

- records:

  A
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble, or any data frame with `doi`, `title` and `year` columns in
  the same shape.

- by:

  Either `"doi"` or `"scopus_id"`, the kind of identifier in `records`
  to look records up by (see
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)).

- view:

  Either `"FULL"` (the default) or `"REF"`, passed to
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md).
  `"FULL"` returns a document's whole bibliography in one request.
  `"REF"` serves it about 40 references per request, which
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
  follows page by page, so a document with *N* references costs
  `ceiling(N / 40)` requests (see its documentation for the details and
  for the entitlement each view needs). The `REF` response also carries
  no keywords of either kind, so under that view only the references are
  requested and `keywords` is empty for every record.

- cache_dir, resume:

  As in
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md):
  an optional directory for per-identifier cache files, and whether an
  existing one is reused. Worth setting for anything beyond a handful of
  records, since this performs one Abstract Retrieval request per
  record, against its own, smaller weekly quota.

- api_key, inst_token:

  Optional credentials (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported.

- keywords:

  Which keywords fill the `keywords` column: `"author"` (the default)
  for the author keywords, `"index"` for the index keywords 'Scopus'
  assigns, or `"both"` for the author keywords followed by each index
  keyword not already among them. The match is on the exact text, so a
  term that differs only in case appears twice. `"index"` and `"both"`
  need `view = "FULL"`, since the `REF` response carries no keywords of
  either kind, and raise a `scopus_error_bad_input` error under `"REF"`
  before any request. Index keywords and author keywords give different
  co-occurrence results, and the *Details* of
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
  describe how each is chosen and the entitlement each depends on.
  Either choice costs the same request per record.

## Value

A tibble with columns `id` (the identifier `records` was looked up by),
`scopus_id` (the document's own 'Scopus' identifier, as Abstract
Retrieval gives it, or the `scopus_id` of `records` where the lookup
failed or the `REF` response omitted it, and `NA` when neither has one),
`title`, `year`, `keywords` (a list-column: a character vector of the
document's keywords of the kind `keywords` names, split out of
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)'s
joined `authkeywords` and `idxterms` strings, empty when the document
has none, the field is unavailable or `view = "REF"`) and `references`
(a list-column: each entry is the `references` data frame
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
returns for that document, with one row per cited work). A record in
`records` whose identifier is `NA` is dropped, with a warning naming how
many.

The number of Abstract Retrieval requests made and the most recently
parsed quota are attached as the `n_requests` and `quota` attributes, as
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
attaches them. Three more attributes carry what
[`write_scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_corpus.md)
records of the corpus's provenance. `query` holds the field-wrapped
search expression of each cell of the records' plan, or, for records
without a plan, the distinct values of their own `query` column.
`retrieved_at` is when the search that found the records ran, and
`keywords` is the kind of keyword chosen. `query` and `retrieved_at` are
absent when `records` carries neither.

## API access

This performs one Abstract Retrieval request per usable record, or one
per page of references under `view = "REF"`, on top of whatever
retrieved `records` in the first place; see
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)'s
*API access* section for the entitlement `view = "FULL"`/`"REF"` needs
and how a 403 is handled.

## See also

[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md),
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md),
and
[`write_scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_corpus.md)
to write the corpus for theoryforge.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
# Costs one Abstract Retrieval request per record, against a smaller,
# separate weekly quota from Search; see the API access section above.
recs <- scopus_fetch("DOI(10.1038/natrevmats.2016.33)", max_results = 1)
corpus <- scopus_corpus(recs)
corpus$keywords[[1]]
corpus$references[[1]]
}
# The offline companion, which needs no key: one row per document, with
# keywords and references as list-columns. The identifiers, titles and
# years are records of the bundled corpus of real articles, which stands in
# for a harvest because 'Scopus' records may not be redistributed. It holds
# no keywords, bibliographies or 'Scopus' identifiers, so the keywords and
# references are illustrative and the identifiers are left NA.
docs <- example_records[order(-example_records$citations), ][1:2, ]
corpus <- tibble::tibble(
  id = docs$doi,
  scopus_id = NA_character_,
  title = docs$title,
  year = docs$year,
  keywords = list(
    c("graphene", "supercapacitor", "energy storage"),
    c("laser-induced graphene", "flexible electronics")
  ),
  references = list(
    tibble::tibble(
      position = c("1", "2"),
      id = NA_character_,
      doi = example_records$doi[3:4],
      title = example_records$title[3:4],
      authors = example_records$authors[3:4],
      source = example_records$publication[3:4],
      year = example_records$year[3:4],
      citedbycount = example_records$citations[3:4]
    ),
    tibble::tibble()
  )
)
corpus
#> # A tibble: 2 × 6
#>   id                         scopus_id title            year keywords references
#>   <chr>                      <chr>     <chr>           <int> <list>   <list>    
#> 1 10.1038/natrevmats.2016.33 NA        Graphene for b…  2016 <chr>    <tibble>  
#> 2 10.1021/am509065d          NA        Flexible and S…  2015 <chr>    <tibble>  
corpus$keywords[[1]]
#> [1] "graphene"       "supercapacitor" "energy storage"
corpus$references[[1]]
#> # A tibble: 2 × 8
#>   position id    doi                     title authors source  year citedbycount
#>   <chr>    <chr> <chr>                   <chr> <chr>   <chr>  <int>        <int>
#> 1 1        NA    10.1021/am509065d       Flex… Zhiwei… ACS A…  2015          469
#> 2 2        NA    10.1016/j.electacta.20… Heav… Vikran… Elect…  2015          195
```
