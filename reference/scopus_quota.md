# Parse 'Scopus' quota and rate-limit headers

Elsevier returns the caller's weekly quota and short-term rate-limit
status in response headers. `scopus_quota()` extracts them into a tidy
list so a workflow can pause, schedule or report on the remaining
allowance.

## Usage

``` r
scopus_quota(resp)
```

## Arguments

- resp:

  An [httr2::response](https://httr2.r-lib.org/reference/response.html)
  object, typically captured during a request.

## Value

A list with elements `limit`, `remaining`, `reset` (a `POSIXct` time at
which the rate-limit window resets, or `NA`), `status` and `retry_after`
(seconds, or `NA`). A missing header yields `NA`.

## Details

The relevant headers are `X-RateLimit-Limit`, `X-RateLimit-Remaining`,
`X-RateLimit-Reset` (epoch seconds), `X-ELS-Status` and `Retry-After`.
When the API raises a quota or rate-limit error, the parsed quota is
also attached to the resulting condition, where it is available as
`cnd$quota`.

## Examples

``` r
# Build a fake response to show the shape of the output (no network used).
resp <- httr2::response(
  status_code = 200,
  headers = list(
    `X-RateLimit-Limit` = "20000",
    `X-RateLimit-Remaining` = "19987",
    `X-RateLimit-Reset` = "1700000000"
  )
)
scopus_quota(resp)
#> $limit
#> [1] 20000
#> 
#> $remaining
#> [1] 19987
#> 
#> $reset
#> [1] "2023-11-14 22:13:20 UTC"
#> 
#> $status
#> [1] NA
#> 
#> $retry_after
#> [1] NA
#> 
```
