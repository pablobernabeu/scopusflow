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
be extracted and tracked over time (`scopus_extract_dois()`, `scopus_diff_dois()`,
`scopus_diff_records()`),
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
testability reason, the package calls `httr2` directly, as explained below.

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

The package talks to the API through `httr2` directly, and this is its
substantive core. Working at the request level gives control over pagination,
parsing of quota headers, back-off through `req_retry()` that honours
`Retry-After` and typed classification of errors. It also makes offline testing
possible through `httr2::local_mocked_responses()`, which is what lets the test
suite cover each HTTP status without a network. The imports are kept small:
`cli`, `httr2`, `jsonlite`, `rlang`, `tibble` and the base packages `stats`,
`tools` and `utils`. `jsonlite` parses the API responses. Because `httr2` only
suggests it, the dependency has to be declared here explicitly. Optional
features live in Suggests. `ggplot2` and `grid` draw the figures, `shiny`,
`bslib`, `callr` and `fansi` run the code-free app, `knitr` and `rmarkdown`
build the vignettes, and `testthat`, `withr` and `spelling` serve the checks.

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
labels sit in the right margin (via `clip = "off"`), which spares the panel the
wide in-panel gutter they would otherwise need, and the y-axis is capped at a
data-driven round value, so the panel carries little empty space. A shaded band
shows a Wilson score interval on each yearly share. 'Scopus' counts are exact,
so there is no sampling distribution for an interval to describe. The band is
therefore documented as an illustrative stability range, and never as a
confidence interval. It widens where the reference set is small, flagging
volatile shares.

Where several topics converge near the final year, their direct labels would
stack. They are de-collided at draw time: the label block is a small custom
ggplot2 `Geom` whose grob carries the endpoints to grid, and a `makeContent`
method (registered on `grid::makeContent`) spreads them once the panel's
physical size is finally known, using one rendered line of text as the minimum
gap. The labels carry no leader lines. They are colour-matched to their lines
and spread in the same order as the line ends, and a leader from a line's end to
its nudged label would cut across the neighbouring labels' text. Spreading
against the rendered text height keeps labels legible at any figure size,
including the app's short result card, where a gap fixed as a fraction of the
data range at build time overlapped. Beyond what fits one line per topic in a
short panel the function still falls back to the legend. This needs only `grid`,
which ships with R and is already attached by ggplot2, so it adds no external
dependency. The dependencies ggrepel, directlabels and scales were considered
for labelling and formatting and rejected, since the same results, including
this device-aware de-collision, are reachable within ggplot2 and base grid, and
the package keeps its imports small. ggrepel would also make the figure depend
on whether an optional package is installed. A theme helper was left out of the
first release, when one plotting function gave it nothing to be shared with.
`scopus_minimal_theme()` now backs all four plots but stays internal, since a
caller who wants to restyle a figure can add their own theme to the ggplot
object the function returns.

## API additions and rejected options

`scopus_combine()` (with a `c()` method) fills a real gap, since plain `rbind()`
leaves duplicate entry numbers. It renumbers and optionally de-duplicates by
identifier or DOI. `scopus_query()` composes field-tagged boolean queries and
groups their operands (see the next section). `as_tibble()` and `as.data.frame()`
methods make the class easy to shed. Two tempting ideas were rejected: aliasing
the exports to a single `scopus_*` prefix (needless churn for established names),
and warning when a field tag is not one of the common ones (Scopus has many valid
tags beyond the common dozen, so the warning would fire on legitimate input).

## Grouping composed queries

'Scopus' reads an unbracketed query by operator precedence. Its search tips
give the order OR, then AND, then AND NOT. Elsevier has announced that the
order will become AND NOT, then AND, then OR (Feldner, Scopus blog, 24 March
2025). A live check on 2 October 2026 found AND NOT still applied last, as the
search tips document.
`TITLE("working memory") AND NOT TITLE(children) AND PUBYEAR > 2020`
returned 19,510 records, against 5,454 when the first two operands were
bracketed, because the appended limit fell inside the negation. Each order
breaks a different shape, a clause appended after a top-level AND NOT under the
first and after a top-level OR under the second, and brackets fix both.

Every place the package composes a string therefore groups its operands.
`scopus_query()` trims each term and, when it joins two or more without a field
tag, brackets each term of several words, since 'Scopus' joins the words of an
unquoted term with AND. White space there means the 29 characters Python's
`str.isspace()` accepts, the no-break space among them, so the twins trim and
bracket the same terms. `trimws()` strips only four of them by default, and
`[[:space:]]` misses the no-break space on Windows. A term that already binds
as one operand is left as written: a quoted or braced phrase, a bracketed group
or a single field-tagged group. Bracketing every term was rejected, because it
would change correct joins such as `CRISPR OR Cas9` and every documented
example.
`scopus_compare_topics()` joins the reference and each term as
`(reference) AND (term)`, the form `scopus_intersections()` already used.
Joined bare, an AND NOT reference took the term into its negation, so the
comparison set outgrew the reference and shares passed 100%. The expected
strings are shared with the Python twin in
`tests/testthat/fixtures/query-grouping.json`.

The R package sends the year as the `date` request parameter, so its year
limits never entered the query and were never at risk. The Python twin folds
the year into the query string, because pybliometrics keys its download cache
on the query alone. It brackets the query only when a scan that skips phrases
and nested brackets finds a top-level OR, AND NOT or proximity operator.
Unconditional brackets would have changed every folded string and forced every
existing checkpoint and download cache to be fetched again. The conditional
rule changes only the strings that were already wrong, and their checkpoints
are refetched once under the existing different-plan warning. Two guards were
proposed and dropped, since the grouping leaves them nothing to catch. One
would have warned when a comparison count exceeded its reference count, the
other when a record appeared in more than one year cell.

## Offline query checks

`scopus_check_query()` refuses, before any request, a query that cannot do what
it appears to ask, and checks nothing less certain, since a warning that fires
on legitimate input is the noise the field-tag decision above rejected. The
first of its three errors is refinement syntax. `LIMIT-TO()` and `EXCLUDE()`
come from the web interface's refinement panel, and the Search API ignores them
without an error: rscopus issue #50 found 55 records with
`LIMIT-TO(SUBJAREA, ...)`, the unfiltered count, against 36 with `SUBJAREA()`,
and pybliometrics documents `LIMIT-TO()` as affecting the display only. The
second is a field given for a query that already opens with a tag, so that one
tag nests inside the other and the API answers with HTTP 400, as a live request
showed. Unbalanced brackets, quotation marks or braces are the third.
`INDEXTERMS()` only warns, because pybliometrics documents it as not working but
its behaviour has not been observed. The scan treats a quoted or braced phrase as
text, as the grouping code does, and the messages are shared word for word
with the Python twin through `tests/testthat/fixtures/query-checks.json`.

A query counts as opening with a tag when a capitalised word meets its bracket,
as in `TITLE(x)`, or when one of the common tags of `scopus_field_tags()` is
followed by white space and a bracket, the form the web interface writes,
`TITLE-ABS-KEY ( x )`. The audit proposed allowing white space after any
capitalised word. That would have refused `HIV (prevention OR treatment)` given
a field, a valid search for a term and a bracketed group, so the spaced form is
limited to the tags the package lists. `scopus_wrap_concept()` uses the same
test, so a concept pasted in the spaced form is used as written.

Several further checks were proposed and dropped. A fully bracketed reading of
the query under Scopus precedence would depend on the operator order, and
Elsevier is changing it. Warnings for a bare NOT or a clause after a top-level
AND NOT overlap the grouping above. A PUBYEAR in the query beside `years` is
visible in the search record, since the record prints the expression. A
separate exported validator was rejected in favour of the check every entry
point already calls. A relative-recall helper, counting a chain of known DOIs
alone and joined to the strategy, waits for a live check of how the API treats
long DOI chains and the case of the DOIs it returns. The designing-queries
article gives the recipe meanwhile.

## Robustness

