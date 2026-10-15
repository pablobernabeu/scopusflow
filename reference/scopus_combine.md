# Combine record sets into one

Binds several
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
objects into a single one, renumbering `entry_number` across the result
and, optionally, dropping duplicates. This is the safe way to merge
separate fetches: plain [`rbind()`](https://rdrr.io/r/base/cbind.html)
would leave duplicate entry numbers, and
[`c()`](https://rdrr.io/r/base/c.html) would return a list.

## Usage

``` r
scopus_combine(..., dedupe = FALSE)

# S3 method for class 'scopus_records'
c(x, ...)
```

## Arguments

- ...:

  Two or more
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  objects, or a single list of them.

- dedupe:

  Whether, and by which rule, to keep once the records that are one
  record. `FALSE`, the default, keeps every row. `TRUE`, also spelled
  `"id_or_shared_doi"`, treats records as one when they share a 'Scopus'
  identifier, or when they share a DOI and one of them lacks an
  identifier. `"id_or_doi"` also merges records with different
  identifiers that share a DOI, and `"id_then_doi"` applies the rule of
  scopusflow 0.4.0 and earlier. See Details.

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  object (for the [`c()`](https://rdrr.io/r/base/c.html) method).

## Value

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble. Per-retrieval attributes such as `total_results` and `plan` are
not carried over, since they describe a single fetch. The provenance a
merge leaves true is kept, as
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
keeps it for plan cells. `retrieved_at` is the earliest of the inputs'
times and `retrieved_until` the latest, so a baseline merged with its
update is dated from one to the other. Every contributing
`scopusflow_version` is listed. The merge itself is recorded in the
`combined` attribute, a list of `n_in` (records supplied), `n_out`
(records kept), `n_removed`, `deduplicated`, `rule` (the rule applied,
`NA` when none was) and `doi_conflicts` (how many DOIs records with
different identifiers share, `NA` when no rule was applied). It is what
lets
[`scopus_search_report()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_search_report.md)
state how many duplicates were removed and how, so the PRISMA-S item is
answered.

## Details

De-duplication compares DOIs as
[`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md)
does, without resolver prefixes such as `https://doi.org/` or `doi:` and
ignoring case. It keeps the first record of each group, in the order the
sets were given, and a record with neither an identifier nor a DOI
cannot be matched and is kept.

Under the default rule, records with the same 'Scopus' identifier are
one record, and a record without an identifier joins the identified
record that carries its DOI. Records with different identifiers are
never merged, even when they share a DOI. 'Scopus' holds duplicate
records of one paper (Valderrama-Zurián et al., 2015), but it also gives
one DOI to distinct papers (Franceschini et al., 2015), and a review
loses a wrongly removed record for good where a surviving duplicate is
caught at screening. Such DOIs are counted in `doi_conflicts`, which the
search record reports, so that they can be checked by hand. A record
without an identifier whose DOI two identified records carry is kept
once, apart from both. Records without an identifier that share a DOI no
identified record carries are one record.

`"id_or_doi"` merges every record linked to another by a shared
identifier or a shared DOI, directly or through a chain of such links.
It suits a set whose shared DOIs have been checked and found to be
duplicates. `"id_then_doi"` keys each record on its identifier, failing
that on its DOI lower-cased but not otherwise cleaned, and so reproduces
a set de-duplicated by scopusflow 0.4.0 or earlier.

## References

Franceschini, F., Maisano, D., & Mastrogiacomo, L. (2015). Errors in DOI
indexing by bibliometric databases. *Scientometrics*, *102*(3),
2181–2186.
[doi:10.1007/s11192-014-1503-4](https://doi.org/10.1007/s11192-014-1503-4)

Valderrama-Zurián, J.-C., Aguilar-Moya, R., Melero-Fuentes, D., &
Aleixandre-Benavent, R. (2015). A systematic analysis of duplicate
records in Scopus. *Journal of Informetrics*, *9*(3), 570–576.
[doi:10.1016/j.joi.2015.05.002](https://doi.org/10.1016/j.joi.2015.05.002)

## See also

[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
which combines plan cells the same way.

## Examples

``` r
# A baseline retrieval and a later one, merged into a cumulative set. The
# bundled corpus of real articles stands in for both, since 'Scopus'
# records may not be redistributed.
baseline <- example_records[example_records$year <= 2023, ]
later <- example_records
combined <- scopus_combine(baseline, later, dedupe = TRUE)
nrow(combined)
#> [1] 149

# Those records carry no 'Scopus' identifier, so de-duplication falls back
# to the DOI. The eleven that arrived without one cannot be matched, and so
# survive in both copies, which is why 138 distinct articles come back as
# 149 rows.
sum(is.na(example_records$doi))
#> [1] 11
```
