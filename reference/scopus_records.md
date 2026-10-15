# Normalise raw 'Scopus' entries to a stable tidy schema

Converts the nested list returned by the 'Scopus' Search API into a
flat, predictable
[tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per record. This shape is the common currency of the package. Both
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
and
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
return it, and the DOI, comparison and export helpers all consume it.

## Usage

``` r
# S3 method for class 'scopus_records'
as_tibble(x, ...)

# S3 method for class 'scopus_records'
as.data.frame(x, ...)

# S3 method for class 'scopus_records'
autoplot(object, ...)

scopus_records(
  x,
  query = NA_character_,
  view = NULL,
  fields = c("core", "extended")
)

is_scopus_records(x)
```

## Arguments

- x:

  An object to test.

- ...:

  Ignored, for S3 compatibility.

- object:

  A scopus_records object (for the `autoplot()` method).

- query:

  Optional character scalar recording the query that produced the
  entries, kept in the `query` column for provenance.

- view:

  Optional character scalar naming the Search API view the entries came
  from. Pass `"COMPLETE"` to read `authors` from the author list that
  view carries and to add an `authkeywords` column (see below). Any
  other value, including the default `NULL`, reads the first author and
  reproduces the original columns exactly, so existing callers that
  never mention `view` see no change at all.
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  and
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  pass this through automatically.

- fields:

  `"core"` (the default) builds the columns listed under *Value*,
  exactly as before. `"extended"` also keeps the document type, source
  type, volume, issue, pages, ISSN, PubMed identifier and open-access
  status the Search API sends with every record, and under
  `view = "COMPLETE"` the abstract, at no extra quota (see *Extended
  fields*).
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  and
  [`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  pass this through.

## Value

The coercion methods return a plain
[tibble](https://tibble.tidyverse.org/reference/tibble.html) or data
frame with the same columns and the `scopus_records` class removed.

The `autoplot()` method returns a
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
of the records per year. The bars cover every year the set's plan
searched, a year without records drawn as a zero bar, and no year the
plan did not search. A plan over 2015, 2016, 2019 and 2020 therefore
draws no bar for 2017 or 2018. A harvest stopped before its last cell
covers only the cells it ran. Without a plan, or with one that sent no
year limit, the bars run from the first year in the records to the last.
When a `max_results` cap stopped any cell of the retrieval, a caption
says that the bars count records retrieved, not publications per year.
When the years plotted reach the year of the recorded `retrieved_at`,
the caption also says that year was incomplete when the records were
retrieved, as
[`plot_scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_trend.md)
does.

A tibble of class `scopus_records` with the columns `entry_number`
(integer), `scopus_id` (character), `doi` (character), `title`
(character), `authors` (character, the author list under
`view = "COMPLETE"` and the first author otherwise, as *Details*
explains), `year` (integer, the leading four digits of the cover date),
`date` (character, the ISO cover date), `publication` (character, the
source title), `citations` (integer) and `query` (character). A missing
field becomes `NA`, and an empty result set yields a zero-row tibble
with the same columns. When `view = "COMPLETE"`, an `authkeywords`
column is added: the author-supplied keywords the 'Scopus' Search API
returns under that view, as a single string in 'Scopus' own
`" | "`-delimited form (`NA` when the document has none, or when the API
omits the field for a given key's entitlement; see *Details*). With
`fields = "extended"`, the character columns `doc_type`,
`doc_type_description`, `source_type`, `volume`, `issue`, `pages`,
`issn` and `pubmed_id` follow, then the integer `open_access` and, under
`view = "COMPLETE"`, the character `abstract`. `doc_type` and
`doc_type_description` hold the document-type code and name 'Scopus'
gives the record, such as `"ar"` and `"Article"`, and `source_type`
holds the source type, such as `"Journal"`. `issn` is the print ISSN as
'Scopus' writes it, without the hyphen, kept as text so its leading
zeros survive. `open_access` is the open-access status code (see
*Extended fields*).

`is_scopus_records()` returns a length-one logical.

## Details

The 'Scopus' API signals an empty result set with a single sentinel
entry that carries an `error` field and no identifier. This is detected
and turned into a zero-row result, with no spurious record in it, while
a genuine record that also carries a per-entry `error` annotation is
kept.

What `authors` holds depends on the view. The Search API's `dc:creator`
field is the first author alone under either view, in the indexed form
'Scopus' uses (`"Zhang F."`). The author list arrives only under
`view = "COMPLETE"`, as the `author` objects Elsevier's views table
lists for that view alone. A `STANDARD` record therefore names its first
author, and a tally of `STANDARD` authors counts first authorships. A
harvest records its view in the `view` attribute (see
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)),
and
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
and
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)
say once per session that a set retrieved under `STANDARD` names first
authors only. Under `COMPLETE`, each author is written as
`"Surname, Given"`, as the surname alone when the given name is missing
or empty, or as the indexed name when the surname is missing. Exact
duplicates are dropped. The API lists at most 100 authors per record,
and its `author-count` field gives the total. A record whose list names
nobody falls back to `dc:creator`. The Python twin builds the same
string from pybliometrics' `author_names` in the common case, and parts
company at two edges. Where an author object lacks a `surname` or
`given-name` key, pybliometrics builds no list, so that twin keeps the
first author while this one lists every author. Where a surname is null
or empty, pybliometrics writes the given name after a bare comma, and
this package uses the indexed name.

