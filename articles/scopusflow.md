# Get started

``` r

library(scopusflow)
```

This vignette is fully reproducible without a Scopus API key. Elsevier’s
API terms do not permit redistributing retrieved records, so no package
can ship a genuine Scopus harvest, and scopusflow bundles an openly
licensed stand-in instead. `example_records` holds 138 real journal
articles on graphene supercapacitors published between 2015 and 2024,
with their real titles, DOIs, journals, first authors and citation
counts. They come from OpenAlex, whose metadata is released under CC0,
reshaped into the schema a retrieval returns. The harvest is complete
rather than sampled, so its rows per year are the real number of
publications per year for that query, and its gaps are genuine too:
eleven records carry no DOI and two no source title, exactly as they
arrive. Running the equivalent query against Scopus yields the same kind
of object, with the same columns and the same handling, though not an
identical set of records. The steps that genuinely need the API are
shown but not run, each paired with the offline equivalent.

## Describing a search as a plan

A plan separates describing a search from executing it. Plans are
inspectable, saveable and version-controllable, and they can be
partitioned, for example by year, so that a large retrieval stays under
the API’s `start < 5000` ceiling and can be cached and resumed.

The plan below describes the search the bundled records came from, so
the rest of the article follows one worked example from description to
export.

``` r

plan <- scopus_plan(
  "graphene supercapacitor",
  years     = 2015:2024,
  field     = "TITLE-ABS-KEY",
  partition = "year"
)
plan
```

| cell | query                                  | date | year | view     | page_size |
|-----:|:---------------------------------------|:-----|-----:|:---------|----------:|
|    1 | TITLE-ABS-KEY(graphene supercapacitor) | 2015 | 2015 | STANDARD |       200 |
|    2 | TITLE-ABS-KEY(graphene supercapacitor) | 2016 | 2016 | STANDARD |       200 |
|    3 | TITLE-ABS-KEY(graphene supercapacitor) | 2017 | 2017 | STANDARD |       200 |
|    4 | TITLE-ABS-KEY(graphene supercapacitor) | 2018 | 2018 | STANDARD |       200 |
|    5 | TITLE-ABS-KEY(graphene supercapacitor) | 2019 | 2019 | STANDARD |       200 |
|    6 | TITLE-ABS-KEY(graphene supercapacitor) | 2020 | 2020 | STANDARD |       200 |
|    7 | TITLE-ABS-KEY(graphene supercapacitor) | 2021 | 2021 | STANDARD |       200 |
|    8 | TITLE-ABS-KEY(graphene supercapacitor) | 2022 | 2022 | STANDARD |       200 |
|    9 | TITLE-ABS-KEY(graphene supercapacitor) | 2023 | 2023 | STANDARD |       200 |
|   10 | TITLE-ABS-KEY(graphene supercapacitor) | 2024 | 2024 | STANDARD |       200 |

Each row is one query cell. Field tags wrap the query and years become a
date filter:

``` r

scopus_plan("language learning", field = "TITLE")$query
#> [1] "TITLE(language learning)"
scopus_plan("x", years = 2015:2020)$date
#> [1] "2015-2020"

# A plan is a classed object; is_scopus_plan() confirms it.
is_scopus_plan(plan)
#> [1] TRUE
```

## Sizing and fetching

