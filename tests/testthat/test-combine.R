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
  expect_equal(attr(merged, "retrieved_at"),
               as.POSIXct("2026-07-22 09:15:00", tz = "UTC"))
  expect_equal(attr(merged, "scopusflow_version"), "0.3.0")

  report <- scopus_search_report(merged)
  expect_true(is.na(report$reported_total))
  expect_true(grepl("cannot be shown to be complete",
                    format(report, style = "paragraph"), fixed = TRUE))
  expect_true(grepl("Records identified from Scopus: 276",
                    format(report, style = "report"), fixed = TRUE))
})
