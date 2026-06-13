# Design notes for scopusflow

This memo records the design decisions behind scopusflow and the assumptions
made while creating it. It is excluded from the built package through
`.Rbuildignore`.

## Chosen package concept

scopusflow is a coherent, quota-aware workflow layer over the Elsevier 'Scopus'
Search API. A search is first described as a reproducible plan with
`scopus_plan()` and sized cheaply with `scopus_count()`. It is then retrieved
with `scopus_fetch()` or `scopus_fetch_plan()`, which handle pagination,
rate-limit responses, retry with back-off and optional resumable caching. Results
are normalised to a stable tidy schema by `scopus_records()`, from which DOIs can
be extracted and tracked over time (`scopus_extract_dois()`, `scopus_diff_dois()`),
topics compared (`scopus_compare_topics()`, `plot_scopus_comparison()`) and
output exported for downstream tools (`as_bibliometrix()`,
`write_scopus_records()`, `read_scopus_records()`). The package refactors the
author's `pablobernabeu/rscopus_plus` scripts into a tested, documented package
with typed error handling.

## Rejected alternatives

A thin wrapper around `rscopus` was set aside as too slight to be novel, and
because `rscopus` hides the underlying request, which rules out per-status
offline testing. A general multi-database tool spanning Scopus, OpenAlex and
Crossref was set aside for a first release as well, since the scope would be
large and the adjacent databases are already well served by `openalexR` and
`rcrossref`. scopusflow stays focused on the Scopus workflow. For the same
testability reason, the package calls `httr2` directly rather than depending on
`rscopus`, as explained below.

## Main competitors and adjacent packages

| Package | Niche | Overlap |
|---|---|---|
| `rscopus` | Low-level Scopus API wrapper | Same API, lower layer, with no plans, quota handling, diffing or caching |
| `openalexR` | OpenAlex client | Different database |
| `pubmedR`, `dimensionsR` | PubMed and Dimensions clients | Different databases |
| `rcrossref` | Crossref metadata | Different database |
| `bibliometrix` | Science mapping and analysis | Downstream, fed by scopusflow |
| `revtools`, `litsearchr`, `citationchaser`, `synthesisr` | Systematic-review tooling | A different stage of the workflow |

No current CRAN package provides a Scopus-specific reproducible retrieval and
trend-comparison workflow.

## Dependency strategy

The package talks to the API through `httr2` directly rather than through
`rscopus`, and this is its substantive core. Working at the request level gives
control over pagination, parsing of quota headers, back-off through
`req_retry()` that honours `Retry-After` and typed classification of errors. It
also makes offline testing possible through `httr2::local_mocked_responses()`,
which is what lets the test suite cover each HTTP status without a network. The
imports are kept small: `cli`, `httr2`, `jsonlite`, `rlang`, `tibble` and the
base packages `stats`, `tools` and `utils`. `jsonlite` parses the API responses,
since `httr2` only suggests it, so the dependency is declared rather than left
implicit. Optional features live in Suggests, namely `ggplot2` for plotting,
`knitr` and `rmarkdown` for the vignette, and `testthat`, `withr` and `spelling`.

## CRAN risks and mitigations

'Scopus' is an Elsevier trademark. The precedent of `rscopus`, `pubmedR` and
`dimensionsR` shows that CRAN accepts database names, and the package quotes
'Scopus' and 'API' in the Title and Description, acknowledges the trademark and
states plainly that it is an independent client. Live API access is kept out of
the checks: every example is based on a fixture or a mock, or guarded with
`@examplesIf scopus_has_key()`, the tests never touch the network, and the
vignette runs on bundled fixtures, while the live tests are gated behind
`skip_on_cran()` and a key. No key or other secret is stored anywhere. Keys are
read only from environment variables, options or arguments, and are redacted in
request output. Nothing is written to disk unless the user asks, the cache is
opt-in under `tools::R_user_dir()` and can be cleared, and examples and tests
write only to `tempdir()`.

## Why the package is substantial

The package does real work beyond forwarding calls. It constructs and partitions
query plans, paginates within the API's `start < 5000` ceiling, parses quota
headers, maps HTTP statuses onto a typed condition hierarchy, retries with
back-off, caches each plan cell so a run can resume, normalises records to a
stable schema, cleans and diffs DOIs, computes comparison percentages with care
around a zero denominator, and converts results for bibliometrix.

## Quota optimisation

The Elsevier weekly quota is charged per request, so the cheapest way to retrieve
a result set is to use the largest page the view permits. The Scopus Search API
allows up to 200 records per request for the `STANDARD` view, and 25 for
`COMPLETE`, which mirrors the `count = 200` default in `rscopus`. For that reason
`page_size` defaults to the view maximum, keeping the number of requests, and so
the quota, as low as possible for a given retrieval. This is a documented,
terms-compliant efficiency. No limit is bypassed, the per-query `start < 5000`
ceiling is still respected, and the remaining quota is surfaced through
`scopus_quota()` so that a caller can pace itself.

## Naming

The chosen name, `scopusflow`, is a valid package name with no underscore and no
collision among current or archived CRAN packages. The backups held in reserve
are `scopustools` and `scopusquota`.

## Testing strategy

The suite uses testthat (third edition) and runs entirely offline, with
`httr2::local_mocked_responses()` standing in for HTTP and a static JSON fixture
in `inst/extdata`. It covers plan construction and validation, pagination and the
5000-record cap, quota parsing, record normalisation, DOI extraction and diffing,
the comparison percentages including the zero-denominator case, the mapping of
HTTP statuses 400, 401, 403, 404, 413, 414, 429 and the 5xx range onto
conditions, transient classification, offline handling, caching and resume,
plotting where ggplot2 is present, the I/O round-trips and key handling.

## Documentation strategy

Every export carries roxygen2 documentation with fast, fixture-based examples.
The package also ships a README, one vignette driven by fixtures, an
`inst/CITATION` file, a `NEWS.md` and a `cran-comments.md`.

## Assumptions

On licensing, the original `rscopus_plus` code is licensed CC BY 4.0 and was
written solely by Pablo Bernabeu. As the sole copyright holder he may relicense
his own work, so scopusflow is released under the MIT licence, which is
appropriate for software on CRAN. No third-party code was copied.

On API access, users supply their own Elsevier API key under their own
institutional agreement and the Elsevier API terms. The package neither bundles
nor evades any quota, and only makes legitimate use more efficient, as described
above.

On identity, the author is Pablo Bernabeu, pcbernabeu@gmail.com, ORCID
0000-0003-1083-2460.