[`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)
reports whether a key is configured, without revealing it. It is the
guard the package’s own examples use to skip the steps that need the
API, so it is the natural switch for a reproducible script:

``` r

scopus_has_key()
#> [1] FALSE
```

With a key configured, you size a search cheaply and then execute the
plan, optionally caching each cell so that an interrupted run resumes
without re-spending quota. These contact the API, so they are not
evaluated here:

``` r

scopus_count("graphene supercapacitor", years = 2015:2024, field = "TITLE-ABS-KEY")

records <- scopus_fetch_plan(plan, cache_dir = scopus_cache_dir(), resume = TRUE)
```

Without a key, the bundled corpus stands in for the result of that
harvest, and the sections below run on it.

## The record schema

Whether records come from the API or from the bundled corpus, they share
one stable schema, so everything below would read the same on a harvest
of your own. [`summary()`](https://rdrr.io/r/base/summary.html) takes
stock of a set, and the first rows show the columns:

``` r

records <- example_records
summary(records)
#> <scopus_records> summary
#> 138 records, from 2015 to 2024.
#> 90 sources, 127 with a DOI.
#> Cited 7015 times in total, median 24 per record.
#> Most frequent source: ACS Applied Materials & Interfaces.
#> Most cited: Graphene for batteries, supercapacitors and beyond.

head(records)
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


# A record set is a classed tibble; is_scopus_records() confirms the contract.
is_scopus_records(records)
#> [1] TRUE
```

[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
produces this same shape from a raw API response, flattening the nested
result into one row per record. The entry below carries the fields of a
real article, one of those in the bundled corpus, in the form the API
returns them:

``` r

raw <- list(entry = list(
  list(`prism:doi` = "10.1021/am509065d",
       `dc:title` = "Flexible and Stackable Laser-Induced Graphene Supercapacitors",
       `dc:creator` = "Zhiwei Peng",
       `prism:publicationName` = "ACS Applied Materials & Interfaces",
       `prism:coverDate` = "2015-01-13", `citedby-count` = "469")
))
scopus_records(raw, query = "TITLE-ABS-KEY(graphene supercapacitor)")
```

| entry_number | scopus_id | doi | title | authors | year | date | publication | citations | query |
|---:|:---|:---|:---|:---|---:|:---|:---|---:|:---|
| 1 | NA | 10.1021/am509065d | Flexible and Stackable Laser-Induced Graphene Supercapacitors | Zhiwei Peng | 2015 | 2015-01-13 | ACS Applied Materials & Interfaces | 469 | TITLE-ABS-KEY(graphene supercapacitor) |

## Most frequent sources and authors

A record set already answers the first descriptive questions.
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
tallies the most frequent sources or authors, counting each contributor
once per record. Across these 138 articles the tally is long-tailed, as
a real literature is. They are spread over 90 distinct journals, and
only one, *ACS Applied Materials & Interfaces*, appears more than five
times.

``` r

scopus_top(records, by = "source")
```

| value                              |   n |
|:-----------------------------------|----:|
| ACS Applied Materials & Interfaces |   8 |
| Journal of Power Sources           |   5 |
| Synthetic Metals                   |   5 |
| Electrochimica Acta                |   4 |
| Journal of Materials Chemistry A   |   4 |
| Scientific Reports                 |   4 |
| Journal of Alloys and Compounds    |   3 |
| Journal of Energy Storage          |   3 |
| Materials Chemistry and Physics    |   3 |
| Nanotechnology                     |   3 |

[`vignette("analysing-a-literature")`](https://pablobernabeu.github.io/scopusflow/articles/analysing-a-literature.md)
covers growth trends, top-source and top-author plots and abstract
retrieval in depth.

## DOIs and change tracking

Extract a clean, deduplicated DOI list for import into a reference
manager, and compare two retrievals to see exactly what changed. Eleven
of the 138 records arrived without a DOI, so 127 come back:

``` r

dois <- scopus_extract_dois(records)
length(dois)
#> [1] 127
head(dois, 4)
#> [1] "10.15541/jim20140527"            "10.1021/am509065d"              
#> [3] "10.1016/j.electacta.2015.02.019" "10.1002/smll.201403383"
```

A search re-run later gains records and occasionally loses one to
re-indexing. Here the baseline stops at 2023 and the second pull adds
the 2024 articles while dropping the first record:

``` r

baseline <- records[records$year <= 2023, ]
later <- records[-1, ]
print(scopus_diff_dois(old = baseline, new = later))
#> <scopus_doi_diff> 14 added, 1 removed, 112 unchanged
#> # A tibble: 127 × 2
#>    doi                            status
#>    <chr>                          <fct> 
#>  1 10.1002/adfm.202315137         added 
#>  2 10.1002/asia.202400548         added 
#>  3 10.1002/slct.202302535         added 
#>  4 10.1016/j.cej.2024.148822      added 
#>  5 10.1016/j.diamond.2024.110842  added 
#>  6 10.1016/j.isci.2024.111696     added 
#>  7 10.1016/j.jallcom.2024.175000  added 
#>  8 10.1016/j.jallcom.2024.177248  added 
#>  9 10.1016/j.jpowsour.2024.234127 added 
#> 10 10.1016/j.jpowsour.2024.236149 added 
#> # ℹ 117 more rows
```

You can write the DOIs to a path you specify, and read the file back to
see exactly what lands on disk:

``` r

out <- file.path(tempdir(), "dois.csv")
scopus_extract_dois(records, file = out)
writeLines(head(readLines(out), 5))
```

    "doi"
    "10.15541/jim20140527"
    "10.1021/am509065d"
    "10.1016/j.electacta.2015.02.019"
    "10.1002/smll.201403383"

## Comparing topic trends

[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
measures how the internal emphasis of a literature shifts, expressed as
each comparison topic’s yearly share of the reference literature. It
issues one count request per term per year, so it needs the API:

``` r

cmp <- scopus_compare_topics(
  reference_query  = "language learning",
  comparison_terms = c("effect size", "Bayesian"),
  years            = 2015:2020,
  field            = "TITLE-ABS-KEY"
)
plot_scopus_comparison(cmp)
```

The result is a tidy table with one row per topic and year, which
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
draws with direct line labels, a colour-blind-safe palette and shaded
stability bands.
[`vignette("comparing-topics")`](https://pablobernabeu.github.io/scopusflow/articles/comparing-topics.md)
builds the object offline, shows the plot in its variations and explains
how to read the bands.

## Author keywords and references

A search only returns the fields the Search API carries. Author keywords
and a document’s own reference list need `view = "COMPLETE"` and
Abstract Retrieval respectively, both at a materially different quota
cost from an ordinary search;
[`vignette("keywords-and-references")`](https://pablobernabeu.github.io/scopusflow/articles/keywords-and-references.md)
walks through both, and
[`scopus_corpus()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_corpus.md),
which combines them into a minimal
`id`/`title`/`year`/`keywords`/`references` shape for downstream tools.

