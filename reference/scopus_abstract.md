# Retrieve abstracts and richer metadata

Fetches the abstract text and core metadata for one or more records from
the Elsevier 'Scopus' Abstract Retrieval API. This complements the
Search API used elsewhere in the package: a search returns many records
with a few fields each, whereas this returns the fuller record,
including the abstract, for a known identifier. Passing `include` adds
author keywords and/or the document's reference list to the same
request.

## Usage

``` r
scopus_abstract(
  ids,
  by = c("doi", "scopus_id"),
  view = NULL,
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

  Optional character scalar naming the Abstract Retrieval view to
  request: one of `"META"`, `"META_ABS"`, `"REF"` or `"FULL"`. `NULL`
  (the default) omits the `view` parameter from the request entirely,
  exactly as scopusflow has always done, so existing calls that never
  mention `view` are unaffected. Retrieving `include = "references"`
  requires `view = "FULL"` or `view = "REF"`; see *Details* for how the
  two differ and which to prefer.

- include:

  Optional character vector naming extra fields to retrieve in the same
  request: `"references"` and/or `"keywords"`. Both require Abstract
  Retrieval's `FULL` or `REF` view (see `view`), an entitlement that is
  separate from ordinary abstract access and from 'Scopus' Search
  access, and that, per Elsevier's own documentation, some fields
  (notably author keywords) may need to be requested from your
  Scopus/Elsevier account contact even when the view itself is otherwise
  accessible. See *Details*.

- cache_dir:

  Optional directory for per-identifier cache files, as in
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md).
  `NULL` (the default) performs no caching. Worth setting whenever
  `include` is used: Abstract Retrieval draws on its own weekly quota,
  smaller than and separate from Search's, and every identifier here
  costs its own request, so re-running an interrupted batch without a
  cache re-spends quota already spent.

- resume:

  Logical. When `TRUE` (the default) and `cache_dir` is set, an
  identifier whose cache file already exists is loaded from disk rather
  than requested again.

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
are attached as the `n_requests` and `quota` attributes, since this is a
materially more expensive operation than a search call.

When `include` names `"keywords"`, an `authkeywords` column is added:
the document's author-supplied keywords, joined the same way as
`authors` (`"; "`-separated), or `NA` when the document has none, or
when the API omits the field for a given key's entitlement (see
*Details*).

When `include` names `"references"`, a `references` list-column is
added: one data frame per document, with one row per cited work, rather
than a single joined string. Its columns are `position` (the reference's
place in the bibliography), `id` (the 'Scopus' identifier of the cited
work, when resolved), `doi`, `title`, `authors`, `source` (the journal
or other venue), `year` and `citedbycount` (the cited work's own
citation count; populated only under `view = "REF"`, `NA` under
`"FULL"`). A document with no resolvable references yields a zero-row
data frame, not `NA`, so the column can always be unnested. This is a
leaner field set than pybliometrics' own `references` in the Python
twin, which exposes several further fields pybliometrics already parses;
see the Python package's equivalent documentation for that fuller shape.

## Details

Retrieving references or keywords needs Abstract Retrieval's `FULL` or
`REF` view. In development, against a live key with full Abstract
Retrieval access, `view = "FULL"` returned a complete, correctly counted
reference list for every document tried. `view = "REF"` returned the
identical, complete list in one case but a truncated (paginated) subset
in another, on an otherwise identical request made moments apart, so
`"FULL"` is recommended when your entitlement allows it. `"REF"` remains
available for accounts entitled only to it; when the number of
references returned does not match the document's own reported reference
count, a warning is issued naming the identifier, since the list may be
an incomplete page rather than the whole bibliography.

Author keywords were not populated by either 'Scopus' Search's
`COMPLETE` view (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
or Abstract Retrieval's `FULL` view in this package's own development
testing, against a live, otherwise fully-entitled key, on documents that
do carry author keywords in 'Scopus' itself. If your own keywords come
back all `NA`, this is most likely an entitlement gap specific to that
field, worth raising with your Scopus/Elsevier account contact, rather
than the documents genuinely having none.

## API access

This performs one request per identifier and requires a valid API key
and internet access; full-text abstract access, and the `FULL`/`REF`
views in particular, can also depend on your entitlement. A view or
field your key is not entitled to raises a `scopus_error_forbidden`
condition with a message naming the view and suggesting who to contact,
rather than a generic HTTP failure; because entitlement is an
account-level property, not a per-document one, retrieval stops at the
first such failure instead of repeating it for every remaining
identifier. See the *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
for the other conditions that may be raised.

## See also

[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md),
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md),
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
to assemble a minimal keyword/reference corpus across many documents.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
scopus_abstract("10.1038/s41586-019-0001-1")

# Author keywords and a structured reference list, in the same request.
# Costs one Abstract Retrieval request per identifier, against a smaller,
# separate weekly quota from Search; see the API access section above for
# the entitlement this needs.
rich <- scopus_abstract(
  "10.1038/nature14539",
  view = "FULL", include = c("references", "keywords")
)
rich$references[[1]]
}
```
