# Example set of normalised 'Scopus' records

A small set of three records in the shape that
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns, provided so that the package can be explored and its examples
run without a 'Scopus' API key. The records were normalised from the
static page fixture bundled in `inst/extdata`.

## Usage

``` r
example_records
```

## Format

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble with three rows and the standard schema:

- entry_number:

  Position within the retrieval.

- scopus_id:

  The 'Scopus' record identifier.

- doi:

  Digital Object Identifier.

- title:

  Document title.

- authors:

  First or corresponding author.

- year:

  Publication year.

- date:

  Cover date in ISO form.

- publication:

  Source title.

- citations:

  Citation count.

- query:

  The query that produced the record.

## Source

Synthetic example data, illustrative only.

## Examples

``` r
example_records
#> <scopus_records> 3 records
#> query: "TITLE-ABS-KEY(bibliometric)"
#> # A tibble: 3 × 9
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… A re… Smith …  2019 2019… Journal of…        12
#> 2            2 85000000002 10.1… Quot… Doe A.   2020 2020… Scientomet…         5
#> 3            3 85000000003 10.1… Trac… Lee K.   2021 2021… Journal of…         0
summary(example_records)
#> <scopus_records> summary
#> 3 records, from 2019 to 2021.
#> 2 sources, 3 with a DOI.
#> Cited 17 times in total, median 5 per record.
#> Most frequent source: Journal of Bibliometrics.
#> Most cited: A reproducible workflow for bibliometric retrieval.
```
