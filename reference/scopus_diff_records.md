# Compare two retrievals record by record

Identifies which records were added, removed or unchanged between an
earlier and a later retrieval, and gives each record's citation count in
both.
[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
compares DOIs alone, and this function compares the records themselves,
matched as `scopus_combine(dedupe = TRUE)` matches them. A record
without a DOI is therefore still tracked by its 'Scopus' identifier, and
two records under one DOI are not taken for one.

## Usage

``` r
scopus_diff_records(old, new)
```

## Arguments

- old, new:

  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  objects, or data frames with a `scopus_id` or a `doi` column,
  representing the earlier (`old`) and later (`new`) retrievals. The
  `title`, `year` and `citations` columns are read where present.

## Value

A tibble of class `scopus_record_diff`, one row per record, with the
columns `status`, `scopus_id`, `doi`, `title`, `year`, `citations_old`
and `citations_new`. `status` is a factor with levels `"added"` (in
`new` only), `"removed"` (in `old` only), `"conflict"` (see Details) and
`"unchanged"` (in both). Rows are sorted by status, then DOI, identifier
and title, in byte order, so the order is the same under every locale
and in the Python twin. The integer attributes `n_old_without_id_or_doi`
and `n_new_without_id_or_doi` count the records on each side that
carried neither key and so were not compared. Printing shows the counts
in each category, and those records where there are any.

## Details

Two records are one record when they share a 'Scopus' identifier, or
when they share a DOI and one of them lacks an identifier. DOIs are
compared as
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
compares them, without resolver prefixes and ignoring case. Records with
different identifiers are never matched, even under one DOI, since
'Scopus' gives one DOI to distinct papers as well as holding duplicate
records of one paper
([`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
gives the sources).

A record found in one retrieval only is a `"conflict"` where the other
retrieval gives its DOI to a different record. It may have been
re-indexed under a new identifier, or it may be a distinct paper sharing
the DOI. Only the two records themselves can tell, so it is counted
neither as added nor as removed. A record without an identifier whose
DOI two identified records carry is in the same position. A record with
neither an identifier nor a DOI cannot be matched at all, and is left
out of the rows and counted.

`scopus_id` is the identifier the record was matched on, missing for a
record matched on its DOI alone. `doi` is the DOI without its resolver
prefix, in the case the record gives it. `doi`, `title` and `year` come
from the later retrieval where it holds the record and gives a value,
and from the earlier one otherwise, while `citations_old` and
`citations_new` come from each retrieval in turn. Where one retrieval
holds a record more than once, the first value it gives is used.

## See also

[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
to compare DOIs alone,
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
to merge the retrievals.

## Examples

``` r
# The bundled corpus carries no 'Scopus' identifiers, so its records are
# matched on their DOIs, and the eleven in each pull without one cannot be
# compared at all.
baseline <- example_records[example_records$year <= 2023, ]
later <- example_records[-1, ]
scopus_diff_records(old = baseline, new = later)
#> <scopus_record_diff> 14 added, 1 removed, 0 in conflict, 112 unchanged, 11
#> earlier and 11 later records without an identifier or a DOI not compared
#> # A tibble: 127 × 7
#>    status scopus_id doi                  title  year citations_old citations_new
#>    <fct>  <chr>     <chr>                <chr> <int>         <int>         <int>
#>  1 added  NA        10.1002/adfm.202315… Vasc…  2024            NA            32
#>  2 added  NA        10.1002/asia.202400… A Hi…  2024            NA             6
#>  3 added  NA        10.1002/slct.202302… Allo…  2024            NA             2
#>  4 added  NA        10.1016/j.cej.2024.… High…  2024            NA            31
#>  5 added  NA        10.1016/j.diamond.2… Copp…  2024            NA            21
#>  6 added  NA        10.1016/j.isci.2024… Boos…  2024            NA             8
#>  7 added  NA        10.1016/j.jallcom.2… Enha…  2024            NA             5
#>  8 added  NA        10.1016/j.jallcom.2… From…  2024            NA            84
#>  9 added  NA        10.1016/j.jpowsour.… How …  2024            NA            14
#> 10 added  NA        10.1016/j.jpowsour.… High…  2024            NA             3
#> # ℹ 117 more rows

# Two pulls of three records each, with identifiers as a live harvest
# carries them. 10.5555 is the DOI prefix reserved for tests, so none of
# these resolve. The later pull holds 10.5555/c under a new identifier,
# which makes both records under it a conflict to check, and a record from
# another source, without an identifier, that is new.
old <- data.frame(
  scopus_id = c("85000000001", "85000000002", "85000000003"),
  doi = c("10.5555/a", "10.5555/b", "10.5555/c"),
  citations = c(5L, 3L, 8L)
)
new <- data.frame(
  scopus_id = c("85000000001", "85000000033", NA),
  doi = c("10.5555/a", "10.5555/c", "https://doi.org/10.5555/D"),
  citations = c(9L, 10L, NA)
)
scopus_diff_records(old, new)
#> <scopus_record_diff> 1 added, 1 removed, 2 in conflict, 1 unchanged
#> # A tibble: 5 × 7
#>   status    scopus_id   doi       title  year citations_old citations_new
#>   <fct>     <chr>       <chr>     <chr> <int>         <int>         <int>
#> 1 added     NA          10.5555/D NA       NA            NA            NA
#> 2 removed   85000000002 10.5555/b NA       NA             3            NA
#> 3 conflict  85000000003 10.5555/c NA       NA             8            NA
#> 4 conflict  85000000033 10.5555/c NA       NA            NA            10
#> 5 unchanged 85000000001 10.5555/a NA       NA             5             9
```
