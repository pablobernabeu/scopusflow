# Design notes for scopusflow

This memo records the design decisions behind scopusflow and the
assumptions made while creating it. It is excluded from the built
package through `.Rbuildignore`.

## Chosen package concept

scopusflow is a coherent, quota-aware workflow layer over the Elsevier
‘Scopus’ Search API. A search is first described as a reproducible plan
with
[`scopus_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_plan.md)
and sized cheaply with
[`scopus_count()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_count.md).
It is then retrieved with
[`scopus_fetch()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch.md)
or
[`scopus_fetch_plan()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_fetch_plan.md),
which handle pagination, rate-limit responses, retry with back-off and
optional resumable caching. Results are normalised to a stable tidy
schema by
[`scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_records.md),
from which DOIs can be extracted and tracked over time
([`scopus_extract_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_extract_dois.md),
[`scopus_diff_dois()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_diff_dois.md)),
topics compared
([`scopus_compare_topics()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_compare_topics.md),
[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md))
and output exported for downstream tools
([`as_bibliometrix()`](https://pablobernabeu.github.io/scopusflow/reference/as_bibliometrix.md),
[`write_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md),
[`read_scopus_records()`](https://pablobernabeu.github.io/scopusflow/reference/write_scopus_records.md)).
The package refactors the author’s `pablobernabeu/rscopus_plus` scripts
into a tested, documented package with typed error handling.

## Rejected alternatives

A thin wrapper around `rscopus` was set aside as too slight to be novel,
and because `rscopus` hides the underlying request, which rules out
per-status offline testing. A general multi-database tool spanning
Scopus, OpenAlex and Crossref was set aside for a first release as well,
since the scope would be large and the adjacent databases are already
well served by `openalexR` and `rcrossref`. scopusflow stays focused on
the Scopus workflow. For the same testability reason, the package calls
`httr2` directly rather than depending on `rscopus`, as explained below.

## Main competitors and adjacent packages

| Package | Niche | Overlap |
|----|----|----|
| `rscopus` | Low-level Scopus API wrapper | Same API, lower layer, with no plans, quota handling, diffing or caching |
| `openalexR` | OpenAlex client | Different database |
| `pubmedR`, `dimensionsR` | PubMed and Dimensions clients | Different databases |
| `rcrossref` | Crossref metadata | Different database |
| `bibliometrix` | Science mapping and analysis | Downstream, fed by scopusflow |
| `revtools`, `litsearchr`, `citationchaser`, `synthesisr` | Systematic-review tooling | A different stage of the workflow |

No current CRAN package provides a Scopus-specific reproducible
retrieval and trend-comparison workflow.

## Dependency strategy

The package talks to the API through `httr2` directly rather than
through `rscopus`, and this is its substantive core. Working at the
request level gives control over pagination, parsing of quota headers,
back-off through `req_retry()` that honours `Retry-After` and typed
classification of errors. It also makes offline testing possible through
[`httr2::local_mocked_responses()`](https://httr2.r-lib.org/reference/with_mocked_responses.html),
which is what lets the test suite cover each HTTP status without a
network. The imports are kept small: `cli`, `httr2`, `jsonlite`,
`rlang`, `tibble` and the base packages `stats`, `tools` and `utils`.
`jsonlite` parses the API responses, since `httr2` only suggests it, so
the dependency is declared rather than left implicit. Optional features
live in Suggests, namely `ggplot2` for plotting, `knitr` and `rmarkdown`
for the vignette, and `testthat`, `withr` and `spelling`.

## CRAN risks and mitigations

‘Scopus’ is an Elsevier trademark. The precedent of `rscopus`, `pubmedR`
and `dimensionsR` shows that CRAN accepts database names, and the
package quotes ‘Scopus’ and ‘API’ in the Title and Description,
acknowledges the trademark and states plainly that it is an independent
client. Live API access is kept out of the checks: every example is
based on a fixture or a mock, or guarded with
`@examplesIf scopus_has_key()`, the tests never touch the network, and
the vignette runs on bundled fixtures, while the live tests are gated
behind `skip_on_cran()` and a key. No key or other secret is stored
anywhere. Keys are read only from environment variables, options or
arguments, and are redacted in request output. Nothing is written to
disk unless the user asks, the cache is opt-in under
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html) and can be
cleared, and examples and tests write only to
[`tempdir()`](https://rdrr.io/r/base/tempfile.html).

## Why the package is substantial

The package does real work beyond forwarding calls. It constructs and
partitions query plans, paginates within the API’s `start < 5000`
ceiling, parses quota headers, maps HTTP statuses onto a typed condition
hierarchy, retries with back-off, caches each plan cell so a run can
resume, normalises records to a stable schema, cleans and diffs DOIs,
computes comparison percentages with care around a zero denominator, and
converts results for bibliometrix.

## Quota optimisation

The Elsevier weekly quota is charged per request, so the cheapest way to
retrieve a result set is to use the largest page the view permits. The
Scopus Search API allows up to 200 records per request for the
`STANDARD` view, and 25 for `COMPLETE`, which mirrors the `count = 200`
default in `rscopus`. For that reason `page_size` defaults to the view
maximum, keeping the number of requests, and so the quota, as low as
possible for a given retrieval. This is a documented, terms-compliant
efficiency. No limit is bypassed, the per-query `start < 5000` ceiling
is still respected, and the remaining quota is surfaced through
[`scopus_quota()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_quota.md)
so that a caller can pace itself.

## Visualisation

[`plot_scopus_comparison()`](https://pablobernabeu.github.io/scopusflow/reference/plot_scopus_comparison.md)
is deliberately built from ggplot2 alone, using only features ggplot2
already bundles: a viridis discrete scale, which is colour-blind-safe,
and integer year breaks computed from the data so the axis never shows
half-years. For a handful of topics the lines are labelled directly,
which removes the colour-matching round-trip a legend imposes, and a
`highlight` argument greys all but one topic when a figure needs a
single focus. Direct labels sit in the right margin (via `clip = "off"`)
rather than a wide in-panel gutter, and the y-axis is capped at a
data-driven round value, so the panel carries little empty space. A
shaded band shows a Wilson score interval on each yearly share. Because
‘Scopus’ returns exact counts rather than a sample, the band is
documented honestly as an illustrative stability range, not a confidence
interval: it widens where the reference set is small, flagging volatile
shares. The dependencies ggrepel, directlabels and scales were
considered for labelling and formatting and rejected, since the same
results are reachable within ggplot2 and the package keeps its imports
small. An exported theme helper was also rejected: with one plotting
function it would add surface for no reuse, so the theme stays inline.

## API additions and rejected options

[`scopus_combine()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_combine.md)
(with a [`c()`](https://rdrr.io/r/base/c.html) method) fills a real gap,
since plain [`rbind()`](https://rdrr.io/r/base/cbind.html) leaves
duplicate entry numbers; it renumbers and optionally de-duplicates by
identifier or DOI.
[`scopus_query()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_query.md)
composes field-tagged boolean queries so the brackets and tags are
correct by construction. `as_tibble()` and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) methods
make the class easy to shed. Two tempting ideas were rejected: aliasing
the exports to a single `scopus_*` prefix (needless churn for
established names), and warning when a field tag is not one of the
common ones (Scopus has many valid tags beyond the common dozen, so the
warning would fire on legitimate input).

## Robustness

Responses are parsed with `simplifyVector = FALSE`, so an array-valued
field such as several authors under `dc:creator` arrives as a list;
`scopus_field()` collapses it to a semicolon-separated string rather
than silently keeping the first element. The empty-result sentinel is
recognised only when an entry carries an `error` field *and* no
identifier, so a real record with a per-entry error annotation is not
dropped. Totals are carried as doubles, since broad queries can report
billions of matches that would overflow a 32-bit integer to `NA` and
suppress the cap warning.

## Naming

The chosen name, `scopusflow`, is a valid package name with no
underscore and no collision among current or archived CRAN packages. The
backups held in reserve are `scopustools` and `scopusquota`.

## Testing strategy

The suite uses testthat (third edition) and runs entirely offline, with
[`httr2::local_mocked_responses()`](https://httr2.r-lib.org/reference/with_mocked_responses.html)
standing in for HTTP and a static JSON fixture in `inst/extdata`. It
covers plan construction and validation, pagination and the 5000-record
cap, quota parsing, record normalisation, DOI extraction and diffing,
the comparison percentages including the zero-denominator case, the
mapping of HTTP statuses 400, 401, 403, 404, 413, 414, 429 and the 5xx
range onto conditions, transient classification, offline handling,
caching and resume, plotting where ggplot2 is present, the I/O
round-trips and key handling. An offline request-contract test pins the
outbound URL, query parameters and auth header, so a change to the
request shape is caught even though no real request is made. Spelling is
enforced during `R CMD check` through `tests/spelling.R`, and a
`_R_CHECK_DEPENDS_ONLY_` CI run proves the Imports are declared
correctly. The mocks cannot tell whether the live API has changed, so a
weekly, key-gated live smoke test checks that a real query still returns
the documented, populated schema; it skips itself, staying green, until
a `SCOPUS_API_KEY` secret is added.

## Documentation strategy

Every export carries roxygen2 documentation with fast, fixture-based
examples. The package also ships a README, one vignette driven by
fixtures, an `inst/CITATION` file, a `NEWS.md` and a `cran-comments.md`.

## Continuous maintenance

The package depends on several actively developed packages, `httr2` most
of all, so a scheduled dependency canary
(`.github/workflows/dependency-check.yaml`) rebuilds and checks it every
other day against the current and development versions of those
dependencies. A breaking change therefore surfaces here before it
reaches a release. The workflow flags the maintainer through a single,
de-duplicated issue. The whole pipeline runs on GitHub’s free Actions
minutes and needs no secret. The attempt to resolve a breakage has three
tiers: with no secret it asks a free GitHub Models model to diagnose and
propose a fix in the issue; with a Claude subscription OAuth token
(`CLAUDE_CODE_OAUTH_TOKEN`, no per-token cost) or a paid
`ANTHROPIC_API_KEY`, the Claude Code action attempts a full fix and
opens a pull request. Every tier is best-effort, so detection and
flagging never depend on it. Dependabot keeps the workflow actions
themselves current.

## Version 0.2.0: API reach and an analysis layer

The first release stopped at retrieval. 0.2.0 reaches further into the
API and adds the analysis that a study usually needs next, all kept
offline-testable.

Cursor pagination (`scopus_fetch(cursor = TRUE)`) follows the API’s
`@next` cursor instead of an offset, so a single large query can be
harvested past the 5000-record ceiling that offset paging imposes. It is
opt-in, since the records then arrive in deep-paging rather than
relevance order, which is the right trade for a complete harvest but not
for a top-of-results sample.
[`scopus_abstract()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_abstract.md)
adds the Abstract Retrieval API, a second endpoint, so the abstract and
fuller metadata of a known record can be read; a batch is resilient,
turning a per-id failure into an `NA` row with a warning rather than
losing the whole call. Both are tested with `httr2` mocks and a
key-gated live test, exactly as the Search API is.

The analysis layer consumes objects already in hand:
[`scopus_top()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_top.md)
tallies sources or authors from a record set in memory, and
[`scopus_trend()`](https://pablobernabeu.github.io/scopusflow/reference/scopus_trend.md)
counts a query year by year through the API (the single-query companion
to the topic comparison). Each pairs with a plot, and an `autoplot()`
method gives a record set an honest default figure. A shared, unexported
`scopus_minimal_theme()` now backs the several plots, the internal
helper the earlier notes said would be justified once a second plotting
function appeared.

## Assumptions

On licensing, the original `rscopus_plus` code is licensed CC BY 4.0 and
was written solely by Pablo Bernabeu. As the sole copyright holder he
may relicense his own work, so scopusflow is released under the MIT
licence, which is appropriate for software on CRAN. No third-party code
was copied.

On API access, users supply their own Elsevier API key under their own
institutional agreement and the Elsevier API terms. The package neither
bundles nor evades any quota, and only makes legitimate use more
efficient, as described above.

On identity, the author is Pablo Bernabeu, <pcbernabeu@gmail.com>, ORCID
0000-0003-1083-2460.