## Export and interoperability

Hand results to `bibliometrix`-style workflows, or save and reload them:

``` r

m <- as_bibliometrix(records)
head(m[, c("AU", "TI", "PY", "SO", "TC")])
```

| AU | TI | PY | SO | TC |
|:---|:---|---:|:---|---:|
| JIANHUA YU | ENHANCED CAPACITIVE PROPERTIES OF ALL-SOLID-STATE SYMMETRIC GRAPHENE SUPERCAPACITORS BY INCORPORATING NITROGEN-DOPING AND SNO2 NANOPARTICLES | 2015 | JOURNAL OF INORGANIC MATERIALS | 1 |
| PATRICK R RICE | FABRICATION AND CHARACTERIZATION OF A VERTICALLY-ORIENTED GRAPHENE SUPERCAPACITOR | 2015 | DIGITALCOMMONS - CALPOLY (CALIFORNIA STATE POLYTECHNIC UNIVERSITY) | 0 |
| ZHIWEI PENG | FLEXIBLE AND STACKABLE LASER-INDUCED GRAPHENE SUPERCAPACITORS | 2015 | ACS APPLIED MATERIALS & INTERFACES | 469 |
| VIKRANT SAHU | HEAVILY NITROGEN DOPED, GRAPHENE SUPERCAPACITOR FROM SILK COCOON | 2015 | ELECTROCHIMICA ACTA | 195 |
| CHIH-TAO CHIEN | GRAPHENE-BASED INTEGRATED PHOTOVOLTAIC ENERGY HARVESTING/STORAGE DEVICE | 2015 | SMALL | 108 |
| HAO YANG | NANOPOROUS GRAPHENE MATERIALS BY LOW-TEMPERATURE VACUUM-ASSISTED THERMAL PROCESS FOR ELECTROCHEMICAL ENERGY STORAGE | 2015 | JOURNAL OF POWER SOURCES | 47 |

``` r


path <- file.path(tempdir(), "records.rds")
write_scopus_records(records, path)
identical(read_scopus_records(path), records)
#> [1] TRUE
```

## Handling failures

Network and API problems surface as typed conditions, all inheriting
from `scopus_error`, so a workflow can respond to them in code:

``` r

tryCatch(
  scopus_fetch("..."),
  scopus_error_no_key     = function(e) message("No API key configured."),
  scopus_error_rate_limit = function(e) message("Rate limited, so backing off."),
  scopus_error            = function(e) message("Scopus error: ", conditionMessage(e))
)
```
