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
# The bundled corpus of real articles stands in for a harvest of your own,
# since 'Scopus' records may not be redistributed.
dois <- scopus_extract_dois(example_records)
length(dois)
#> [1] 127
head(dois, 3)
#> [1] "10.15541/jim20140527"            "10.1021/am509065d"              
#> [3] "10.1016/j.electacta.2015.02.019"

# Eleven of its 138 records arrived without a DOI, as records do, and so
# drop out of the list.
sum(is.na(example_records$doi))
#> [1] 11

# The same cleaning applies to a bare vector, so a resolver prefix or a
# difference in case does not make one article look like two.
scopus_extract_dois(c("https://doi.org/10.1/A", "doi: 10.1/a", "10.2/B"))
#> [1] "10.1/A" "10.2/B"

# Write to a temporary file (never the working directory).
path <- tempfile(fileext = ".csv")
scopus_extract_dois(example_records, file = path)
```
