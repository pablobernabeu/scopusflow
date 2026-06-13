# Plot a topic comparison

Draws a line chart of comparison percentage over time, one line per
comparison topic, from the output of
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md).

## Usage

``` r
plot_scopus_comparison(x, pub_count_in_legend = TRUE, ...)

# S3 method for class 'scopus_comparison'
autoplot(object, ...)
```

## Arguments

- x:

  A `scopus_comparison` object from
  [`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md).

- pub_count_in_legend:

  Logical, appending each topic's total record count to its legend label
  by default.

- ...:

  Currently unused, present for S3 consistency.

- object:

  A `scopus_comparison` object (for the `autoplot()` method).

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object. Printing it draws the plot.

## Details

This needs the suggested package ggplot2 and raises an informative error
when it is absent. The chart shows the comparison topics alone, since
the reference is the 100% denominator against which they are measured.

## See also

[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)

## Examples

``` r
cmp <- tibble::tibble(
  query = "q", query_type = "comparison", abridged_query = rep(c("a", "b"), each = 3),
  year = rep(2018:2020, 2), n = c(5, 6, 7, 1, 2, 3), reference_n = rep(10, 6),
  comparison_percentage = c(50, 60, 70, 10, 20, 30),
  average_comparison_percentage = rep(c(60, 20), each = 3)
)
class(cmp) <- c("scopus_comparison", class(cmp))
plot_scopus_comparison(cmp)
```
