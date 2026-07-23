# Export records to BibTeX or RIS

Turns a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
set into a BibTeX or RIS string, the interchange formats that reference
managers (Zotero, EndNote, Mendeley) and LaTeX bibliographies import.
Each record becomes one entry, with its authors split out and the
'Scopus' identifier kept as a note. Records are treated as journal
articles, the dominant 'Scopus' content type. BibTeX citation keys are
made unique within the export, and special characters are escaped.

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
#>   title = {Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles},
cat(substr(as_ris(example_records), 1, 200))
#> TY  - JOUR
#> TI  - Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles
#> AU  - Jianhua Yu
#> PY  - 2015
#> JO  - Journal 
```
