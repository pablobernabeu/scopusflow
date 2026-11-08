## Submission

This is an update from scopusflow 0.4.0, which CRAN published on 2026-08-21, to
0.5.0.

0.5.0 changes results and interfaces. Some functions return different values
for the same input (topic comparisons and multi-word query terms, which are now
bracketed, the author column under the 'COMPLETE' view, reference lists, which
are now returned whole, offset paging after a short page and the
de-duplication that `scopus_combine(dedupe = TRUE)` applies among them), and
some input that 0.4.0 accepted is refused before any request, such as
unbalanced brackets, the refinements that the 'Scopus' Search API ignores and
logical arguments that are not TRUE or FALSE. The package now requires httr2
1.0.4 or later, where it required 1.0.0, because it retries transport failures
with the 'retry_on_failure' argument of `httr2::req_retry()`, and suggests
shiny 1.6.0 or later for its app. NEWS.md lists each of these changes under
'Upgrading from the previous release (0.4.0)', in three parts: 'Changed
results', 'Changed interface' and 'Changed output'.

The release adds `scopus_diff_records()`, `write_scopus_corpus()` and
`as_theoryforge_corpus()`. `citation("scopusflow")` gives the DOI that CRAN
registered, <https://doi.org/10.32614/CRAN.package.scopusflow>, with CRAN as
the publisher, where it gave the Zenodo concept DOI. The options that set the
API's addresses accept only an https URL on an elsevier.com host, so the API
key is sent to Elsevier alone.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

GitHub Actions, run 42427789546 on 2026-11-08, at commit 83f2177 on the
ccr-48a6a874-3shvqm branch. The package sources of this submission are those of
that commit. Because a pull request started the run, it checked out a merge of
that commit into main. That merge differs from the commit only in a workflow
file under .github, a directory that .Rbuildignore excludes. Each leg built the
tarball with `--no-manual --compact-vignettes=gs+qpdf` and ran
`R CMD check --as-cran --no-manual` on it, without the CRAN incoming checks,
which r-lib/actions turns off. Each leg ended with 'Status: OK':

* ubuntu-latest (Ubuntu 24.04.5 LTS), R 4.6.2
* ubuntu-latest (Ubuntu 24.04.5 LTS), R-devel (2026-11-05 r90840)
* ubuntu-latest (Ubuntu 24.04.5 LTS), R 4.5.3
* ubuntu-latest (Ubuntu 24.04.5 LTS), R 4.4.3
* ubuntu-latest (Ubuntu 24.04.5 LTS), R 4.3.3
* windows-latest (Windows Server 2025, x86_64-w64-mingw32), R 4.6.2
* windows-latest (Windows Server 2025, x86_64-w64-mingw32), R-devel
  (2026-11-06 r90845 ucrt)
* macos-latest (macOS 26.7.2, aarch64-apple-darwin23), R 4.6.2

The test suite passed in every leg, with no failures or warnings. Seven live
tests skip everywhere, because they run only with an API key and an opt-in
variable. One more test skips on Linux, which has no German time locale, and
one on Windows, which lets a read-only directory be written.

The same run checked the package under R 4.6.2 on ubuntu-latest twice more:
with only its strong dependencies available to the check
(`_R_CHECK_DEPENDS_ONLY_=true`, `--as-cran`, without re-building the vignettes)
and with httr2 1.0.4, the minimum that DESCRIPTION declares. Both ended with
'Status: OK'.

Some platforms may report a note listing possibly misspelled words in the
DESCRIPTION, among them 'DOIs', 'Elsevier', 'PRISMA', 'Rethlefsen',
'bibliometric' and 'resumable'. These are spelled correctly. 'Elsevier' is the
company that provides the API, 'PRISMA-S' and 'Rethlefsen' name the reporting
standard and its first author, 'DOIs' is the plural of the abbreviation defined
in the same sentence, and 'bibliometric' and 'resumable' are standard terms in
this field.

## Reverse dependencies

There are no reverse dependencies on CRAN.

## Notes for the CRAN team

* The package is an independent client for the Elsevier 'Scopus' APIs. 'Scopus'
  is a trademark of Elsevier, which the DESCRIPTION and README acknowledge, and
  the package is not affiliated with or endorsed by Elsevier. The software and
  API names are single-quoted in the Title and Description.
* All examples and tests run offline. Examples use bundled data or are guarded
  with `@examplesIf scopus_has_key()`, and the test suite intercepts all HTTP
  with `httr2::local_mocked_responses()`. No example or test contacts the
  network or needs an API key. The live integration tests are skipped on CRAN
  and need both `SCOPUS_API_KEY` and `SCOPUSFLOW_LIVE_TESTS`.
* No API keys or other secrets are stored in the package. Keys are read only
  from environment variables, options or explicit arguments, are redacted in
  request output and are sent only to Elsevier over https.
* The package writes nothing implicitly. The optional cache is created only when
  the user passes a path or opts in through `scopus_cache_dir()`, which lies
  under `tools::R_user_dir()`, and `scopus_cache_clear()` clears it. The app
  keeps its working files under `tempdir()`. Examples and tests write only to
  `tempdir()`.
* The app's interface packages (shiny, bslib and callr) are in Suggests and used
  only inside `run_app()`, which checks for them with
  `rlang::check_installed()`. ggplot2 is in Suggests for the plotting
  functions, which check for it in the same way, and fansi is used only when it
  is installed. The package builds, loads and checks without them.

## Licensing

The package reuses ideas from the author's own `rscopus_plus` scripts. The
author is the sole copyright holder and releases scopusflow under the MIT
licence.
