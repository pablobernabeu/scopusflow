# Tracking how a literature changes between retrievals

``` r

library(scopusflow)
```

Run the same search a few months apart and the result will have grown,
and perhaps lost a record that was re-indexed. This article shows how to
see what changed and how to merge retrievals without duplicates. It runs
offline on the bundled `example_records`, a corpus of 138 real journal
articles that stands in for ‘Scopus’ records, since those may not be
redistributed. That corpus is a complete harvest of one query from 2015
to 2024, so a pull that stopped at 2023 and a later one that reaches
2024 are both slices of the same search.

## The baseline

The first retrieval ran at the end of 2023 and returned everything
published up to then.

``` r

baseline <- example_records[example_records$year <= 2023, ]
nrow(baseline)
```

    [1] 124

## A later retrieval

A year on, the search is repeated. It now picks up the 2024 papers, and
one record that was present the first time has since been re-indexed and
no longer matches.

``` r

later <- example_records[-1, ]
nrow(later)
```

    [1] 137

## What changed

[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)
reports which DOIs were added, removed or unchanged between the two
retrievals, and prints the counts in each category.

``` r

changes <- scopus_diff_dois(old = baseline, new = later)
print(changes)
```

    <scopus_doi_diff> 14 added, 1 removed, 112 unchanged, 11 earlier and 11 later
    records without a DOI not compared
    # A tibble: 127 × 2
       doi                            status
       <chr>                          <fct> 
     1 10.1002/adfm.202315137         added 
     2 10.1002/asia.202400548         added 
     3 10.1002/slct.202302535         added 
     4 10.1016/j.cej.2024.148822      added 
     5 10.1016/j.diamond.2024.110842  added 
     6 10.1016/j.isci.2024.111696     added 
     7 10.1016/j.jallcom.2024.175000  added 
     8 10.1016/j.jallcom.2024.177248  added 
     9 10.1016/j.jpowsour.2024.234127 added 
    10 10.1016/j.jpowsour.2024.236149 added 
    # ℹ 117 more rows

The newly indexed papers come back as `added`, the records present both
times as `unchanged` and anything dropped from the later pull as
`removed`. The counts work out at fourteen added, one removed and 112
unchanged. Fourteen are added because that is how many of the 2024
papers carry a DOI, and the re-indexed record takes the unchanged count
from 113 down to 112. Records without a DOI cannot be tracked this way.
There are eleven in each pull here, and the printed line counts them, as
do the attributes `n_old_without_doi` and `n_new_without_doi`.

To act on one category, filter the table, which is an ordinary tibble.

``` r

head(changes[changes$status == "added", ])
```

| doi                           | status |
|:------------------------------|:-------|
| 10.1002/adfm.202315137        | added  |
| 10.1002/asia.202400548        | added  |
| 10.1002/slct.202302535        | added  |
| 10.1016/j.cej.2024.148822     | added  |
| 10.1016/j.diamond.2024.110842 | added  |
| 10.1016/j.isci.2024.111696    | added  |

## Comparing records

