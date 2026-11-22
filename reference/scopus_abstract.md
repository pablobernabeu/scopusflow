# Retrieve abstracts and richer metadata

Fetches the abstract text and core metadata for one or more records from
the Elsevier 'Scopus' Abstract Retrieval API. This complements the
Search API used elsewhere in the package: a search returns many records
with a few fields each, whereas this returns the fuller record,
including the abstract, for a known identifier. Passing `include` adds
the author keywords, the index keywords and the document's reference
list, or any of them, to the same request.

## Usage

``` r
scopus_abstract(
  ids,
  by = c("doi", "scopus_id"),
  view = "META_ABS",
  include = character(),
  cache_dir = NULL,
  resume = TRUE,
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE
)
```

## Arguments

- ids:

  Character vector of identifiers to look up, either Digital Object
  Identifiers or 'Scopus' record identifiers (with or without the
  `"SCOPUS_ID:"` prefix), according to `by`.

- by:

  Either `"doi"` or `"scopus_id"`, the kind of identifier in `ids`.

- view:

  The Abstract Retrieval view to request: `"META_ABS"` (the default),
  `"META"`, `"REF"` or `"FULL"`, or `NULL`. `"META_ABS"` is the view
  Elsevier documents as carrying the abstract with the core metadata.
  `NULL` sends no `view` parameter, as version 0.4.0 and earlier did,
  and leaves the choice to the API. Elsevier documents its default as
  `"META"`, a view without the abstract, although the API has returned
  the abstract to a request without a view. Retrieving
  `include = "references"` requires `view = "FULL"` or `view = "REF"`.
  *Details* says how the two differ and which to prefer.

- include:

  Optional character vector naming extra fields to retrieve in the same
  request: any of `"references"`, `"keywords"` (the author keywords) and
  `"index_terms"` (the index keywords 'Scopus' assigns). `"references"`
  requires `view = "FULL"` or `view = "REF"`, and `"keywords"` and
  `"index_terms"` require `view = "FULL"`, since the `REF` response
  carries neither kind of keyword. Both views need an entitlement
  separate from ordinary abstract access and from 'Scopus' Search
  access. Elsevier's documentation adds that some fields, such as the
  index keywords, are available only on request, even when the view
  itself is accessible. See *Details*.

- cache_dir:

  Optional directory for per-identifier cache files, as in
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md).
  `NULL` (the default) performs no caching. Set it whenever `include` is
  used. Abstract Retrieval draws on its own weekly quota, separate from
  and smaller than Search's, and every identifier costs at least one
  request, so re-running an interrupted batch without a cache spends
  that quota again. A `cache_dir` that cannot be written is refused
  before any request, and a checkpoint that cannot be written all the
  same gives a warning and keeps the row, as in
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md).

- resume:

  Logical. When `TRUE` (the default) and `cache_dir` is set, an
  identifier whose cache file already exists is loaded from disk,
  sparing a second request for it. A cache file that cannot be read
  back, for example one left half-written by an interrupted run, is
  retrieved again with a `scopus_warning_cache_unreadable` warning, and
  the batch carries on. One holding a different identifier, since
  distinct identifiers can share a cache filename, is retrieved again
  with a `scopus_warning_cache_mismatch` warning.

- api_key, inst_token:

  Optional credentials (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, progress is reported.

## Value

A tibble of class `scopus_abstracts`, one row per identifier, with
columns `id` (the input identifier), `scopus_id`, `doi`, `title`,
`abstract`, `publication`, `year` and `citations`. A field the API does
not return is `NA`. An identifier that cannot be retrieved (for example
one not in 'Scopus') yields a row of `NA`s with a warning, so a batch is
not lost to a single failure. The number of Abstract Retrieval requests
made and the most recently parsed quota (see
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md))
are attached as the `n_requests` and `quota` attributes, since a
retrieval here costs at least one request for each identifier (one for
each page of references under `view = "REF"`), where a search returns
many records with each request.

When `include` names `"keywords"`, an `authkeywords` column is added:
the document's author-supplied keywords, joined the same way as
`authors` (`"; "`-separated), or `NA` when the document has none, or
when the API omits the field for a given key's entitlement (see
*Details*).

When `include` names `"index_terms"`, an `idxterms` column is added
after any `authkeywords`: the index keywords of the document, joined by
`"; "`, or `NA` when the response carries none. An entry without text is
dropped.

When `include` names `"references"`, a `references` list-column is
added: one data frame per document, with one row per cited work, so that
no joined string has to be split again. Its columns are `position` (the
reference's place in the bibliography), `id` (the 'Scopus' identifier of
the cited work, when resolved), `doi`, `title`, `authors`, `source` (the
journal or other venue), `year` and `citedbycount` (the cited work's own
citation count, given only under `view = "REF"` and `NA` under
`"FULL"`). A document with no resolvable references yields a zero-row
data frame, so the column can always be unnested.

## Details

