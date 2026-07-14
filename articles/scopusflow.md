# Get started

``` r

library(scopusflow)
```

This vignette is fully reproducible without a Scopus API key. It draws
on a small static fixture bundled with the package, so the whole
workflow can be shown offline. The few steps that genuinely need the API
are shown but not run.

## Describing a search as a plan

A plan separates describing a search from executing it. Plans are
inspectable, saveable and version-controllable, and they can be
partitioned, for example by year, so that a large retrieval stays under
the API’s `start < 5000` ceiling and can be cached and resumed.

``` r

plan <- scopus_plan(
  "machine translation",
  years     = 2018:2020,
  field     = "TITLE-ABS-KEY",
  partition = "year"
)
plan
```

| cell | query                              | date | year | view     | page_size |
|-----:|:-----------------------------------|:-----|-----:|:---------|----------:|
|    1 | TITLE-ABS-KEY(machine translation) | 2018 | 2018 | STANDARD |       200 |
|    2 | TITLE-ABS-KEY(machine translation) | 2019 | 2019 | STANDARD |       200 |
|    3 | TITLE-ABS-KEY(machine translation) | 2020 | 2020 | STANDARD |       200 |

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

scopus_count("machine translation", years = 2018:2020, field = "TITLE-ABS-KEY")

records <- scopus_fetch_plan(plan, cache_dir = scopus_cache_dir(), resume = TRUE)
```

## The record schema

Whether records come from the API or from the bundled example data, they
share one stable schema. The package ships a small, already normalised
set, which we use here to continue offline:

``` r

records <- example_records
records
```

| entry_number | scopus_id | doi | title | authors | year | date | publication | citations | query |
|---:|:---|:---|:---|:---|---:|:---|:---|---:|:---|
| 1 | 85000000001 | 10.1038/s41586-019-0001-1 | Genome editing with CRISPR-Cas9: principles and applications | Zhang F. | 2019 | 2019-04-12 | Nature | 540 | illustrative multi-disciplinary sample |
| 2 | 85000000002 | 10.1038/s41586-020-0002-2 | Deep learning for medical image analysis: a review | Kumar S. | 2020 | 2020-02-20 | Nature | 210 | illustrative multi-disciplinary sample |
| 3 | 85000000003 | 10.1038/s41558-018-0085-1 | Climate change adaptation in coastal megacities | Okafor N. | 2018 | 2018-03-19 | Nature Climate Change | 122 | illustrative multi-disciplinary sample |
| 4 | 85000000004 | 10.1002/adma.202100001 | Graphene electrodes for next-generation energy storage | Tanaka H. | 2021 | 2021-01-15 | Advanced Materials | 45 | illustrative multi-disciplinary sample |
| 5 | 85000000005 | 10.1016/S1470-2045(20)30013-9 | Checkpoint inhibitors in cancer immunotherapy | Garcia M. | 2020 | 2020-07-01 | The Lancet Oncology | 388 | illustrative multi-disciplinary sample |
| 6 | 85000000006 | 10.1103/PhysRevLett.116.061102 | Observation of gravitational waves from a binary black hole merger | Abbott B. | 2016 | 2016-02-11 | Physical Review Letters | 4200 | illustrative multi-disciplinary sample |

``` r


# A record set is a classed tibble; is_scopus_records() confirms the contract.
is_scopus_records(records)
#> [1] TRUE
```

[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
produces this same shape from a raw API response, flattening the nested
result into one row per record:

``` r

# A couple of records in the shape the Scopus API returns them.
raw <- list(entry = list(
  list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1000/aaa",
       `dc:title` = "A reproducible workflow", `dc:creator` = "Smith J.",
       `prism:publicationName` = "J. Bibliometrics",
       `prism:coverDate` = "2020-05-01", `citedby-count` = "12"),
  list(`dc:identifier` = "SCOPUS_ID:2", `prism:doi` = "10.1000/bbb",
       `dc:title` = "Quota-aware querying", `dc:creator` = "Doe A.",
       `prism:publicationName` = "Scientometrics Today",
       `prism:coverDate` = "2021-01-10", `citedby-count` = "3")
))
scopus_records(raw, query = "TITLE-ABS-KEY(workflow)")
```

| entry_number | scopus_id | doi | title | authors | year | date | publication | citations | query |
|---:|:---|:---|:---|:---|---:|:---|:---|---:|:---|
| 1 | 1 | 10.1000/aaa | A reproducible workflow | Smith J. | 2020 | 2020-05-01 | J. Bibliometrics | 12 | TITLE-ABS-KEY(workflow) |
| 2 | 2 | 10.1000/bbb | Quota-aware querying | Doe A. | 2021 | 2021-01-10 | Scientometrics Today | 3 | TITLE-ABS-KEY(workflow) |

## Most frequent sources and authors

A record set already answers the first descriptive questions.
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
tallies the most frequent sources or authors, counting each contributor
once per record:

``` r

