# Building and exporting a reference set

``` r

library(scopusflow)
```

A retrieval becomes useful once it leaves the package, as a reading list
in a reference manager or as input to a science-mapping tool. This
article covers that export end of the workflow, using the bundled
`example_records` so every step runs without an API key.

## Take stock first

Before exporting anything, it helps to see what the set contains.
[`summary()`](https://rdrr.io/r/base/summary.html) reports the size, the
span of years, the number of distinct sources, the citation spread and
the most-cited record.

``` r

summary(example_records)
#> <scopus_records> summary
#> 6 records, from 2016 to 2021.
#> 5 sources, 6 with a DOI.
#> Cited 5505 times in total, median 299 per record.
#> Most frequent source: Nature.
#> Most cited: Observation of gravitational waves from a binary black hole merger.
```

A record set is an ordinary tibble underneath, so it drops straight into
tidyverse or base workflows. `as_tibble()` and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) make that
explicit when a downstream tool expects a plain frame.

``` r

tibble::as_tibble(example_records)
#> # A tibble: 6 × 10
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… Geno… Zhang …  2019 2019… Nature            540
#> 2            2 85000000002 10.1… Deep… Kumar …  2020 2020… Nature            210
#> 3            3 85000000003 10.1… Clim… Okafor…  2018 2018… Nature Cli…       122
#> 4            4 85000000004 10.1… Grap… Tanaka…  2021 2021… Advanced M…        45
#> 5            5 85000000005 10.1… Chec… Garcia…  2020 2020… The Lancet…       388
#> 6            6 85000000006 10.1… Obse… Abbott…  2016 2016… Physical R…      4200
#> # ℹ 1 more variable: query <chr>
as.data.frame(example_records)[1:3, c("title", "year")]
#>                                                          title year
#> 1 Genome editing with CRISPR-Cas9: principles and applications 2019
#> 2           Deep learning for medical image analysis: a review 2020
#> 3              Climate change adaptation in coastal megacities 2018
```

## A clean, deduplicated DOI list

Reference managers such as Zotero import most reliably from DOIs.
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
pulls them out, normalises them and removes duplicates, so the same
article imports once even when its DOI was stored with a resolver prefix
or in a different case.

``` r

dois <- scopus_extract_dois(example_records)
dois
#> [1] "10.1038/s41586-019-0001-1"      "10.1038/s41586-020-0002-2"     
#> [3] "10.1038/s41558-018-0085-1"      "10.1002/adma.202100001"        
#> [5] "10.1016/S1470-2045(20)30013-9"  "10.1103/PhysRevLett.116.061102"
```

The list can be written to a single-column CSV at a path you choose.
Nothing is written unless a path is given.

``` r

out <- file.path(tempdir(), "reference-set.csv")
scopus_extract_dois(example_records, file = out)
readLines(out)
#> [1] "\"doi\""                            "\"10.1038/s41586-019-0001-1\""     
#> [3] "\"10.1038/s41586-020-0002-2\""      "\"10.1038/s41558-018-0085-1\""     
#> [5] "\"10.1002/adma.202100001\""         "\"10.1016/S1470-2045(20)30013-9\"" 
#> [7] "\"10.1103/PhysRevLett.116.061102\""
```

## Into a reference manager

A DOI list is enough for an import-by-identifier, but a full record
carries more.
[`as_ris()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)
and
[`as_bibtex()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibtex.md)
render the set in the two interchange formats that reference managers
read, so a search moves straight into Zotero, EndNote or a LaTeX
bibliography. Each record becomes one entry, with its authors split out.

``` r

cat(substr(as_ris(example_records), 1, 320))
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
#> TI  - Deep learning for medical image analysis: a review
#> AU  - Kumar S.
#> PY  - 2020
#> JO  - Nature
#> DO  - 10.1038/s41586-020-00
```

Pass a `file` to write the whole set; nothing is written without one.

``` r

bib <- file.path(tempdir(), "reference-set.bib")
as_bibtex(example_records, file = bib)
```

## Handing off to science mapping

[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)
re-maps the records to the tagged column layout that the
[bibliometrix](https://www.bibliometrix.org) package and the wider ISI
convention expect.

``` r

m <- as_bibliometrix(example_records)
m[, c("AU", "TI", "PY", "SO", "TC", "DB")]
#>          AU                                                                 TI
#> 1  ZHANG F.       GENOME EDITING WITH CRISPR-CAS9: PRINCIPLES AND APPLICATIONS
#> 2  KUMAR S.                 DEEP LEARNING FOR MEDICAL IMAGE ANALYSIS: A REVIEW
#> 3 OKAFOR N.                    CLIMATE CHANGE ADAPTATION IN COASTAL MEGACITIES
#> 4 TANAKA H.             GRAPHENE ELECTRODES FOR NEXT-GENERATION ENERGY STORAGE
#> 5 GARCIA M.                      CHECKPOINT INHIBITORS IN CANCER IMMUNOTHERAPY
#> 6 ABBOTT B. OBSERVATION OF GRAVITATIONAL WAVES FROM A BINARY BLACK HOLE MERGER
#>     PY                      SO   TC     DB
#> 1 2019                  NATURE  540 SCOPUS
#> 2 2020                  NATURE  210 SCOPUS
#> 3 2018   NATURE CLIMATE CHANGE  122 SCOPUS
#> 4 2021      ADVANCED MATERIALS   45 SCOPUS
#> 5 2020     THE LANCET ONCOLOGY  388 SCOPUS
#> 6 2016 PHYSICAL REVIEW LETTERS 4200 SCOPUS
```

From there the usual bibliometrix entry points apply. This step needs
that package, so it is shown but not run.

``` r

if (requireNamespace("bibliometrix", quietly = TRUE)) {
  results <- bibliometrix::biblioAnalysis(as_bibliometrix(records))
  summary(results, k = 10)
}
```

As noted on the
[`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md)
help page, this reconstructs the core descriptive fields only. Analyses
that need full affiliations or cited references still call for a
complete ‘Scopus’ CSV or BibTeX export read with
`bibliometrix::convert2df()`.

## Saving the working set

To pick the work up in a later session, save the records and read them
back. The `.rds` form preserves the types and class exactly, while
`.csv` is portable plain text.

``` r

path <- file.path(tempdir(), "records.rds")
write_scopus_records(example_records, path)
identical(read_scopus_records(path), example_records)
#> [1] TRUE
```