Responses are parsed with `simplifyVector = FALSE`, so a field that arrives as
an array is kept as a list. `scopus_field()` collapses an array of scalars to a
semicolon-separated string, where keeping its first element would lose the
rest. None of the fields the records read is sent that way. `dc:creator` in
particular is one name, the first author, under either view, and the author
list exists only under `COMPLETE` (see *Authors: the first author or the author
list* below).
The empty-result sentinel is recognised only when an entry carries an `error` field
*and* no identifier, so a real record with a per-entry error annotation is not
dropped. Totals are carried as doubles, since broad queries can report billions of
matches that would overflow a 32-bit integer to `NA` and suppress the cap warning.
The cap warning itself is conditioned on `max_results` as well as the total, so a
caller who asked for fewer records than the ceiling and received exactly that is
not told their retrieval was truncated. Every request carries a transfer timeout,
read from `getOption("scopusflow.timeout", 60)`: curl's own default is no timeout
at all, so a connection that opens and then stalls hangs the session outright, and
the retry policy never fires because no response arrives to be classified.

Input errors carry `scopus_error_bad_input` beneath `scopus_error`, so the
contract that every scopusflow error inherits `scopus_error` holds for them as
well. Up to and including 0.4.0, 66 validation sites raised the
subclass on its own and the argument matching raised bare rlang errors, so a
handler for `scopus_error` saw neither, and the app's Check size handler let a
blank query close the session. Two internal helpers in `R/conditions.R` now
carry the classes: `scopus_abort_bad_input()` for the package's own checks and
`scopus_match_arg()` around `rlang::arg_match()`. The second re-signals rlang's
condition with the two classes prepended. Rebuilding it from its message would
also have worked, but re-signalling keeps rlang's bullets, call and backtrace
unchanged. The alternative of documenting that argument-matching errors come
from rlang was rejected, since a caller cannot know which arguments are matched
that way. An input error is not transient, so code that retries on
`scopus_error` has to test the subclass.

## Authors: the first author or the author list

Elsevier's Search views table lists `dc:creator` as the first author in both
views, and the `author` objects (`authid`, `authname`, `surname`, `given-name`
and the rest) as the complete author list under `COMPLETE` alone. A live check
on 2 October 2026 agreed, finding only `dc:creator` under `STANDARD` and the
whole array under `COMPLETE`. Up to 0.4.0 the `authors` column read
`dc:creator` in every view, so it held the first author everywhere while the
documentation promised every author. The tests mocked an array-valued
`dc:creator` the API never sends. Author tallies, bibliometrix collaboration
measures and exports were built on first authors.

The column now follows the API. Under `COMPLETE` it is built from the `author`
array, each name written `"Surname, Given"` and joined by `"; "`, the separator
the tally and the exporters already split on. The API lists at most 100 authors
per record, and `author-count` gives the total. The Python twin joins
pybliometrics' `author_names`, which uses a bare `";"`, the same way, so the
twins build byte-identical strings, held to one shared fixture
(`tests/testthat/fixtures/complete-authors.json`). Exact duplicate author
objects are dropped, as pybliometrics' `deduplicate()` drops them.
De-duplicating by `authid` was considered and rejected, since the twins would
then disagree wherever the array lists one author in two positions. Two edges
remain where pybliometrics parses differently, and both twins document them. An
author object without a `surname` or `given-name` key leaves pybliometrics
building no list, and a null or empty surname is written after a bare comma.
Under `STANDARD` the column keeps the first author, the only name that view
carries.

A set's view travels as the `view` attribute. An author tally (`scopus_top()`)
or a bibliometrix conversion of a `STANDARD` set warns that its authors are
first authors. The two share one `rlang::warn()` frequency id, so a session
sees the warning once, whichever function meets the set first. The
reference-manager exports stay silent, since a BibTeX or RIS entry with one
author is a correct export of what the record holds, and a warning there would
fire on every routine export. The app's Top authors tab says the same in a note
above the plot and draws its tally under quiet verbosity, which leaves the
session's one warning for the user's own code.

Checkpoints written before the change are handled by view. A `COMPLETE`
checkpoint holds first authors where the list belongs, so a manifest without
`records_schema`, or no manifest at all, makes it a cache miss, refetched once
with a warning that names the reason. A `STANDARD` checkpoint was always read
correctly and is served as before, at no cost. The Python twin needs no refetch,
since its old `COMPLETE` checkpoints already held the list, joined with `";"`,
and are joined again as they are served.

## Exported names, titles and the RIS source tag

`dc:creator` writes a name as `"Zhang F."`, with no comma. BibTeX reads a
comma-free name as given name first (Patashnik, 1988), so BibTeX and biber
took `F.` for the family name and plain.bst sorted a bibliography by initials,
while Zotero's RIS import kept the whole string as a single field. The
exporters therefore put a comma before a final run of initials, using one strict
rule in both twins: an initial is an upper-case letter, optionally followed by
one lower-case letter, then a full stop. The Unicode classes catch `Ö.` and
`Д.`, which an ASCII class misses, and the two-letter form catches `Yu.`. The
looser patterns the audit first proposed all turned the bundled `Fisher D. J.`
into `Fisher D., J.`. Names with a comma and names given first are written as
they stand. A given-first name ending in an initial (`John A.`) would be
inverted, a risk accepted because `dc:creator` does not send that form. The rule
applies at export only, so the `authors` column keeps what 'Scopus' sent and the
citation keys do not move. BibTeX also takes run-together initials (`J.R.`) for
one given name, so the BibTeX form spaces them, and RIS keeps the spelling
'Scopus' uses. The Python twin has no `\p{Lu}` in `re`, so it matches the same
pattern against each name's letter-case shape, which keeps the two twins'
backtracking identical. Both are held to `fixtures/author-names.json`.

BibTeX styles lower-case unbraced title letters, so a title word with a capital
after its first letter is braced whole (`{DNA}`, `{CRISPR-Cas9}`). A word
capitalised only at its start is left to the style, which is what sentence
case expects. A word that opens with an escape (`\#MeToo`) is braced twice,
because BibTeX reads a brace group opening with a backslash as a special
character and changes the case of the letters inside it. RIS gives the source under `T2`, as Elsevier's own RIS export
does. Zotero reads `JO` as the journal abbreviation and copies it to the
publication title only when nothing else fills that field. Keeping `JO` behind
a flag was rejected, since no reader that depends on it was found. The exports'
expected output is pinned by a hand-written golden for a six-record fixture,
shared by both suites. `example_records` could not serve, since all its names
but one are given first and hide the defect.

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
made. The mocks also bypass `req_retry()`, so the retry loop never runs offline.
The suite instead tests its parts: which responses `scopus_is_transient()` calls
transient (a 429 marked `QUOTA_EXCEEDED` is not), the `Retry-After` parser under
a German time locale, and the policy `scopus_req_retry()` attaches to a request,
`retry_on_failure` included. Spelling is checked by `tests/spelling.R`, which
fails `R CMD check` wherever `NOT_CRAN` is true: under `devtools::check()` and
across the GitHub Actions matrix, where setup-r sets it. The test is skipped on CRAN, in a plain
`R CMD check` and by `devtools::test()`, which runs only `tests/testthat`. It
raises an error because the NOTE it used to produce left CI green and let
unlisted words reach the 0.4.0 release. Which words need listing depends on the
version of R. The spelling package checks words with hunspell, which by default
ignores the words in R's own `share/dictionaries/en_stats` list, and R 4.4.0
added macOS to that list. R 4.3, the `oldrel-3` leg of the matrix, therefore
flagged the README's macOS while every later R accepted it. `inst/WORDLIST`
lists the word itself, since the declared floor is R 4.1.0. Run under R 4.4 or
later, `spelling::update_wordlist()` offers to remove it again, and the offer
should be declined. A `_R_CHECK_DEPENDS_ONLY_` CI run
proves the Imports are declared correctly. The mocks cannot tell whether the
live API has changed, so a weekly, key-gated live
smoke test checks that a real query still returns the documented, populated
schema. It skips itself, staying green, until a `SCOPUS_API_KEY` secret is added.

## Documentation strategy

Every export carries roxygen2 documentation with fast, fixture-based examples.
The package also ships a README, ten vignettes driven by the bundled corpus and
by fixtures, an `inst/CITATION` file, a `NEWS.md` and a `cran-comments.md`.

