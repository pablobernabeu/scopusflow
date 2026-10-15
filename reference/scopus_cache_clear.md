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
# The managed cache is pointed at a temporary directory first, so that
# running this example cannot delete the checkpoints of a real harvest.
# Nothing is cached there, and clearing an absent cache is safe.
old <- Sys.getenv("R_USER_CACHE_DIR", unset = NA)
Sys.setenv(R_USER_CACHE_DIR = tempfile())
scopus_cache_clear()
if (is.na(old)) Sys.unsetenv("R_USER_CACHE_DIR") else
  Sys.setenv(R_USER_CACHE_DIR = old)
```
