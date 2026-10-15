# Tracking how a literature changes between retrievals

``` r

library(scopusflow)
```

A literature is a moving target. Run the same search a few months apart
and the result will have grown, and perhaps lost a record that was
re-indexed. This article shows how to see exactly what changed and how
to merge retrievals safely. It runs offline on the bundled
`example_records`, a corpus of 138 real journal articles the package
ships because ‘Scopus’ records may not be redistributed. That corpus is
a complete harvest of one query from 2015 to 2024, so a pull that
stopped at 2023 and a later one that reaches 2024 are both genuine
slices of the same search.

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
times as `unchanged`, and anything dropped from the later pull as
`removed`. The counts work out at fourteen added, one removed and 112
unchanged. Fourteen are added because that is how many of the 2024
papers carry a DOI, and the re-indexed record takes the unchanged count
from 113 down to 112. Records without a DOI cannot be tracked this way
at all. There are eleven in each pull here, and the printed line counts
them, as do the attributes `n_old_without_doi` and `n_new_without_doi`.

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
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
de-duplicates them by default: on a shared ‘Scopus’ identifier, or on a
shared DOI where one of the two records lacks an identifier. A record
without a DOI is then tracked by its identifier, and each row carries
the record’s title and year and its citation counts in both pulls. Where
a record is found in one pull only and the other pull gives its DOI to a
different record, it is marked `conflict`. It may have been re-indexed
under a new identifier or may be a distinct paper sharing the DOI, and
only the records themselves can tell. The bundled records carry no
identifier, so here they are matched on their DOIs, and the eleven
without one in each pull cannot be compared.

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

The citation columns show how far each record’s count moved between the
two pulls. They are equal here, because both pulls were cut from one
snapshot.

## Merging without duplicates

To keep a cumulative set across retrievals, combine them.
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
renumbers the records and, with `dedupe = TRUE`, keeps each one once, so
the records the two pulls share are not doubled. Records with the same
‘Scopus’ identifier are one record, and a record without an identifier
joins the identified record that carries its DOI, however the DOI is
spelled.

``` r

combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
```

    [1] 149

That is 149 rows for 138 distinct articles, and the gap is instructive.
These records carry no ‘Scopus’ identifier, never having come from
‘Scopus’, so de-duplication falls back to the DOI. The eleven that
arrived without one have no key to match on, and so survive in both
copies. A live harvest carries an identifier on every record, so the
same call on two real pulls returns each record once. Two records of one
article under different identifiers, which ‘Scopus’ does hold, are both
kept, since ‘Scopus’ also gives one DOI to distinct papers. The merge
counts the DOIs such records share, and the search record gives the
count, so that they can be checked by hand. `dedupe = "id_or_doi"`
merges them once they have been.

The base [`c()`](https://rdrr.io/r/base/c.html) method concatenates
record sets directly, renumbering but without de-duplicating, so it is
the building block that
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
adds the duplicate handling to.

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
`retrieved_at` attribute, together with the `scopusflow` version that
took it. That matters for this workflow in particular, because
`citations` is a snapshot value that keeps moving, so a difference
between two pulls only means something once you know how far apart they
were. Both survive the `.rds` form and neither survives `.csv`, which is
a table of columns. The bundled corpus used here carries neither, which
is why it round-trips identically above.

In a live setting the later retrieval would come from the API, where
here it is a slice of the bundled corpus, and everything else would be
as above. Both pulls could then say when they were taken. The baseline
would be an earlier pull of your own, since the bundled one came from
OpenAlex and would differ from any ‘Scopus’ pull for that reason alone.
Both pulls would carry a ‘Scopus’ identifier on every record, so
[`scopus_diff_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_records.md)
could compare them all.

``` r

later <- scopus_fetch('"graphene supercapacitor"', field = "TITLE-ABS-KEY")
attr(later, "retrieved_at")
scopus_diff_dois(old = read_scopus_records(path), new = later)
scopus_diff_records(old = read_scopus_records(path), new = later)
```
