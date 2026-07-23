# Comparing topics over time

``` r

library(scopusflow)
```

A common bibliometric question is not how large a literature is, but how
its internal emphasis shifts over time. Within deep-learning research,
say, is the share of work that also concerns medical imaging growing
faster than the share about computer vision?
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
for ‘computer vision’ in 2020 means that 30% of the deep-learning
records that year also mention computer vision. The reference is the
denominator, so it sits at 100% by construction and is not drawn.

``` r

cmp <- scopus_compare_topics(
  reference_query  = "deep learning",
  comparison_terms = c("computer vision", "natural language processing",
                       "medical imaging", "drug discovery"),
  years            = 2013:2021,
  field            = "TITLE-ABS-KEY"
)
```

## The shape of the result

The result is a tidy table with one row per topic and year. A comparison
counts whole literatures rather than the records in hand, so unlike a
trend it cannot be derived from the corpus the package bundles for its
other examples. The table below is rebuilt in the same shape, with
illustrative counts, so the rest of the article runs without a key. The
reference set grows over the period, which the uncertainty band will
reflect.

``` r

years <- 2013:2021
ref_n <- round(seq(400, 1600, length.out = length(years)))
mk <- function(from, to) round(seq(from, to, length.out = length(years)))
counts <- list(
  "computer vision" = mk(140, 720),
  "natural language processing" = mk(90, 540),
  "medical imaging" = mk(15, 260),
  "drug discovery" = mk(8, 170)
)
cmp <- tibble::tibble(
  query = "q",
  query_type = c(rep("reference", length(years)),
                 rep("comparison", length(counts) * length(years))),
  abridged_query = c(rep("deep learning", length(years)),
                     rep(names(counts), each = length(years))),
  year = rep(years, length(counts) + 1),
  n = c(ref_n, unlist(counts, use.names = FALSE)),
  reference_n = rep(ref_n, length(counts) + 1),
  comparison_percentage = 100 * c(ref_n, unlist(counts, use.names = FALSE)) /
    rep(ref_n, length(counts) + 1),
  average_comparison_percentage = c(rep(100, length(years)),
                                    rep(c(40, 33, 15, 9), each = length(years)))
)
class(cmp) <- c("scopus_comparison", class(cmp))
cmp
```

| query | query_type | abridged_query | year | n | reference_n | comparison_percentage | average_comparison_percentage |
|:---|:---|:---|---:|---:|---:|---:|---:|
| q | reference | deep learning | 2013 | 400 | 400 | 100.000000 | 100 |
| q | reference | deep learning | 2014 | 550 | 550 | 100.000000 | 100 |
| q | reference | deep learning | 2015 | 700 | 700 | 100.000000 | 100 |
| q | reference | deep learning | 2016 | 850 | 850 | 100.000000 | 100 |
| q | reference | deep learning | 2017 | 1000 | 1000 | 100.000000 | 100 |
| q | reference | deep learning | 2018 | 1150 | 1150 | 100.000000 | 100 |
| q | reference | deep learning | 2019 | 1300 | 1300 | 100.000000 | 100 |
| q | reference | deep learning | 2020 | 1450 | 1450 | 100.000000 | 100 |
| q | reference | deep learning | 2021 | 1600 | 1600 | 100.000000 | 100 |
| q | comparison | computer vision | 2013 | 140 | 400 | 35.000000 | 40 |
| q | comparison | computer vision | 2014 | 212 | 550 | 38.545454 | 40 |
| q | comparison | computer vision | 2015 | 285 | 700 | 40.714286 | 40 |
| q | comparison | computer vision | 2016 | 358 | 850 | 42.117647 | 40 |
| q | comparison | computer vision | 2017 | 430 | 1000 | 43.000000 | 40 |
| q | comparison | computer vision | 2018 | 502 | 1150 | 43.652174 | 40 |
| q | comparison | computer vision | 2019 | 575 | 1300 | 44.230769 | 40 |
| q | comparison | computer vision | 2020 | 648 | 1450 | 44.689655 | 40 |
| q | comparison | computer vision | 2021 | 720 | 1600 | 45.000000 | 40 |
| q | comparison | natural language processing | 2013 | 90 | 400 | 22.500000 | 33 |
| q | comparison | natural language processing | 2014 | 146 | 550 | 26.545455 | 33 |
| q | comparison | natural language processing | 2015 | 202 | 700 | 28.857143 | 33 |
| q | comparison | natural language processing | 2016 | 259 | 850 | 30.470588 | 33 |
| q | comparison | natural language processing | 2017 | 315 | 1000 | 31.500000 | 33 |
| q | comparison | natural language processing | 2018 | 371 | 1150 | 32.260870 | 33 |
| q | comparison | natural language processing | 2019 | 428 | 1300 | 32.923077 | 33 |
| q | comparison | natural language processing | 2020 | 484 | 1450 | 33.379310 | 33 |
| q | comparison | natural language processing | 2021 | 540 | 1600 | 33.750000 | 33 |
| q | comparison | medical imaging | 2013 | 15 | 400 | 3.750000 | 15 |
| q | comparison | medical imaging | 2014 | 46 | 550 | 8.363636 | 15 |
| q | comparison | medical imaging | 2015 | 76 | 700 | 10.857143 | 15 |
| q | comparison | medical imaging | 2016 | 107 | 850 | 12.588235 | 15 |
| q | comparison | medical imaging | 2017 | 138 | 1000 | 13.800000 | 15 |
| q | comparison | medical imaging | 2018 | 168 | 1150 | 14.608696 | 15 |
| q | comparison | medical imaging | 2019 | 199 | 1300 | 15.307692 | 15 |
| q | comparison | medical imaging | 2020 | 229 | 1450 | 15.793103 | 15 |
| q | comparison | medical imaging | 2021 | 260 | 1600 | 16.250000 | 15 |
| q | comparison | drug discovery | 2013 | 8 | 400 | 2.000000 | 9 |
| q | comparison | drug discovery | 2014 | 28 | 550 | 5.090909 | 9 |
| q | comparison | drug discovery | 2015 | 48 | 700 | 6.857143 | 9 |
| q | comparison | drug discovery | 2016 | 69 | 850 | 8.117647 | 9 |
| q | comparison | drug discovery | 2017 | 89 | 1000 | 8.900000 | 9 |
| q | comparison | drug discovery | 2018 | 109 | 1150 | 9.478261 | 9 |
| q | comparison | drug discovery | 2019 | 130 | 1300 | 10.000000 | 9 |
| q | comparison | drug discovery | 2020 | 150 | 1450 | 10.344828 | 9 |
| q | comparison | drug discovery | 2021 | 170 | 1600 | 10.625000 | 9 |

