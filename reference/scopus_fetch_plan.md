# Execute a 'Scopus' search plan, with optional caching and resume

Runs every cell of a
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
in turn, optionally caching each cell's result so that an interrupted or
quota-limited retrieval can resume without re-spending quota on the
cells already fetched. Results are accumulated and bound once into a
single
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble.

## Usage

``` r
scopus_fetch_plan(
  plan,
  max_results = Inf,
  cache_dir = NULL,
  resume = TRUE,
  api_key = NULL,
  inst_token = NULL,
  verbose = FALSE,
  cursor = FALSE,
  fields = c("core", "extended")
)
```

## Arguments

- plan:

  A `scopus_plan` object from
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md).

- max_results:

  Maximum records to retrieve per cell (default `Inf`). A finite cap is
  recorded on the result, and
  [`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
  says which cells stopped at it.

- cache_dir:

  Optional directory for per-cell cache files. The default of `NULL`
  performs no caching. Pass an explicit path you control, or
  [`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md)
  to use a managed, clearable cache under
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html). Caching
  happens only when you opt in through this argument. A cache directory
  serves one plan: cells are checkpointed by their position in the plan
  and their year, so give each distinct plan its own directory. As a
  safeguard, a checkpoint is served only when the query, year, view,
  page size and paging mode it was fetched under all match the plan
  cell, and only when its own `max_results` did not truncate it below
  what is being asked for now; anything else is a cache miss, refetched
  and overwritten. A checkpoint holding more records than the current
  `max_results` asks for is served trimmed to that cap, the fuller set
  staying on disk. A checkpoint that cannot be read back, for example
  one left half-written by an interrupted run, is also treated as a
  miss, and never aborts the harvest. A `COMPLETE` checkpoint written by
  a release that read `authors` from the first author alone (0.4.0 and
  earlier) is a miss as well, and is refetched once with a warning.
  `STANDARD` checkpoints from those releases are served as before, since
  their authors were read correctly. Checkpoints also record their
  `fields`. One fetched with `fields = "extended"` serves a core
  request, with the extra columns dropped, while a core one is a miss
  for an extended request and is refetched with a warning. A checkpoint
  written before the fields were recorded counts as core.

- resume:

  Logical. When `TRUE` and `cache_dir` is set, a cell whose cache file
  already exists is loaded from disk, sparing a second request.

