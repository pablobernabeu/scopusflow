# Convert records to a bibliometrix-compatible data frame

Re-maps a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble to the tagged column layout used by the bibliometrix package (and
the wider ISI/Web of Science convention), so results can flow into
downstream science-mapping workflows.

## Usage

``` r
as_bibliometrix(x)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble.

## Value

A data frame (classed `bibliometrixDB`) with the standard tag columns
`AU` (authors), `TI` (title), `SO` (source or publication), `DI` (DOI),
`PY` (publication year), `TC` (times cited), `UT` (record id) and `DB`
(`"SCOPUS"`). Character tag fields are upper-cased to match the
bibliometrix convention.

## Details

This produces the *shape* bibliometrix expects from the core descriptive
fields. It reconstructs only what the 'Scopus' Search API returns, so
richer fields that some bibliometrix analyses use, such as full author
affiliations or cited references, are left out. To obtain those, export
a full 'Scopus' CSV or BibTeX file from the web interface and read it
with `bibliometrix::convert2df()`.

## Examples

``` r
recs <- scopus_records(list(entry = list(
  list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
       `dc:title` = "A study", `dc:creator` = "Doe J.",
       `prism:publicationName` = "Journal", `prism:coverDate` = "2020-01-01",
       `citedby-count` = "3")
)))
as_bibliometrix(recs)
#>       AU      TI      SO     DI   PY TC UT     DB
#> 1 DOE J. A STUDY JOURNAL 10.1/a 2020  3  1 SCOPUS
```
