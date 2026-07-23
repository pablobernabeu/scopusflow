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

## Visualisation

`plot_scopus_comparison()` is deliberately built from ggplot2 alone, using only
features ggplot2 already bundles: a viridis discrete scale, which is
colour-blind-safe, and integer year breaks computed from the data so the axis
never shows half-years. For a handful of topics the lines are labelled directly,
which removes the colour-matching round-trip a legend imposes, and a `highlight`
argument greys all but one topic when a figure needs a single focus. Direct
labels sit in the right margin (via `clip = "off"`) rather than a wide in-panel
gutter, and the y-axis is capped at a data-driven round value, so the panel
carries little empty space. A shaded band shows a Wilson score interval on each
yearly share. Because 'Scopus' returns exact counts rather than a sample, the
band is documented honestly as an illustrative stability range, not a confidence
interval: it widens where the reference set is small, flagging volatile shares.

Where several topics converge near the final year, their direct labels would
stack. They are de-collided at draw time rather than at build time: the label
block is a small custom ggplot2 `Geom` whose grob carries the endpoints to grid,
and a `makeContent` method (registered on `grid::makeContent`) spreads them when
the panel's physical size is finally known, using one rendered line of text as
the minimum gap. The labels carry no leader lines: they are colour-matched to
their lines and spread in the same order as the line ends, and a leader from a
line's end to its nudged label would cut across the neighbouring labels' text.
Spreading against
the rendered text height, not a fixed fraction of the data range, keeps labels
legible at any figure size, including the app's short result card, where a
build-time gap overlapped. Beyond what fits one line per topic in a short panel
the function still falls back to the legend. This needs only `grid`, which ships
with R and is already attached by ggplot2, so it adds no external dependency. The
dependencies ggrepel, directlabels and scales were considered for labelling and
formatting and rejected, since the same results, including this device-aware
de-collision, are reachable within ggplot2 and base grid, and the package keeps
its imports small; ggrepel would also make the figure depend on whether an
optional package is installed. An exported theme helper was also rejected: with
one plotting function it would add surface for no reuse, so the theme stays
inline.

## API additions and rejected options

`scopus_combine()` (with a `c()` method) fills a real gap, since plain `rbind()`
leaves duplicate entry numbers; it renumbers and optionally de-duplicates by
identifier or DOI. `scopus_query()` composes field-tagged boolean queries so the
brackets and tags are correct by construction. `as_tibble()` and `as.data.frame()`
methods make the class easy to shed. Two tempting ideas were rejected: aliasing
the exports to a single `scopus_*` prefix (needless churn for established names),
and warning when a field tag is not one of the common ones (Scopus has many valid
tags beyond the common dozen, so the warning would fire on legitimate input).

## Robustness

Responses are parsed with `simplifyVector = FALSE`, so an array-valued field such
as several authors under `dc:creator` arrives as a list; `scopus_field()` collapses
it to a semicolon-separated string rather than silently keeping the first element.
The empty-result sentinel is recognised only when an entry carries an `error` field
*and* no identifier, so a real record with a per-entry error annotation is not
dropped. Totals are carried as doubles, since broad queries can report billions of
matches that would overflow a 32-bit integer to `NA` and suppress the cap warning.

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
plotting where ggplot2 is present, the I/O round-trips and key handling. An
offline request-contract test pins the outbound URL, query parameters and auth
header, so a change to the request shape is caught even though no real request is
made. Spelling is enforced during `R CMD check` through `tests/spelling.R`, and a
`_R_CHECK_DEPENDS_ONLY_` CI run proves the Imports are declared correctly. The
mocks cannot tell whether the live API has changed, so a weekly, key-gated live
smoke test checks that a real query still returns the documented, populated
schema; it skips itself, staying green, until a `SCOPUS_API_KEY` secret is added.

## Documentation strategy

Every export carries roxygen2 documentation with fast, fixture-based examples.
The package also ships a README, one vignette driven by fixtures, an
`inst/CITATION` file, a `NEWS.md` and a `cran-comments.md`.

### Where the bundled example records come from

The examples need a corpus that looks like what a user really retrieves,
because a bibliometric package documented against obviously invented rows
teaches nothing about the shape of real data. The package cannot simply ship a
'Scopus' harvest: the Elsevier API terms do not permit redistributing retrieved
records, so that option is closed to any package, not merely to this one.

