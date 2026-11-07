# Contributing to scopusflow

Thank you for considering a contribution. Issues and pull requests about bugs,
documentation or new features are welcome.

## Reporting a problem or suggesting a feature

Please open an issue at
<https://github.com/pablobernabeu/scopusflow/issues>. A small reproducible
example helps a great deal. For a bug, it is also useful to include the output
of `sessionInfo()`. Because the package uses a paid API, please never paste an
API key into an issue.

## Setting up for development

Clone the repository. From its root, install the package's dependencies,
including the suggested ones, and then the development tools:

```sh
git clone https://github.com/pablobernabeu/scopusflow.git
cd scopusflow
```

```r
# install.packages("pak")
pak::local_install_dev_deps()
pak::pak(c("devtools", "roxygen2", "testthat", "spelling", "covr"))
```

The package is developed with the usual devtools workflow:

```r
devtools::document()   # regenerate man/ and NAMESPACE after editing roxygen
devtools::test()       # run the test suite
devtools::check()      # a full R CMD check
```

## How the code is organised

The exported functions are grouped into thematically named files under `R/`, such
as `records.R`, `dois.R`, `plan.R`, `fetch.R`, `compare.R` and `io.R`, while the
internal HTTP layer is in `R/request.R` and `R/conditions.R`. A few
conventions keep the package predictable, and a pull request is easiest to accept
when it follows them.

The tests run offline. HTTP is intercepted with
`httr2::local_mocked_responses()`, and small fixtures are kept in
`tests/testthat/` and `inst/extdata`. A test should never make a real network
request. Live integration tests are skipped on CRAN and run only when the
`SCOPUSFLOW_LIVE_TESTS` environment variable is `"true"` and `SCOPUS_API_KEY`
is set (see *Automated maintenance* below).

Errors are raised as typed conditions in the `scopus_error` family through
`rlang::abort()`, never with a bare `stop()`, so that callers can handle them
programmatically. An invalid argument goes through `scopus_abort_bad_input()`,
and a choice among fixed values is matched with `scopus_match_arg()` in place of
`rlang::arg_match()`, so that input errors stay in the family too. User-facing
messages use `cli`.

An API key is a secret. It is read only from the `SCOPUS_API_KEY` environment
variable, the `scopusflow.api_key` option or an `api_key` argument, and it is
kept out of printed output. Nothing is written to disk unless the caller asks,
and examples and tests write only to `tempdir()`.

The prose follows British spelling, and the names `'Scopus'` and `'API'` are
single-quoted in the DESCRIPTION and the help files. Running
`spelling::spell_check_package()` before a pull request keeps the word list
tidy.

## Automated maintenance

Two scheduled workflows check the package for breakage caused by upstream
changes. The first, a dependency check
(`.github/workflows/dependency-check.yaml`), runs every other day and can also
be run on demand from the Actions tab. It rebuilds and checks the package
against the current and the development versions of the key dependencies,
`httr2` above all, to catch a breaking change before it reaches a release. When
the check fails, the workflow opens or updates a single issue with the log and
marks the run as failed. It closes the issue once the check passes again.

Because the dependency check executes development code fetched from other
repositories, it runs with read-only repository access. Write access to the
repository is held by a companion workflow
(`.github/workflows/dependency-autofix.yaml`) that runs only after a failed
check. Each workflow declares the permissions it needs, so the repository's
default workflow permissions can stay read-only.

Dependabot (`.github/dependabot.yml`) keeps the GitHub Actions used by the
workflows up to date through weekly pull requests. It does not track CRAN
packages, which the dependency check covers at runtime.

The dependency check, its issue reporting and Dependabot run on GitHub's free
Actions minutes for public repositories and need no secret. When a breaking
change is found, the attempt to resolve it has three tiers, in order of
capability:

* With no secret, the dependency check asks a free GitHub Models model to
  diagnose the breakage and propose a fix, and includes that suggestion in the
  issue it raises.
* With a `CLAUDE_CODE_OAUTH_TOKEN` secret, generated from a Claude Pro or Max
  subscription with `claude setup-token`, the companion auto-fix workflow has
  the Claude Code action attempt a fix in the code and open a pull request for
  review. The attempt is billed to the subscription, with no per-token charge.
* With an `ANTHROPIC_API_KEY` secret, the same fix attempt runs against the paid
  API.

The auto-fix pull request additionally requires 'Settings → Actions → General'
to allow GitHub Actions to create and approve pull requests. Because the
auto-fix job opens the pull request with the workflow's own token, continuous
integration does not start on it by itself. Run R-CMD-check on its branch
before merging. A fix attempt that fails is reported on the open dependency
issue and marks the run as failed.

The second scheduled workflow, a weekly live smoke test
(`.github/workflows/live-api-check.yaml`), checks the package against the
'Scopus' API itself. The ordinary test suite mocks all HTTP, so it cannot tell
whether the API has renamed a field or changed its envelope. The live smoke
test runs a tiny query against the API and checks that the records come back
with the documented columns populated.

The live tests run only where `SCOPUSFLOW_LIVE_TESTS` is `"true"`. The workflow
sets the variable and a local `devtools::test()` does not, so a local run spends
no quota even with a key in `~/.Renviron`. To run the live tests by hand, set
the variable in the session. The workflow needs a `SCOPUS_API_KEY` repository
secret. Until one is set, the live tests skip themselves and the run passes, but
a warning in the log and the run summary says that the check is dormant. Once a
key is present, a skipped live test fails the run, so a passing run always means
that the tests ran.

## Submitting a pull request

Please base your work on `main`, keep the change focused and add or update tests
and documentation alongside the code. Running `devtools::document()`,
`devtools::test()` and `devtools::check()` locally before opening the pull
request saves a round trip. Continuous integration then checks the package on
Windows, macOS and several versions of R on Linux. A further run with only the
package's declared dependencies on the path (a `_R_CHECK_DEPENDS_ONLY_` run)
proves that nothing in `R/` relies on an undeclared package.

By contributing, you agree that your contribution is licensed under the same MIT
licence as the package, and that you will follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
