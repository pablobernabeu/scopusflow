# Comparing topics over time

``` r

library(scopusflow)
```

A bibliometric study often asks how the internal emphasis of a
literature shifts over time. Within deep-learning research, for example,
it might ask whether the share of work that also concerns medical
imaging is growing faster than the share about computer vision.
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
answers that question, and
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
shows the answer. The comparison contacts the API, so it is shown but
not run. The plotting is reproduced offline from an object of the same
shape.

## What the comparison measures

For each year and each comparison term, the function counts the records
matching both the reference topic and that term, and expresses the count
as a percentage of the records matching the reference alone. A value of
30% for ‘computer vision’ in 2020 means that 30% of the deep-learning
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
counts whole literatures, so, unlike a trend, it cannot be derived from
the harvest the package bundles for its other examples. The table below
is rebuilt in the same shape with illustrative counts, and the rest of
the article runs without a key. Its reference set grows over the period,
which the uncertainty band reflects.

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
  average_comparison_percentage =
    100 * stats::ave(n, abridged_query, FUN = sum) / sum(ref_n)
)
class(cmp) <- c("scopus_comparison", class(cmp))

# The whole table is too long to read here, so show its first year across every
# topic. The `query` column is left out because a real comparison carries the
# whole query string sent to the API in it, which is too long for a table. The
# illustrative table built above holds a placeholder there instead.
cmp[cmp$year == min(cmp$year), setdiff(names(cmp), "query")]
```

| query_type | abridged_query | year | n | reference_n | comparison_percentage | average_comparison_percentage |
|:---|:---|---:|---:|---:|---:|---:|
| reference | deep learning | 2013 | 400 | 400 | 100.00 | 100.00000 |
| comparison | computer vision | 2013 | 140 | 400 | 35.00 | 43.00000 |
| comparison | natural language processing | 2013 | 90 | 400 | 22.50 | 31.50000 |
| comparison | medical imaging | 2013 | 15 | 400 | 3.75 | 13.75556 |
| comparison | drug discovery | 2013 | 8 | 400 | 2.00 | 8.90000 |

Those are the five rows for the first year, one for the reference and
one for each comparison term. The whole table has 45 rows on the same
pattern. The `query` column left out above is still in the object. In
the output of
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md),
it carries the whole query behind each count, and in this illustrative
table it carries a placeholder.

The `comparison_percentage` column is the per-year share, and
`average_comparison_percentage` is the same ratio computed over the
whole period, which orders the topics in the plot. A year in which the
reference has no records has no defined share, so it is recorded as
`NA`. A zero there would be read as a real observation.

## A first plot

Drawing the comparison takes one call on the result.

``` r

plot_scopus_comparison(cmp, legend_inside = TRUE)
```

![Four application areas' share of the deep-learning literature from
2013 to 2021, with shaded uncertainty bands and an in-panel
legend](comparing-topics_files/figure-html/unnamed-chunk-4-1.png)

Here `legend_inside = TRUE` places the legend inside the panel, in
whichever corner has the most free space. The chart uses whole-number
year breaks and a colour-blind-safe palette. Left at its default, it
labels each line at its end when there are only a few topics, so the
reader never has to match colours to a legend. Each label carries the
topic’s total record count.

The shaded band around each line is a Wilson stability range. It is wide
in the early years, when the reference set is small and the share would
move easily, and narrows as the literature grows. Scopus returns exact
counts, so nothing here is a sample from which an interval could be
estimated. The band is illustrative, as the
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
help page sets out.

## When lines converge at the right end

Direct labels are legible only if they do not overlap, and topics
sometimes end the period at nearly the same share.
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
spreads converging labels apart automatically when the figure is drawn,
so they stay readable in any figure tall enough to stack them. Here, six
sub-areas of materials-science research all end 2013–2021 within three
points of one another.

``` r

years <- 2013:2021
ends <- c(18, 18.6, 19.2, 19.8, 20.4, 21)
names(ends) <- c(
  "graphene", "perovskites", "MXenes", "COFs", "MOFs", "aerogels"
)
ref_n <- round(seq(500, 2000, length.out = length(years)))
converge <- function(end) round(end *
  (0.5 + 0.5 * (0:(length(years) - 1)) / (length(years) - 1)) * ref_n / 100)
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
with end labels automatically spread apart so that none
overlaps](comparing-topics_files/figure-html/unnamed-chunk-6-1.png)

Each of the six labels stays readable, colour-matched to its own line
and spread in the same order as the line ends.

## Drawing the eye to one topic

When one topic is the focus of a figure, `highlight` draws it in an
accent colour and the other topics in grey.

``` r

plot_scopus_comparison(cmp, highlight = "medical imaging")
```

![The same chart with the medical-imaging topic highlighted against the
others in
grey](comparing-topics_files/figure-html/unnamed-chunk-7-1.png)

## Adjusting the labels

The count suffix on each label can be turned off, and the uncertainty
band can be removed.

``` r

plot_scopus_comparison(cmp, pub_count_in_legend = FALSE, interval = FALSE)
```

![The comparison chart without record counts or
bands](comparing-topics_files/figure-html/unnamed-chunk-8-1.png)

The return value is an ordinary [ggplot2](https://ggplot2.tidyverse.org)
object, so any further adjustment, such as a different theme or a saved
file, takes one `+` or one call to
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).

## Reading the result as a table

When the numbers matter more than the picture, the usual tools apply,
because the output is a tibble. Here are the comparison topics ranked by
their average share, the order in which
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
returns them.

``` r

comp <- cmp[cmp$query_type == "comparison", ]
unique(comp[, c("abridged_query", "average_comparison_percentage")])
```

| abridged_query              | average_comparison_percentage |
|:----------------------------|------------------------------:|
| computer vision             |                      43.00000 |
| natural language processing |                      31.50000 |
| medical imaging             |                      13.75556 |
| drug discovery              |                       8.90000 |
