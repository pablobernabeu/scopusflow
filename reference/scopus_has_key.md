# Locate the 'Scopus' API key and institutional token

`scopus_has_key()` reports whether an API key can be found, without
revealing it. The key itself is resolved internally and is never printed
by the package.

## Usage

``` r
scopus_has_key()
```

## Value

A length-one logical that is safe to print, `TRUE` when a non-empty key
is available and `FALSE` otherwise.

## Details

The key is looked up first from the `api_key` argument of whichever
function is being called, then from the `scopusflow.api_key` option, and
finally from the `SCOPUS_API_KEY` environment variable. An optional
institutional token, used for off-campus access to subscriber content,
is resolved the same way from the `inst_token` argument, the
`scopusflow.inst_token` option, or the `SCOPUS_INST_TOKEN` environment
variable.

A key is a secret. The safest home for it is `~/.Renviron`, as in
`SCOPUS_API_KEY=xxxx`, rather than a script, and it should stay out of
version control.

## See also

[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md),
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)

## Examples

``` r
# Does the current session have a key configured?
scopus_has_key()
#> [1] FALSE
```