The README names no version number. It is knitted into the tarball before CRAN
accepts a submission, so a version typed into it is wrong on CRAN from the day
of release: the README inside 0.4.0 said CRAN carried 0.1.0. The CRAN badge
shows the live version, and NEWS lists what each release added. A typed version
kept in step by a CI check was considered and rejected, since the README on
GitHub and on the site would then name a version CRAN had not yet accepted.

### How chunk output is presented

The vignettes set `collapse = FALSE, comment = ""`, so knitr writes each chunk's
output into a block of its own carrying no `#>` marker. Two considerations
decided this. The prefix exists to keep a collapsed block paste-safe, output
lines staying valid R comments when the whole block is copied; once output sits
in a separate block the source is paste-clean without it, so the marker earns
nothing. It also cost parity: the Python twin renders results through
markdown-exec, which has never prefixed anything, so the two documentation sets
disagreed on every page.

Two surfaces keep the prefix deliberately. The README renders on GitHub and CRAN,
where the site stylesheet does not reach, leaving the marker as the only thing
distinguishing output from code. pkgdown reference pages interleave input and
output line by line inside one block, which is precisely the case the marker
disambiguates, and splitting them there is not under our control.

What marks output as output is the stylesheet. An output block is a bare
`<pre>`, highlighted source always being wrapped in `div.sourceCode`, and
`pkgdown/extra.scss` gives that bare `<pre>` a raised navy ground and an accent
rule. One alternative was rejected, `comment = ""` while leaving the default
`collapse = TRUE`: that merges unprefixed output into the source fence, where it
is highlighted as R and swept into the copy button.

Note that `cat()` never affected the prefix. It removes the quotes and the `[1]`
index, and it remains necessary for multi-line generated strings such as an RIS
export, since `print()` renders those as a single escaped one-liner.

### Where the bundled example records come from

The examples need a corpus that looks like what a user retrieves,
because a bibliometric package documented against obviously invented rows
teaches nothing about the shape of real data. The package cannot simply ship a
'Scopus' harvest: the Elsevier API terms do not permit redistributing retrieved
records, so that option is closed to every package, this one included.

`example_records` therefore holds 138 real journal articles on graphene
supercapacitors retrieved from OpenAlex, whose metadata is released under CC0
and may be redistributed, reshaped into the schema `scopus_fetch()` returns. The
titles, DOIs, source titles, first authors and citation counts are real and
verifiable. `scopus_id` is empty throughout, since the records did not come from
'Scopus' and no honest value exists for that column; de-duplication falls back
to the DOI, which is the same path any record with a missing identifier takes.
The harvest is complete, so the rows per year are the real publications per year
and a trend figure drawn from it is a real curve. Eleven
records carry no DOI and two no source title, and those gaps are kept because a
real harvest has them and the reference-set examples are more useful for showing
how they are handled.

Two alternatives were rejected. Inventing records that merely look plausible was
the previous approach and is worse than it appears: the earlier fixture paired
genuine, resolving DOIs with invented titles and authors, so a reader who
checked one found it mislabelled a real published paper. Restricting the
examples to key-gated live calls was also rejected, since it would leave every
reference page showing an unevaluated block and no output at all.

The documentation therefore has to say which search the corpus answers. It
came from OpenAlex's exact-phrase search for "graphene supercapacitor" in
titles and abstracts, limited to journal articles. Up to 0.4.0 the worked
examples gave `TITLE-ABS-KEY(graphene supercapacitor)` as its search, which
'Scopus' reads as graphene AND supercapacitor, and their PRISMA-S paragraph
called that search complete at 138 records. In OpenAlex, the two words
unquoted match about a hundred times as many records as the phrase. The
demonstration plan now quotes the phrase, under the same field tag. The closest
'Scopus' form of the OpenAlex search,
`TITLE-ABS("graphene supercapacitor") AND DOCTYPE(ar)` with no field, was
considered and set aside. The examples also teach `field`, and no 'Scopus'
query would return the OpenAlex result set in any case. The search-record
demonstrations set the retrieval attributes by hand, each cell's reported total
being its count of bundled records. They therefore call those values
illustrative and say that the paragraph describes no search that was run. The
app's demo search record blanks the corpus's `query` column for the same
reason. The keywords-and-references article builds its offline shapes from the
corpus in view, as the Python guide does. It used to pair real calls on a real
DOI with invented keywords and four of the paper's 103 references, which is the
pairing of genuine identifiers with invented content rejected above.

The non-ASCII characters that survive in the data are deliberate. Accented and
Cyrillic author names and the en dashes in titles are part of real names and
real titles, so they are marked UTF-8 and left as they arrived. Transliterating
them would misspell published work. Only U+2010, a hyphen indistinguishable from
the ASCII one, is normalised, so a single visible character is not stored two
ways.

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
cursor in place of an offset, so a single large query can be harvested past the
5000-record ceiling that offset paging imposes. It is opt-in, since the records
then arrive in deep-paging order, which is the right trade for a complete
harvest and the wrong one for a top-of-results sample. `scopus_abstract()` adds
the Abstract Retrieval API, a second endpoint, so the abstract and fuller
metadata of a known record can be read. A batch is resilient, turning a per-id
failure into an `NA` row with a warning, which keeps the rest of the call. Both
are tested with `httr2` mocks and a key-gated live test, exactly as the Search
API is.

The analysis layer consumes objects already in hand: `scopus_top()` tallies
sources or authors from a record set in memory, and `scopus_trend()` counts a
query year by year through the API (the single-query companion to the topic
comparison). Each pairs with a plot, and an `autoplot()` method gives a record
set an honest default figure. The plots now share the internal
`scopus_minimal_theme()` described under *Visualisation* above.

### Pre-CRAN hardening of the 0.2.0 additions

A multi-agent adversarial review of the 0.2.0 code, with every finding
independently verified against the source, surfaced no blockers but a set of
edge-case robustness gaps that were closed before submission, since a defect is
far cheaper to fix before CRAN than after:

- `scopus_top()` now orders ties by `value` in byte order (`order(..., method =
  "radix")`), replacing the locale-dependent `sort(table())`, so which tied
  values survive the top-`n` cut is reproducible across platforms. It also
  rejects fractional and non-finite `n`, matching the package's other count
  validators.
- `scopus_trend()` warns when a year's response carries no total, which it used
  to record silently as `NA`.
- `scopus_abstract()` percent-encodes each identifier path segment while
  preserving the structural slashes a DOI needs, so a DOI containing reserved
  characters is not mis-parsed. It resolves the key once up front, so a missing
  key aborts at that point, where it used to degrade to a tibble of `NA` rows.
  A malformed `200` body is raised as a typed `scopus_error_malformed` (also in
  `scopus_search_page()`), so the batch degrades to an `NA` row where an untyped
  `jsonlite` error would have aborted it.
- Cursor paging gained a bounded backstop: it stops once the reported total is
  reached and, against a non-conforming server that never signals the end, after
  `getOption("scopusflow.max_cursor_pages", 1e5)` pages with a typed warning
  (set the option to `Inf` to disable), so an unbounded harvest cannot silently
  burn memory and quota.
- The plot functions guard empty `scopus_trend`/`scopus_top` inputs with a typed
  condition, in place of the opaque `sprintf` crash or silent blank chart they
  produced before.

### A local-first app

`run_app()` launches a Shiny front end so the workflow can be driven without
writing code, while a panel mirrors every choice back as a runnable script, so
driving the app teaches the package it drives. It is deliberately local-first,
bound to `127.0.0.1`: a hosted multi-user version would
conflict with Elsevier's API terms (which expect calls not to be proxied through
a server-side component) and with the institutional-IP entitlement model (calls
from a cloud IP get reduced access), and it would put third parties in custody of
users' keys. Running on the user's own machine sidesteps all three, and removes
any platform timeout on a long harvest.

The long retrieval runs in a background `callr::r_bg()` child whose `verbose`
`cli` output is written to a log file the server tails (a poll on
`invalidateLater`, rendered through `fansi`). Capturing it over a pipe was
rejected, since a pipe deadlocks once the OS buffer fills. The code mirror is
built from hand-rolled templates. `shinymeta` was rejected in turn, because the
expensive step runs across an async boundary it cannot see. The
reproducible-code, progress-parsing and ANSI-to-HTML helpers are factored into
`app-helpers.R` so they are unit-tested offline. The reactive layer around them
is not.

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

