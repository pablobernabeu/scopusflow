# Export records to BibTeX or RIS

Turns a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
set into a BibTeX or RIS string, the interchange formats that reference
managers (Zotero, EndNote, Mendeley) and LaTeX bibliographies import.
Each record becomes one entry, with its authors split out and the
'Scopus' identifier kept as a note. BibTeX citation keys are made unique
within the export, and special characters are escaped.

## Usage

``` r
as_bibtex(x, file = NULL)

as_ris(x, file = NULL)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble.

- file:

  Optional path to write to. With the default `NULL` the formatted
  string is returned; with a path it is written there and returned
  invisibly. Nothing is written unless a path is given.

## Value

A length-one character string of the formatted records (returned
invisibly when `file` is supplied).

## Details

A set retrieved with `fields = "extended"` (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
carries each record's 'Scopus' document type, and the entry is typed by
it. A conference paper (`cp`) becomes an RIS `CPAPER` and a BibTeX
`@inproceedings`, and a conference review (`cr`) an RIS `CONF` and a
BibTeX `@inproceedings`. A book chapter (`ch`) becomes an RIS `CHAP` and
a BibTeX `@incollection`, and a book (`bk`) an RIS `BOOK` and a BibTeX
`@book`. Every other record, and every record of a set retrieved with
the core fields, is a journal article (`JOUR`, `@article`). In BibTeX,
the source title of a conference paper or chapter goes under
`booktitle`, braced as the title is, and a journal article's under
`journal`. A book in a book series gives the series under `series`, and
a book outside a series, whose source title 'Scopus' gives as the book's
own, names no source. RIS gives the source under `T2` except for such a
book, since Zotero reads a book's `T2` as its series. The entries also
carry the volume, issue, pages, ISSN and document type (RIS `M3`). Under
`view = "COMPLETE"` they carry the abstract and the author keywords, one
`KW` line each in RIS and joined by commas in BibTeX. Keywords are split
at the `" | "` the Search API joins them with and at the `"; "`
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
joins its own with. A value the record lacks is left out, never filled
in.

Names are written family name first, with a comma. Under the `STANDARD`
view, the `authors` column holds 'Scopus' names in the form `Zhang F.`,
which BibTeX would read as given name "Zhang" and family name "F.", so a
name ending in initials is exported as `Zhang, F.`. BibTeX entries also
space run-together initials (`Kitchin, J. R.`), which BibTeX otherwise
takes for a single given name. Names that already carry a comma, as
under `COMPLETE`, and names given first are written as they stand. The
`authors` column itself and the citation keys are unchanged. In a BibTeX
title, every word with a capital after its first letter is braced
(`{DNA}`, `{CRISPR-Cas9}`), so bibliography styles cannot lower-case it.

An RIS entry gives the source title under `T2`, the tag 'Scopus' itself
uses and reference managers read as the publication title, records the
database as `DB - Scopus` and, when the record has an identifier, gives
the EID as the accession number (`AN - 2-s2.0-<scopus_id>`).

## See also

[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md),
[`write_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md),
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)

## Examples

``` r
# On the bundled corpus of real articles, which stands in for a retrieval
# of your own because 'Scopus' records may not be redistributed. Only the
# opening of each export is shown; pass `file` to write the whole set.
cat(substr(as_bibtex(example_records), 1, 200))
#> @article{jianhua2015,
#>   author = {Jianhua Yu},
#>   title = {Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and {SnO2} Nanoparticles
cat(substr(as_ris(example_records), 1, 200))
#> TY  - JOUR
#> TI  - Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles
#> AU  - Jianhua Yu
#> PY  - 2015
#> T2  - Journal 
```
