# Plot the most frequent values in a record set

Draws a horizontal bar chart from the output of
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md).

## Usage

``` r
plot_scopus_top(x, ...)

# S3 method for class 'scopus_top'
autoplot(object, ...)
```

## Arguments

- x:

  A `scopus_top` object from
  [`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md).

- ...:

  Currently unused, present for S3 consistency.

- object:

  A `scopus_top` object (for the `autoplot()` method).

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object. Needs the suggested package ggplot2.

## See also

[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)

## Examples

``` r
# On the bundled corpus of real articles, which needs no key.
plot_scopus_top(scopus_top(example_records, by = "source"))
```