The app's checkpoints live in `tempdir()`, under a directory named by the
browser session's token, and a session's end removes that directory alone.
Every tab of one running app is a session of the same R process, so they share
`tempdir()`. The first design keyed checkpoints by search only, and its
end-of-session handler removed the shared root, so closing any tab deleted
every other tab's checkpoints mid-harvest. Keeping the checkpoints in the
managed cache, so that a later session could resume them, was rejected. Search
terms would then outlive the app, contrary to its promise that none linger on
disk, and the cache would be written without the user opting in. Resuming
therefore works within a tab, after Cancel or a failure, and a harvest that has
to outlast the session is the generated script's work. Naming checkpoints by a
hash of each cell's identity, which would let one directory hold many plans,
was deferred. It changes the cache layout of both twins and would force a
second refetch of every cache soon after 0.4.0's.

The script gives its plan a directory of its own under `scopus_cache_dir()`.
The name holds the query's words and the years, and ends in eight hexadecimal
digits of a hash over the query, field, view, partition and years. Pointing
every plan at the managed cache's root made one plan's cells overwrite
another's, since a cache directory serves one plan. The record cap is left out
of the hash on purpose. A checkpoint records whether a cap stopped it, so a
rerun without the cap refetches only the cells the cap cut short.

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
specific to that one field. Nothing in the parsing accounts for it, and the
root cause cannot be confirmed without a second, differently-entitled key.

`view = "FULL"` is the default for references over `view = "REF"`, the
opposite of what an older pybliometrics issue (`pybliometrics#81`) would
suggest. `"FULL"` returned a complete, correctly counted reference list in one
request for every document tried in live testing. `"REF"` is paged: the 40 of
103 references first seen on one call were the first page, which 0.4.0 took
for an inconsistency of the API because it never asked for a second. The
Abstract Retrieval WADL documents `startref` for the REF view, and
pybliometrics has paged REF since 3.6 (`_get_all_refs()` in its
`superclasses/base.py`), moving `startref` on by one page each time (41 after
a first page of 40) and naming no `refcount`, which its source says leads to
errors. Its live test retrieves 48 of 48 references that way.
`scopus_abstract()` now does the same, asking for startref = held + 1,
at a cost of `ceiling(N / 40)` requests for a document with *N* references,
each counted in `n_requests`. A request with `refcount = 200` was refused in a
live check on 2 October 2026.

The base of `startref` is not settled. The Scopus API Guide (V1, p. 52) says it
counts from 0, pybliometrics from 1, and the live check accepted both 0 and 1
without the follow-up that would tell them apart. The paging loop is therefore
built so that either reading, and a server that ignores `startref`
altogether, ends without looping or repeating references. It de-duplicates on
each reference's `@id`, or on its whole content when it carries none, and stops
on an empty page, on a page that adds no new reference, or after `ceiling(n / k)`
pages, k being the first page's length. A zero-based server would then leave
one reference out per later page, and the count check that compares the
references held with the document's reported total, kept as a backstop under
either view, warns about it. The base should be checked once against the live
API before release. A page that fails fails its identifier as a whole: a partial
bibliography is not checkpointed, and every page already requested counts.

REF checkpoints are keyed `REF-paged`, so the possibly truncated ones 0.4.0
wrote are refetched once and never served as complete, following 0.4.0's own
refetch of checkpoints it could no longer trust. REF also names a cited work's
title and source `title` and `sourcetitle`, where FULL uses `ref-title` and
`ref-sourcetitle`. pybliometrics reads either, and the R parser read only the
FULL names until the paging change, so both columns were always `NA` under
REF.

The `references` list-column carries a leaner, hand-picked field set
(`position`, `id`, `doi`, `title`, `authors`, `source`, `year`,
`citedbycount`). The raw API exposes a good deal more, but R has no equivalent
of pybliometrics' own parsing to lean on, and re-deriving its full,
implementation-specific field set (`authors_auid`, `authors_affiliationid`,
`type`, `text`, `fulltext`, and so on) was judged not worth the parsing
surface for what this package's own users are likely to need. The Python
twin, which already gets this for free from pybliometrics' `Reference`
namedtuple, exposes the fuller native shape, and the difference is documented in
both packages' equivalent function so that the divergence is not a silent one.

A 403 during `scopus_abstract()` now stops the whole batch, where every other
per-identifier failure degrades to an `NA` row and a warning. Entitlement is a
property of the account, so a 403 on the first identifier will recur on every
remaining one, and repeating an already-known failure serves nobody.
Implementing this exposed a `tryCatch()` hazard worth recording: a condition
raised *inside* one handler of a `tryCatch()` call can still be caught by a
sibling handler of that same call (verified directly), so the abort could not
simply be issued from within the `scopus_error_forbidden` handler alongside a
generic `scopus_error` handler in the same `tryCatch()`. It had to be deferred
to a sentinel checked immediately after the `tryCatch()` call returns, outside
any handler's dynamic scope. A related and easier-to-miss scoping pitfall is
that `<<-` inside a bare block passed as `tryCatch()`'s first argument still
skips that block's own environment, because a bare block is evaluated directly
in the caller's frame, where a closure would have had one of its own. A counter incremented
there needs a plain `<-`, even though the same counter does need `<<-` inside
the handler functions, which are real closures.

`scopus_corpus()` assembles `id`/`title`/`year`/`keywords`/`references` from
an existing `scopus_records` result plus one `scopus_abstract()` call, and so
repeats no part of the search, since a caller ordinarily already has records
in hand by the time keywords or references are wanted. It does not
replace `as_bibliometrix()`, which keeps its own established field-mapping
convention for bibliometrix users. The two are complementary exports for
different downstream tools, matching how `as_bibtex()`/`as_ris()` sit
alongside `as_bibliometrix()` already.

## Abstract Retrieval: the default view and collapsed lists

`scopus_abstract()` names `view = "META_ABS"` by default. Up to 0.4.0 it sent
no view. Elsevier documents the view served then as META (the Abstract
Retrieval WADL and the Scopus API Guide), and its views table lists the
abstract, `dc:description`, only under META_ABS and FULL. A live request on 2
October 2026 nonetheless returned the abstract without a view, so the old
default did not visibly fail for that key. The view is named all the same. The
`abstract` column should not rest on a server choice that the documentation
contradicts and that may differ by entitlement, and the Python twin has named
META_ABS since its first release. Keeping `NULL` as the default and
documenting the live finding was therefore rejected. `view = NULL` still sends
no view, and its checkpoints keep the `default` key, so a cache written by
0.4.0 still serves it.

