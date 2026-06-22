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
cat(substr(as_bibtex(example_records), 1, 200))
#> @article{zhang2019,
#>   author = {Zhang F.},
#>   title = {Genome editing with CRISPR-Cas9: principles and applications},
#>   journal = {Nature},
#>   year = {2019},
#>   doi = {10.1038/s41586-019-0001-1},
#>   note 
cat(substr(as_ris(example_records), 1, 200))
#> TY  - JOUR
#> TI  - Genome editing with CRISPR-Cas9: principles and applications
#> AU  - Zhang F.
#> PY  - 2019
#> JO  - Nature
#> DO  - 10.1038/s41586-019-0001-1
#> N1  - Scopus ID: 85000000001
#> ER  - 
#> 
#> TY  - JOUR
#> TI 
```