Author keywords are only ever present under `view = "COMPLETE"`; the
`STANDARD` view (the default throughout the package) never includes
them, and `authkeywords` is not added to the output at all in that case,
so existing code that inspects the column names of a `STANDARD`-view
result is unaffected. Even under `COMPLETE` view, some 'Scopus' API keys
do not return populated author keywords (this was observed directly
against a live, otherwise fully-entitled key during development, on
documents that do carry author keywords in 'Scopus' itself); if your own
keywords come back all `NA`, the field is most likely gated by your
account's entitlement rather than genuinely absent, and is worth raising
with your 'Scopus'/Elsevier account contact.

## Extended fields

Elsevier's [Search views
table](https://dev.elsevier.com/sc_search_views.html) lists every field
`fields = "extended"` reads under both views, except the abstract
(`dc:description`), which only the `COMPLETE` view carries. They arrive
in the responses a retrieval already pays for, so they cost no extra
quota. A `COMPLETE` harvest returns up to 25 abstracts with each
request, while
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
spends one request per record from the separate Abstract Retrieval
quota.

`doc_type` holds the code the `DOCTYPE()` search field takes. Elsevier's
[search tips](https://dev.elsevier.com/sc_search_tips.html) list the
codes with their names: `ar` for an article, `re` a review, `cp` a
conference paper, `er` an erratum and others. A retracted item carries
`tb`, which that list leaves out. The 'Scopus' Content Coverage Guide
(section 3.1) defines an erratum as a report of an error, correction or
retraction of a previously published paper, so `er` covers retraction
notices as well as corrections. The guide gives an article the type
Retracted once a retraction notice for it is published. These codes are
the labels 'Scopus' assigns, and they do not screen a set for
retractions, since 'Scopus' does not label every retracted item (Ortega
and Delgado-Quirós, 2024). Check a set against the [Retraction Watch
database](https://www.crossref.org/documentation/retrieve-metadata/retraction-watch/),
which Crossref makes openly available, before relying on it.
[summary()](https://pablobernabeu.github.io/scopusflow/reference/summary.scopus_records.md)
reports how many records 'Scopus' labels `er` and `tb`. Errata can also
be left out of the search itself with `AND NOT DOCTYPE(er)`, joined by
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md),
which brackets the rest of the query first, since 'Scopus' applies AND
NOT last (see *Examples*).

`open_access` holds the code 'Scopus' sends in its `openaccess` field.
Elsevier's Scopus APIs Getting Started Guide (section 17) illustrates
its values with 0 for a record that is not open access, 1 for gold and 2
for green. The column therefore holds a status code, which can take
values other than 0 and 1.

## References

Elsevier. (2023). *Scopus APIs getting started guide* (Version 1).
<https://dev.elsevier.com/guides/Scopus%20API%20Guide_V1_20230907.pdf>

Elsevier. (2023). *Scopus content coverage guide*.
<https://supportcontent.elsevier.com/Support%20Hub/Scopus/Scopus_ContentCoverage_Guide_WEB.pdf>

Ortega, J. L., & Delgado-Quirós, L. (2024). The indexation of retracted
literature in seven principal scholarly databases: A coverage comparison
of Dimensions, OpenAlex, PubMed, Scilit, Scopus, The Lens and Web of
Science. *Scientometrics*, *129*(7), 3769–3785.
[doi:10.1007/s11192-024-05034-y](https://doi.org/10.1007/s11192-024-05034-y)

## Examples

``` r
# An entry in the shape the Search API returns it. The fields are those of
# a real article, taken from the bundled `example_records`, which stands in
# for a harvest because 'Scopus' records may not be redistributed. It
# carries no 'Scopus' identifier, so `dc:identifier` is absent and
# `scopus_id` comes back NA, as it does for any unidentified record.
raw <- list(entry = list(
  list(
    `prism:doi` = "10.1021/am509065d",
    `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
    `dc:creator` = "Zhiwei Peng",
    `prism:publicationName` = "ACS Applied Materials & Interfaces",
    `prism:coverDate` = "2015-01-13",
    `citedby-count` = "469"
  )
))
scopus_records(raw, query = 'TITLE-ABS-KEY("graphene supercapacitor")')
#> <scopus_records> 1 record
#> query: "TITLE-ABS-KEY(\"graphene supercapacitor\")"
#> # A tibble: 1 × 9
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 NA        10.102… Flex… Zhiwei…  2015 2015… ACS Applie…       469

# Under COMPLETE view an entry may also carry author keywords, which the
# Search API returns in its own " | "-delimited form. The bundled corpus
# holds no keywords, so the ones below are illustrative.
raw_complete <- list(entry = list(
  list(
    `prism:doi` = "10.1021/am509065d",
    `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
    authkeywords = "graphene | supercapacitor | energy storage"
  )
))
scopus_records(raw_complete, view = "COMPLETE")
#> <scopus_records> 1 record
#> # A tibble: 1 × 11
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 NA        10.102… Flex… NA         NA NA    NA                 NA
#> # ℹ 2 more variables: query <chr>, authkeywords <chr>

# fields = "extended" keeps the fields both views send beyond the core ones.
# The volume, issue, pages and print ISSN below are the article's own. The
# document type and source type are illustrative, since the bundled corpus
# came from OpenAlex and records no 'Scopus' labels.
raw_extended <- list(entry = list(
  list(
    `prism:doi` = "10.1021/am509065d",
    `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
    subtype = "ar",
    subtypeDescription = "Article",
    `prism:aggregationType` = "Journal",
    `prism:volume` = "7",
    `prism:issueIdentifier` = "5",
    `prism:pageRange` = "3414-3419",
    `prism:issn` = "19448244"
  )
))
extended <- scopus_records(raw_extended, fields = "extended")
as.data.frame(extended)[, c("doc_type", "volume", "issue", "pages", "issn")]
#>   doc_type volume issue     pages     issn
#> 1       ar      7     5 3414-3419 19448244

# Errata can be left out of the search itself. scopus_query() brackets the
# rest of the query, since 'Scopus' applies AND NOT last.
scopus_query(
  scopus_query("graphene", "graphite", .op = "OR", .field = "TITLE-ABS-KEY"),
  "DOCTYPE(er)", .op = "AND NOT"
)
#> [1] "(TITLE-ABS-KEY(graphene) OR TITLE-ABS-KEY(graphite)) AND NOT DOCTYPE(er)"

# An object already in this schema is returned unchanged.
identical(scopus_records(example_records), example_records)
#> [1] TRUE
```
