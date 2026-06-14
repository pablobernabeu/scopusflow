# Example set of normalised 'Scopus' records

A small set of six illustrative records spanning several disciplines
(genome editing, machine learning, climate science, materials, oncology
and physics), in the shape that
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns. It is provided so that the package can be explored and its
examples run without a 'Scopus' API key. The records were normalised
from the static page fixture bundled in `inst/extdata`.

## Usage

``` r
example_records
```

## Format

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble with six rows and the standard schema:

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
#> <scopus_records> 6 records
#> query: "illustrative multi-disciplinary sample"
#> # A tibble: 6 × 9
#>   entry_number scopus_id   doi   title authors  year date  publication citations
#>          <int> <chr>       <chr> <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 85000000001 10.1… Geno… Zhang …  2019 2019… Nature            540
#> 2            2 85000000002 10.1… Deep… Kumar …  2020 2020… Nature            210
#> 3            3 85000000003 10.1… Clim… Okafor…  2018 2018… Nature Cli…       122
#> 4            4 85000000004 10.1… Grap… Tanaka…  2021 2021… Advanced M…        45
#> 5            5 85000000005 10.1… Chec… Garcia…  2020 2020… The Lancet…       388
#> 6            6 85000000006 10.1… Obse… Abbott…  2016 2016… Physical R…      4200
summary(example_records)
#> <scopus_records> summary
#> 6 records, from 2016 to 2021.
#> 5 sources, 6 with a DOI.
#> Cited 5505 times in total, median 299 per record.
#> Most frequent source: Nature.
#> Most cited: Observation of gravitational waves from a binary black hole merger.
```
