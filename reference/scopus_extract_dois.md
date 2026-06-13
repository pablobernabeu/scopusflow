# Extract, clean and optionally export DOIs

Pulls Digital Object Identifiers from a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
object (or a bare character vector), normalises them and removes missing
values. The resulting list can be imported into a reference manager such
as Zotero to assemble a bibliography.

## Usage

``` r
scopus_extract_dois(x, dedupe = TRUE, file = NULL)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble, or a character vector of DOIs.

- dedupe:

  Logical, dropping duplicate DOIs by default.

- file:

  Optional path at which to write the DOIs as a single-column CSV. A
  file is written only when this argument is supplied, and only to the
  exact path given, so the package always leaves the working directory
  untouched unless asked. Parent directories are assumed to exist
  already.

## Value

A character vector of cleaned DOIs, returned invisibly when `file` is
written.

## Details

Normalisation trims surrounding whitespace and strips common resolver
prefixes (`https://doi.org/`, `http://dx.doi.org/`, `doi:`) so that the
same article is counted once even when its DOI is formatted differently
in two records. Because DOIs are case-insensitive, comparison and
deduplication ignore case, while the output keeps the original casing.

## See also

[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
to compare two retrievals.

## Examples

``` r
recs <- scopus_records(list(entry = list(
  list(`prism:doi` = "10.1/AAA"),
  list(`prism:doi` = "https://doi.org/10.1/aaa"),
  list(`prism:doi` = NULL)
)))
scopus_extract_dois(recs)
#> [1] "10.1/AAA"

# Write to a temporary file (never the working directory).
path <- tempfile(fileext = ".csv")
scopus_extract_dois(recs, file = path)
```
