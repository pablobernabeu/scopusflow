# Retrieve abstracts and richer metadata

Fetches the abstract text and core metadata for one or more records from
the Elsevier 'Scopus' Abstract Retrieval API. This complements the
Search API used elsewhere in the package: a search returns many records
with a few fields each, whereas this returns the fuller record,
including the abstract, for a known identifier.

## Usage

``` r
scopus_abstract(
  ids,
  by = c("doi", "scopus_id"),
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
not lost to a single failure.

## API access

This performs one request per identifier and requires a valid API key
and internet access; full-text abstract access can also depend on your
entitlement. See the *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
for the conditions that may be raised.

## See also

[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md),
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
scopus_abstract("10.1038/s41586-019-0001-1")
}
```
