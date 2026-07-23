# A worked example harvest, in the shape 'Scopus' records take

One hundred and thirty-eight real journal articles on graphene
supercapacitors published between 2015 and 2024, carrying their real
titles, DOIs, source titles, first authors and citation counts. The
dataset lets the package be explored, and every example and vignette be
run, without an API key.

## Usage

``` r
example_records
```

## Format

A
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble with 138 rows and the standard schema:

- entry_number:

  Position within the retrieval.

- scopus_id:

  Empty throughout. These records did not come from 'Scopus', so they
  carry no 'Scopus' identifier; de-duplication falls back to the DOI, as
  it does for any record whose identifier is missing.

- doi:

  Digital Object Identifier, missing for eleven records.

- title:

  Document title. Publisher markup for subscripts and italics is
  stripped; nothing else is altered.

- authors:

  First author, as named by the source.

- year:

  Publication year.

- date:

  Publication date in ISO form.

- publication:

  Source title, missing for two records.

- citations:

  Citation count at the time of retrieval.

- query:

  The search phrase that produced the record.

## Source

Retrieved from OpenAlex (<https://openalex.org>) on 2026-07-22: the
complete result set for the phrase "graphene supercapacitor" in title or
abstract, restricted to journal articles from 2015 to 2024. OpenAlex
data is released under CC0. Retrieval and reshaping are reproducible
from `data-raw/example_records.R`.

## Details

The records are deliberately not a 'Scopus' harvest. The Elsevier API
terms do not permit redistributing retrieved records, so no package can
ship one. These come instead from OpenAlex, whose metadata is released
under CC0 and may therefore be redistributed, and are reshaped into the
schema
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
returns. Running the equivalent query against 'Scopus' yields the same
kind of object, with the same columns and the same handling, though not
an identical set of records.

Two properties are worth knowing when reading the examples. The harvest
is complete rather than sampled, so the number of rows per year is the
real number of publications per year for that query, and the trend
figures show a real publication curve. The gaps are also genuine: eleven
records carry no DOI and two no source title, exactly as they arrive.
They are kept because a real harvest has such gaps, and the
reference-set examples are the more useful for showing how they are
handled.

## Examples

``` r
example_records
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

# The columns and the behaviour are those of a real retrieval, so the
# analysis helpers work on it directly.
scopus_top(example_records, by = "source", n = 5)
#> # A tibble: 5 × 2
#>   value                                  n
#> * <chr>                              <int>
#> 1 ACS Applied Materials & Interfaces     8
#> 2 Journal of Power Sources               5
#> 3 Synthetic Metals                       5
#> 4 Electrochimica Acta                    4
#> 5 Journal of Materials Chemistry A       4
```
