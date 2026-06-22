# Launch the scopusflow app

Starts a local, code-free Shiny app for building a search, retrieving
records, comparing topic trends and exporting the results, with a live
terminal that streams the retrieval's progress and a panel that mirrors
every choice as runnable R code. A *Demo mode* (on by default)
synthesises records and a topic comparison so the whole workflow can be
explored with no key and no network; switch it off and supply a key to
query 'Scopus' for real. The app runs on your own machine: your API key
never leaves it, and requests originate from your own network, which is
what the 'Scopus' API expects. It needs the suggested packages shiny,
bslib and callr (and ggplot2 for the plots, fansi for coloured terminal
output).

## Usage

``` r
run_app(host = "127.0.0.1", port = NULL, launch.browser = TRUE)
```

## Arguments

- host:

  The address to listen on. Defaults to `"127.0.0.1"`, so the app is
  reachable only from your own machine and the key is never exposed on
  the network.

- port:

  The port to listen on, or `NULL` (default) to choose one.

- launch.browser:

  Logical, whether to open a browser. Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Called for its side effect of running the app; does not return until the
app is closed.

## See also

[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md),
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md)

## Examples

``` r
if (FALSE) { # \dontrun{
run_app()
} # }
```