`example_records` therefore holds 138 real journal articles on graphene
supercapacitors retrieved from OpenAlex, whose metadata is released under CC0
and may be redistributed, reshaped into the schema `scopus_fetch()` returns. The
titles, DOIs, source titles, first authors and citation counts are real and
verifiable. `scopus_id` is empty throughout, since the records did not come from
'Scopus' and no honest value exists for that column; de-duplication falls back
to the DOI, which is the same path any record with a missing identifier takes.
The harvest is complete rather than sampled, so the rows per year are the real
publications per year and a trend figure drawn from it is a real curve. Eleven
records carry no DOI and two no source title, and those gaps are kept because a
real harvest has them and the reference-set examples are more useful for showing
how they are handled.

Two alternatives were rejected. Inventing records that merely look plausible was
the previous approach and is worse than it appears: the earlier fixture paired
genuine, resolving DOIs with invented titles and authors, so a reader who
checked one found it mislabelled a real published paper. Restricting the
examples to key-gated live calls was also rejected, since it would leave every
reference page showing an unevaluated block and no output at all.

The non-ASCII characters that survive in the data are deliberate. Accented and
Cyrillic author names and the en dashes in titles are part of real names and
real titles, so they are marked UTF-8 rather than transliterated, which would
misspell published work. Only U+2010, a hyphen indistinguishable from the ASCII
one, is normalised, so a single visible character is not stored two ways.

## Continuous maintenance

The package depends on several actively developed packages, `httr2` most of all,
so a scheduled dependency canary
(`.github/workflows/dependency-check.yaml`) rebuilds and checks it every other
day against the current and development versions of those dependencies. A
breaking change therefore surfaces here before it reaches a release. The workflow
flags the maintainer through a single, de-duplicated issue. The whole pipeline
runs on GitHub's free Actions minutes and needs no secret. The attempt to resolve
a breakage has three tiers: with no secret it asks a free GitHub Models model to
diagnose and propose a fix in the issue; with a Claude subscription OAuth token
(`CLAUDE_CODE_OAUTH_TOKEN`, no per-token cost) or a paid `ANTHROPIC_API_KEY`, the
Claude Code action attempts a full fix and opens a pull request. Every tier is
best-effort, so detection and flagging never depend on it. Dependabot keeps the
workflow actions themselves current.

## Version 0.2.0: API reach and an analysis layer

The first release stopped at retrieval. 0.2.0 reaches further into the API and
adds the analysis that a study usually needs next, all kept offline-testable.

Cursor pagination (`scopus_fetch(cursor = TRUE)`) follows the API's `@next`
cursor instead of an offset, so a single large query can be harvested past the
5000-record ceiling that offset paging imposes. It is opt-in, since the records
then arrive in deep-paging rather than relevance order, which is the right trade
for a complete harvest but not for a top-of-results sample. `scopus_abstract()`
adds the Abstract Retrieval API, a second endpoint, so the abstract and fuller
metadata of a known record can be read; a batch is resilient, turning a per-id
failure into an `NA` row with a warning rather than losing the whole call. Both
are tested with `httr2` mocks and a key-gated live test, exactly as the Search
API is.

The analysis layer consumes objects already in hand: `scopus_top()` tallies
sources or authors from a record set in memory, and `scopus_trend()` counts a
query year by year through the API (the single-query companion to the topic
comparison). Each pairs with a plot, and an `autoplot()` method gives a record
set an honest default figure. A shared, unexported `scopus_minimal_theme()` now
backs the several plots, the internal helper the earlier notes said would be
justified once a second plotting function appeared.

### Pre-CRAN hardening of the 0.2.0 additions

A multi-agent adversarial review of the 0.2.0 code, with every finding
independently verified against the source, surfaced no blockers but a set of
edge-case robustness gaps that were closed before submission, since a defect is
far cheaper to fix before CRAN than after:

- `scopus_top()` now orders ties by `value` in byte order (`order(..., method =
  "radix")`) instead of the locale-dependent `sort(table())`, so which tied
  values survive the top-`n` cut is reproducible across platforms; it also
  rejects fractional and non-finite `n`, matching the package's other count
  validators.
- `scopus_trend()` warns (rather than silently recording `NA`) when a year's
  response carries no total.
- `scopus_abstract()` percent-encodes each identifier path segment while
  preserving the structural slashes a DOI needs, so a DOI containing reserved
  characters is not mis-parsed; it resolves the key once up front so a missing
  key aborts cleanly instead of degrading to a tibble of `NA` rows; and a
  malformed `200` body is raised as a typed `scopus_error_malformed` (also in
  `scopus_search_page()`), so the batch degrades to an `NA` row rather than
  aborting on an untyped `jsonlite` error.
