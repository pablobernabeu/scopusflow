# Plot a publication trend

Draws annual record counts over time from the output of
[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md).

## Usage

``` r
plot_scopus_trend(x, ...)

# S3 method for class 'scopus_trend'
autoplot(object, ...)
```

## Arguments

- x:

  A `scopus_trend` object from
  [`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md).

- ...:

  Currently unused, present for S3 consistency.

- object:

  A `scopus_trend` object (for the `autoplot()` method).

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object. Needs the suggested package ggplot2.

## See also

[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)

## Examples

``` r
tr <- tibble::tibble(query = "q", year = 2015:2020, n = c(120, 180, 240, 310, 400, 520))
class(tr) <- c("scopus_trend", class(tr))
plot_scopus_trend(tr)
```
