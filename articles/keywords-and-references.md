# Author keywords and references

Keyword co-occurrence and citation-network analysis both need something
the Search API alone does not return: a document’s author-supplied
keywords, and its own reference list. This walks through retrieving
both, what each costs, and what your ‘Scopus’ entitlement needs to
cover.

The code chunks below run for real, against the live API, whenever this
vignette is built on a machine with a configured key
([`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md));
on CRAN, and anywhere else without a key, they are shown but skipped, so
the package can still be checked and built without one.

``` r

library(scopusflow)
```

## Author keywords from a search

The Search API’s `COMPLETE` view carries an `authkeywords` field
alongside the usual title, DOI and date. Requesting it costs no extra
request beyond `COMPLETE`’s own smaller page size (25 records per page,
against 200 for `STANDARD`), which already means more requests, and so
more quota, for the same number of records.

``` r

recs <- scopus_fetch("DOI(10.1038/nature14539)", view = "COMPLETE")
recs$authkeywords
```

In development, this field came back `NA` even on a live, otherwise
fully-entitled key, for documents that do carry author keywords in
‘Scopus’ itself, which points to an entitlement gap specific to this one
field rather than the documents genuinely having none. If your own
keywords come back all `NA`, it is worth raising with your
Scopus/Elsevier account contact.

## References via Abstract Retrieval

The reference list is not available from Search under any view; it needs
Abstract Retrieval’s `FULL` or `REF` view, an entitlement separate from
ordinary abstract access and from Search access. This is a per-document
endpoint, so retrieving references for *n* documents costs *n* requests
against Abstract Retrieval’s own, smaller weekly quota, separate from
Search’s.

``` r

ab <- scopus_abstract(
  "10.1038/nature14539",
  view = "FULL", include = c("references", "keywords")
)
ab$references[[1]][, c("title", "authors", "source", "year")]
```

`view = "FULL"` is the recommended default: in development, it returned
a complete, correctly counted reference list for every document tried,
while `view = "REF"` returned an inconsistent, sometimes-truncated
subset, on an otherwise identical request made moments apart.
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
warns when the number of references returned does not match the
document’s own reported count, rather than returning a partial list
silently.

``` r

attr(ab, "n_requests")   # requests spent so far
attr(ab, "quota")$remaining
```

A key or subscription tier that does not cover the requested view raises
a `scopus_error_forbidden` condition naming the view, rather than a
generic HTTP failure, and stops the whole batch rather than repeating
the same failure for every remaining identifier, since entitlement is an
account-level property, not a per-document one.

For more than a handful of identifiers, pass `cache_dir` so an
interrupted or quota-limited batch resumes without re-spending quota
already spent:

``` r

ab <- scopus_abstract(
  dois, view = "FULL", include = c("references", "keywords"),
  cache_dir = "abstract-cache"
)
```

## A minimal, cross-tool corpus

[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
combines a search result with this Abstract Retrieval step, returning a
minimal shape close to what OpenAlex’s `works` API already returns:
`id`, `title`, `year`, `keywords` (a list-column of character vectors)
and `references` (a list-column of data frames), rather than
bibliometrix’s semicolon-joined citation strings. It does not replace
\[[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)\],
which keeps its own field-mapping convention for users who want that
instead.

``` r

recs <- scopus_fetch("DOI(10.1038/nature14539)", max_results = 1)
corpus <- scopus_corpus(recs, view = "FULL")
corpus$keywords[[1]]
nrow(corpus$references[[1]])
```

This costs one Abstract Retrieval request per record in `recs`, on top
of whatever retrieved `recs` in the first place.