The `comparison_percentage` column is the per-year share, and
`average_comparison_percentage` is the same ratio computed over the
whole period, which is what orders the topics. A year in which the
reference has no records has no defined share and is recorded as `NA`
rather than as a misleading zero.

## A first plot

``` r

plot_scopus_comparison(cmp, legend_inside = TRUE)
```

![Four application areas' share of the deep-learning literature from
2013 to 2021, with shaded uncertainty bands and an in-panel
legend](comparing-topics_files/figure-html/unnamed-chunk-4-1.png)

Here `legend_inside = TRUE` places the topic key inside the panel, in
whichever corner has the most free space, rather than labelling each
line at its end. Left at its default the chart uses whole-number year
breaks, a colour-blind-safe palette and, because there are only a few
topics, labels the lines directly so the reader need not match colours
to a legend. Each label carries the topic’s total record count. The
shaded band around each line is a Wilson stability range: it is wide in
the early years, when the reference set is small and the share would
move easily, and narrows as the literature grows. Because ‘Scopus’
returns exact counts rather than a sample, the band is illustrative
rather than a confidence interval, a point the
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
help page sets out.

## When lines converge at the right end

Direct labels are legible only if they do not overlap, and topics
sometimes end the period at nearly the same share.
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
spreads converging labels apart automatically, at the point the figure
is actually drawn, so they stay readable at any figure size rather than
stacking into an unreadable pile. Here six sub-areas of
materials-science research all end 2013–2021 within three points of one
another.

``` r

years <- 2013:2021
ends <- c(18, 18.6, 19.2, 19.8, 20.4, 21)
names(ends) <- c("graphene", "perovskites", "MXenes", "COFs", "MOFs", "aerogels")
ref_n <- round(seq(500, 2000, length.out = length(years)))
converge <- function(end) round(end * (0.5 + 0.5 * (0:(length(years) - 1)) / (length(years) - 1)) * ref_n / 100)
counts <- lapply(ends, converge)

cmp_converging <- tibble::tibble(
  query = "q",
  query_type = c(rep("reference", length(years)),
                 rep("comparison", length(counts) * length(years))),
  abridged_query = c(rep("energy materials", length(years)),
                     rep(names(counts), each = length(years))),
  year = rep(years, length(counts) + 1),
  n = c(ref_n, unlist(counts, use.names = FALSE)),
  reference_n = rep(ref_n, length(counts) + 1),
  comparison_percentage = 100 * c(ref_n, unlist(counts, use.names = FALSE)) /
    rep(ref_n, length(counts) + 1),
  average_comparison_percentage = c(rep(100, length(years)),
                                    rep(ends, each = length(years)))
)
class(cmp_converging) <- c("scopus_comparison", class(cmp_converging))
```

``` r

plot_scopus_comparison(cmp_converging)
```

![Six materials-science sub-areas converging to similar shares by 2021,
with end labels automatically spread apart rather than
overlapping](comparing-topics_files/figure-html/unnamed-chunk-6-1.png)

Without this, six labels ending within three points of each other would
print on top of one another; here every one is still readable, each
colour-matched to its own line and spread in the same order as the line
ends.

## Drawing the eye to one topic

When one topic is the focus of a figure, `highlight` draws it in an
accent colour and greys the rest, which keeps the context visible
without letting it compete.

``` r

plot_scopus_comparison(cmp, highlight = "medical imaging")
```

![The same chart with the medical-imaging topic highlighted against the
others in
grey](comparing-topics_files/figure-html/unnamed-chunk-7-1.png)

## Adjusting the labels

The count suffix on each label can be turned off, and the uncertainty
band can be removed, when a cleaner look is wanted.

``` r

plot_scopus_comparison(cmp, pub_count_in_legend = FALSE, interval = FALSE)
```

![The comparison chart without record counts or
bands](comparing-topics_files/figure-html/unnamed-chunk-8-1.png)

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
```

| abridged_query              | average_comparison_percentage |
|:----------------------------|------------------------------:|
| computer vision             |                            40 |
| natural language processing |                            33 |
| medical imaging             |                            15 |
| drug discovery              |                             9 |
