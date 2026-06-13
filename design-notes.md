# Design notes for scopusflow

This memo records the design decisions behind **scopusflow** and the assumptions
made while creating it. It is excluded from the built package via
`.Rbuildignore`.

## Chosen package concept

A coherent, quota-aware **workflow layer** over the Elsevier Scopus Search API:

- describe searches as reproducible *plans* (`scopus_plan()`);
- size them cheaply (`scopus_count()`);
- retrieve them with pagination, rate-limit handling, retry/back-off and
  optional resumable caching (`scopus_fetch()`, `scopus_fetch_plan()`);
- normalise results to a stable tidy schema (`scopus_records()`);
- extract and **track changes** in DOI sets (`scopus_extract_dois()`,
  `scopus_diff_dois()`);
- compare publication trends across topics (`scopus_compare_topics()`,
  `plot_scopus_comparison()`);
- export to bibliometrix-compatible and plain formats (`as_bibliometrix()`,
  `write_scopus_records()` / `read_scopus_records()`).

It refactors the author's `pablobernabeu/rscopus_plus` scripts into a tested,
documented package with typed error handling.

## Rejected alternatives

- **A thin `rscopus` wrapper.** Rejected: not novel enough, and `rscopus` hides
  the underlying request, preventing per-status offline testing.
- **A general multi-database tool** (Scopus + OpenAlex + Crossref). Rejected for
  a first release: scope creep, and adjacent databases are already well served
  (`openalexR`, `rcrossref`). scopusflow stays focused on the Scopus workflow.
- **Depending on `rscopus`.** Rejected in favour of calling `httr2` directly
  (see below).

## Main competitors / adjacent packages

| Package | Niche | Overlap |
|---|---|---|
| `rscopus` | Low-level Scopus API wrapper | Same API; different layer (no plans/quota/diff/cache) |
| `openalexR` | OpenAlex client | Different database |
| `pubmedR`, `dimensionsR` | PubMed / Dimensions clients | Different databases |
| `rcrossref` | Crossref metadata | Different database |
| `bibliometrix` | Science mapping/analysis | Downstream; scopusflow feeds it |
| `revtools`, `litsearchr`, `citationchaser`, `synthesisr` | Systematic-review tooling | Downstream / different stage |

No current CRAN package provides a Scopus-specific reproducible retrieval +
trend-comparison workflow.

## Dependency strategy

- **API layer: `httr2` (direct), not `rscopus`.** This is the non-trivial core.
  httr2 gives request-level control of pagination, quota-header parsing,
  `req_retry()` back-off honouring `Retry-After`, typed error classification,
  and — decisively — clean offline testing via `httr2::local_mocked_responses()`.
- **Minimal Imports:** `cli`, `httr2`, `rlang`, `tibble`, plus base `tools`/`utils`.
- **Suggests** for optional features: `ggplot2` (plotting), `jsonlite` (test
  fixtures), `knitr`/`rmarkdown` (vignette), `testthat`, `withr`, `spelling`.

## CRAN risks and mitigations

- **Trademark / name.** "Scopus" is an Elsevier trademark. Precedent (`rscopus`,
  `pubmedR`, `dimensionsR`) shows database names are accepted. `'Scopus'` and
  `'API'` are single-quoted in Title/Description; a trademark acknowledgement
  and "independent client" statement appear in DESCRIPTION and README.
- **Live API in checks.** All examples are fixture/mock based or guarded with
  `@examplesIf scopus_has_key()`; tests never touch the network; the vignette
  uses bundled fixtures. Live tests are `skip_on_cran()` + key/`NOT_CRAN` gated.
- **Secrets.** No keys are stored anywhere; keys come only from env vars,
  options or arguments, and are redacted in request dumps.
- **Filesystem.** Nothing is written implicitly; cache is opt-in under
  `tools::R_user_dir()` and clearable; examples/tests use `tempdir()`.

## Why the package is non-trivial

It is not a wrapper. It implements: query-plan construction and partitioning; a
pagination engine with the API's `start < 5000` ceiling; quota-header parsing;
typed condition hierarchy mapped from HTTP status; retry/back-off; resumable
per-cell caching; a stable normalised schema; DOI cleaning/diffing; safe
percentage maths (zero-denominator handling); and bibliometrix interop.

## Quota optimisation (legitimate, no evasion)

The Elsevier weekly quota is charged per request, so the cheapest way to
retrieve a result set is to use the largest page the view permits: the Scopus
Search API allows up to 200 records per request for `STANDARD` view (25 for
`COMPLETE`), mirroring `rscopus`'s default `count = 200`. `page_size` therefore
defaults to the view maximum, minimising the number of requests - and hence the
quota - for a given retrieval. This is a documented, terms-compliant efficiency,
not evasion: no limit is bypassed and the per-query `start < 5000` ceiling is
still respected. Remaining quota is surfaced via `scopus_quota()` so callers can
pace themselves.

## Naming

- **Chosen:** `scopusflow` (valid; no underscore; no CRAN/archived collision found).
- **Backups:** `scopustools`, `scopusquota`.

## Testing strategy

testthat (3e), fully offline. `httr2::local_mocked_responses()` for HTTP; static
JSON fixture in `inst/extdata`. Coverage: plan/validation, pagination + cap,
quota parsing, record normalisation, DOI extract/diff, comparison percentages
(incl. zero denominator), HTTP status → condition mapping (400/401/403/404/413/
414/429/5xx), transient classification, offline handling, caching/resume,
plotting (conditional on ggplot2), I/O round-trips, key handling.

## Documentation strategy

roxygen2 on all exports (with fast, fixture-based examples), a README, one
vignette driven by fixtures, `inst/CITATION`, `NEWS.md`, `cran-comments.md`.

## Assumptions (explicit)

1. **Licensing.** The original `rscopus_plus` code is CC BY 4.0, authored solely
   by Pablo Bernabeu. As sole copyright holder he may relicense his own work;
   scopusflow is released under the MIT licence, a CRAN-appropriate software
   licence. No third-party code was copied.
2. **API access.** Users supply their own Elsevier API key under their own
   institutional agreement and the Elsevier API terms. The package does not
   bundle or evade any quota; it only optimises legitimate use (see above).
3. **Identity.** Pablo Bernabeu, pcbernabeu@gmail.com, ORCID 0000-0003-1083-2460.