- Cursor paging gained a bounded backstop: it stops once the reported total is
  reached and, against a non-conforming server that never signals the end, after
  `getOption("scopusflow.max_cursor_pages", 1e5)` pages with a typed warning
  (set the option to `Inf` to disable), so an unbounded harvest cannot silently
  burn memory and quota.
- The plot functions guard empty `scopus_trend`/`scopus_top` inputs with a typed
  condition rather than an opaque `sprintf` crash or a silent blank chart.

### A local-first app

`run_app()` launches a Shiny front end so the workflow can be driven without
writing code, while a panel mirrors every choice back as a runnable script, so
the app is an on-ramp to the package rather than a replacement for it. It is
deliberately local-first, bound to `127.0.0.1`: a hosted multi-user version would
conflict with Elsevier's API terms (which expect calls not to be proxied through
a server-side component) and with the institutional-IP entitlement model (calls
from a cloud IP get reduced access), and it would put third parties in custody of
users' keys. Running on the user's own machine sidesteps all three, and removes
any platform timeout on a long harvest.

The long retrieval runs in a background `callr::r_bg()` child whose `verbose`
`cli` output is written to a log file the server tails (a poll on
`invalidateLater`, rendered through `fansi`), rather than captured over a pipe,
which would deadlock once the OS pipe buffer filled. The code mirror is built
from hand-rolled templates, not `shinymeta`, because the expensive step runs
across the async boundary `shinymeta` cannot see. The reproducible-code,
progress-parsing and ANSI-to-HTML helpers are factored into `app-helpers.R` so
they are unit-tested offline; the reactive layer is not.

On the key: it is held only in the session, never written by app code to the
log, the generated script or the cache path. The terminal panel HTML-escapes its
content in both the coloured and plain branches, so a query echoed into the log
cannot inject markup. One residual, accepted exposure: `callr` serialises the
worker's argument list, which includes the key, to a short-lived, user-owned
temp file when launching the child. That is tolerated because the app is local
and the file is the user's own and transient; the alternative of passing the key
through the child's environment was rejected as it would lengthen the exposure
window in the process environment without a net gain on a single-user machine.
The app's interface packages (`shiny`, `bslib`, `callr`, `fansi`) stay in
Suggests and are required only inside `run_app()`.

## Version 0.2.0 (continued): author keywords, references and a minimal corpus

