## Submission

This is an update of scopusflow, from 0.1.0 to 0.3.0. It adds cursor-based
pagination (to retrieve beyond the API's 5000-record offset ceiling), an
abstract-retrieval function, an analysis and plotting layer (annual trends and
top-source/author tallies), reference-manager export (as_bibtex(), as_ris()),
and a local, code-free Shiny app (run_app()). The changes are listed in NEWS.md.
There are no user-facing breaking changes.

The app's interface packages (shiny, bslib, callr, fansi) are in Suggests and
used only inside run_app(), which is guarded with rlang::check_installed(); the
package builds, loads and checks without them.

## Test environments

* Local: Windows 11, R 4.6.1 (2026-07-08)
* GitHub Actions: windows-latest, macOS-latest, ubuntu-latest (release),
  ubuntu-latest (devel and oldrel-1), plus a depends-only run
* win-builder: R-devel and R-release

## R CMD check results

0 errors | 0 warnings | 0 notes locally. When a live 'Scopus' API key is
configured, the local check additionally reports an example-timing note,
because the `@examplesIf scopus_has_key()` examples then run against the live
API; on machines without a key, including CRAN, those examples are skipped and
the note does not arise.

On some platforms a single note may list possibly misspelled words in the
DESCRIPTION ("DOIs", "Elsevier", "bibliometric", "resumable"). These are spelled
correctly: "Elsevier" is the name of the company that provides the API, "DOIs" is
the plural of the abbreviation defined in the same sentence, and "bibliometric"
and "resumable" are standard terms in this field.

## Reverse dependencies

There are no reverse dependencies.

## Notes for the CRAN team

* The package is an independent client for the Elsevier 'Scopus' Search API.
  "Scopus" is a trademark of Elsevier; this is acknowledged in the DESCRIPTION
  and README, and the package is not affiliated with or endorsed by Elsevier.
  The software name and API name are single-quoted in the Title and Description.
* All examples and tests run offline: examples use bundled fixtures or are
  guarded with `@examplesIf scopus_has_key()`, and the test suite intercepts all
  HTTP with `httr2::local_mocked_responses()`. No example or test contacts the
  network or requires an API key. Live integration tests are skipped on CRAN and
  require both `SCOPUS_API_KEY` and `NOT_CRAN`.
* No API keys or other secrets are stored in the package. Keys are read only
  from environment variables, options or explicit arguments, and are redacted in
  request output.
* The package writes nothing implicitly. The optional cache is created only when
  the user passes a path or opts in via `scopus_cache_dir()`, lives under
  `tools::R_user_dir()`, and is clearable with `scopus_cache_clear()`. Examples
  and tests write only to `tempdir()`.

## Licensing

The package reuses ideas from the author's own `rscopus_plus` scripts. The
author is the sole copyright holder and releases scopusflow under the MIT
licence.
