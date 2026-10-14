test_that("scopus_combine binds and renumbers entries", {
  a <- example_records
  b <- example_records
  out <- scopus_combine(a, b)
  expect_s3_class(out, "scopus_records")
  expect_equal(nrow(out), 276L)
  expect_equal(out$entry_number, 1:276)
})

test_that("scopus_combine de-duplicates by id then DOI", {
  out <- scopus_combine(example_records, example_records, dedupe = TRUE)
  # The bundled records carry no 'Scopus' id, so de-duplication falls back to
  # the DOI: the 127 records that have one collapse to a single copy each, and
  # the 11 that have neither key are all kept, as documented below.
  expect_equal(nrow(out), 149L)
  expect_equal(out$entry_number, 1:149)
})

test_that("scopus_combine accepts a single list and rejects non-records", {
  out <- scopus_combine(list(example_records, example_records))
  expect_equal(nrow(out), 276L)
  expect_error(scopus_combine(data.frame(a = 1)), class = "scopus_error_bad_input")
})

test_that("c() method combines record sets", {
  out <- c(example_records, example_records)
  expect_s3_class(out, "scopus_records")
  expect_equal(nrow(out), 276L)
})

test_that("dedupe keeps records that have neither an id nor a DOI", {
  r <- scopus_records(list(entry = list(
    list(`dc:title` = "A"), list(`dc:title` = "B")
  )))
  out <- scopus_combine(r, r, dedupe = TRUE)
  expect_equal(nrow(out), 4L) # no keys, so nothing is treated as a duplicate
})

test_that("dedupe falls back to the DOI (case-insensitively) when the id is absent", {
  r1 <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/x"))))
  r2 <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/X"))))
  out <- scopus_combine(r1, r2, dedupe = TRUE)
  expect_equal(nrow(out), 1L)
})

test_that("coercion strips the scopus_records class", {
  tb <- tibble::as_tibble(example_records)
  expect_false(inherits(tb, "scopus_records"))
  expect_s3_class(tb, "tbl_df")
  df <- as.data.frame(example_records)
  expect_false(inherits(df, "scopus_records"))
  expect_true(is.data.frame(df))
})

test_that("scopus_combine records what went in and what was removed", {
  # The count only exists at the moment of the merge, and PRISMA-S asks for it
  # (item 16), so a report has to be able to read it back.
  merged <- scopus_combine(example_records, example_records, dedupe = TRUE)
  recorded <- attr(merged, "combined")
  expect_equal(recorded$n_in, 276L)
  expect_equal(recorded$n_out, 149L)
  expect_equal(recorded$n_removed, 127L)
  expect_true(recorded$deduplicated)

  # Without de-duplication the merge is still recorded, so a report can tell
  # "no duplicates were removed" from "nobody looked".
  plain <- attr(scopus_combine(example_records, example_records), "combined")
  expect_equal(plain$n_in, 276L)
  expect_equal(plain$n_removed, 0L)
  expect_false(plain$deduplicated)
})

test_that("a merge carries no attribute describing a single retrieval", {
  # rbind() keeps the attributes of its first argument, so a merged set used to
  # inherit one harvest's plan, cell accounting and reported total, and the
  # search record then called the union of two harvests complete against a
  # figure belonging to one of them.
  harvest <- function() {
    r <- example_records
    attr(r, "plan") <- scopus_plan("g", years = 2015:2016, partition = "year")
    attr(r, "total_results") <- 138
    attr(r, "cell_totals") <- tibble::tibble(
      cell = 1:2, date = c("2015", "2016"),
      n_records = c(69L, 69L), reported_total = c(69, 69)
    )
    attr(r, "retrieved_at") <- as.POSIXct("2026-07-22 09:15:00", tz = "UTC")
    attr(r, "scopusflow_version") <- "0.3.0"
    r
  }
  merged <- scopus_combine(harvest(), harvest(), dedupe = TRUE)
  expect_null(attr(merged, "plan"))
  expect_null(attr(merged, "total_results"))
  expect_null(attr(merged, "cell_totals"))

  # The provenance a merge does not invalidate stays, as it does for plan cells.
  # Inputs that record one time each give it as both the earliest and the
  # latest.
  expect_equal(attr(merged, "retrieved_at"),
               as.POSIXct("2026-07-22 09:15:00", tz = "UTC"))
  expect_equal(attr(merged, "retrieved_until"),
               as.POSIXct("2026-07-22 09:15:00", tz = "UTC"))
  expect_equal(attr(merged, "scopusflow_version"), "0.3.0")

  report <- scopus_search_report(merged)
  expect_true(is.na(report$reported_total))
  expect_true(grepl("cannot be shown to be complete",
                    format(report, style = "paragraph"), fixed = TRUE))
  expect_true(grepl("Records identified from Scopus: 276",
                    format(report, style = "report"), fixed = TRUE))
})

# A harvest whose records carry 'Scopus' identifiers (rows 1 to 3) and a set
# from another source that carries none (rows 4 to 10), with its DOIs spelled
# as other sources spell them. The file is byte-identical to the Python twin's
# tests/fixtures/dedupe-fixture.csv, whose suite asserts the same results.
dedupe_fixture <- function() {
  fx <- read_scopus_records(test_path("fixtures", "dedupe-fixture.csv"))
  list(harvest = fx[1:3, ], other = fx[4:10, ])
}

