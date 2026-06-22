# Analysing and visualising a literature

``` r

library(scopusflow)
```

Once a set of records is in hand, the package offers a small analysis
layer that turns it into the figures a bibliometric study usually needs.
The steps that contact the API are shown but not run; the rest use the
bundled `example_records` and run offline.

## What is in a record set

[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
tallies the most frequent sources or authors. Author strings that hold
several names are split, so each contributor is counted once per record.

``` r

scopus_top(example_records, by = "source")
#> # A tibble: 5 × 2
#>   value                       n
#> * <chr>                   <int>
#> 1 Nature                      2
#> 2 Advanced Materials          1
#> 3 Nature Climate Change       1
#> 4 Physical Review Letters     1
#> 5 The Lancet Oncology         1
scopus_top(example_records, by = "author", n = 5)
#> # A tibble: 5 × 2
#>   value         n
#> * <chr>     <int>
#> 1 Abbott B.     1
#> 2 Garcia M.     1
#> 3 Kumar S.      1
#> 4 Okafor N.     1
#> 5 Tanaka H.     1
```

``` r

plot_scopus_top(scopus_top(example_records, by = "source"))
```

![A horizontal bar chart of the most frequent
sources](analysing-a-literature_files/figure-html/unnamed-chunk-3-1.png)

The same plot works on the author tally.

``` r

plot_scopus_top(scopus_top(example_records, by = "author", n = 5))
```

![A horizontal bar chart of the most frequent
authors](analysing-a-literature_files/figure-html/unnamed-chunk-4-1.png)

A record set also has an honest default view: `autoplot()` draws its
records per year. The same `autoplot()` generic dispatches on
`scopus_trend` and `scopus_top` objects too, delegating to the plots
above.

``` r

ggplot2::autoplot(example_records)
```

![A bar chart of records per
year](analysing-a-literature_files/figure-html/unnamed-chunk-5-1.png)

## How a literature grows

[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)
counts how many records match a query in each year, which is the size of
a literature over time. It issues one count request per year, so it
needs the API.

``` r

tr <- scopus_trend("graphene", years = 2004:2022, field = "TITLE-ABS-KEY")
plot_scopus_trend(tr)
```

The result has a fixed shape, which we reproduce here to show the plot.

``` r

years <- 2004:2022
tr <- tibble::tibble(query = "TITLE-ABS-KEY(graphene)", year = years,
                     n = round(exp(seq(log(50), log(28000), length.out = length(years)))))
class(tr) <- c("scopus_trend", class(tr))
plot_scopus_trend(tr)
```

![A line and area chart of records per year rising over
time](analysing-a-literature_files/figure-html/unnamed-chunk-7-1.png)

## Reading the fuller record

The Search API returns a few fields per record. To read the abstract and
the fuller metadata for a record you already know,
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
calls the Abstract Retrieval API, by DOI or ‘Scopus’ identifier. A batch
is resilient, so an identifier that cannot be found yields a row of
`NA`s with a warning rather than stopping the run.

``` r

ab <- scopus_abstract(c("10.1038/s41586-019-0001-1", "10.1103/PhysRevLett.116.061102"))
```

The result is a tibble of class `scopus_abstracts`, one row per
identifier. To show its shape without a key, here is a stand-in with the
same columns.

``` r

ab <- tibble::tibble(
  id          = c("10.1038/s41586-019-0001-1", "10.1103/PhysRevLett.116.061102"),
  scopus_id   = c("85060000001", "84960000002"),
  doi         = c("10.1038/s41586-019-0001-1", "10.1103/PhysRevLett.116.061102"),
  title       = c("A single-cell atlas of gene expression",
                  "Observation of gravitational waves from a binary black hole merger"),
  abstract    = c("Here we present a comprehensive single-cell survey of ...",
                  "On 14 September 2015 the two detectors of LIGO observed ..."),
  publication = c("Nature", "Physical Review Letters"),
  year        = c(2019L, 2016L),
  citations   = c(420L, 5400L)
)
class(ab) <- c("scopus_abstracts", class(ab))
ab
#> <scopus_abstracts> (2 records)
#> # A tibble: 2 × 8
#>   id                  scopus_id doi   title abstract publication  year citations
#>   <chr>               <chr>     <chr> <chr> <chr>    <chr>       <int>     <int>
#> 1 10.1038/s41586-019… 85060000… 10.1… A si… Here we… Nature       2019       420
#> 2 10.1103/PhysRevLet… 84960000… 10.1… Obse… On 14 S… Physical R…  2016      5400

ab[, c("doi", "title", "year")]
#> <scopus_abstracts> (2 records)
#> # A tibble: 2 × 3
#>   doi                            title                                      year
#>   <chr>                          <chr>                                     <int>
#> 1 10.1038/s41586-019-0001-1      A single-cell atlas of gene expression     2019
#> 2 10.1103/PhysRevLett.116.061102 Observation of gravitational waves from …  2016
substr(ab$abstract[2], 1, 40)
#> [1] "On 14 September 2015 the two detectors o"
```

## Beyond five thousand records

A single Search API query returns at most its first 5000 records under
the ordinary offset paging. When you need the whole of a larger result
set in one pass, `scopus_fetch(cursor = TRUE)` follows the API’s cursor
instead, which has no such ceiling.

``` r

recs <- scopus_fetch("TITLE-ABS-KEY(microplastics)", cursor = TRUE)
nrow(recs)
```

The records then arrive in the API’s deep-paging order rather than
sorted by relevance, which is the right trade for a complete harvest.
This is the one-call alternative to the year-partitioned plan in the
*Search plans and quota-aware retrieval* article: a plan keeps each cell
under the ceiling and preserves relevance order, whereas `cursor = TRUE`
harvests the whole set in a single pass. Reach for the plan when you
want cached, resumable cells, and the cursor when you want the complete
set at once.