[`scopus_diff_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_records.md)
compares the records themselves, matching them as
`scopus_combine(dedupe = TRUE)` de-duplicates them: on a shared ‘Scopus’
identifier, or on a shared DOI where one of the two records lacks an
identifier. A record without a DOI is then tracked by its identifier.
Where a record is found in one pull only and the other pull gives its
DOI to a different record, it is marked `conflict`. It may have been
re-indexed under a new identifier or may be a distinct paper sharing the
DOI, and which it is can be decided only by inspecting the records.

The bundled records carry no identifier, so here they are matched on
their DOIs, and the eleven without one in each pull cannot be compared.
Each row carries the record’s title and year and its citation counts in
both pulls.

``` r

records_changed <- scopus_diff_records(old = baseline, new = later)
print(records_changed)
```

    <scopus_record_diff> 14 added, 1 removed, 0 in conflict, 112 unchanged, 11
    earlier and 11 later records without an identifier or a DOI not compared
    # A tibble: 127 × 7
       status scopus_id doi                  title  year citations_old citations_new
       <fct>  <chr>     <chr>                <chr> <int>         <int>         <int>
     1 added  <NA>      10.1002/adfm.202315… Vasc…  2024            NA            32
     2 added  <NA>      10.1002/asia.202400… A Hi…  2024            NA             6
     3 added  <NA>      10.1002/slct.202302… Allo…  2024            NA             2
     4 added  <NA>      10.1016/j.cej.2024.… High…  2024            NA            31
     5 added  <NA>      10.1016/j.diamond.2… Copp…  2024            NA            21
     6 added  <NA>      10.1016/j.isci.2024… Boos…  2024            NA             8
     7 added  <NA>      10.1016/j.jallcom.2… Enha…  2024            NA             5
     8 added  <NA>      10.1016/j.jallcom.2… From…  2024            NA            84
     9 added  <NA>      10.1016/j.jpowsour.… How …  2024            NA            14
    10 added  <NA>      10.1016/j.jpowsour.… High…  2024            NA             3
    # ℹ 117 more rows

The citation columns show how much each record’s count changed between
the two pulls. They are equal here, because both pulls were cut from one
snapshot.

## Merging without duplicates

To keep a cumulative set across retrievals, combine them.
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
renumbers the records and, with `dedupe = TRUE`, keeps each one once.
Records with the same ‘Scopus’ identifier are one record, and a record
without an identifier joins the identified record that carries its DOI.
DOIs are compared ignoring case and any resolver prefix.

``` r

combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
```

    [1] 149

That is 149 rows for 138 distinct articles. These records did not come
from ‘Scopus’ and carry no ‘Scopus’ identifier, so de-duplication falls
back to the DOI. The eleven that arrived without one have no key to
match on, so both copies of each are kept.

A live retrieval carries an identifier on every record, so the same call
on two of them returns each record once. Records with different
identifiers that share a DOI are both kept, since ‘Scopus’ gives one DOI
to distinct papers as well as holding duplicate records of one paper.
The merge counts the DOIs that such records share, and the search record
gives this count so that the records can be checked by hand. Once they
have been checked, `dedupe = "id_or_doi"` merges them.

[`c()`](https://rdrr.io/r/base/c.html) on record sets calls
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md),
so it concatenates and renumbers them in the same way and, unless it is
given `dedupe`, keeps every row.

``` r

stacked <- c(baseline, later)
nrow(stacked)
```

    [1] 261

## Keeping a record of each pull

Saving each retrieval lets you compare against it next time. The `.rds`
form round-trips exactly.

``` r

path <- file.path(tempdir(), "baseline.rds")
write_scopus_records(baseline, path)
identical(read_scopus_records(path), baseline)
```

    [1] TRUE

A live retrieval also carries the date it was taken, as the
`retrieved_at` attribute, together with the `scopusflow` version used to
retrieve it. The date matters for this workflow in particular, because
`citations` is a snapshot value that keeps changing, so a difference
between two pulls means something only once you know how far apart they
were. Both attributes survive the `.rds` form, and neither survives
`.csv`. The bundled corpus used here carries neither.

In a live setting, the later retrieval would come from the API, and
everything else would be as above. The baseline would be an earlier pull
of your own, since the bundled one came from OpenAlex and would differ
from any ‘Scopus’ pull for that reason alone. Both pulls would then be
dated, and each would carry a ‘Scopus’ identifier on every record, so
[`scopus_diff_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_records.md)
could compare them all.

``` r

later <- scopus_fetch('"graphene supercapacitor"', field = "TITLE-ABS-KEY")
attr(later, "retrieved_at")
scopus_diff_dois(old = read_scopus_records(path), new = later)
scopus_diff_records(old = read_scopus_records(path), new = later)
```