scopus_top(records, by = "source")
```

| value                   |   n |
|:------------------------|----:|
| Nature                  |   2 |
| Advanced Materials      |   1 |
| Nature Climate Change   |   1 |
| Physical Review Letters |   1 |
| The Lancet Oncology     |   1 |

[`vignette("analysing-a-literature")`](https://pablobernabeu.github.io/scopusflow/articles/analysing-a-literature.md)
covers growth trends, top-source and top-author plots and abstract
retrieval in depth.

## DOIs and change tracking

Extract a clean, deduplicated DOI list for import into a reference
manager, and compare two retrievals to see exactly what changed:

``` r

dois <- scopus_extract_dois(records)
dois
#> [1] "10.1038/s41586-019-0001-1"      "10.1038/s41586-020-0002-2"     
#> [3] "10.1038/s41558-018-0085-1"      "10.1002/adma.202100001"        
#> [5] "10.1016/S1470-2045(20)30013-9"  "10.1103/PhysRevLett.116.061102"

# Suppose a later retrieval added one DOI and dropped another.
later <- c(dois[-1], "10.1000/example.999")
scopus_diff_dois(old = dois, new = later)
```

| doi                            | status    |
|:-------------------------------|:----------|
| 10.1000/example.999            | added     |
| 10.1038/s41586-019-0001-1      | removed   |
| 10.1002/adma.202100001         | unchanged |
| 10.1016/S1470-2045(20)30013-9  | unchanged |
| 10.1038/s41558-018-0085-1      | unchanged |
| 10.1038/s41586-020-0002-2      | unchanged |
| 10.1103/PhysRevLett.116.061102 | unchanged |

You can write the DOIs to a path you specify, and read the file back to
see exactly what lands on disk:

``` r

out <- file.path(tempdir(), "dois.csv")
scopus_extract_dois(records, file = out)
writeLines(readLines(out))
```

    "doi"
    "10.1038/s41586-019-0001-1"
    "10.1038/s41586-020-0002-2"
    "10.1038/s41558-018-0085-1"
    "10.1002/adma.202100001"
    "10.1016/S1470-2045(20)30013-9"
    "10.1103/PhysRevLett.116.061102"

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

head(as_bibliometrix(records))
```

| AU | TI | SO | DI | PY | TC | UT | DB |
|:---|:---|:---|:---|---:|---:|:---|:---|
| ZHANG F. | GENOME EDITING WITH CRISPR-CAS9: PRINCIPLES AND APPLICATIONS | NATURE | 10.1038/s41586-019-0001-1 | 2019 | 540 | 85000000001 | SCOPUS |
| KUMAR S. | DEEP LEARNING FOR MEDICAL IMAGE ANALYSIS: A REVIEW | NATURE | 10.1038/s41586-020-0002-2 | 2020 | 210 | 85000000002 | SCOPUS |
| OKAFOR N. | CLIMATE CHANGE ADAPTATION IN COASTAL MEGACITIES | NATURE CLIMATE CHANGE | 10.1038/s41558-018-0085-1 | 2018 | 122 | 85000000003 | SCOPUS |
| TANAKA H. | GRAPHENE ELECTRODES FOR NEXT-GENERATION ENERGY STORAGE | ADVANCED MATERIALS | 10.1002/adma.202100001 | 2021 | 45 | 85000000004 | SCOPUS |
| GARCIA M. | CHECKPOINT INHIBITORS IN CANCER IMMUNOTHERAPY | THE LANCET ONCOLOGY | 10.1016/S1470-2045(20)30013-9 | 2020 | 388 | 85000000005 | SCOPUS |
| ABBOTT B. | OBSERVATION OF GRAVITATIONAL WAVES FROM A BINARY BLACK HOLE MERGER | PHYSICAL REVIEW LETTERS | 10.1103/PhysRevLett.116.061102 | 2016 | 4200 | 85000000006 | SCOPUS |

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