- api_key, inst_token:

  Optional credentials (see
  [`scopus_has_key()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_has_key.md)).

- verbose:

  Logical. When `TRUE`, per-cell progress is reported.

- cursor:

  Logical. When `TRUE`, each cell is retrieved with cursor-based
  pagination, which has no 5000-record ceiling, so a cell matching more
  records than that is retrieved whole and still checkpointed. The
  records then arrive in the API's deep-paging order (see
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)).
  The default, `FALSE`, pages by offset, as plans always have, so a cell
  stops at its first 5000 records with a warning. Checkpoints record the
  paging mode and serve only requests made in the same mode. A
  checkpoint written before the mode was recorded counts as
  offset-paged. The Python twin's `fetch_plan()` pages by cursor unless
  told otherwise, the mode it has always used.

- fields:

  `"core"` (the default) or `"extended"`. `"extended"` also keeps the
  document type, source type, volume, issue, pages, ISSN, PubMed
  identifier and open-access status the Search API sends with every
  record, and the abstract under a `COMPLETE` plan. They arrive in the
  responses each cell already pays for, so they cost no extra quota.
  Like `cursor`, it is an argument of the fetch, since it changes how
  the records are read while the search returns the same records. See
  the *Extended fields* section of
  [`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md).

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble combining all cells, with the originating `plan` attached as the
`plan` attribute and the per-cell accounting as `cell_totals`, a tibble
of `cell`, `date`, `n_records` and `reported_total` (the count the API
gave for that cell, `NA` where it gave none). `total_results` is their
sum, and is `NA` unless every cell reported one, since a partial sum
would understate the search while looking like a real figure. A cell
that comes back shorter than the API said it should warns, because a
truncated or refused download otherwise arrives as a merely small result
set; a cell stopped by `max_results` is short by request and does not
warn. A finite `max_results` is attached as the attribute of that name,
the cap of this call: a checkpoint written under a wider cap is served
trimmed to it, so no cell holds more.
[`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
reads all of this back. The `retrieved_at`, `retrieved_until` and
`scopusflow_version` attributes described in
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
are carried across from the cells. `retrieved_at` is the earliest of
their times, since a combined set is only as fresh as its oldest cell.
`retrieved_until` is the latest, the last search, which the record of a
harvest resumed over several days has to give. Every version that
contributed is listed, since resuming an older cache means more than one
did. Each is omitted when any cell cannot supply it, as a checkpoint
written before these attributes existed cannot. Dating the whole from
the part of it that can be dated would misreport the set. A cell written
before `retrieved_until` existed counts by its `retrieved_at`. `paging`
and `view` are kept where every cell records the same one.

## API access

Any cell not served from cache requires a valid API key and internet
access. The *API access* section of
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md)
gives the details.

## See also

[`scopus_cache_dir()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_dir.md),
[`scopus_cache_clear()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_cache_clear.md)

## Examples

``` r
if (FALSE) { # scopusflow::scopus_has_key()
plan <- scopus_plan('"graphene supercapacitor"', years = 2015:2024,
                    field = "TITLE-ABS-KEY", partition = "year")
dir <- file.path(tempdir(), "graphene-cache")
# `max_results` caps each yearly cell, so the example stays small and
# quota-light; drop it to harvest every record in the plan.
recs <- scopus_fetch_plan(plan, max_results = 25, cache_dir = dir, resume = TRUE)
}
# The offline companion, which needs no key: a record set with a plan
# attached. 'Scopus' records may not be redistributed, so the bundled corpus
# of real articles stands in for the harvest. It came from OpenAlex's
# exact-phrase search for the same phrase, so the plan, one cell per year,
# describes a 'Scopus' search that was not run and would return other
# records.
plan <- scopus_plan('"graphene supercapacitor"', years = 2015:2024,
                    field = "TITLE-ABS-KEY", partition = "year")
recs <- example_records
attr(recs, "plan") <- plan
recs
#> <scopus_records> 138 records
#> query: "graphene supercapacitor"
#> # A tibble: 138 × 9
#>    entry_number scopus_id doi    title authors  year date  publication citations
#>           <int> <chr>     <chr>  <chr> <chr>   <int> <chr> <chr>           <int>
#>  1            1 NA        10.15… Enha… Jianhu…  2015 2015… Journal of…         1
#>  2            2 NA        NA     Fabr… Patric…  2015 2015… DigitalCom…         0
#>  3            3 NA        10.10… Flex… Zhiwei…  2015 2015… ACS Applie…       469
#>  4            4 NA        10.10… Heav… Vikran…  2015 2015… Electrochi…       195
#>  5            5 NA        10.10… Grap… Chih-T…  2015 2015… Small             108
#>  6            6 NA        10.10… Nano… Hao Ya…  2015 2015… Journal of…        47
#>  7            7 NA        10.11… Capa… Maxwel…  2015 2015… Physical R…        32
#>  8            8 NA        10.13… Grap… Nurbek…  2015 2015… Optics Let…        48
#>  9            9 NA        10.10… Ultr… Zhong-…  2015 2015… Advanced M…       275
#> 10           10 NA        10.10… Etch… Matthe…  2015 2015… Nanotechno…        24
#> # ℹ 128 more rows
attr(recs, "plan")
#> <scopus_plan> (10 cells, view "STANDARD", partition "year")
#> # A tibble: 10 × 6
#>     cell query                                       date   year view  page_size
#>  * <int> <chr>                                       <chr> <int> <chr>     <int>
#>  1     1 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2015   2015 STAN…       200
#>  2     2 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2016   2016 STAN…       200
#>  3     3 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2017   2017 STAN…       200
#>  4     4 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2018   2018 STAN…       200
#>  5     5 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2019   2019 STAN…       200
#>  6     6 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2020   2020 STAN…       200
#>  7     7 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2021   2021 STAN…       200
#>  8     8 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2022   2022 STAN…       200
#>  9     9 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2023   2023 STAN…       200
#> 10    10 "TITLE-ABS-KEY(\"graphene supercapacitor\"… 2024   2024 STAN…       200
```
