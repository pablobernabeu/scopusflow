# Author keywords and references

Keyword co-occurrence and citation-network analysis both need something
the Search API alone does not return: a document’s author-supplied
keywords, and its own reference list. This walks through retrieving
both, what each costs, and what your ‘Scopus’ entitlement needs to
cover.

The API calls below are shown as you would run them with a configured
key, and they are not run here, so no output appears beneath them. No
key is available when the site and the package are built, and Elsevier’s
terms do not permit redistributing retrieved records in any case. The
shapes the calls return are built in view from `example_records`, the
corpus of real articles the other articles run on. That corpus carries
neither author keywords nor reference lists, so its records and titles
are relabelled into those shapes, and the text says each time what
stands in for what.
[`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)
is the switch you would use to run the calls for real.

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

The column holds one string per record, with the keywords joined by
`" | "`, the form the Search API sends. In development, this field came
back `NA` even on a live, otherwise fully-entitled key, for documents
that do carry author keywords in ‘Scopus’ itself. Those documents do
have keywords, so what this points to is an entitlement gap specific to
this one field. If your own keywords come back all `NA`, it is worth
raising with your Scopus/Elsevier account contact.

## References via Abstract Retrieval

The reference list is not available from Search under any view. It needs
Abstract Retrieval’s `FULL` or `REF` view, an entitlement separate from
ordinary abstract access and from Search access. This is a per-document
endpoint, so retrieving references for *n* documents under `FULL` costs
*n* requests against Abstract Retrieval’s own, smaller weekly quota,
separate from Search’s. Each row of the returned `references` data frame
is one cited work.

``` r

ab <- scopus_abstract(
  "10.1038/nature14539",
  view = "FULL", include = c("references", "keywords")
)
ab$references[[1]][, c("title", "authors", "source", "year")]
```

`include = "keywords"` adds an `authkeywords` column, with the keywords
joined by `"; "` as the `authors` column joins names. The `references`
list-column holds one data frame per document, with the columns
`position`, `id`, `doi`, `title`, `authors`, `source`, `year` and
`citedbycount`. To show that shape offline, the chunk below relabels
three bundled records into those columns, as though they were works
cited by a fourth document. They are not the reference list of the
document above, or of any other. Under `FULL`, a live result writes each
cited work’s authors as surname and initials, such as `"Doe, A."`,
joined by `"; "`. These records carry only each paper’s first author,
written as OpenAlex gives the name. `id` holds a cited work’s ‘Scopus’
identifier, absent from the bundled records, and `citedbycount` is `NA`
under `FULL`, so both are left `NA`.

``` r

cited <- example_records[1:3, ]
refs <- tibble::tibble(
  position = as.character(seq_len(nrow(cited))),
  id = NA_character_,
  doi = cited$doi,
  title = cited$title,
  authors = cited$authors,
  source = cited$publication,
  year = cited$year,
  citedbycount = NA_integer_
)
refs[, c("title", "authors", "source", "year")]
```

| title | authors | source | year |
|:---|:---|:---|---:|
| Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles | Jianhua Yu | Journal of Inorganic Materials | 2015 |
| Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor | Patrick R Rice | DigitalCommons - CalPoly (California State Polytechnic University) | 2015 |
| Flexible and Stackable Laser-Induced Graphene Supercapacitors | Zhiwei Peng | ACS Applied Materials & Interfaces | 2015 |

`view = "FULL"` is the recommended default, since it returns the whole
bibliography in one request. `view = "REF"` serves it about 40
references at a time, and
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
follows the view’s `startref` parameter page by page until the list is
complete, so a document with *N* references costs `ceiling(N / 40)`
requests under `REF`.
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
warns when the number of references it holds still does not match the
document’s own reported count, so a partial list never arrives
unannounced.

The number of requests spent and the remaining Abstract Retrieval quota
are attached as attributes, since this endpoint draws on a separate,
smaller quota that is easy to exhaust unnoticed.

``` r

attr(ab, "n_requests")        # requests spent so far
attr(ab, "quota")$remaining   # Abstract Retrieval quota left
```

A key or subscription tier that does not cover the requested view raises
a `scopus_error_forbidden` condition that names the view, where a
generic HTTP failure would leave you guessing. It stops the whole batch
too, since entitlement is a property of the account, so the same refusal
would only recur on every remaining identifier.

For more than a handful of identifiers, pass `cache_dir` so an
interrupted or quota-limited batch resumes without re-spending quota
already spent.

``` r

ab <- scopus_abstract(
  dois, view = "FULL", include = c("references", "keywords"),
  cache_dir = "abstract-cache"
)
```

## Index keywords

‘Scopus’ records a second kind of keyword. Authors choose their own
keywords, whereas ‘Scopus’ chooses the index keywords and standardises
them to vocabularies derived from thesauri Elsevier owns or licenses,
with synonyms, spellings and plurals brought together.
`include = "index_terms"` adds them as an `idxterms` column, joined by
`"; "` as the author keywords are. Like the author keywords, they come
only with `view = "FULL"`, in the same request.

``` r

ab <- scopus_abstract(
  "10.1038/nature14539",
  view = "FULL", include = c("keywords", "index_terms")
)
ab$idxterms
```

Elsevier’s guide lists index keywords in the `FULL` view as not
available by default, so whether they arrive depends on your key’s
entitlement. In this package’s development testing, they did arrive on
the same key whose author keywords came back empty. Where that happens,
the index keywords may be the only keyword signal a ‘Scopus’ harvest can
give. The two kinds are not interchangeable, though. A standard
vocabulary merges terms that authors phrase differently, so the two give
different co-occurrence networks from the same documents, and a study
should say which it used.

## A minimal, cross-tool corpus

[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
combines a search result with this Abstract Retrieval step, returning a
minimal shape close to what OpenAlex’s `works` API already returns:
`id`, `scopus_id`, `title`, `year`, `keywords` (a list-column of
character vectors) and `references` (a list-column of data frames),
where bibliometrix would give you semicolon-joined citation strings. It
does not replace
\[[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)\],
which keeps its own field-mapping convention for users who want that.

``` r

recs <- scopus_fetch("DOI(10.1038/nature14539)", max_results = 1)
corpus <- scopus_corpus(recs, view = "FULL")
corpus$keywords[[1]]
nrow(corpus$references[[1]])
```

This costs one Abstract Retrieval request per record in `recs`, on top
of whatever retrieved `recs` in the first place. The `keywords` column,
split from the joined `authkeywords` string, holds a character vector
per record, which is the shape co-occurrence analysis wants.
`keywords = "index"` fills it with the index keywords instead, and
`keywords = "both"` with the author keywords followed by each index
keyword not already among them. Either costs what the default costs, and
both need `view = "FULL"`.

``` r

corpus <- scopus_corpus(recs, view = "FULL", keywords = "both")
```

The match is on the exact text, so `"graphene"` from the author and
`"Graphene"` from the index both stay.

Counting every unordered pair of keywords within each document gives the
co-occurrence table the article opened on, and base R is enough for it.

Author keywords are one of the fields that cannot travel with the
package. The corpus below stands them in from each bundled record’s own
title, keeping a fixed vocabulary of terms and recording those a title
mentions. That is a cruder signal than a real keyword list, but the
counting is identical and it runs over 138 published titles.

``` r

vocabulary <- c("graphene", "supercapacitor", "electrode", "energy storage",
                "flexible", "electrochemical")
corpus <- tibble::tibble(
  id = example_records$doi,
  title = example_records$title,
  year = example_records$year,
  keywords = lapply(tolower(example_records$title), function(title) {
    vocabulary[vapply(vocabulary, grepl, logical(1), x = title, fixed = TRUE)]
  })
)
several <- corpus[lengths(corpus$keywords) > 1L, ]
head(data.frame(
  title = several$title,
  keywords = vapply(several$keywords, paste, character(1), collapse = "; ")
), 3)
```

| title | keywords |
|:---|:---|
| Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles | graphene; supercapacitor |
| Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor | graphene; supercapacitor |
| Flexible and Stackable Laser-Induced Graphene Supercapacitors | graphene; supercapacitor; flexible |

``` r

# Each unordered pair once per document, sorted in byte order, so the pairs and
# the order of tied counts do not depend on the locale.
pairs <- do.call(rbind, lapply(corpus$keywords, function(keywords) {
  if (length(keywords) < 2L) return(NULL)
  t(utils::combn(sort(keywords, method = "radix"), 2L))
}))
cooc <- as.data.frame(table(pairs[, 1], pairs[, 2]), stringsAsFactors = FALSE)
names(cooc) <- c("keyword A", "keyword B", "documents")
cooc <- cooc[cooc$documents > 0L, ]
cooc <- cooc[order(-cooc$documents, cooc[["keyword A"]], cooc[["keyword B"]],
                   method = "radix"), ]
rownames(cooc) <- NULL
head(cooc, 5)
```

| keyword A | keyword B      | documents |
|:----------|:---------------|----------:|
| graphene  | supercapacitor |       105 |
| electrode | supercapacitor |        23 |
| electrode | graphene       |        22 |
| flexible  | supercapacitor |        18 |
| flexible  | graphene       |        17 |

Each row is one pair of keywords and the number of documents carrying
both, which is the edge list a co-occurrence network is built from.

## Handing the corpus to theoryforge

theoryforge maps a literature from a corpus file in its own schema, and
[`write_scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_corpus.md)
writes one from a
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md)
result. The file needs a name for the corpus, since the result carries
none.

