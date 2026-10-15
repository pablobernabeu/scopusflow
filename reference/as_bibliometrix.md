# Convert records to a bibliometrix-compatible data frame

Re-maps a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble to the tagged column layout used by the bibliometrix package (and
the wider ISI/Web of Science convention), so results can flow into
downstream science-mapping workflows. The fields follow the conventions
`bibliometrix::convert2df()` applies to a 'Scopus' CSV export, so the
two frames describe a record in the same terms.

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
`PY` (publication year), `TC` (times cited), `UT` (the record's EID) and
`DB` (`"SCOPUS"`). `DE` (author keywords) follows when the set carries
the `authkeywords` column of a `view = "COMPLETE"` retrieval. `DT`
(document type), `VL` (volume) and `IS` (issue) follow when it carries
the columns of a `fields = "extended"` retrieval (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)).
Character tag fields other than `DI` are upper-cased, as bibliometrix
upper-cases them.

## Details

Each author in `AU` is written as bibliometrix writes a 'Scopus' author,
the surname followed by the initials without full stops. The authors are
joined by `";"`. A name in the `"Surname, Given"` form the `COMPLETE`
view gives becomes the surname followed by the initial of each given
name, and a hyphenated given name keeps its hyphen. `"Tour, James M."`
thus becomes `"TOUR JM"` and `"Lee, Chul-Hee"` becomes `"LEE C-H"`. A
name without a comma, such as the `STANDARD` view's `"Lee C.-H."`, loses
its full stops and becomes `"LEE C-H"`. Each given name yields one
initial, so a name that 'Scopus' abbreviates to two letters, such as
`"Yu."` for Yuri, keeps both under `STANDARD` and gives one under
`COMPLETE`.

`UT` holds the EID, `"2-S2.0-"` followed by the 'Scopus' identifier, as
a 'Scopus' import gives it, and is `NA` for a record without an
identifier. `sub("^2-S2.0-", "", UT)` gives back the bare identifier.
`DE` holds the author keywords joined by `"; "`, as in a 'Scopus' CSV
export. Keywords are split at the `" | "` the Search API joins them with
and at the `"; "`
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
joins its own with, so either source can fill the `authkeywords` column.

This produces the *shape* bibliometrix expects from the descriptive
fields. It reconstructs only what the 'Scopus' Search API returns, so
richer fields that some bibliometrix analyses use, such as full author
affiliations or cited references, are left out. To obtain those, export
a full 'Scopus' CSV or BibTeX file from the web interface and read it
with `bibliometrix::convert2df()`.

`AU` holds every author only for a retrieval made with
`view = "COMPLETE"`. Under `STANDARD` the API sends the first author
alone, so each document would look single-authored to the collaboration
measures and co-authorship networks bibliometrix builds from `AU`.
Converting a set retrieved under `STANDARD` therefore raises a warning
of class `scopus_warning_first_author_only`, once per session (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)).

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
