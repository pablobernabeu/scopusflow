# Read and write 'Scopus' record sets

Save a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble to disk and read it back, with a stable round-trip. The file
extension selects the format. An `.rds` file preserves the types and
class exactly, while a `.csv` file is portable plain text. The optional
`authkeywords` column a `view = "COMPLETE"` retrieval adds (see
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md))
round-trips through both formats.

## Usage

``` r
write_scopus_records(x, path)

read_scopus_records(path)
```

## Arguments

- x:

  A
  [scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
  tibble to write.

- path:

  Explicit file path. The functions read from, or write to, exactly this
  path and leave the working directory alone. Parent directories are
  assumed to exist already.

## Value

`write_scopus_records()` returns `x` invisibly. `read_scopus_records()`
returns a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble.

## Examples

``` r
# A round trip on the bundled corpus of real articles, which stands in for
# a retrieval of your own because 'Scopus' records may not be redistributed.
# The .rds form restores the object exactly.
rds <- tempfile(fileext = ".rds")
write_scopus_records(example_records, rds)
identical(read_scopus_records(rds), example_records)
#> [1] TRUE

# The .csv form is portable plain text and reads back to the same schema.
csv <- tempfile(fileext = ".csv")
write_scopus_records(example_records, csv)
head(read_scopus_records(csv))
#> <scopus_records> 6 records
#> query: "graphene supercapacitor"
#> # A tibble: 6 × 9
#>   entry_number scopus_id doi     title authors  year date  publication citations
#>          <int> <chr>     <chr>   <chr> <chr>   <int> <chr> <chr>           <int>
#> 1            1 NA        10.155… Enha… Jianhu…  2015 2015… Journal of…         1
#> 2            2 NA        NA      Fabr… Patric…  2015 2015… DigitalCom…         0
#> 3            3 NA        10.102… Flex… Zhiwei…  2015 2015… ACS Applie…       469
#> 4            4 NA        10.101… Heav… Vikran…  2015 2015… Electrochi…       195
#> 5            5 NA        10.100… Grap… Chih-T…  2015 2015… Small             108
#> 6            6 NA        10.101… Nano… Hao Ya…  2015 2015… Journal of…        47
```
