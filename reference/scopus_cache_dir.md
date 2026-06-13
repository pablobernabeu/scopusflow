# Managed cache directory for scopusflow

Returns (and creates on request) a per-user cache directory under
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), suitable
for passing to `cache_dir` in
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md).
The cache is entirely optional and can be cleared with
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md).

## Usage

``` r
scopus_cache_dir(create = FALSE)
```

## Arguments

- create:

  Logical. When `TRUE`, the directory is created if it is absent.

## Value

The cache directory path, invisibly when `create = TRUE`.

## Examples

``` r
scopus_cache_dir(create = FALSE)
#> [1] "/home/runner/.cache/R/scopusflow"
```