A downstream consumer (theoryforge) needed a keywords list and a references
list per record, which neither the Search nor the Abstract Retrieval side of
the package exposed, and which are otherwise only reachable by exporting from
the 'Scopus' web interface. Before writing any of this, the actual API was
checked directly against a live key (documented in each function's roxygen
under *Details*/*API access*), since a fixed reference guide can drift from
what the API currently returns, and it had: the Search API's `COMPLETE` view
does carry an `authkeywords` field structurally (confirmed via
`pybliometrics`'s own `ScopusSearch` result schema in the Python twin), but it
came back empty, on this key, even for documents that plainly carry author
keywords in 'Scopus' itself, and even under Abstract Retrieval's `FULL` view,
which populated everything else (`idxterms`, `citedby-count`, the full
bibliography) correctly. This is documented as a likely entitlement gap
specific to that one field, not a code defect, since there is no way to
confirm the root cause without a second, differently-entitled key.

`view = "FULL"` is the recommended default for references over `view =
"REF"`, the opposite of what an older pybliometrics issue (`pybliometrics#81`)
would suggest. In this package's own live testing, `"FULL"` returned a
complete, correctly counted reference list for two different documents,
consistently, while `"REF"` returned an inconsistent, sometimes paginated
subset (40 of 103 references on one call, all 103 on another, for the
identical request made moments apart). `scopus_abstract()` therefore compares
the returned count against the document's own reported total and warns on a
mismatch under either view, rather than trusting either view unconditionally.

The `references` list-column carries a leaner, hand-picked field set
(`position`, `id`, `doi`, `title`, `authors`, `source`, `year`,
`citedbycount`) rather than every field the raw API exposes, because R has no
equivalent of pybliometrics' own parsing to lean on and re-deriving its full,
implementation-specific field set (`authors_auid`, `authors_affiliationid`,
`type`, `text`, `fulltext`, and so on) was judged not worth the parsing
surface for what this package's own users are likely to need. The Python
twin, which already gets this for free from pybliometrics' `Reference`
namedtuple, exposes the fuller native shape instead; the difference is
documented in both packages' equivalent function so it is not a silent
divergence.

A 403 during `scopus_abstract()` now stops the whole batch rather than
degrading to a per-identifier `NA` row and warning, unlike other per-identifier
failures: entitlement is an account-level property, not a per-document one, so
a 403 on the first identifier will recur on every remaining one, and repeating
an already-known failure serves nobody. Implementing this surfaced a
non-obvious `tryCatch()` hazard worth recording: a condition raised *inside*
one handler of a `tryCatch()` call can still be caught by a sibling handler of
that same call (verified directly, not assumed), so the abort could not simply
be called from within the `scopus_error_forbidden` handler alongside a generic
`scopus_error` handler in the same `tryCatch()` — it had to be deferred to a
sentinel checked immediately after the `tryCatch()` call returns, outside any
handler's dynamic scope. A related, easier-to-miss scoping pitfall: `<<-`
inside a bare block passed as `tryCatch()`'s first argument (not a closure)
still skips that block's own environment, since a bare block is evaluated
directly in the caller's frame; a counter incremented there needs a plain
`<-`, not `<<-`, even though the same counter genuinely does need `<<-` from
within the handler functions, which are real closures.

`scopus_corpus()` assembles `id`/`title`/`year`/`keywords`/`references` from
an existing `scopus_records` result plus one `scopus_abstract()` call, rather
than duplicating the search step, since a caller ordinarily already has
records in hand by the time keywords or references are wanted. It does not
replace `as_bibliometrix()`, which keeps its own established field-mapping
convention for bibliometrix users; the two are complementary exports for
different downstream tools, matching how `as_bibtex()`/`as_ris()` sit
alongside `as_bibliometrix()` already.

## Concept and intersection sizing

`scopus_intersections()` and `plot_scopus_intersections()` size a named set of
concepts and their intersections, the magnitude snapshot that introduces where
a study or a niche sits within a wider literature. It is a separate pair
rather than an extension of `scopus_compare_topics()` because it answers a
different question: the comparison tracks topics' shares of a reference over
time (one request per term per year), whereas this counts each concept and
each requested intersection once (one request per row), so a whole landscape
costs a handful of count requests. The pair was ported from a prototype
developed and tested against the live API in a real literature review, and two
of its details are deliberate rather than incidental.

First, a concept value that already reads as a complete field-tagged
expression (matched by `^[A-Z][A-Z-]*\(`) is used exactly as given instead of
being wrapped in `field` again. Passing an already-wrapped query through a
further field wrap produces a nested tag such as `TITLE-ABS-KEY(TITLE(x))`,
which the live API rejects as malformed with HTTP 400; the guard is what lets
one call mix bare terms with hand-built expressions. A related quota courtesy:
every row's label and query is assembled, and label collisions (for example an
`abbrev` that maps two concepts to one short form) rejected, before the first
request is sent, so no invalid call spends quota. Counts are kept as doubles,
consistent with `scopus_count()` and the overflow lesson recorded above.

Second, in the plot, each count label sits at `n * gap_mult` rather than
`n + constant`: on a log axis only a constant ratio renders as a constant
pixel gap, so an additive nudge would hug the large counts and overshoot the
small ones. The ratio is in turn derived from the axis's own span
(`gap_mult <- 10^(gap_frac * log10(hi / lo))`, with `gap_frac` about 0.024,
some 2.4% of the panel width) rather than fixed, because a magic constant
tuned on one dataset was observed to read well beside wide many-digit labels
yet touch the point beside single-digit ones once the span narrowed. The prototype's widened right margin (28 pt) is kept as the companion to
`clip = "off"`: on a very wide span the largest count label can spill past the
panel, and the default margin was measured to clip its trailing digits. Rows
counting zero cannot sit on a log axis, so the plot drops them with a warning
and a caption note while the object keeps them, since an empty intersection is
itself a finding. The axis breaks come from a small internal helper
(`scopus_log_breaks()`, powers of ten interleaved with `3 * 10^k` on narrow
spans) rather than from the scales package, which would otherwise have to be
added to Suggests for a single call; the colours reuse the package palette,
with the comparison plot's accent marking the optional highlight.

## Assumptions

On licensing, the original `rscopus_plus` code is licensed CC BY 4.0 and was
written solely by Pablo Bernabeu, who owns it outright and may relicense it, so
scopusflow is released under the MIT licence, which is appropriate for software
on CRAN. No third-party code was copied.

On API access, users supply their own Elsevier API key under their own
institutional agreement and the Elsevier API terms. The package neither bundles
nor evades any quota, and only makes legitimate use more efficient, as described
above.

On identity, the author is Pablo Bernabeu, pcbernabeu@gmail.com, ORCID
0000-0003-1083-2460.