Elsevier's XML-to-JSON conversion sends a one-item array as a bare object,
which `jsonlite` parses as a named list, so iterating over it walks the
object's fields. A lone reference in either view, or a lone author of a
reference, aborted the whole batch that way, and every resume of it, with an
untyped "subscript out of bounds" error. pybliometrics issue #326 shows the
API sending a lone reference like this. A lone author has no recorded
instance yet and is guarded the same way. `scopus_listify()` wraps any named
list that is not empty, and the parser passes it the references, their
authors, their item identifiers and the author keywords, so each list has one
shape to iterate. An empty object becomes an empty list, as an absent one
does, since wrapping it would add a reference or an author whose every field
is missing. The keyword parser used to wrap only an object carrying a known
field, a rule rejected here because an author-keyword object can carry its
attribute alone (`{"@_fa": "true"}`, pybliometrics issue #436). Left
unwrapped, that object was read field by field, giving the keyword "true".

Any other error while the keywords or references are parsed is re-raised as
`scopus_error_malformed`, with the original as its parent. The per-identifier
handler records an `NA` row with a warning and does not checkpoint it, as for
any failed retrieval. A resumed run therefore spends one request to retry the
identifier, which a corrected parser in a later release can then read, where a
checkpointed `NA` row would have hidden the document for good.

## Index keywords

`include = "index_terms"` reads the `FULL` view's `idxterms`, which the Scopus
API Guide (V1, p. 29) lists as not available by default, and which carried
terms on the development key when `authkeywords` came back empty (see the
0.2.0 section above). The column takes the response's own name, `idxterms`, as
`authkeywords` does, and sits between `authkeywords` and `references` in both
twins. The parser follows the author keywords' rule: `mainterm` passes through
`scopus_listify()`, and an entry without text is dropped. pybliometrics'
`idxterms` raises `KeyError` on such an entry, so the Python twin leaves that
document's index keywords `NA` with a warning, where R keeps the other terms.
Reading the response past pybliometrics to match R was rejected, since it would
rest on a private attribute.

`scopus_corpus()` gains `keywords` as its last argument, so a call that passes
`cache_dir` by position keeps working. The Python twin puts it after `resume`,
ahead of the arguments passed on to pybliometrics. `"both"` puts the author
keywords first and adds each index keyword not already among them, matching on
the exact text. Folding case was rejected even though index terms are
capitalised where author keywords often are not, since R's `tolower()` and
Python's `str.lower()` do not agree on every character, and the twins could
then return different lists.
The corpus asks `scopus_abstract()` only for the kinds of keyword it needs, so
a default corpus keeps its checkpoint names. Since the include set is part of
those names, switching an existing corpus to `"index"` or `"both"` spends one
request per identifier again.

## A corpus for theoryforge

theoryforge reads a literature corpus in its own schema
(`schema/corpus.schema.json` in its repository), and its documentation showed
how to convert a `scopus_corpus()` result by hand. That recipe keyed a cited
work on its DOI where there was one and on its 'Scopus' identifier otherwise.
'Scopus' gives a cited work's DOI in some bibliographies only, and in different
cases, so one work became several nodes. Two documents citing the
same two works gave theoryforge an empty co-citation map, where keying the
works on their identifiers gave one edge of count 2. `write_scopus_corpus()` and
`as_theoryforge_corpus()` (Python: `write_corpus()` and
`to_theoryforge_corpus()`) therefore key every work on its 'Scopus'
identifier. A map from DOI to identifier, built from every document and
reference in the corpus carrying both, lends an identifier to a work cited by
DOI alone. The documents' own pairs count first, since they come from the
document's own record. A DOI that nothing pairs with keys as `doi:<doi>`, with
its resolver prefix removed and its ASCII letters lower-cased, since DOI names
are case-insensitive over ASCII (DOI Handbook, section 2.4). Each document is
keyed the same way, so a citation of a document in the corpus meets the
document itself. To that end `scopus_corpus()` gains a `scopus_id` column,
from Abstract Retrieval and, where a lookup failed, from the records. The
writer reads a document's DOI from an `id` that has the shape of one, since the
corpus carries no DOI column of its own. For the same reason it writes no
record `doi`, which the schema leaves optional.

`id` is required. A corpus carries no plan or query to name it by, and a name
made up from its contents would change whenever they did.

Keywords are trimmed, lower-cased and made unique. The index-keyword choice
above rejected folding case because R's `tolower()` and Python's
`str.lower()` disagree on a few characters. The writer folds all the same,
with those two functions. theoryforge compares keywords as exact strings, so
an unfolded `"Graphene"` and `"graphene"` split a keyword theme. The corrected
recipe prepared for theoryforge's documentation also folds with the same
functions, so a corpus keeps its labels when a user moves from that recipe to
the writer. The two functions were compared on every code point from U+0041 to
U+024F and from U+0370 to U+052F (R 4.6.1 on Windows, Python 3.13). They
differed only on the Turkish capital I with a dot, and on a capital sigma
ending a word, which Python writes as a final sigma. The shared golden pins a
capital accented letter. An ASCII-only fold, which would agree everywhere, was rejected because
it leaves a capital accented letter, common in French and German keywords,
apart from its lower-case form.

The file is serialised for byte parity between the twins: sorted keys,
compact separators, UTF-8 without escaping and a closing line feed. jsonlite
and Python's `json` escape the same characters, quotation marks, backslashes
and control characters, and write the same short forms and lower-case `\u`
sequences, as a check with jsonlite 2.0.0 confirmed. R sorts keys with a radix
sort, which orders them by byte as Python orders them by code point. `I()`
keeps a one-element keyword or reference list an array under `auto_unbox`.

A `provenance` object records `source` (the package and its version),
`query`, `retrieved_at` and `keywords`, with three counts: the documents, the
references dropped for want of either identifier and the documents without
keywords. The last is there because an entitlement that returns no author
keywords empties theoryforge's keyword themes whatever the writer does.
theoryforge's schema admits the object beside its own fields. The schema's own
optional `source` object was not reused, since it records theoryforge's
OpenAlex fetch, with fields such as `per_page` and `sort` that a 'Scopus'
corpus has no value for. `query` is the field-wrapped
expression of each cell of the records' plan, as the search record states it.
The records' `query` column is no substitute where a plan exists, since the
Python twin writes each cell's year limit into it and R does not, and the twins
would record different strings. `retrieved_at` is when the search ran, the
records' own `retrieved_at`, since Abstract Retrieval checkpoints carry no
time.

The output is validated against a copy of theoryforge's schema in the test
fixtures, which records the theoryforge commit it was taken from in a
`$comment`. Python validates with jsonschema, a development dependency only.
R checks it with a small validator in the tests that covers the keywords the
schema uses, since `jsonvalidate` would add a JavaScript engine to Suggests
for one test. Neither validates at run time, which would make jsonschema a
dependency of the package. The golden replaces the running version in
`source` with `<version>`, so that a release leaves it alone.

## Concept and intersection sizing

`scopus_intersections()` and `plot_scopus_intersections()` size a named set of
concepts and their intersections, the magnitude snapshot that introduces where
a study or a niche sits within a wider literature. The pair stands apart from
`scopus_compare_topics()` because it answers a different question: the
comparison tracks topics' shares of a reference over time (one request per year
for the reference and one per term per year), whereas this counts each concept
and each requested intersection
once (one request per row), so a whole landscape costs a handful of count
requests. The pair was ported from a prototype developed and tested against the
live API in a real literature review, and two of its details are deliberate
enough to be worth recording.

First, a concept value that already reads as a complete field-tagged
expression (matched by `^[A-Z][A-Z-]*\(`) is used exactly as given, and `field`
leaves it alone. Passing an already-wrapped query through a
further field wrap produces a nested tag such as `TITLE-ABS-KEY(TITLE(x))`,
which the live API rejects as malformed with HTTP 400; the guard is what lets
one call mix bare terms with hand-built expressions. A related quota courtesy:
every row's label and query is assembled, and label collisions (for example an
`abbrev` that maps two concepts to one short form) rejected, before the first
request is sent, so no invalid call spends quota. Counts are kept as doubles,
consistent with `scopus_count()` and the overflow lesson recorded above.

Second, in the plot, each count label sits at `n * gap_mult`. On a log axis
only a constant ratio renders as a constant pixel gap, so the additive nudge
`n + constant` would hug the large counts and overshoot the small ones. The
ratio is in turn derived from the axis's own span
(`gap_mult <- 10^(gap_frac * log10(hi / lo))`, with `gap_frac` about 0.024,
some 2.4% of the panel width). A fixed constant tuned on one dataset was
observed to read well beside wide many-digit labels yet touch the point beside
single-digit ones once the span narrowed. The prototype's widened right margin
(28 pt) is kept as the companion to `clip = "off"`: on a very wide span the
largest count label can spill past the panel, and the default margin was
measured to clip its trailing digits. Rows counting zero cannot sit on a log
axis, so the plot drops them with a warning and a caption note while the object
keeps them, since an empty intersection is itself a finding. The axis breaks
come from a small internal helper (`scopus_log_breaks()`, powers of ten
interleaved with `3 * 10^k` on narrow spans), which spares Suggests the scales
package for a single call. The colours reuse the package palette, with the
comparison plot's accent marking the optional highlight.

## Checkpoint identity, and what a cache hit has to prove

A checkpoint used to be keyed on the plan cell's position alone, guarded only by
comparing the query recorded in the cached records. Under `partition = "year"`,
which is the arrangement the documentation recommends, every cell of a plan
carries the same field-wrapped query and the year travels separately as the
`date` request parameter, so that guard could never distinguish one year's
checkpoint from another's. Two plans over overlapping year spans pointed at one
directory therefore returned each other's years, silently.

