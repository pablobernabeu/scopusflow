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

## Automated maintenance

Two scheduled safeguards watch for breakage from the package’s
dependencies, so that an upstream change does not quietly stop the
package working.

A dependency canary (`.github/workflows/dependency-check.yaml`) runs
every other day. It rebuilds and checks the package against the current
and the development versions of the key dependencies, `httr2` above all,
and so catches a breaking change before it reaches a release. When the
check fails it opens, or updates, a single issue with the log, and
closes it again once the check passes. It can also be run on demand from
the Actions tab.

The whole canary, the issue flagging and Dependabot run on GitHub’s free
Actions minutes for public repositories and need no secret. When a
breaking change is found, the attempt to resolve it has three tiers, in
order of capability:

- With no secret, the workflow asks a free GitHub Models model to
  diagnose the breakage and propose a fix, and includes that suggestion
  in the issue it raises. This costs nothing.
- With a `CLAUDE_CODE_OAUTH_TOKEN` secret, generated from a Claude Pro
  or Max subscription with `claude setup-token`, the Claude Code action
  attempts a full fix and opens a pull request for review, billed to the
  subscription rather than per token.
- With an `ANTHROPIC_API_KEY` secret, the same agentic fix runs against
  the paid API.

Dependabot (`.github/dependabot.yml`) keeps the GitHub Actions used by
the workflows up to date through weekly pull requests. It does not track
CRAN packages, which is why the dependency canary watches those at
runtime instead.

For the issue and pull-request automation to work, the repository’s
*Settings → Actions → General → Workflow permissions* must grant read
and write permissions and, for the auto-fix pull request, allow GitHub
Actions to create pull requests.

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
