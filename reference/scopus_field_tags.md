# Recognised 'Scopus' field tags

Lists the field tags that
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
and
[`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md)
understand, together with a short note on what each one searches.
Passing one of these tags as `field` restricts a query to the
corresponding part of a record, so `TITLE-ABS-KEY` looks in the title,
abstract and keywords while `AUTH` looks only at author names. Other
valid 'Scopus' tags are accepted too. This is a guide to the common
ones.

## Usage

``` r
scopus_field_tags()
```

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with a
`tag` column and a `searches` column describing the scope of each tag.

## See also

[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)

## Examples

``` r
scopus_field_tags()
#> # A tibble: 12 × 2
#>    tag                searches                                  
#>    <chr>              <chr>                                     
#>  1 TITLE              Words in the document title               
#>  2 TITLE-ABS-KEY      Title, abstract and keywords              
#>  3 TITLE-ABS-KEY-AUTH Title, abstract, keywords and author names
#>  4 ABS                Abstract text                             
#>  5 KEY                Indexed and author keywords               
#>  6 AUTH               Author names                              
#>  7 AUTHKEY            Author-supplied keywords                  
#>  8 AFFIL              Affiliation, any part                     
#>  9 AFFILORG           Affiliation organisation name             
#> 10 SRCTITLE           Source (publication) title                
#> 11 DOI                Digital Object Identifier                 
#> 12 ALL                All available fields                      
```
