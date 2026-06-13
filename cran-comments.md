## Submission

This is a new submission (scopusflow 0.1.0).

## Test environments

* Local: Windows 11, R 4.5.1
* GitHub Actions: windows-latest, macOS-latest, ubuntu-latest (release),
  ubuntu-latest (devel and oldrel-1)
* win-builder: R-devel and R-release

## R CMD check results

0 errors | 0 warnings | 1 note

The note is the standard "New submission" note. It may also list the package
website, https://pablobernabeu.github.io/scopusflow/, as not yet resolving. The
GitHub Pages site is published from CI, so that URL goes live once the first
pkgdown deployment completes. The GitHub repository is already public, and these
URLs are the package's intended canonical home.

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
