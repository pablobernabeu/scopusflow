# Designing precise queries across disciplines

``` r

library(scopusflow)
```

A retrieval is only as good as its query. This article shows how to
compose correct, field-tagged ‘Scopus’ queries with
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md),
which spares you pasting fragments together by hand, where a missing
bracket or a mistyped tag quietly returns the wrong records. Everything
here is string construction, so it all runs offline, and each query is
shown as the literal string it produces.

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

# molecular biology
scopus_query("CRISPR", .field = "TITLE-ABS-KEY")
```

    [1] "TITLE-ABS-KEY(CRISPR)"

``` r

scopus_query("gravitational waves", .field = "TITLE-ABS-KEY") # physics
```

    [1] "TITLE-ABS-KEY(gravitational waves)"

``` r

# environmental science
scopus_query("microplastics", .field = "TITLE-ABS-KEY")
```

    [1] "TITLE-ABS-KEY(microplastics)"

``` r

scopus_query("blockchain", .field = "TITLE-ABS-KEY")          # computer science
```

    [1] "TITLE-ABS-KEY(blockchain)"

``` r

scopus_query("digital humanities", .field = "AUTHKEY")        # humanities
```

    [1] "AUTHKEY(digital humanities)"

The last example uses `AUTHKEY`, the author-supplied keywords, which
isolates work that self-identifies with a field and so cuts incidental
mentions.

## Combining terms with boolean operators

Passing several terms joins them. The default operator is `AND`, and
`OR` or `AND NOT` are available through `.op`.

``` r

# Two concepts that must co-occur (materials science).
scopus_query("perovskite", "solar cell", .field = "TITLE-ABS-KEY")
```

    [1] "TITLE-ABS-KEY(perovskite) AND TITLE-ABS-KEY(solar cell)"

``` r

# Two names for one condition, either of which will do (medicine). writeLines()
# shows the quotation marks without the backslashes R prints to escape them.
writeLines(scopus_query('"heart attack"', '"myocardial infarction"', .op = "OR"))
```

    "heart attack" OR "myocardial infarction"

``` r

# A family of related tools (molecular biology).
scopus_query("CRISPR", "Cas9", "Cas12", .op = "OR")
```

    [1] "CRISPR OR Cas9 OR Cas12"

``` r

# Excluding a dominant homonym, so the snake stays out of the results.
scopus_query("python", "snake", .op = "AND NOT", .field = "TITLE-ABS-KEY")
```

    [1] "TITLE-ABS-KEY(python) AND NOT TITLE-ABS-KEY(snake)"

## Phrases

‘Scopus’ joins the words of an unquoted term with AND, so `heart attack`
finds records that mention both words anywhere in the searched field.
Double quotation marks ask for a loose phrase, whose words must sit next
to each other, although punctuation is ignored and plurals are included.
Braces ask for an exact phrase, including any stop words, spaces and
punctuation. Elsevier’s [search
tips](https://dev.elsevier.com/sc_search_tips.html) describe all three.

``` r

writeLines(scopus_query('"heart attack"', .field = "TITLE-ABS-KEY")) # loose phrase
```

    TITLE-ABS-KEY("heart attack")

``` r

writeLines(scopus_query("{heart attack}", .field = "TITLE-ABS-KEY")) # exact phrase
```

    TITLE-ABS-KEY({heart attack})

[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
leaves both kinds of phrase as written. When terms are joined without a
field tag, a term of several unquoted words is put in brackets, so it
stays one operand of the join. Joined bare, the first query below would
read as `machine AND (learning OR deep) AND learning`.

``` r

writeLines(scopus_query("machine learning", "deep learning", .op = "OR"))
```

    (machine learning) OR (deep learning)

``` r

writeLines(scopus_query('"machine learning"', '"deep learning"', .op = "OR"))
```

    "machine learning" OR "deep learning"

## Brackets in a query written by hand

A query that mixes operators needs brackets to say what it means. The
search tips state that ‘Scopus’ applies OR first, then AND, then AND
NOT, so `A AND NOT B AND C` reads as `A AND NOT (B AND C)`. Elsevier has
announced a new order, with AND NOT first, then AND, then OR ([Feldner,
2025](https://blog.scopus.com/boolean-searches-in-scopus-understanding-operator-precedence-best-practices/)),
under which `A OR B AND C` reads as `A OR (B AND C)`. Brackets give the
same reading under either order.

The package brackets the strings it composes. A query built by an
earlier
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
call keeps its own join together when it is joined again, as below, and
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
and
[`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)
bracket each side of their joins. The year limit of a plan, a count or a
trend never enters the query string, since it travels as a separate
request parameter.

``` r

young <- scopus_query("children", "adolescents", .op = "OR")
scopus_query("vaccine", young)
```

    [1] "vaccine AND (children OR adolescents)"

## From a query to a plan

A composed query drops straight into the rest of the workflow. Here it
anchors a year-partitioned plan, which keeps each cell under the API’s
5000-record ceiling.

