# Search plans and quota-aware retrieval

``` r

library(scopusflow)
```

The Elsevier Scopus Search API is generous but bounded. A weekly quota
limits how many requests you may make, a short-term rate limit caps how
fast you may make them, and no single query will return more than its
first 5000 records. This article shows how scopusflow works within those
bounds so that a large retrieval is reproducible, efficient and
resumable. The steps that contact the API need a key and are not run
here. Everything else runs offline.

## A query, built safely

Most queries combine a few terms under a field tag.
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
assembles them without the bracket and tag mistakes that creep in when
fragments are pasted together by hand.

``` r

q <- scopus_query("language learning", "effect size", .field = "TITLE-ABS-KEY")
q
#> [1] "TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size)"
```

The recognised field tags, and what each one searches, are listed by
[`scopus_field_tags()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_field_tags.md).

``` r

scopus_field_tags()
#> # A tibble: 12 × 2
#>    tag                searches                                  
#>    <chr>              <chr>                                     
#>  1 TITLE              Words in the document title               
#>  2 TITLE-ABS-KEY      Title, abstract and keywords              
#>  3 TITLE-ABS-KEY-AUTH Title, abstract, keywords and author names
#>  4 ABS                Abstract text                             
#>  5 KEY                Indexed and author keywords               
#>  6 AUTH               Author names                              
#>  7 AUTHKEY            Author-supplied keywords                  
#>  8 AFFIL              Affiliation, any part                     
#>  9 AFFILORG           Affiliation organisation name             
#> 10 SRCTITLE           Source (publication) title                
#> 11 DOI                Digital Object Identifier                 
#> 12 ALL                All available fields
```

## Describing the search as a plan

A plan records exactly what will be fetched, so it can be saved,
reviewed and re-run. Partitioning by year is the recommended way to stay
under the 5000-record ceiling, since each year becomes its own cell.

``` r

plan <- scopus_plan(q, years = 2010:2020, partition = "year")
plan
#> <scopus_plan> (11 cells, view "STANDARD", partition "year")
#> # A tibble: 11 × 6
#>     cell query                                       date   year view  page_size
#>  * <int> <chr>                                       <chr> <int> <chr>     <int>
#>  1     1 TITLE-ABS-KEY(language learning) AND TITLE… 2010   2010 STAN…       200
#>  2     2 TITLE-ABS-KEY(language learning) AND TITLE… 2011   2011 STAN…       200
#>  3     3 TITLE-ABS-KEY(language learning) AND TITLE… 2012   2012 STAN…       200
#>  4     4 TITLE-ABS-KEY(language learning) AND TITLE… 2013   2013 STAN…       200
#>  5     5 TITLE-ABS-KEY(language learning) AND TITLE… 2014   2014 STAN…       200
#>  6     6 TITLE-ABS-KEY(language learning) AND TITLE… 2015   2015 STAN…       200
#>  7     7 TITLE-ABS-KEY(language learning) AND TITLE… 2016   2016 STAN…       200
#>  8     8 TITLE-ABS-KEY(language learning) AND TITLE… 2017   2017 STAN…       200
#>  9     9 TITLE-ABS-KEY(language learning) AND TITLE… 2018   2018 STAN…       200
#> 10    10 TITLE-ABS-KEY(language learning) AND TITLE… 2019   2019 STAN…       200
#> 11    11 TITLE-ABS-KEY(language learning) AND TITLE… 2020   2020 STAN…       200
```

Each cell carries the query, the year, the view and the page size. The
page size deserves a moment’s attention, because it is where quota is
won or lost.

## Why page size is a quota decision

Scopus charges quota per request, not per record. A page may hold up to
200 records under the `STANDARD` view, or 25 under `COMPLETE`.
Retrieving a thousand records in pages of 200 therefore costs five
requests, where pages of 25 would cost forty. For that reason
`page_size` defaults to the largest the view allows, which is the same
efficiency `rscopus` relies on, and is in no sense an evasion of the
quota: every request is counted, and the 5000-record ceiling still
holds.

``` r

scopus_plan(q, view = "STANDARD")$page_size[1]
#> [1] 200
scopus_plan(q, view = "COMPLETE")$page_size[1]
#> [1] 25
```

## Sizing before spending

Counting is cheap and does not download records, so it is worth doing
first. The count comes back with the parsed quota attached, which lets a
workflow decide whether it has the allowance to proceed.

``` r

n <- scopus_count(q, years = 2010:2020)
n
attr(n, "quota")
```

That allowance is parsed from the response headers by
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md).
To show its shape without a network call, apply it to a constructed
response:

``` r

resp <- httr2::response(
  status_code = 200,
  headers = list(
    `X-RateLimit-Limit`     = "20000",
    `X-RateLimit-Remaining` = "19987",
    `X-RateLimit-Reset`     = "1700000000"
  )
)
scopus_quota(resp)
#> $limit
#> [1] 20000
#> 
#> $remaining
#> [1] 19987
#> 
#> $reset
#> [1] "2023-11-14 22:13:20 UTC"
#> 
#> $status
#> [1] NA
#> 
#> $retry_after
#> [1] NA
```

## Fetching, with caching and resume

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
runs each cell in turn. Given a cache directory it writes each cell to
disk as it completes, so a run interrupted halfway, or stopped by the
quota, resumes from where it left off rather than paying for the same
cells again.

``` r

records <- scopus_fetch_plan(
  plan,
  cache_dir = scopus_cache_dir(),
  resume = TRUE
)
records
```

The cache lives under
[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md).
To force a fresh retrieval, empty it with
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md).
Both are shown but not run, so the article does not touch a real cache:

``` r

scopus_cache_dir()    # where completed cells are written
scopus_cache_clear()  # remove them, so the next run re-fetches from scratch
```

The result is a `scopus_records` tibble, the same shape returned by
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
for a single query and by the bundled `example_records`.

``` r

example_records
#> <scopus_records> 6 records
#> query: "illustrative multi-disciplinary sample"
#> # A tibble: 6 × 9
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… Geno… Zhang …  2019 2019… Nature            540
#> 2            2 85000000002 10.1… Deep… Kumar …  2020 2020… Nature            210
#> 3            3 85000000003 10.1… Clim… Okafor…  2018 2018… Nature Cli…       122
#> 4            4 85000000004 10.1… Grap… Tanaka…  2021 2021… Advanced M…        45
#> 5            5 85000000005 10.1… Chec… Garcia…  2020 2020… The Lancet…       388
#> 6            6 85000000006 10.1… Obse… Abbott…  2016 2016… Physical R…      4200
```

## Combining separate retrievals

Results gathered in separate runs combine safely with
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md),
which renumbers the records and can drop duplicates by Scopus identifier
or DOI. This is preferable to
[`rbind()`](https://rdrr.io/r/base/cbind.html), which would leave
duplicate entry numbers.

``` r

scopus_combine(example_records, example_records, dedupe = TRUE)
#> <scopus_records> 6 records
#> query: "illustrative multi-disciplinary sample"
#> # A tibble: 6 × 9
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… Geno… Zhang …  2019 2019… Nature            540
#> 2            2 85000000002 10.1… Deep… Kumar …  2020 2020… Nature            210
#> 3            3 85000000003 10.1… Clim… Okafor…  2018 2018… Nature Cli…       122
#> 4            4 85000000004 10.1… Grap… Tanaka…  2021 2021… Advanced M…        45
#> 5            5 85000000005 10.1… Chec… Garcia…  2020 2020… The Lancet…       388
#> 6            6 85000000006 10.1… Obse… Abbott…  2016 2016… Physical R…      4200
```

## When the ceiling bites

A query matching more than 5000 records cannot be retrieved in full from
a single call.
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns the first 5000 and warns. The remedy is to split the search by
year, or by any other facet, so that each cell stays under the ceiling.
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
tells you in advance whether a split is needed.

## Handling interruptions

Network and API problems are raised as typed conditions, all inheriting
from `scopus_error`, so a long retrieval can respond to them rather than
stopping dead.

``` r

result <- tryCatch(
  scopus_fetch_plan(plan, cache_dir = scopus_cache_dir()),
  scopus_error_rate_limit = function(e) {
    message("Rate limited; the cached cells are safe. Try again later.")
    NULL
  }
)
```

Because each completed cell is already cached, resuming after such a
pause costs nothing for the work already done.
