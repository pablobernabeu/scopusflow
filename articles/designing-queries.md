# Designing precise queries across disciplines

``` r

library(scopusflow)
```

A retrieval is only as good as its query. This article shows how to
compose correct, field-tagged ‘Scopus’ queries with
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
rather than pasting fragments by hand, where a missing bracket or a
mistyped tag quietly returns the wrong records. Everything here is
string construction, so it all runs offline; each query is shown as the
literal string it produces.

## Field tags decide where to look

A field tag restricts a query to part of a record.
[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md)
lists the common ones.

``` r

scopus_field_tags()
```

| tag                | searches                                   |
|:-------------------|:-------------------------------------------|
| TITLE              | Words in the document title                |
| TITLE-ABS-KEY      | Title, abstract and keywords               |
| TITLE-ABS-KEY-AUTH | Title, abstract, keywords and author names |
| ABS                | Abstract text                              |
| KEY                | Indexed and author keywords                |
| AUTH               | Author names                               |
| AUTHKEY            | Author-supplied keywords                   |
| AFFIL              | Affiliation, any part                      |
| AFFILORG           | Affiliation organisation name              |
| SRCTITLE           | Source (publication) title                 |
| DOI                | Digital Object Identifier                  |
| ALL                | All available fields                       |

The most generally useful tag is `TITLE-ABS-KEY`, which searches the
title, abstract and keywords together, broad enough to catch a topic
without the noise of a full-text match.

## One term, many disciplines

The same builder serves any field. Each call below returns the exact
query string that would be sent to ‘Scopus’.

``` r

scopus_query("CRISPR", .field = "TITLE-ABS-KEY")              # molecular biology
#> [1] "TITLE-ABS-KEY(CRISPR)"
scopus_query("gravitational waves", .field = "TITLE-ABS-KEY") # physics
#> [1] "TITLE-ABS-KEY(gravitational waves)"
scopus_query("microplastics", .field = "TITLE-ABS-KEY")       # environmental science
#> [1] "TITLE-ABS-KEY(microplastics)"
scopus_query("blockchain", .field = "TITLE-ABS-KEY")          # computer science
#> [1] "TITLE-ABS-KEY(blockchain)"
scopus_query("digital humanities", .field = "AUTHKEY")        # humanities
#> [1] "AUTHKEY(digital humanities)"
```

The last example uses `AUTHKEY`, the author-supplied keywords, which
isolates work that self-identifies with a field and so cuts incidental
mentions.

## Combining terms with boolean operators

Passing several terms joins them. The default operator is `AND`, and
`OR` or `AND NOT` are available through `.op`.

``` r

# Two concepts that must co-occur (materials science).
scopus_query("perovskite", "solar cell", .field = "TITLE-ABS-KEY")
#> [1] "TITLE-ABS-KEY(perovskite) AND TITLE-ABS-KEY(solar cell)"

# Spelling variants, either of which will do (economics).
scopus_query("behavioral economics", "behavioural economics", .op = "OR")
#> [1] "behavioral economics OR behavioural economics"

# A family of related tools (molecular biology).
scopus_query("CRISPR", "Cas9", "Cas12", .op = "OR")
#> [1] "CRISPR OR Cas9 OR Cas12"

# Excluding a dominant homonym (programming, not herpetology).
scopus_query("python", "snake", .op = "AND NOT", .field = "TITLE-ABS-KEY")
#> [1] "TITLE-ABS-KEY(python) AND NOT TITLE-ABS-KEY(snake)"
```

## From a query to a plan

A composed query drops straight into the rest of the workflow. Here it
anchors a year-partitioned plan, which keeps each cell under the API’s
5000-record ceiling.

``` r

q <- scopus_query("gut microbiome", "immunology", .field = "TITLE-ABS-KEY")
q
#> [1] "TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology)"
plan <- scopus_plan(q, years = 2015:2022, partition = "year")
plan
```

| cell | query | date | year | view | page_size |
|---:|:---|:---|---:|:---|---:|
| 1 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2015 | 2015 | STANDARD | 200 |
| 2 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2016 | 2016 | STANDARD | 200 |
| 3 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2017 | 2017 | STANDARD | 200 |
| 4 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2018 | 2018 | STANDARD | 200 |
| 5 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2019 | 2019 | STANDARD | 200 |
| 6 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2020 | 2020 | STANDARD | 200 |
| 7 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2021 | 2021 | STANDARD | 200 |
| 8 | TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology) | 2022 | 2022 | STANDARD | 200 |

The plan is ready to size and run, which contacts the API.

``` r

scopus_count(q, years = 2015:2022)
records <- scopus_fetch_plan(plan)
```

## Searching by affiliation

Field tags reach beyond topics. `AFFILORG` searches the affiliation,
which turns a query into an institution-level view of output.

``` r

scopus_query("Max Planck", .field = "AFFILORG")
#> [1] "AFFILORG(Max Planck)"
```

## When a term is empty

The builder validates its input, so a stray empty term is caught early
rather than producing a malformed query.

``` r

tryCatch(
  scopus_query("graphene", ""),
  scopus_error_bad_input = function(e) conditionMessage(e)
)
#> [1] "`...` must be one or more non-empty character terms."
```
