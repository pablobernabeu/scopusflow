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
# On the bundled corpus of real articles, which stands in for a retrieval
# of your own because 'Scopus' records may not be redistributed.
m <- as_bibliometrix(example_records)
head(m[, c("AU", "TI", "PY", "SO", "TC", "DB")])
#>               AU
#> 1     JIANHUA YU
#> 2 PATRICK R RICE
#> 3    ZHIWEI PENG
#> 4   VIKRANT SAHU
#> 5 CHIH-TAO CHIEN
#> 6       HAO YANG
#>                                                                                                                                             TI
#> 1 ENHANCED CAPACITIVE PROPERTIES OF ALL-SOLID-STATE SYMMETRIC GRAPHENE SUPERCAPACITORS BY INCORPORATING NITROGEN-DOPING AND SNO2 NANOPARTICLES
#> 2                                                            FABRICATION AND CHARACTERIZATION OF A VERTICALLY-ORIENTED GRAPHENE SUPERCAPACITOR
#> 3                                                                                FLEXIBLE AND STACKABLE LASER-INDUCED GRAPHENE SUPERCAPACITORS
#> 4                                                                             HEAVILY NITROGEN DOPED, GRAPHENE SUPERCAPACITOR FROM SILK COCOON
#> 5                                                                      GRAPHENE-BASED INTEGRATED PHOTOVOLTAIC ENERGY HARVESTING/STORAGE DEVICE
#> 6                          NANOPOROUS GRAPHENE MATERIALS BY LOW-TEMPERATURE VACUUM-ASSISTED THERMAL PROCESS FOR ELECTROCHEMICAL ENERGY STORAGE
#>     PY                                                                 SO  TC
#> 1 2015                                     JOURNAL OF INORGANIC MATERIALS   1
#> 2 2015 DIGITALCOMMONS - CALPOLY (CALIFORNIA STATE POLYTECHNIC UNIVERSITY)   0
#> 3 2015                                 ACS APPLIED MATERIALS & INTERFACES 469
#> 4 2015                                                ELECTROCHIMICA ACTA 195
#> 5 2015                                                              SMALL 108
#> 6 2015                                           JOURNAL OF POWER SOURCES  47
#>       DB
#> 1 SCOPUS
#> 2 SCOPUS
#> 3 SCOPUS
#> 4 SCOPUS
#> 5 SCOPUS
#> 6 SCOPUS
```
