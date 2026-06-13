# Read and write 'Scopus' record sets

Save a
[scopus_records](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md)
tibble to disk and read it back, with a stable round-trip. The file
extension selects the format. An `.rds` file preserves the types and
class exactly, while a `.csv` file is portable plain text.

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
recs <- scopus_records(list(entry = list(
  list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
       `dc:title` = "A study", `prism:coverDate` = "2020-01-01")
)))
path <- tempfile(fileext = ".csv")
write_scopus_records(recs, path)
read_scopus_records(path)
#> <scopus_records> (1 record)
#> # A tibble: 1 × 10
#>   entry_number scopus_id doi    title  authors  year date  publication citations
#>          <int> <chr>     <chr>  <chr>  <chr>   <int> <chr> <chr>           <int>
#> 1            1 1         10.1/a A stu… NA       2020 2020… NA                 NA
#> # ℹ 1 more variable: query <chr>
```