The year is now part of the checkpoint's filename, and the rest of what shapes
a cell (query, view, page size, and the `max_results` it was fetched under) is
written as a manifest beside the records and compared on resume. Folding the
year into the recorded query, which is how the Python twin solves the same
problem in `_cell_query()`, was rejected here: this package sends the year as a
separate `date` parameter, so folding it in would have changed the requests made
and the `query` column every record carries, for no gain over naming the file
properly. The Python twin folds it for a reason of its own. pybliometrics
accepts `date` as a request parameter, but it keys its search cache on the
query string and view alone, an MD5 digest of the query filed under the view.
With the year sent as a parameter, one year's cached response would answer
another year's search. The Python twin now bypasses that cache by
default, sending `refresh=True` unless the caller opts back in, and the folded
year keeps that opt-in safe. The two engines therefore reach the same guarantee
by different routes, which is why the Python guide describes its checkpoint
identity in its own terms.

`max_results` had to enter the identity for the same reason. A cell fetched
under a cap was served unchanged to a later caller asking for everything, so a
capped exploratory run poisoned the full harvest that followed. The manifest
records whether the cap actually bit. One that never did leaves the checkpoint
usable for any later request, so the common case costs no extra quota.

A checkpoint without a manifest is served as before when the query in its
records matches the cell. An empty one is served too, since it has no query
values to contradict the cell. That branch is kept for files this package did
not write. The manifest is an attribute of the same `.rds` as the records, so
no interruption can separate the two. The 0.3.x checkpoints that predate it are
named `cell-NNN.rds`, without the year, so a resume never finds them. The
Python twin is in a different position. Its manifest is a separate file,
`cell-NNN.json` beside each checkpoint. Earlier releases had written
checkpoints under the same names without one, and their row-based guard served
an empty cell to any plan sharing the directory. That twin therefore refetches
a manifest-less empty checkpoint, at one request per cell and with one warning
for the harvest. R has no such checkpoints to refetch.

Checkpoints are written to a sibling temp file and renamed, since a rename
within one directory is atomic on POSIX and NTFS alike, and read through
`tryCatch()`. The interruptions this cache exists to survive are exactly what
leaves a half-written `.rds`, and before this a damaged checkpoint aborted every
subsequent resume with an untyped error that could only be cleared by finding
and deleting the file by hand.

A cache directory is checked before any request. It is created if need be,
and a file is created in it and removed again. A path that is a file, or a
directory the user cannot write, is thus refused as bad input with nothing
spent. Up to 0.4.0 such a directory cost a cell's requests and then lost its
records to an untyped error from `saveRDS()`. Creating a file is the test
because `?file.access` advises trying the operation itself, and the Python
twin cannot use `os.access`, which on Windows reports a directory that an ACL
denies as writable. A checkpoint that still cannot be written, on a full disk
or where a directory has taken its name, gives
`scopus_warning_cache_unwritable`, and the records are returned without it.

The `scopus_cache_clear()` example points `R_USER_CACHE_DIR` at a temporary
directory and restores the variable afterwards, whether or not it was set.
`example()`, `R CMD check` and pkgdown do not redirect `tools::R_user_dir()`,
so the example used to delete the managed cache of whoever ran it.
`\dontrun{}` was rejected, since CRAN asks for an example that can run to be
run.

## Paging a plan

Up to 0.4.0, a plan could only be paged by offset. A year cell matching more
than 5000 records therefore stopped at 5000, and both warnings advised
partitioning by year, which the plan already was. `scopus_fetch_plan()` now
takes `cursor`, an argument of the fetch and not a field of the plan, for three
reasons. `scopus_fetch()` already takes `cursor`, and the search record already
treats the mode as settled when the search is run. A plan field would also have
changed plan equality, both golden search records and the snippet round trip.
The default stays `FALSE`, so an existing script fetches what it fetched before
and its checkpoints stay valid. The Python twin keeps cursor paging as its
default for the same reason, and both defaults are documented.

The mode joins the checkpoint identity. A manifest written before it was
recorded, and a checkpoint without a manifest, count as offset, the only mode a
plan had. Serving either to a cursor request could hand back a cell cut short
at the ceiling. The audit also proposed setting `complete = FALSE` on an
offset cell stopped at the ceiling. That was dropped, because an offset refetch
stops at the same record and the mode in the identity already keeps such a
checkpoint from a cursor request. A checkpoint that differs from the request
in its mode alone was written by the same plan, and the warning for it names
both modes. It leaves out the advice to give each plan its own `cache_dir`,
which a caller switching modes on the capped warning's advice would otherwise
read in every cell. Inside a plan, the capped warning names
`scopus_fetch_plan(plan, cursor = TRUE)`. The shortfall warning keeps its
wording, which the Python twin shares word for word. The reproduction snippet
adds `cursor = TRUE` when the records say they were paged by cursor.

The Python twin used to send `cursor=True` to pybliometrics, which reads
`cursor` as an alias for `subscriber` and lets it win, so a caller's
`subscriber=False` was ignored and `cursor=False` raised a `TypeError`. It now
sends `subscriber`, the documented name, alone. Where this package stops an
offset-paged cell at 5000 records with a warning, pybliometrics refuses a search
above 5000 matches with `ScopusQueryError`, which that twin raises again with
the cell named.

## Extended record fields

Elsevier's Search views table lists, under both views, each record's document
type (`subtype` and `subtypeDescription`), source type, volume, issue, pages,
ISSN, PubMed identifier and open-access status, and under `COMPLETE` the
abstract (`dc:description`). Both twins used to discard all of them. A
reviewer could not drop errata, flag what 'Scopus' labels retracted or keep the
articles alone once the harvest was in. A `COMPLETE` harvest also threw away
the abstracts it had paid for, up to 25 with each request, where Abstract
Retrieval spends a request on each record from a separate quota. With
`fields = "extended"`, the records keep every one of these fields.

`fields` is an argument of `scopus_records()`, `scopus_fetch()` and
`scopus_fetch_plan()`, for the reasons that made `cursor` one (see *Paging a
plan*). It changes how the records are read while the search returns the same
records, and a plan field would have changed plan equality, both golden search
records and the snippet round trip. The default stays `"core"`, so an existing
script returns what it returned before, and the new columns follow the core ones
and `authkeywords`, so code that picks columns by position is unaffected. The
Python twin's `to_records()` and `fetch_plan()` take the same argument and build
the same columns, both held to `tests/testthat/fixtures/extended-entry.json`.
`test_pyb.py` also runs the Python copy of that fixture through pybliometrics'
own parser.

The ISSN is kept as text, since one such as `00368075` begins with zeros that a
number would lose. R reads every column of a CSV file as text before typing it,
so `read_scopus_records()` needed only to keep the extended columns, where it
used to drop them. The Python twin names them among the columns its CSV reader
must not infer. `open_access` is an integer in both twins, because pybliometrics
reads `openaccess` as one. Elsevier's Scopus APIs Getting Started Guide (2023,
section 17) illustrates the field with 0 for not open access, 1 for gold and 2
for green, so the column is documented as a status code. The audit planned a 0
or 1 flag, and those values contradict it. The legacy `openaccessFlag`, true
for gold and empty for other kinds of open access, is not read.

A checkpoint records its fields in its manifest. An extended checkpoint serves a
core request, the extra columns dropped from the served copy, which then holds
what a core fetch returns. A core checkpoint is a miss for an extended request.
A manifest that names no fields, and a checkpoint without a manifest, were
written when every checkpoint held the core columns, so they count as core and
go on serving core requests at no cost. The Python twin decides by the
checkpoint's columns, since its manifest is a separate file that an earlier
version can leave beside a replaced checkpoint. It records the fields in the
manifest as well.

`summary()` counts the document types and says how many records 'Scopus' labels
errata (`er`) or retracted (`tb`). Elsevier's search tips list the `DOCTYPE()`
codes without `tb`, although retraction studies search with it. Sharma and
Khurana (2025, arXiv:2502.00673), for example, retrieved 33,188 records of
document type Retracted with `DOCTYPE(tb)`. The 'Scopus' Content Coverage Guide
(2023, section 3.1) defines both types. An erratum reports an error, correction
or retraction of an earlier paper, so retraction notices are errata too, and an
article becomes Retracted once a retraction notice for it is published. The
counts are worded as labels, never as a retraction screen. Ortega and
Delgado-Quirós (2024, Scientometrics, 129(7), 3769-3785) attribute part of
OpenAlex's wider coverage of retracted literature to inaccurate labelling in
'Scopus', and the documentation points to the Retraction Watch database, which
Crossref distributes openly.