``` r

write_scopus_corpus(corpus, "corpus.json", id = "graphene-supercapacitors")
```

theoryforge compares cited works as exact strings, so the writer gives
each one a single key across the corpus, its ‘Scopus’ identifier, as
`scopus:<id>`. ‘Scopus’ gives a cited work’s DOI in some bibliographies
only, and in different cases. A key built from the DOI wherever there is
one would therefore split the work into several nodes and lose its
co-citation edges. A reference that carries only a DOI takes the
identifier that another reference pairs with the same DOI, and a DOI
that nothing pairs with is keyed as `doi:<doi>`, lower-cased. Keywords
are lower-cased as well, so the `"graphene"` and `"Graphene"` that
`keywords = "both"` keeps apart become one. The chunk below runs the
writer on two bundled records, each made to cite the same two others,
the second with the DOIs in capitals. Both cite the same two keys.

``` r

docs <- example_records[!is.na(example_records$doi), ][1:4, ]
cites <- function(dois) tibble::tibble(id = NA_character_, doi = dois)
corpus <- tibble::tibble(
  id = docs$doi[1:2],
  scopus_id = NA_character_,
  title = docs$title[1:2],
  year = docs$year[1:2],
  keywords = list(c("Graphene", "supercapacitor"), "graphene"),
  references = list(cites(docs$doi[3:4]), cites(toupper(docs$doi[3:4])))
)
doc <- as_theoryforge_corpus(corpus, id = "graphene-supercapacitors")
doc$records[[1]]$references
```

    [1] "doi:10.1016/j.electacta.2015.02.019" "doi:10.1002/smll.201403383"         

``` r

doc$records[[2]]$references
```

    [1] "doi:10.1016/j.electacta.2015.02.019" "doi:10.1002/smll.201403383"         

The file also carries a `provenance` block recording the search
expression, when the search ran and the kind of keyword, with counts of
the references dropped and of the records without keywords. An
entitlement that returns no author keywords shows up in that last count,
and it leaves theoryforge’s keyword themes empty whatever the writer
does.
