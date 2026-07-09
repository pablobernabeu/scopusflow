# Spread converging end-labels at draw time

Internal grid method for the
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
direct labels. It runs whenever the label grob is drawn, when the panel
viewport (and so the rendered text height) is finally known, and spreads
the labels by at least one line of text so converging topics never
overlap however the figure is sized. The panel coordinates are `[0, 1]`
(npc), so the measured text height, the spread and the overflow shift
are all in those units. Not called directly.

## Usage

``` r
# S3 method for class 'sf_endlabels'
makeContent(x)
```

## Arguments

- x:

  The `sf_endlabels` gTree built by `sf_geom_end_labels()`.

## Value

The gTree with its text children set.