One difference between the twins remains. pybliometrics converts HTML
character references in `dc:title`, `dc:description` and `authkeywords` to the
characters they stand for, and R keeps the text as the API sends it. The shared
fixture holds none, so the twins agree on it, and the abstract shares the edge
the titles already had.

## Typed exports and the bibliometrix frame

With the extended fields, the exporters type each record by its 'Scopus' code.
A conference paper (`cp`) becomes an RIS `CPAPER` and a BibTeX
`@inproceedings`, a chapter (`ch`) `CHAP` and `@incollection`, and a book
(`bk`) `BOOK` and `@book`. Everything else stays `JOUR` and `@article`, so a
set retrieved with the core fields exports exactly as before, as the
six-record golden still shows. A conference review (`cr`) becomes `CONF` in
RIS, and `@inproceedings` in BibTeX, where it is an item in the proceedings.
Zotero's RIS import reads `CONF` as a conference paper too. `@proceedings`
was set aside, since it describes a whole volume with editors and no authors.

Where the source goes was checked against Zotero's RIS translator. It reads
`T2` as the publication title of a journal article, the book title of a
chapter, the conference name of a conference paper and the series of a book.
'Scopus' gives a book in a book series the series as its source, and a book
outside a series itself. Such a book therefore has no `T2`, since one would
have filed its own title as its series. BibTeX gives the source of a book
under `series` only when 'Scopus' calls the source a book series. A conference
paper keeps `T2`, as Elsevier's own RIS export writes it, although Zotero then
reads the proceedings title as the conference name. `C3`, Zotero's tag for the
proceedings title, was not adopted, because other readers and 'Scopus' itself
use `T2`. `SN` carries the ISSN for every type. RIS defines it as an ISSN or
ISBN, and Zotero files it as an ISBN outside journal articles.

The author keywords come in two forms. The Search API's `COMPLETE` view joins
them with `" | "`, and `scopus_abstract()` joins its own with `"; "`. One rule
splits at either, so keywords from both endpoints export alike. RIS gives one
`KW` line per keyword, and BibTeX joins them with commas, the separator biblatex
reads. A keyword containing a comma or a semicolon is then split, as Zotero and
bibliometrix would split it. The pages split at a single hyphen into `SP` and
`EP`, and BibTeX writes the range with `--`. A page that is no range, such as
an article number, stays whole. The typed exports are pinned by a second
hand-written golden, `export-fixture-typed`, shared by both suites, so that
the six-record golden goes on pinning a core export.

`as_bibliometrix()` was checked against `bibliometrix::convert2df()` (version
5.4.1) reading a 'Scopus' CSV export of the same records. That function strips
full stops and commas from each author and joins the authors with `";"`. It
upper-cases every field and takes `UT` from the EID and `DE` from the author
keywords, joined in the CSV with `"; "`. The frame now matches it tag for
tag on those records, the one difference being that a missing value is `NA`
where `convert2df()` writes an empty string. The audit proposed `";"` between
keywords. `"; "` is kept, since that is what `convert2df()` produces. A
`COMPLETE` name such as `"Tour, James M."` would lose its comma to the same
rule and read `"TOUR JAMES M"`, bibliometrix's full-name form, so the given
names are reduced to their initials first. The audit suggested building `AU`
from the author objects' indexed `authname`, which the records do not keep.
Reducing the given names gives the same string except where 'Scopus'
abbreviates a given name to two letters, as in `Yu.`.

## Dating a retrieval

`citations` is a snapshot value that moves continuously, and the
change-tracking workflow rests on diffing two pulls, so a saved set that cannot
say when it was taken cannot honestly be compared with another. Retrievals now
carry `retrieved_at` and `scopusflow_version`. Both are attributes, so the
documented schema and the CSV round-trip are untouched, at the cost of `.csv`
not preserving them. A combined harvest takes the earliest of
its cells' times, since a combined set is only as fresh as its oldest cell, and
lists every version that contributed, since resuming an older cache means more
than one did. The bundled `example_records` deliberately carries neither, so
that the round-trip identity shown in the documentation stays deterministic.

The earliest time alone cannot date a search for a methods section, though.
PRISMA-S item 13 asks for the date when the last search occurred, and its
explanation asks for the time frame over which the searches ran (Rethlefsen et
al., 2021). A harvest resumed a week later, or a baseline merged with its update
a year on, was dated by its first cell, so the record never named the last
search. Retrievals therefore also carry `retrieved_until`. For a single search,
it is the same time as `retrieved_at`. For a combined set, it is the latest of
its parts' times, and a part written before the attribute existed counts by its
one stamp. Both are claimed only when every part carries a time, as the
earliest always was. `retrieved_at` keeps the earliest, so a set is still read
as only as fresh as its oldest cell. The search record dates such a set from
the first time to the last, and item 13 gives the last. Stamps that fall on one
UTC day give one date, as a single stamp always has, so the record of a one-day
harvest did not change. The Python twin's `scopus_combine()` carries both times
by the same rule, so a merged set reads alike in both twins, as the shared
golden file `tests/testthat/golden-search-record-merged.txt` pins.

## Writing up a search: the honesty contract

`scopus_search_report()` assembles the search-strategy record a systematic
review has to report, following PRISMA-S (Rethlefsen et al., 2021, Systematic
Reviews, 10, 39) and the identification counts of the PRISMA 2020 flow diagram.
The output is destined for a published methods section, which decides the whole
design: the report may state only what the objects in front of it record.
Nothing is inferred from the running session. `Sys.time()` never stands in for
an absent `retrieved_at`; the reported total is read from what the API said,
never inferred from the row count, and is claimed overall only when every cell
reported one; duplicates are counted only where `scopus_combine()` recorded
removing them; and a PRISMA-S item is listed as supplied only where the evidence
exists, which leaves nine of the sixteen (peer review, grey literature, citation
searching and the rest) explicitly the author's. A plausible figure nobody can
check would be worse than an admitted gap, so every unverifiable field says it
is unrecorded, in words.

Three additions were needed to make that possible, and each is useful in its own
right. `scopus_fetch_plan()` now carries per-cell accounting (`cell_totals`) and
warns on a cell that came back shorter than the API said it should, which closes
a parity gap: the Python twin has warned on a shortfall since 0.3.0 and the
warning text is byte-identical between them. `scopus_combine()` records `n_in`,
`n_out`, `n_removed` and `deduplicated`, a count that exists only at the moment
of the merge. Retrievals also record `paging`, since an offset-paged query stops
at the API's ceiling where a cursor-paged one does not, and the record has to
say which was used.

The rendering is held byte-identical against the Python twin's, pinned by
`tests/testthat/golden-search-record.txt` and its copy in the Python repo, and
for a merged set by `golden-search-record-merged.txt` beside it. The
reproduction snippet is the one part that cannot be shared, being code in the
host language; both suites evaluate the snippet they emit over a grid of plans
and assert it rebuilds an identical plan, which is the executable form of the
report's central claim.

The same honesty rule settles four further details. Without a plan, the year
limit is unrecorded, not absent, since this package sends the year as the
request's `date` parameter, which the records never see. The cell then reads
"year limit unrecorded", and item 8 stays with the author, since the expression
is recorded but the field tag and limits it was sent with are not.
`scopus_fetch()` therefore attaches the one-cell plan it ran, and a one-cell
plan takes the set's own counts, since it stands for the one search they come
from. Years are read back from the cells' limits, and year cells with gaps
between them are listed ("2015, 2020 and 2025"), because a span over the gaps
would claim years no cell searched. Within such a list, a run of three or more
years is still written as a span, so that a decade is not spelled out year by
year. Item 2 asks for the databases searched together on one platform, as Ovid
searches several at once. Scopus is searched on its own, so the record supplies
the item, as it supplies the platform for item 1. Any other database a review
searched is the author's to name under item 1.

