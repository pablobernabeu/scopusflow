# Contributing to scopusflow

Thank you for considering a contribution. Issues and pull requests are
both welcome, whether they fix a bug, improve the documentation or add a
feature.

## Reporting a problem or suggesting a feature

Please open an issue at
<https://github.com/pablobernabeu/scopusflow/issues>. A small
reproducible example helps a great deal, and for a bug it is useful to
include the output of
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html). Because the
package talks to a paid API, please never paste an API key into an
issue.

## Setting up for development

Clone the repository and install the development dependencies:

``` r

# install.packages("pak")
pak::pak("pablobernabeu/scopusflow")
pak::pak(c("devtools", "roxygen2", "testthat", "spelling", "covr"))
```

The package is developed with the usual devtools workflow:

``` r

devtools::document()   # regenerate man/ and NAMESPACE after editing roxygen
devtools::test()       # run the test suite
devtools::check()      # a full R CMD check
```

## How the code is organised

The exported functions are grouped into thematically named files under
`R/`, such as `records.R`, `dois.R`, `plan.R`, `fetch.R`, `compare.R`
and `io.R`, while the internal HTTP layer lives in `R/request.R` and
`R/conditions.R`. A few conventions keep the package predictable, and a
pull request is easiest to accept when it follows them.

The tests run entirely offline. HTTP is intercepted with
[`httr2::local_mocked_responses()`](https://httr2.r-lib.org/reference/with_mocked_responses.html)
and small fixtures live in `tests/testthat/` and `inst/extdata`. A test
should never make a real network request. Live integration tests are
gated behind `skip_on_cran()` and a key, so they run only when
`SCOPUS_API_KEY` is set.

Errors are raised as typed conditions in the `scopus_error` family
through
[`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html), rather
than with a bare [`stop()`](https://rdrr.io/r/base/stop.html), so that
callers can handle them programmatically. User-facing messages use
`cli`.

An API key is a secret. It is read only from the `SCOPUS_API_KEY`
environment variable, the `scopusflow.api_key` option or an `api_key`
argument, and it is kept out of printed output. Nothing is written to
disk unless the caller asks, and examples and tests write only to
[`tempdir()`](https://rdrr.io/r/base/tempfile.html).

The prose follows British spelling, and the names `'Scopus'` and `'API'`
are single-quoted in the DESCRIPTION and the help files. Running
[`spelling::spell_check_package()`](https://docs.ropensci.org/spelling//reference/spell_check_package.html)
before a pull request keeps the word list tidy.

## Submitting a pull request

Please base your work on `main`, keep the change focused, and add or
update tests and documentation alongside the code. Running
`devtools::document()`, `devtools::test()` and `devtools::check()`
locally before opening the pull request saves a round trip. Continuous
integration then checks the package on Windows, macOS and several
versions of R on Linux.

By contributing you agree that your contribution is licensed under the
same MIT licence as the package, and that you will follow the [Code of
Conduct](https://pablobernabeu.github.io/scopusflow/CODE_OF_CONDUCT.md).
