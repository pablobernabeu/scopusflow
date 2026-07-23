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
# Drawn from the bundled corpus of real articles, which needs no key. That
# corpus is a complete harvest, so its rows per year are the publications
# per year its query returns.
by_year <- table(example_records$year)
tr <- tibble::tibble(
  query = "TITLE-ABS-KEY(graphene supercapacitor)",
  year = as.integer(names(by_year)),
  n = as.numeric(by_year)
)
class(tr) <- c("scopus_trend", class(tr))
plot_scopus_trend(tr)
```
