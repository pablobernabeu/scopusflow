# Write a corpus in theoryforge's corpus schema

Turns a
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
result into the literature corpus that theoryforge's `tf_read_corpus()`,
`tf_litmap()` and `tf_landscape()` read, following the corpus schema
theoryforge publishes (`schema/corpus.schema.json` in its repository).
`as_theoryforge_corpus()` returns the document as a list, and
`write_scopus_corpus()` writes it to a JSON file. Neither needs
theoryforge installed, and neither makes a request.

## Usage

``` r
as_theoryforge_corpus(corpus, id)

write_scopus_corpus(corpus, path, id)
```

## Arguments

- corpus:

  A
  [`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
  result, or a data frame with the same `id`, `title`, `year`,
  `keywords` and `references` columns, where each `references` entry is
  a data frame with `id` and `doi` columns. A `scopus_id` column is used
  when present.

- id:

  A non-empty string naming the corpus, written as its top-level `id`.
  It is required, since a
  [`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
  result carries no name of its own.

- path:

  The file to write, exactly as given. Parent directories are assumed to
  exist already.

## Value

`as_theoryforge_corpus()` returns the document as a list with the
elements `id`, `provenance`, `records` and `schema_version` (`"1.0"`).
`write_scopus_corpus()` returns the same list invisibly.

## Details

theoryforge compares references as exact strings, so the writer gives
each cited work one key across the whole corpus, its 'Scopus'
identifier, as `scopus:<id>`. 'Scopus' gives a cited work's DOI in some
bibliographies only, and in different cases. A key built from the DOI
wherever there is one would therefore split one work into several nodes
and lose the co-citation edges between them. A reference that carries
only a DOI takes the 'Scopus' identifier that a document or reference
elsewhere in the corpus pairs with the same DOI, the documents' own
identifiers counting first. A DOI that nothing pairs with is keyed as
`doi:<doi>`, without its resolver prefix and with its ASCII letters
lower-cased, since DOIs are case-insensitive over ASCII (DOI Handbook,
section 2.4). A reference with neither is dropped, and a
`scopus_warning_dropped_references` warning says how many. Each document
is keyed the same way, from its `scopus_id` or else from an `id` that is
a DOI or a 'Scopus' identifier, so a citation of a document in the
corpus and the document itself share one key.

Keywords are trimmed, lower-cased with
[`tolower()`](https://rdrr.io/r/base/chartr.html) and made unique,
keeping the first of each, and empty ones are dropped, so `"Graphene"`
and `"graphene "` count as one keyword. The Python twin lower-cases with
`str.lower()`. The two agree on the Latin, Greek and Cyrillic letters in
common use and differ on a few special cases, such as the Turkish
capital I with a dot and a capital sigma ending a word, which Python
writes as a final sigma. A missing year is written as `null`, and a
missing title is left out, since the schema admits the one and not the
other.

The document also carries a `provenance` object, which the schema admits
beside its own fields: `source` (`"Scopus via scopusflow <version>"`),
`query`, `retrieved_at` (in UTC, as `YYYY-MM-DDTHH:MM:SSZ`), `keywords`,
`n_records`, `n_references_dropped` and `n_records_without_keywords`.
`query`, `retrieved_at` and `keywords` come from the attributes
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
attaches, and are `null` when the corpus lacks them. `query` is a
string, or an array of strings when the records were searched with
several expressions. Author keywords can come back empty under some
entitlements (see
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)),
which leaves theoryforge's keyword themes empty whatever the writer
does, and `n_records_without_keywords` shows when that happened.

The file is UTF-8, with no escaping beyond what JSON requires, sorted
keys, no spaces between tokens and one line feed at the end, so the same
corpus gives the same bytes from either twin.

## See also

[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md),
which builds the corpus.

## Examples

``` r
# Two records of the bundled corpus of real articles, each citing the same
# two others. The keywords and the citations are illustrative, since the
# bundled records carry neither.
docs <- example_records[!is.na(example_records$doi), ][1:4, ]
cited <- tibble::tibble(id = NA_character_, doi = docs$doi[3:4])
corpus <- tibble::tibble(
  id = docs$doi[1:2],
  scopus_id = NA_character_,
  title = docs$title[1:2],
  year = docs$year[1:2],
  keywords = list(c("Graphene", "supercapacitor"), "graphene"),
  references = list(cited, cited)
)
doc <- as_theoryforge_corpus(corpus, id = "graphene-supercapacitors")
doc$records[[1]]$keywords
#> [1] "graphene"       "supercapacitor"
doc$records[[1]]$references
#> [1] "doi:10.1016/j.electacta.2015.02.019" "doi:10.1002/smll.201403383"         

# Written to a temporary file (never the working directory).
path <- tempfile(fileext = ".json")
write_scopus_corpus(corpus, path, id = "graphene-supercapacitors")
substr(readLines(path, encoding = "UTF-8"), 1, 160)
#> [1] "{\"id\":\"graphene-supercapacitors\",\"provenance\":{\"keywords\":null,\"n_records\":2,\"n_records_without_keywords\":0,\"n_references_dropped\":0,\"query\":null,\"retrieved_at\""
```
