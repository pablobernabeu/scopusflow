# Assemble a reproducible record of a 'Scopus' search

Turns a harvest, or a plan not yet run, into the search-strategy record
a systematic review has to report: what was searched, exactly how, when,
how much came back, and how much the API said there was. The record
prints as a readable report, formats as a methods paragraph fit to paste
into a manuscript, and writes as Markdown. The reporting standard it
follows is PRISMA-S (Rethlefsen et al., 2021), together with the
identification counts of the PRISMA 2020 flow diagram.

## Usage

``` r
scopus_search_report(x, plan = NULL, file = NULL)

# S3 method for class 'scopus_search_report'
format(x, style = c("report", "paragraph", "markdown"), ...)

# S3 method for class 'scopus_search_report'
print(x, ...)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  object, which supplies the counts and the retrieval provenance and,
  through its `plan` attribute, the plan; or a bare
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  for a search that has not been run yet. For
  [`format()`](https://rdrr.io/r/base/format.html) and
  [`print()`](https://rdrr.io/r/base/print.html), the report object
  itself.

- plan:

  Optional
  [`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
  describing `x`. Supply it when a record set does not carry one, for
  example one retrieved with
  [`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
  or read back from a `.csv`. An explicit plan takes precedence over the
  one `x` carries.

- file:

  Optional path at which to write the record as Markdown. A file is
  written only when this argument is supplied, and only to the exact
  path given, so the package leaves the working directory untouched
  unless asked. Parent directories are assumed to exist already.

- style:

  Which rendering to return: `"report"` for the readable record that
  [`print()`](https://rdrr.io/r/base/print.html) shows, `"paragraph"`
  for the methods paragraph, or `"markdown"` for the whole record as
  Markdown, which is what `file` writes.

- ...:

  Ignored, present for compatibility with the generics.

## Value

A list of class `scopus_search_report`, returned invisibly when `file`
is written. Its elements are the fields the record is built from:
`database`, `platform`, `query` (the base query), `field`, `expression`
(the field-wrapped query of each cell), `view`, `page_size`, `paging`,
`partition`, `n_cells`, `years`, `cells` (a tibble of `cell`, `limit`,
`n_records` and `reported_total`), `searched_at`, `version`,
`n_records`, `n_with_doi`, `reported_total`, `records_combined`,
`duplicates_removed`, `deduplicated`, `snippet` and `prisma` (a tibble
of `item`, `name`, `source` and `note`). A field the objects do not
record is `NA`.

[`format()`](https://rdrr.io/r/base/format.html) returns a length-one
character string.

## Details

Everything in the record comes from the objects handed to it. The date
of the search is the `retrieved_at` attribute
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
attaches, never the current time; the number of records the API reported
as matching is what the cells recorded (the `cell_totals` attribute
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)
attaches, or `total_results` for a set retrieved without a plan), never
an inference from the number of rows, and it is given overall only when
every cell reported one; and the duplicates removed are those
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
recorded removing. Where an attribute is absent, as it is for a set read
back from a `.csv`, for the bundled corpus, and for a cell resumed from
a checkpoint written before these attributes existed, the record says
the field is unrecorded rather than filling it. This matters most for
completeness: a harvest whose reported total is unknown is never
described as exhaustive.

The PRISMA-S map is decided the same way. Items the package holds
evidence for (the database and platform, the full strategy, the limits,
the date, the totals, and de-duplication where it was performed) are
listed as supplied. The rest, among them peer review of the strategy,
grey literature, other databases and citation searching, are listed as
the author's to supply, because the package has no way to know them.

## References

Rethlefsen, M. L., Kirtley, S., Waffenschmidt, S., Ayala, A. P., Moher,
D., Page, M. J., & Koffel, J. B. (2021). PRISMA-S: an extension to the
PRISMA Statement for Reporting Literature Searches in Systematic
Reviews. *Systematic Reviews*, *10*, 39.
[doi:10.1186/s13643-020-01542-z](https://doi.org/10.1186/s13643-020-01542-z)

## See also

[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)

## Examples

``` r
# A search described but not yet run. The record says so throughout rather
# than implying figures it cannot have.
plan <- scopus_plan("graphene supercapacitor", years = 2015:2024,
                    field = "TITLE-ABS-KEY", partition = "year")
scopus_search_report(plan)
#> Search strategy record (PRISMA-S)
#> 
#> Database: Scopus, on the Elsevier Scopus Search API
#> Search expression: TITLE-ABS-KEY(graphene supercapacitor)
#> Field tag: TITLE-ABS-KEY
#> Years: 2015 to 2024
#> Partition: one cell per year, 10 cells
#> View: STANDARD
#> Page size: 200 records per request
#> Paging: unrecorded
#> Date searched: unrecorded, this plan has not been run
#> Software: unrecorded
#> Records retrieved: none, this plan has not been run
#> Records reported as matching: unrecorded, this plan has not been run
#> Completeness: unrecorded, this plan has not been run
#> Duplicates removed: unrecorded, this plan has not been run
#> Records carrying a DOI: unrecorded, this plan has not been run
#> 
#> Cells
#>   1 (2015): retrieved records unrecorded
#>   2 (2016): retrieved records unrecorded
#>   3 (2017): retrieved records unrecorded
#>   4 (2018): retrieved records unrecorded
#>   5 (2019): retrieved records unrecorded
#>   6 (2020): retrieved records unrecorded
#>   7 (2021): retrieved records unrecorded
#>   8 (2022): retrieved records unrecorded
#>   9 (2023): retrieved records unrecorded
#>   10 (2024): retrieved records unrecorded
#> 
#> PRISMA 2020 identification
#>   Records identified from Scopus: unrecorded, this plan has not been run
#>   Duplicate records removed before screening: unrecorded, this plan has not been run
#> 
#> PRISMA-S items this record supplies
#>   1 Database name. Scopus, searched on the Elsevier Scopus Search API.
#>   8 Full search strategies. The search expression, field tag and year limit of every cell, as the plan sends them.
#>   9 Limits and restrictions. Publication years 2015 to 2024. scopusflow applies no document type, language or subject area limit of its own.
#> 
#> PRISMA-S items only you can supply
#>   2 Multi-database searching. Whether any database besides Scopus was searched, and how the strategy was translated for it.
#>   3 Study registries. Any trial or study registry searched.
#>   4 Online resources and browsing. Any web site, table of contents or other source searched or browsed by hand.
#>   5 Citation searching. Any backward or forward citation searching.
#>   6 Contacts. Any authors or organisations contacted for studies.
#>   7 Other methods. Any further method used to identify records.
#>   10 Search filters. Any published or validated search filter used, and where it came from. scopusflow applies none of its own.
#>   11 Prior work. Any earlier review or strategy this search was adapted from.
#>   12 Updates. Whether the search was re-run or updated, and when.
#>   13 Dates of searches. The date of each search, which this plan has not been run to produce.
#>   14 Peer review. Whether the strategy was peer reviewed, and by whom.
#>   15 Total records. The number of records identified, which this plan has not been run to produce.
#>   16 Deduplication. How duplicate records were removed, which this plan has not been run to produce.
#> 
#> The reporting standard is PRISMA-S (Rethlefsen et al., 2021, Systematic Reviews, 10, 39, https://doi.org/10.1186/s13643-020-01542-z), with the identification counts of the PRISMA 2020 flow diagram.
#> 
#> The methods paragraph is format(x, style = "paragraph"); pass file = to write the whole record as Markdown.

# The same search after a harvest. The bundled corpus of real articles
# stands in for one, since 'Scopus' records may not be redistributed, so the
# attributes a live retrieval records are set here by hand.
recs <- example_records
attr(recs, "plan") <- plan
attr(recs, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
attr(recs, "scopusflow_version") <- "0.3.0"
report <- scopus_search_report(recs)
report
#> Search strategy record (PRISMA-S)
#> 
#> Database: Scopus, on the Elsevier Scopus Search API
#> Search expression: TITLE-ABS-KEY(graphene supercapacitor)
#> Field tag: TITLE-ABS-KEY
#> Years: 2015 to 2024
#> Partition: one cell per year, 10 cells
#> View: STANDARD
#> Page size: 200 records per request
#> Paging: unrecorded
#> Date searched: 2026-07-22 09:15:00 UTC
#> Software: scopusflow 0.3.0
#> Records retrieved: 138
#> Records reported as matching: unrecorded, the API's own count did not travel with this set
#> Completeness: unrecorded, since the number of records the API reported as matching is not known
#> Duplicates removed: unrecorded, no de-duplication step was recorded for this set
#> Records carrying a DOI: 127 of 138
#> 
#> Cells
#>   1 (2015): retrieved records unrecorded
#>   2 (2016): retrieved records unrecorded
#>   3 (2017): retrieved records unrecorded
#>   4 (2018): retrieved records unrecorded
#>   5 (2019): retrieved records unrecorded
#>   6 (2020): retrieved records unrecorded
#>   7 (2021): retrieved records unrecorded
#>   8 (2022): retrieved records unrecorded
#>   9 (2023): retrieved records unrecorded
#>   10 (2024): retrieved records unrecorded
#> 
#> PRISMA 2020 identification
#>   Records identified from Scopus: 138
#>   Duplicate records removed before screening: unrecorded, no de-duplication step was recorded for this set
#> 
#> PRISMA-S items this record supplies
#>   1 Database name. Scopus, searched on the Elsevier Scopus Search API.
#>   8 Full search strategies. The search expression, field tag and year limit of every cell, as the plan sends them.
#>   9 Limits and restrictions. Publication years 2015 to 2024. scopusflow applies no document type, language or subject area limit of its own.
#>   13 Dates of searches. 2026-07-22 09:15:00 UTC.
#>   15 Total records. 138 records retrieved from Scopus. The API's own count of matching records is unrecorded.
#> 
#> PRISMA-S items only you can supply
#>   2 Multi-database searching. Whether any database besides Scopus was searched, and how the strategy was translated for it.
#>   3 Study registries. Any trial or study registry searched.
#>   4 Online resources and browsing. Any web site, table of contents or other source searched or browsed by hand.
#>   5 Citation searching. Any backward or forward citation searching.
#>   6 Contacts. Any authors or organisations contacted for studies.
#>   7 Other methods. Any further method used to identify records.
#>   10 Search filters. Any published or validated search filter used, and where it came from. scopusflow applies none of its own.
#>   11 Prior work. Any earlier review or strategy this search was adapted from.
#>   12 Updates. Whether the search was re-run or updated, and when.
#>   14 Peer review. Whether the strategy was peer reviewed, and by whom.
#>   16 Deduplication. How duplicate records were removed, which this set does not record.
#> 
#> The reporting standard is PRISMA-S (Rethlefsen et al., 2021, Systematic Reviews, 10, 39, https://doi.org/10.1186/s13643-020-01542-z), with the identification counts of the PRISMA 2020 flow diagram.
#> 
#> The methods paragraph is format(x, style = "paragraph"); pass file = to write the whole record as Markdown.

# The methods paragraph, and the Markdown record for a supplementary file.
cat(format(report, style = "paragraph"))
#> The literature was searched in Scopus, on the Elsevier Scopus Search API, on 22 July 2026. The search expression was TITLE-ABS-KEY(graphene supercapacitor), limited to publication years 2015 to 2024. It was partitioned into 10 cells, one per year, each retrieved through the STANDARD view in pages of 200 records, under a paging mode this record does not carry. The search retrieved 138 records. The API's own count of matching records was not recorded, so the harvest cannot be shown to be complete. Of the records retrieved, 127 carry a DOI. No de-duplication step was recorded for this set. The search was run with scopusflow 0.3.0. The PRISMA-S items this record cannot supply, among them peer review of the strategy, grey literature and any other database searched, remain yours to report.
path <- tempfile(fileext = ".md")
scopus_search_report(recs, file = path)
```