Two ways of retrieving less than the search matched are recorded on the set,
so the record can say why it holds fewer records. `scopus_attach_provenance()`
keeps a finite `max_results` as an attribute, for `scopus_fetch()` and for
every cell alike. `scopus_fetch_plan()` carries the one cap of its call, since
a checkpoint written under a wider cap is served trimmed to it. No cap leaves
no attribute, so existing sets and the first golden file are unchanged. A cell
stopped at the cap is one holding as many records as the cap allowed where the
API reported more or nothing. The completeness line puts the whole shortfall
down to the cap only when every cell that fell short stopped at it. Otherwise,
it counts the cells that did, so a shortfall the cap does not explain stays
visible. Item 9 names the cap, or says it did not bind, because PRISMA-S asks
for every limit, and the snippet passes it. `autoplot()` captions a set whose
cap bound, since its bars then count the cap.

The Python twin's `fetch_plan()` can stop between cells through `should_stop`,
set by its app's Cancel, and it records `stopped_early`, `cells_planned` and
`cells_run`. Its record joins the cells that ran onto the plan, marks the rest
"not run", gives the years searched beside the years planned and calls the
harvest incomplete. A plan passed by hand that is not the one the harvest ran,
with a different number of cells or cells the harvest never had, keeps the
cells unrecorded as before. This package has no partial-return path, since the
app cancels by killing its background worker, and that twin's `fetch_plan()`
takes no cap. Each branch is ported to the other twin all the same, dormant
there, so that the two renderers stay one function, held to the shared golden
files `golden-search-record-capped.txt` and `golden-search-record-stopped.txt`.
Two simpler options were rejected. A Python-only wording for the stop would
have split the renderers, and a cap recorded only in `cell_totals` would have
missed `scopus_fetch()`, whose set has no cells to record it in. The app's cap
field defaulted to 200 records per year, so every live harvest was capped
unless the user cleared it. It now starts blank, and a harvest is capped only
on request. The Python app has no cap field and never caps one. A blank field
risks no unbounded spend, since offset paging stops a cell at 5000 records, 25
requests under `STANDARD` and 200 under `COMPLETE`.

## De-duplication: which records are one record

`scopus_combine()` keyed a record on its 'Scopus' identifier and, failing that,
on its DOI lower-cased. An unidentified record therefore never matched the
identified record carrying its DOI, and `https://doi.org/10.5555/X` never
matched `10.5555/x`. Both cases arise when a harvest is merged with a set from
another source, a hand-edited CSV or the bundled corpus, which carries no
identifiers. The API itself returns bare DOIs and an identifier on every record.

Merging every pair of records that share a DOI was rejected as the default.
'Scopus' holds duplicate records of one paper under different identifiers
(Valderrama-Zurián et al., 2015, Journal of Informetrics, 9(3), 570–576), but
it also gives one DOI to distinct papers (Franceschini, Maisano and
Mastrogiacomo, 2015, Scientometrics, 102(3), 2181–2186). The two errors cost a
review different amounts. A surviving duplicate is caught at screening, while a
wrongly removed record is lost without trace. The default rule therefore links
records that share an identifier, and an unidentified record to the one
identifier that carries its cleaned DOI. Records with different identifiers
stay apart. The DOIs they share are counted in the `combined` attribute as
`doi_conflicts`, and item 16 of the search record gives the count so that the
reviewer can check them. An unidentified record whose DOI two identifiers carry
cannot be assigned to either, and is kept once under the DOI.
`dedupe = "id_or_doi"` takes connected components over both keys, for a set
whose shared DOIs have been checked. `"id_then_doi"` keeps the 0.4.0 key
unchanged, so that an earlier set can be reproduced, and a set that records no
rule, having been merged by 0.4.0, keeps the 0.4.0 wording in item 16.

DOIs are cleaned as `scopus_extract_dois()` cleans them, by
`scopus_tidy_dois()`, the element-wise form of `scopus_clean_dois()`. Under the
two new rules a blank identifier counts as none, because `read.csv()` reads an
empty field of a character column as `""`. The Python twin computes the same group keys, and both
suites assert the same kept rows and the same item 16 wording on the
byte-identical fixture `dedupe-fixture.csv`.

## Change tracking: what a diff can and cannot compare

`scopus_diff_dois()` compares DOIs alone, so a record without one dropped out
of its rows without a trace, 11 of the 138 records in the bundled corpus.
'Scopus' gives no DOI to a share of what it indexes, more of it in the arts
and humanities and among books and proceedings (Gorraiz et al., 2016, Journal
of Informetrics, 10(1), 98–109). The diff now counts those records on each
side, in the attributes `n_old_without_doi` and `n_new_without_doi`, and its
printed line names them. It orders its rows with `method = "radix"`, as
`scopus_top()` already did, since the default order followed the locale's
collation and the Python twin compares code points. testthat runs every test
under the C collation, which is why no test had caught the difference, and the
order tests now set an English collation explicitly.

Adding `by = "scopus_id"` to `scopus_diff_dois()` was rejected. It would have
returned identifiers from a function and in a column named for DOIs. The new
`scopus_diff_records()` compares records under the default rule of
`scopus_combine()`, applied across the two pulls, so a diff and a merge of the
same two sets agree on which records are one. A record found in one pull only
whose DOI the other pull gives to a different record is a `conflict`. It may
have been re-indexed under a new identifier or may be a distinct paper sharing
the DOI, and counting it as added or removed would claim more than the records
show. Records sharing a DOI within one pull are not in conflict, since nothing
in the other pull makes their status uncertain. The identifier reported is the
one in the group key, so a record matched through a copy without an
identifier keeps its identifier. The other values come from the later pull
where it gives them, since a later record carries 'Scopus' corrections.

Two further additions were deferred. One is a helper that re-runs a saved
plan and attaches the previous provenance and the diff, which would let the
search record supply PRISMA-S item 12. The other is an opt-in fallback that
matches records on title and year. Both twins assert the same rows and counts
on the byte-identical fixture `diff-fixture.csv`.

## Tested version floors

`R (>= 4.1.0)` was an untested claim: the check matrix reached only `oldrel-1`,
around four minor versions above it. It now also runs `oldrel-2` and `oldrel-3`,
which reaches roughly R 4.3. The remaining gap between R 4.1 and R 4.3 is still
untested, and closing it means either pinning an explicit old R in the matrix,
where current CRAN builds of the dependencies may not be installable, or raising
the declared floor. That is a release decision and is left open deliberately.

The package floors are now exercised by a `min-deps` job that installs
`httr2@1.0.4` and runs the check against it. Only httr2 is pinned: it is the
dependency whose API this package leans on hardest, and pinning it alone avoids
dragging the rest of the library backwards and failing the job for reasons that
have nothing to do with scopusflow. The declared `rlang (>= 1.0.0)` was
corrected to `1.1.0`, which is not a narrowing: httr2 declares
`rlang (>= 1.1.0)` itself, from 1.0.0 on, so no installation satisfying the
httr2 floor could ever have used rlang 1.0.0. The job asserts the versions it
ended up with, since a pin that silently failed would leave the check passing
against the current releases and proving nothing.

The httr2 floor was 1.0.0 until the development version after 0.4.0, when it
rose to 1.0.4. That release introduced `req_retry(retry_on_failure = )` and
stopped retrying transport failures, such as a timeout or a reset connection,
unless it is `TRUE` (httr2's NEWS for 1.0.4). Under every later httr2, one
such failure therefore aborted a harvest, while the job pinned to 1.0.0, which
still retried them, stayed green. `scopus_req_retry()` now passes
`retry_on_failure = TRUE`, and passing it to httr2 1.0.0 to 1.0.3 is an
unused-argument error, hence the new floor. Checking `formals()` for the
argument would have kept the old floor but left it exercising different retry
behaviour from current releases.

The new floor brought one more difference into range. httr2 1.0.4 to 1.0.7
reject `req_retry(max_tries = 1)` as an invalid argument, while 1.1.0 and later
read it as a request not to retry (httr2's NEWS for 1.1.0). The
`scopusflow.max_tries` option was passed straight through, so a single try
failed every request under those four releases, and the `min-deps` job caught
it in the test that sets the option to 1. `scopus_req_retry()` now attaches no
retry policy for a single try, and httr2 performs a request without one exactly
once in every release from the floor on. Raising the floor to 1.1.0 was the
alternative, and was rejected because nothing else in the package needs that
release.

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
