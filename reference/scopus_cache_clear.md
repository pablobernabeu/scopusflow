# Clear the scopusflow managed cache

Deletes the cache files written under
[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md).
A cache you created in a directory of your own is left untouched.

## Usage

``` r
scopus_cache_clear()
```

## Value

Invisibly, `TRUE` once the managed cache directory is removed or found
to be absent.

## Examples

``` r
# Safe to call even when nothing is cached.
scopus_cache_clear()
```
