## Submission

This is an update of scopusflow, from 0.1.0 to 0.4.0. CRAN carries 0.1.0. The
versions in between, 0.2.0, 0.2.1 and 0.3.0, were released on GitHub and
archived on Zenodo but were never submitted to CRAN, so this submission carries
their changes as well as the newest work. NEWS.md lists all of it; the
paragraphs below give the shape of it.

Retrieval reaches further than it did in 0.1.0. `scopus_fetch()` gained
cursor-based pagination, which retrieves a whole large query without the API's
5000-record offset ceiling. `scopus_abstract()` retrieves abstracts and fuller
metadata from the 'Scopus' Abstract Retrieval API, including a document's own
reference list as a structured, per-citation data frame and its author keywords,
and `scopus_corpus()` assembles a minimal keyword and reference corpus from a
record set. A search can request author keywords through `view = "COMPLETE"`.

There is now an analysis, plotting and export layer. `scopus_trend()` reports
annual record counts, `scopus_top()` tallies the most frequent sources or
authors, and `scopus_intersections()` sizes a named set of concepts and their
intersections in single count requests, each with a plotting counterpart.
`as_bibtex()` and `as_ris()` export a record set to the two reference-manager
interchange formats. `run_app()` launches a local, code-free Shiny app that
mirrors every choice as a runnable R script.

Version 0.4.0 adds the reporting layer. `scopus_search_report()` assembles the
reproducible search-strategy record a systematic review has to publish,
following the 'PRISMA-S' reporting standard (Rethlefsen and others, 2021,
<doi:10.1186/s13643-020-01542-z>) with the identification counts of the PRISMA
2020 flow diagram. It prints as a readable report, formats as a methods
paragraph and writes as Markdown. `scopus_combine()` merges record sets and
records the merge counts that 'PRISMA-S' asks for, and a retrieval now carries
its plan, per-cell accounting, paging mode, retrieval time and package version
as attributes. Alongside that, 0.4.0 fixes a family of silent cache defects that
could serve one plan's records to another, and three points at which a record
count past 2^31 was coerced to `NA`.

The bundled `example_records` dataset was replaced in 0.3.0 and so is new to
CRAN. It now holds 138 real journal articles on graphene supercapacitors, so the
examples run against data of the shape and messiness a real retrieval returns.
The records are not a 'Scopus' harvest, since the Elsevier API terms do not
permit redistributing retrieved records; they come from OpenAlex, whose metadata
is released under CC0, reshaped into the schema `scopus_fetch()` returns, and
both the help page and the data-raw script state that provenance. Code using the
dataset by name continues to work, its class and columns being unchanged, though
any code depending on the previous six rows will see different values.

The app's interface packages (shiny, bslib, callr, fansi) are in Suggests and
used only inside `run_app()`, which is guarded with `rlang::check_installed()`;
the package builds, loads and checks without them.

## Test environments

* Local: Windows 11, R 4.6.1, R CMD check --as-cran on the built tarball, run
  with no 'Scopus' API key configured (2026-08-21). Status: OK.
* GitHub Actions, at the commit this tarball was built from, so covering the
  same code but not the version number now in DESCRIPTION (last run
  2026-08-20):
  windows-latest (release and devel), macOS-latest (release), ubuntu-latest
  (release, devel, oldrel-1, oldrel-2 and oldrel-3), which reaches back to
  roughly R 4.3, plus a depends-only run, a run against the declared minimum
  dependency versions, and a namespace check. All returned Status: OK.

## R CMD check results

0 errors | 0 warnings | 0 notes.

Two conditions of the local run are worth recording, because a check made
without them reports notes that say nothing about the package. Pandoc was on the
check subprocess PATH; without it the check reports that 'README.md' and
'NEWS.md' cannot be checked, which is an artefact of the machine. No API key was
configured; with one, the `@examplesIf scopus_has_key()` examples run against the
live API and the check reports an example taking more than five seconds, which is
network latency rather than computation. On a machine without a key, including
CRAN and the GitHub Actions runners, those examples are skipped and the note
cannot arise.

Some platforms may report a note listing possibly misspelled words in the
DESCRIPTION, among them "DOIs", "Elsevier", "PRISMA", "Rethlefsen",
"bibliometric" and "resumable". These are spelled correctly. "Elsevier" is the
name of the company that provides the API, "PRISMA-S" and "Rethlefsen" name the
reporting standard and its first author, "DOIs" is the plural of the
abbreviation defined in the same sentence, and "bibliometric" and "resumable"
are standard terms in this field.

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
  require both `SCOPUS_API_KEY` and `SCOPUSFLOW_LIVE_TESTS`.
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
