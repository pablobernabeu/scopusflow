# Comparing topics over time

``` r

library(scopusflow)
```

A common bibliometric question is not how large a literature is, but how
its internal emphasis shifts over time. Within research on language
learning, say, is the share of work that also discusses effect sizes
growing?
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
answers exactly this, and
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
shows the answer. The comparison itself contacts the API, so it is shown
but not run; the plotting is reproduced offline from an object of the
same shape.

## What the comparison measures

For each year and each comparison term, the function counts the records
matching the reference topic *and* that term, and expresses it as a
percentage of the records matching the reference *alone*. A value of 30%
for “effect size” in 2020 means that 30% of the language-learning
records that year also mention effect sizes. The reference is the
denominator, so it sits at 100% by construction and is not drawn.

``` r

cmp <- scopus_compare_topics(
  reference_query  = "language learning",
  comparison_terms = c("effect size", "Bayesian", "replication"),
  years            = 2014:2021,
  field            = "TITLE-ABS-KEY"
)
```

## The shape of the result

The result is a tidy table with one row per topic and year. We build one
here with the same columns so the rest of the article runs without a
key.

``` r

years <- 2014:2021
cmp <- tibble::tibble(
  query = "q",
  query_type = c(rep("reference", length(years)),
                 rep("comparison", 3 * length(years))),
  abridged_query = c(rep("language learning", length(years)),
                     rep(c("effect size", "Bayesian", "replication"),
                         each = length(years))),
  year = rep(years, 4),
  n = c(rep(900, length(years)),
        round(seq(120, 360, length.out = length(years))),
        round(seq(40, 200, length.out = length(years))),
        round(seq(20, 150, length.out = length(years)))),
  reference_n = rep(900, 4 * length(years)),
  comparison_percentage = c(rep(100, length(years)),
                            seq(13, 40, length.out = length(years)),
                            seq(4, 22, length.out = length(years)),
                            seq(2, 17, length.out = length(years))),
  average_comparison_percentage = c(rep(100, length(years)),
                                    rep(c(27, 13, 9), each = length(years)))
)
class(cmp) <- c("scopus_comparison", class(cmp))
cmp
#> <scopus_comparison> (4 topics)
#> # A tibble: 32 × 8
#>    query query_type abridged_query  year     n reference_n comparison_percentage
#>    <chr> <chr>      <chr>          <int> <dbl>       <dbl>                 <dbl>
#>  1 q     reference  language lear…  2014   900         900                 100  
#>  2 q     reference  language lear…  2015   900         900                 100  
#>  3 q     reference  language lear…  2016   900         900                 100  
#>  4 q     reference  language lear…  2017   900         900                 100  
#>  5 q     reference  language lear…  2018   900         900                 100  
#>  6 q     reference  language lear…  2019   900         900                 100  
#>  7 q     reference  language lear…  2020   900         900                 100  
#>  8 q     reference  language lear…  2021   900         900                 100  
#>  9 q     comparison effect size     2014   120         900                  13  
#> 10 q     comparison effect size     2015   154         900                  16.9
#> # ℹ 22 more rows
#> # ℹ 1 more variable: average_comparison_percentage <dbl>
```

The `comparison_percentage` column is the per-year share, and
`average_comparison_percentage` is the same ratio computed over the
whole period, which is what orders the topics. A year in which the
reference has no records has no defined share and is recorded as `NA`
rather than as a misleading zero.

## A first plot

``` r

plot_scopus_comparison(cmp)
```

![Three topics' share of the language-learning literature from 2014 to
2021](comparing-topics_files/figure-html/unnamed-chunk-4-1.png)

The chart uses whole-number year breaks, a colour-blind-safe palette
and, because there are only a few topics, labels the lines directly so
the reader need not match colours to a legend. Each label carries the
topic’s total record count.

## Drawing the eye to one topic

When one topic is the focus of a figure, `highlight` draws it in an
accent colour and greys the rest, which keeps the context visible
without letting it compete.

``` r

plot_scopus_comparison(cmp, highlight = "Bayesian")
```

![The same chart with the Bayesian topic highlighted against the others
in grey](comparing-topics_files/figure-html/unnamed-chunk-5-1.png)

## Adjusting the labels

The count suffix on each label can be turned off when a cleaner look is
wanted.

``` r

plot_scopus_comparison(cmp, pub_count_in_legend = FALSE)
```

![The comparison chart without record counts in the
labels](comparing-topics_files/figure-html/unnamed-chunk-6-1.png)

The return value is an ordinary [ggplot2](https://ggplot2.tidyverse.org)
object, so any further adjustment, a different theme or a saved file, is
one `+` or one
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
away.

## Reading the result as a table

Sometimes the numbers matter more than the picture. Because the output
is a tibble, the usual tools apply: here are the topics ranked by their
average share.

``` r

comp <- cmp[cmp$query_type == "comparison", ]
unique(comp[, c("abridged_query", "average_comparison_percentage")])
#> <scopus_comparison> (3 topics)
#> # A tibble: 3 × 2
#>   abridged_query average_comparison_percentage
#>   <chr>                                  <dbl>
#> 1 effect size                               27
#> 2 Bayesian                                  13
#> 3 replication                                9
```