test_that("an unidentified record joins the identified record with its DOI, however spelled", {
  # 0.4.0 keyed an unidentified record on its DOI, lower-cased only, so the
  # prefixed and upper-case copies of 10.5555/abc.1 survived beside the
  # harvest's record of it.
  fx <- dedupe_fixture()
  out <- scopus_combine(fx$harvest, fx$other, dedupe = TRUE)
  expect_identical(out$title, c(
    "First record under a shared DOI", "Second record under the shared DOI",
    "An article in the harvest", "An unidentified copy under the shared DOI",
    "An article no harvest holds", "A record with no key",
    "Another record with no key"
  ))
  expect_identical(out$entry_number, 1:7)
  abc <- out[grepl("abc.1", tolower(out$doi), fixed = TRUE), ]
  expect_identical(abc$scopus_id, "85000000333")

  recorded <- attr(out, "combined")
  expect_identical(recorded$n_removed, 3L)
  expect_identical(recorded$rule, "id_or_shared_doi")
  expect_identical(attr(scopus_combine(fx$harvest, fx$other, dedupe = "id_or_shared_doi"),
                        "combined"), recorded)
})

test_that("records with different identifiers and one DOI are kept and counted", {
  # 'Scopus' holds duplicate records under different identifiers, and it also
  # gives one DOI to distinct papers, so neither record is dropped by default.
  # The unidentified copy of that DOI cannot be assigned to either and is kept
  # once, apart from both.
  fx <- dedupe_fixture()
  out <- scopus_combine(fx$harvest, fx$other, dedupe = TRUE)
  expect_identical(sum(tolower(out$doi) == "10.5555/same", na.rm = TRUE), 2L)
  expect_identical(attr(out, "combined")$doi_conflicts, 1L)
})

test_that('dedupe = "id_or_doi" merges records with different identifiers under one DOI', {
  fx <- dedupe_fixture()
  out <- scopus_combine(fx$harvest, fx$other, dedupe = "id_or_doi")
  expect_identical(out$title, c(
    "First record under a shared DOI", "An article in the harvest",
    "An article no harvest holds", "A record with no key",
    "Another record with no key"
  ))
  recorded <- attr(out, "combined")
  expect_identical(recorded$rule, "id_or_doi")
  expect_identical(recorded$doi_conflicts, 1L)
  expect_identical(recorded$n_removed, 5L)
})

test_that('dedupe = "id_then_doi" reproduces the 0.4.0 rule', {
  out <- scopus_combine(example_records, example_records, dedupe = "id_then_doi")
  expect_identical(nrow(out), 149L)
  expect_identical(attr(out, "combined")$rule, "id_then_doi")

  # The 0.4.0 rule compares DOIs lower-cased but not cleaned, so a resolver
  # prefix keeps two copies apart that the default rule merges.
  r1 <- scopus_records(list(entry = list(list(`prism:doi` = "https://doi.org/10.1/X"))))
  r2 <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/x"))))
  expect_identical(nrow(scopus_combine(r1, r2, dedupe = "id_then_doi")), 2L)
  expect_identical(nrow(scopus_combine(r1, r2, dedupe = TRUE)), 1L)
})

test_that("every rule merges empty sets to an empty set", {
  empty <- example_records[0, ]
  for (rule in c("id_or_shared_doi", "id_or_doi", "id_then_doi")) {
    out <- scopus_combine(empty, empty, dedupe = rule)
    expect_identical(nrow(out), 0L)
    expect_identical(attr(out, "combined")$doi_conflicts, 0L)
  }
})

test_that("a merge without de-duplication records no rule", {
  plain <- attr(scopus_combine(example_records, example_records), "combined")
  expect_identical(plain$rule, NA_character_)
  expect_identical(plain$doi_conflicts, NA_integer_)
})

test_that("dedupe refuses anything but TRUE, FALSE or the name of a rule", {
  r <- example_records[1:2, ]
  for (bad in list("both", NA, c(TRUE, FALSE), 1)) {
    expect_error(scopus_combine(r, r, dedupe = bad), class = "scopus_error_bad_input")
  }
  expect_error(
    scopus_combine(r, r, dedupe = "both"),
    '`dedupe` must be TRUE, FALSE, "id_or_shared_doi", "id_or_doi" or "id_then_doi".',
    fixed = TRUE
  )
})

test_that("the search record's item 16 names the rule the merge used", {
  # The wording is asserted word for word in the Python suite too.
  fx <- dedupe_fixture()
  note <- function(x) scopus_search_report(x)$prisma$note[16]

  merged <- scopus_combine(fx$harvest, fx$other, dedupe = TRUE)
  expect_identical(note(merged), paste(
    "3 duplicate records removed by scopus_combine() from 10 combined,",
    "matched on a shared Scopus identifier, or on a shared DOI where one",
    "record lacks an identifier. Records with different Scopus identifiers",
    "that share a DOI were kept, which leaves 1 DOI to check by hand."
  ))
  expect_identical(note(scopus_combine(fx$harvest, fx$other, dedupe = "id_or_doi")), paste(
    "5 duplicate records removed by scopus_combine() from 10 combined,",
    "matched on a shared Scopus identifier or a shared DOI, even where the",
    "identifiers differ. Records with different Scopus identifiers were",
    "merged under 1 shared DOI."
  ))
  expect_identical(
    note(scopus_combine(example_records, example_records, dedupe = "id_then_doi")),
    paste("127 duplicate records removed by scopus_combine() from 276 combined,",
          "matched on the Scopus identifier and failing that the DOI.")
  )

  # A set merged by 0.4.0 records no rule, and keeps the wording it had.
  attr(merged, "combined") <- list(n_in = 10L, n_out = 7L, n_removed = 3L,
                                   deduplicated = TRUE)
  expect_identical(note(merged), paste(
    "3 duplicate records removed by scopus_combine() from 10 combined,",
    "matched on the Scopus identifier and failing that the DOI."
  ))
})
