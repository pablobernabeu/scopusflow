# Count 'Scopus' results for a query

Retrieves only the total number of records matching a query, without
downloading them. This is the inexpensive way to size a retrieval before
committing quota. The count can guide how to partition a
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
or simply report how large a topic is.

## Usage

``` r
scopus_count(
  query,
  years = NULL,
  field = NULL,
  view = c("STANDARD", "COMPLETE"),
  api_key = NULL,
  inst_token = NULL
)
```

## Arguments

- query:

  Character scalar. The base search expression, checked offline before
  any request (see the *Query checks* section of
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- years:

  Optional integer vector of publication years. `scopus_count()`,
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  and
  [`scopus_intersections()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_intersections.md)
  send one inclusive range from the earliest year to the latest, as a
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  with `partition = "none"` does, so `c(2015, 2020)` covers every year
  from 2015 to 2020.
  [`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md),
  [`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
  and a plan with `partition = "year"` take each listed year. An empty
  vector places no year restriction, as `NULL` does, where the years
  form a range, and is refused where each year is counted.

- field:

  Optional 'Scopus' field tag to wrap the query in (see
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)).

- view:

  Either `"STANDARD"` or `"COMPLETE"`. `COMPLETE` adds an `authkeywords`
  column to
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)/[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
  output (see
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
  at no extra cost beyond `COMPLETE`'s own smaller page size, which
  already means more requests, and so more quota, for the same number of
  records.

- api_key, inst_token:

  Optional credentials, resolved by default from options or environment
  variables (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

## Value

A single number giving the total number of matching records, or `NA`
when the API reports no total. It is returned as a double so that very
large totals are represented exactly, with no risk of overflow, and the
parsed quota (see
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md))
attached as the `quota` attribute so a workflow can pace itself off a
count.

## API access

This function performs a network request and therefore requires a valid
API key and internet access. When no key is configured it raises a
`scopus_error_no_key` condition, and other failures raise typed
`scopus_error` subclasses such as `scopus_error_rate_limit`. A
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) around the call
lets a workflow handle these gracefully. Throttling (HTTP 429) and
server errors are retried with back-off first, and so are transport
failures such as a timeout or a reset connection. A spent weekly quota,
which Elsevier also answers with HTTP 429, is not retried: it raises
`scopus_error_quota_exceeded`, a subclass of `scopus_error_rate_limit`
whose message gives the reset time. When the last attempt at a request
times out after `getOption("scopusflow.timeout", 60)` seconds, the error
is `scopus_error_timeout`, a subclass of `scopus_error_offline`.

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
scopus_count('"graphene supercapacitor"', years = 2015:2024,
             field = "TITLE-ABS-KEY")
}
# The offline companion, which needs no key: one number with the parsed
# quota attached. The bundled corpus of real articles is a complete harvest
# of OpenAlex's exact-phrase search for the same phrase, so its row count is
# the total of that search. A 'Scopus' count of the phrase would differ. The
# quota attribute is parsed from real response headers by scopus_quota(), so
# it cannot drift from what a live call attaches.
resp <- httr2::response(
  status_code = 200,
  headers = list(
    `X-RateLimit-Limit` = "20000",
    `X-RateLimit-Remaining` = "19987",
    `X-RateLimit-Reset` = "1700000000"
  )
)
n <- nrow(example_records)
attr(n, "quota") <- scopus_quota(resp)
n
#> [1] 138
#> attr(,"quota")
#> attr(,"quota")$limit
#> [1] 20000
#> 
#> attr(,"quota")$remaining
#> [1] 19987
#> 
#> attr(,"quota")$reset
#> [1] "2023-11-14 22:13:20 UTC"
#> 
#> attr(,"quota")$status
#> [1] NA
#> 
#> attr(,"quota")$retry_after
#> [1] NA
#> 
```
