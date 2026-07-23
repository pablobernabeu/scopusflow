# Building and exporting a reference set

``` r

library(scopusflow)
```

A retrieval becomes useful once it leaves the package, as a reading list
in a reference manager or as input to a science-mapping tool. This
article covers that export end of the workflow. Every step runs without
an API key, on the bundled `example_records`, a corpus of 138 real
journal articles that stands in for a harvest of your own because Scopus
records may not be redistributed;
[`vignette("scopusflow")`](https://pablobernabeu.github.io/scopusflow/articles/scopusflow.md)
describes where it comes from.

## Take stock first

Before exporting anything, it helps to see what the set contains.
[`summary()`](https://rdrr.io/r/base/summary.html) reports the size, the
span of years, the number of distinct sources, the citation spread and
the most-cited record.

``` r

summary(example_records)
#> <scopus_records> summary
#> 138 records, from 2015 to 2024.
#> 90 sources, 127 with a DOI.
#> Cited 7015 times in total, median 24 per record.
#> Most frequent source: ACS Applied Materials & Interfaces.
#> Most cited: Graphene for batteries, supercapacitors and beyond.
```

Eleven of those 138 records arrived without a DOI, which is why the
summary counts 127 with one. That is ordinary in a real harvest, and the
sections below show how each export handles it.

A record set is an ordinary tibble underneath, so it drops straight into
tidyverse or base workflows. `as_tibble()` and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) make that
explicit when a downstream tool expects a plain frame.

``` r

head(tibble::as_tibble(example_records))
```

| entry_number | scopus_id | doi | title | authors | year | date | publication | citations | query |
|---:|:---|:---|:---|:---|---:|:---|:---|---:|:---|
| 1 | NA | 10.15541/jim20140527 | Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles | Jianhua Yu | 2015 | 2015-01-01 | Journal of Inorganic Materials | 1 | graphene supercapacitor |
| 2 | NA | NA | Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor | Patrick R Rice | 2015 | 2015-01-01 | DigitalCommons - CalPoly (California State Polytechnic University) | 0 | graphene supercapacitor |
| 3 | NA | 10.1021/am509065d | Flexible and Stackable Laser-Induced Graphene Supercapacitors | Zhiwei Peng | 2015 | 2015-01-13 | ACS Applied Materials & Interfaces | 469 | graphene supercapacitor |
| 4 | NA | 10.1016/j.electacta.2015.02.019 | Heavily nitrogen doped, graphene supercapacitor from silk cocoon | Vikrant Sahu | 2015 | 2015-02-04 | Electrochimica Acta | 195 | graphene supercapacitor |
| 5 | NA | 10.1002/smll.201403383 | Graphene-Based Integrated Photovoltaic Energy Harvesting/Storage Device | Chih-Tao Chien | 2015 | 2015-02-19 | Small | 108 | graphene supercapacitor |
| 6 | NA | 10.1016/j.jpowsour.2015.03.015 | Nanoporous graphene materials by low-temperature vacuum-assisted thermal process for electrochemical energy storage | Hao Yang | 2015 | 2015-03-05 | Journal of Power Sources | 47 | graphene supercapacitor |

``` r

as.data.frame(example_records)[1:3, c("title", "year")]
```

| title | year |
|:---|---:|
| Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles | 2015 |
| Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor | 2015 |
| Flexible and Stackable Laser-Induced Graphene Supercapacitors | 2015 |

## A clean, deduplicated DOI list

Reference managers such as Zotero import most reliably from DOIs.
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
pulls them out, normalises them and removes duplicates, so the same
article imports once even when its DOI was stored with a resolver prefix
or in a different case.

``` r

dois <- scopus_extract_dois(example_records)
length(dois)
#> [1] 127
head(dois, 6)
#> [1] "10.15541/jim20140527"            "10.1021/am509065d"              
#> [3] "10.1016/j.electacta.2015.02.019" "10.1002/smll.201403383"         
#> [5] "10.1016/j.jpowsour.2015.03.015"  "10.1103/physrevb.91.125415"
```

The same cleaning applies to a plain vector of DOIs from any source, so
the first two entries below collapse to one because comparison ignores
case and resolver prefixes, while `dedupe = FALSE` keeps every
occurrence, for instance to count how often a DOI recurs across
retrievals.

``` r

scopus_extract_dois(c("https://doi.org/10.1/A", "doi: 10.1/a", "10.2/B"))
#> [1] "10.1/A" "10.2/B"
scopus_extract_dois(c("https://doi.org/10.1/A", "doi: 10.1/a", "10.2/B"),
                    dedupe = FALSE)
#> [1] "10.1/A" "10.1/a" "10.2/B"
```

The list can be written to a single-column CSV at a path you choose.
Nothing is written unless a path is given. Here are the first few lines
of the file, which holds a header and one DOI per line:

``` r

out <- file.path(tempdir(), "reference-set.csv")
scopus_extract_dois(example_records, file = out)
writeLines(head(readLines(out), 6))
```

    "doi"
    "10.15541/jim20140527"
    "10.1021/am509065d"
    "10.1016/j.electacta.2015.02.019"
    "10.1002/smll.201403383"
    "10.1016/j.jpowsour.2015.03.015"

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

cat(substr(as_ris(example_records), 1, 470))
```

    TY  - JOUR
    TI  - Enhanced Capacitive Properties of All-solid-state Symmetric Graphene Supercapacitors by Incorporating Nitrogen-doping and SnO2 Nanoparticles
    AU  - Jianhua Yu
    PY  - 2015
    JO  - Journal of Inorganic Materials
    DO  - 10.15541/jim20140527
    ER  - 

    TY  - JOUR
    TI  - Fabrication and Characterization of a Vertically-Oriented Graphene Supercapacitor
    AU  - Patrick R Rice
    PY  - 2015
    JO  - DigitalCommons - CalPoly (California State Polytechnic University)
    ER  - 

The first two entries of 138 are shown. The second has no DOI, so its
`DO` line is simply absent rather than empty, and the entry still
imports on its title, author and year.

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
head(m[, c("AU", "TI", "PY", "SO", "TC", "DB")])
```

| AU | TI | PY | SO | TC | DB |
|:---|:---|---:|:---|---:|:---|
| JIANHUA YU | ENHANCED CAPACITIVE PROPERTIES OF ALL-SOLID-STATE SYMMETRIC GRAPHENE SUPERCAPACITORS BY INCORPORATING NITROGEN-DOPING AND SNO2 NANOPARTICLES | 2015 | JOURNAL OF INORGANIC MATERIALS | 1 | SCOPUS |
| PATRICK R RICE | FABRICATION AND CHARACTERIZATION OF A VERTICALLY-ORIENTED GRAPHENE SUPERCAPACITOR | 2015 | DIGITALCOMMONS - CALPOLY (CALIFORNIA STATE POLYTECHNIC UNIVERSITY) | 0 | SCOPUS |
| ZHIWEI PENG | FLEXIBLE AND STACKABLE LASER-INDUCED GRAPHENE SUPERCAPACITORS | 2015 | ACS APPLIED MATERIALS & INTERFACES | 469 | SCOPUS |
| VIKRANT SAHU | HEAVILY NITROGEN DOPED, GRAPHENE SUPERCAPACITOR FROM SILK COCOON | 2015 | ELECTROCHIMICA ACTA | 195 | SCOPUS |
| CHIH-TAO CHIEN | GRAPHENE-BASED INTEGRATED PHOTOVOLTAIC ENERGY HARVESTING/STORAGE DEVICE | 2015 | SMALL | 108 | SCOPUS |
| HAO YANG | NANOPOROUS GRAPHENE MATERIALS BY LOW-TEMPERATURE VACUUM-ASSISTED THERMAL PROCESS FOR ELECTROCHEMICAL ENERGY STORAGE | 2015 | JOURNAL OF POWER SOURCES | 47 | SCOPUS |

From there the usual bibliometrix entry points apply. This step needs
that package, so it is shown but not run.

``` r

if (requireNamespace("bibliometrix", quietly = TRUE)) {
  results <- bibliometrix::biblioAnalysis(m)
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