``` r

q <- scopus_query("gut microbiome", "immunology", .field = "TITLE-ABS-KEY")
q
```

    [1] "TITLE-ABS-KEY(gut microbiome) AND TITLE-ABS-KEY(immunology)"

``` r

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

Without a key,
[`vignette("scopusflow")`](https://pablobernabeu.github.io/scopusflow/articles/scopusflow.md)
carries the same two steps through to a record set, standing the bundled
corpus of real articles in for the harvest, since ‘Scopus’ records may
not be redistributed.

## Searching by affiliation

Field tags reach beyond topics. `AFFILORG` searches the affiliation,
which turns a query into an institution-level view of output.

``` r

scopus_query("Max Planck", .field = "AFFILORG")
```

    [1] "AFFILORG(Max Planck)"

## When a term is empty

The builder validates its input, so a stray empty term is caught at
construction, well before it can produce a malformed query.

``` r

tryCatch(
  scopus_query("graphene", ""),
  scopus_error_bad_input = function(e) conditionMessage(e)
)
```

    [1] "`...` must be one or more non-empty character terms."

## Checks before any request

[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md),
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md),
[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md),
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
and
[`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)
check each query offline before anything is sent, and refuse three
mistakes. Refinement syntax copied from the web interface, such as
`LIMIT-TO(DOCTYPE, "ar")`, is ignored by the Search API, so the search
would run unfiltered with no sign of a problem. A field tag wrapped
around a query that already opens with one is rejected by the API. A
bracket, quotation mark or brace left unclosed changes what the rest of
the query means. Each raises `scopus_error_bad_input` with a message
saying what to write instead.

``` r

tryCatch(
  scopus_plan('working memory AND (LIMIT-TO (DOCTYPE, "ar"))'),
  scopus_error_bad_input = function(e) writeLines(strwrap(conditionMessage(e), 76))
)
```

    The query contains LIMIT-TO() or EXCLUDE(), which belong to the Scopus web
    interface's refinement panel. The Search API does not apply them, so the
    search would run unfiltered (pybliometrics documents LIMIT-TO() as
    affecting the display only). Write the limit as a search field instead,
    such as DOCTYPE(ar), LANGUAGE(english), SUBJAREA(PSYC), SRCTYPE(j) or
    PUBYEAR > 2015.

Written as search fields, the same limits pass the check.

``` r

scopus_plan("working memory AND DOCTYPE(ar) AND LANGUAGE(english)")$query
```

    [1] "working memory AND DOCTYPE(ar) AND LANGUAGE(english)"

A strategy pasted from the advanced search with its own tags, such as
`TITLE-ABS-KEY ( "working memory" )`, is sent as written when `field` is
left as `NULL`. `INDEXTERMS()`, which pybliometrics documents as not
working through the Search API, raises a warning, and `KEY()` searches
the index terms together with author keywords, trade names and chemical
names.

## Checking recall against known records

A search strategy can be tested against records already known to be
relevant, for instance the studies included in an earlier review or
those named by experts, collected without the strategy’s help. The share
of them the strategy retrieves is its relative recall ([Sampson et al.,
2006](https://doi.org/10.1186/1471-2288-6-33)), and [Bramer et
al. (2018)](https://doi.org/10.5195/jmla.2018.283) make the check a step
in developing a search. It takes two searches per chain of DOIs, run
under the same year limit. The chain alone finds which known records
‘Scopus’ indexes, and the strategy joined to the chain finds which of
those it retrieves. A known record the chain does not find, because
‘Scopus’ does not index it or holds it without that DOI, cannot show
whether the strategy finds it. It is left out of the denominator and
listed, so it can be checked by hand.

The sketch below contacts the API, so it is not run here. The DOIs are
placeholders for your own, and
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
cleans them first, so a resolver prefix or a difference in case does no
harm. Chains of at most 25 DOIs keep each request short. How the API
treats much longer chains has not been checked.

``` r

known <- scopus_extract_dois(
  c("10.xxxx/known-1", "https://doi.org/10.xxxx/known-2", "doi:10.xxxx/known-3")
)
strategy <- scopus_query("working memory", "training", .field = "TITLE-ABS-KEY")
years <- 2010:2024

chains <- vapply(
  split(known, ceiling(seq_along(known) / 25)),
  function(dois) paste(sprintf('DOI("%s")', dois), collapse = " OR "),
  character(1)
)
found <- function(query) {
  tolower(scopus_extract_dois(scopus_fetch(query, years = years)))
}

indexed <- unique(unlist(lapply(chains, found)))
retrieved <- unique(unlist(lapply(chains, function(chain) {
  found(sprintf("(%s) AND (%s)", strategy, chain))
})))
not_found <- setdiff(tolower(known), indexed)
relative_recall <- length(retrieved) / length(indexed)
```

The figure describes the strategy against this reference set alone, so
report the set, its source and the DOIs left out alongside it.
