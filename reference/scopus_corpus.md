# Assemble a minimal, cross-tool corpus with keywords and references

Takes a
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble, such as the output of
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
or
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
and enriches it with author keywords and structured references via
Abstract Retrieval, returning a minimal, uniform shape close to what
OpenAlex's `works` API already returns: an `id`, `title`, `year`,
`keywords` (a list-column of character vectors) and `references` (a
list-column of data frames). This is meant for downstream tools that
want to consume 'Scopus' output without writing their own parsing layer,
for example for keyword co-occurrence or citation-network analysis. It
does not replace
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
  verbose = FALSE
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
  `"FULL"` is recommended: in development, it returned a complete,
  correctly counted reference list for every document tried, while
  `"REF"` returned an inconsistent, sometimes-truncated subset (see
  [`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)'s
  documentation for the details and for the entitlement each view
  needs). The `REF` response also carries no author keywords, so under
  that view only the references are requested and `keywords` is empty
  for every record.

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

## Value

A tibble with columns `id` (the identifier `records` was looked up by),
`title`, `year`, `keywords` (a list-column: a character vector of the
document's author keywords, split out of
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)'s
joined `authkeywords` string, empty when the document has none, the
field is unavailable or `view = "REF"`) and `references` (a list-column:
each entry is the `references` data frame
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
returns for that document, with one row per cited work). A record in
`records` whose identifier is `NA` is dropped, with a warning naming how
many.

## API access

This performs one Abstract Retrieval request per usable record, on top
of whatever retrieved `records` in the first place; see
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)'s
*API access* section for the entitlement `view = "FULL"`/`"REF"` needs
and how a 403 is handled.

## See also

[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md),
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
# Costs one Abstract Retrieval request per record, against a smaller,
# separate weekly quota from Search; see the API access section above.
recs <- scopus_fetch("DOI(10.1038/nature14539)", max_results = 1)
corpus <- scopus_corpus(recs)
corpus$keywords[[1]]
corpus$references[[1]]
}
# The shape of the return value, built offline so it runs without a key:
# one row per document, with keywords and references as list-columns.
corpus <- tibble::tibble(
  id = c("10.1038/nature14539", "10.1126/science.abc1234"),
  title = c("Deep learning", "Porous carbon electrodes at scale"),
  year = c(2015L, 2020L),
  keywords = list(
    c("machine learning", "neural networks", "representation learning"),
    c("graphene", "supercapacitor", "energy storage")
  ),
  references = list(
    tibble::tibble(
      position = c("1", "2"),
      title = c("ImageNet classification with deep convolutional networks",
                "Learning hierarchical features for scene labeling"),
      authors = c("Krizhevsky, A.; Sutskever, I.; Hinton, G.",
                  "Farabet, C.; Couprie, C.; Najman, L.; LeCun, Y."),
      sourcetitle = c("Adv. Neural Inf. Process. Syst.",
                      "IEEE Trans. Pattern Anal. Mach. Intell."),
      publicationyear = c("2012", "2013")
    ),
    tibble::tibble()
  )
)
corpus
#> # A tibble: 2 × 5
#>   id                      title                         year keywords references
#>   <chr>                   <chr>                        <int> <list>   <list>    
#> 1 10.1038/nature14539     Deep learning                 2015 <chr>    <tibble>  
#> 2 10.1126/science.abc1234 Porous carbon electrodes at…  2020 <chr>    <tibble>  
corpus$keywords[[1]]
#> [1] "machine learning"        "neural networks"        
#> [3] "representation learning"
corpus$references[[1]]
#> # A tibble: 2 × 5
#>   position title                             authors sourcetitle publicationyear
#>   <chr>    <chr>                             <chr>   <chr>       <chr>          
#> 1 1        ImageNet classification with dee… Krizhe… Adv. Neura… 2012           
#> 2 2        Learning hierarchical features f… Farabe… IEEE Trans… 2013           
```