Retrieving references needs Abstract Retrieval's `FULL` or `REF` view,
and keywords need `FULL`. `FULL` returns the whole bibliography in one
request. `REF` serves it a page at a time, about 40 references per
request, so `scopus_abstract()` follows the view's `startref` parameter
until it holds as many references as the document reports, as
pybliometrics does. A `REF` document with *N* references therefore costs
`ceiling(N / 40)` requests, each counted in `n_requests`, which makes
`"FULL"` the cheaper view when your entitlement allows it. Elsevier's
guide numbers `startref` from 0 and pybliometrics from 1, and which of
the two the API follows has not been confirmed. Paging stops on an empty
page, on a page that adds no new reference or after as many pages as the
first page's length implies, so neither numbering can make it loop or
repeat references. When the number of references held still differs from
the document's reported count, a `scopus_warning_incomplete_references`
warning says so. An identifier whose later page fails is a failed
retrieval: it gets a row of `NA`s with a warning and is not
checkpointed.

A key entitled to the `COMPLETE` view of 'Scopus' Search (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
and the `FULL` view of Abstract Retrieval has received no author
keywords under either, for documents that carry them in 'Scopus'. If
your keywords come back all `NA`, the field is most likely missing from
your key's entitlement, and your Elsevier account contact can say
whether it can be added.

Index keywords are the other kind 'Scopus' records. Authors choose their
own keywords, whereas 'Scopus' chooses the index keywords and
standardises them to vocabularies derived from thesauri Elsevier owns or
licenses, with synonyms, spellings and plurals brought together. The two
kinds therefore give different keyword co-occurrence results, and a
study should say which it used. Elsevier's guide lists index keywords in
the `FULL` view as not available by default, so whether they arrive
depends on your key's entitlement as well. They did arrive for the key
that received no author keywords.

## API access

This performs one request per identifier, or one per page of references
under `view = "REF"` with `include = "references"`. It requires a valid
API key and internet access, and access to abstracts, to the `FULL` and
`REF` views in particular, can also depend on your entitlement. A view
or field your key is not entitled to raises a `scopus_error_forbidden`
condition with a message that names the view and says whom to contact.
Because entitlement is a property of the account, retrieval stops at the
first such failure, so the same refusal is not repeated for every
remaining identifier.

A spent weekly quota (HTTP 429 marked `QUOTA_EXCEEDED`) also stops the
requests, but returns what the batch holds, since it usually arrives
part-way through. The rows already retrieved are kept, and each
identifier not retrieved gets a row of `NA`s that is not checkpointed.
One `scopus_warning_quota_exceeded` warning names the identifier
reached, how many were not retrieved and when the quota resets. A
checkpoint in `cache_dir` is still read after the stop. See the *API
access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
for the other conditions that may be raised.

## See also

[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md),
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md),
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
to assemble a minimal corpus of keywords and references across many
documents.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
# One record of the bundled corpus, looked up for real.
scopus_abstract(scopus_extract_dois(example_records)[1])

# Author keywords and a structured reference list, in the same request.
# This costs one Abstract Retrieval request per identifier, from a weekly
# quota separate from and smaller than Search's. The API access section
# above says which entitlement it needs.
rich <- scopus_abstract(
  "10.1038/natrevmats.2016.33",
  view = "FULL", include = c("references", "keywords")
)
rich$references[[1]]
}
# The same shape offline, with no key. The identifiers, titles, sources and
# citation counts are two records of the bundled corpus of real articles. A
# live call adds the abstract text, so it is left as a placeholder here, as
# is the 'Scopus' identifier, which the corpus does not carry.
cited <- example_records[order(-example_records$citations), ][1:2, ]
abstracts <- tibble::tibble(
  id = cited$doi,
  scopus_id = NA_character_,
  doi = cited$doi,
  title = cited$title,
  abstract = NA_character_,
  publication = cited$publication,
  year = cited$year,
  citations = cited$citations
)
class(abstracts) <- c("scopus_abstracts", class(abstracts))
abstracts
#> <scopus_abstracts> (2 records)
#> # A tibble: 2 × 8
#>   id                  scopus_id doi   title abstract publication  year citations
#>   <chr>               <chr>     <chr> <chr> <chr>    <chr>       <int>     <int>
#> 1 10.1038/natrevmats… NA        10.1… Grap… NA       Nature Rev…  2016      1247
#> 2 10.1021/am509065d   NA        10.1… Flex… NA       ACS Applie…  2015       469

# A reference list arrives as one data frame per document, in the
# `references` list-column added by include = "references". The corpus
# carries no bibliographies, so its own records fill the columns here,
# standing in for the works the first document cites.
refs <- example_records[1:3, ]
abstracts$references <- list(
  tibble::tibble(
    position = as.character(seq_len(nrow(refs))),
    id = NA_character_,
    doi = refs$doi,
    title = refs$title,
    authors = refs$authors,
    source = refs$publication,
    year = refs$year,
    citedbycount = refs$citations
  ),
  tibble::tibble()
)
abstracts$references[[1]]
#> # A tibble: 3 × 8
#>   position id    doi                  title    authors source  year citedbycount
#>   <chr>    <chr> <chr>                <chr>    <chr>   <chr>  <int>        <int>
#> 1 1        NA    10.15541/jim20140527 Enhance… Jianhu… Journ…  2015            1
#> 2 2        NA    NA                   Fabrica… Patric… Digit…  2015            0
#> 3 3        NA    10.1021/am509065d    Flexibl… Zhiwei… ACS A…  2015          469
```
