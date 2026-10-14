test_that("the record diff matches on identifiers and, failing them, on DOIs", {
  # The Python suite asserts the same rows, values and counts on the same
  # fixture. The record re-indexed under a new identifier is a conflict on
  # both sides, the record without a DOI is matched on its identifier, and the
  # records without an identifier join the identified records carrying their
  # DOIs, however the DOIs are spelled.
  fx <- diff_fixture()
  d <- scopus_diff_records(fx$old, fx$new)
  expect_s3_class(d, "scopus_record_diff")
  expect_named(d, c("status", "scopus_id", "doi", "title", "year",
                    "citations_old", "citations_new"))
  expect_identical(levels(d$status), c("added", "removed", "conflict", "unchanged"))
  expect_identical(as.character(d$status), rep(
    c("added", "removed", "conflict", "unchanged"), c(2L, 1L, 2L, 4L)
  ))
  expect_identical(d$scopus_id, c(
    "85000000008", NA, "85000000002", "85000000003", "85000000033",
    "85000000005", "85000000006", "85000000001", "85000000004"
  ))
  expect_identical(d$doi, c(
    "10.5555/new.8", "10.5555/new.9", "10.5555/gone.2", "10.5555/MOVED",
    "10.5555/moved", "10.5555/JOINED.5", "10.5555/SIX.6", "10.5555/kept.1", NA
  ))
  expect_identical(d$title[c(2L, 7L)], c(
    "A new record from another source",
    "A record the later pull holds without an identifier"
  ))
  expect_identical(d$year, c(2022L, 2022L, 2020L, 2021L, 2021L, 2021L, 2019L,
                             2020L, 2021L))
  expect_identical(d$citations_old, c(NA, NA, 3L, 8L, NA, 2L, 7L, 5L, 1L))
  expect_identical(d$citations_new, c(0L, NA, NA, NA, 10L, 6L, 11L, 9L, 4L))
  expect_identical(attr(d, "n_old_without_id_or_doi"), 1L)
  expect_identical(attr(d, "n_new_without_id_or_doi"), 1L)
})

test_that("the record diff prints its counts and what it could not compare", {
  fx <- diff_fixture()
  expect_match(printed(scopus_diff_records(fx$old, fx$new)),
               paste("2 added, 1 removed, 2 in conflict, 4 unchanged, 1",
                     "earlier and 1 later records without an identifier",
                     "or a DOI not compared"), fixed = TRUE)
  complete <- scopus_diff_records(fx$old[1:2, ], fx$new[1, ])
  expect_no_match(printed(complete), "not compared", fixed = TRUE)
})

test_that("a record is in conflict only where the other pull gives its DOI to another record", {
  # Two distinct records sharing a DOI in both pulls are each matched on their
  # identifier and unchanged. A third record under that DOI, new to the later
  # pull, may be either of them re-indexed or a third paper.
  old <- data.frame(scopus_id = c("1", "2"), doi = c("10.5555/x", "10.5555/X"))
  new <- data.frame(scopus_id = c("1", "2", "3"),
                    doi = c("10.5555/x", "10.5555/X", "10.5555/x"))
  d <- scopus_diff_records(old, new)
  expect_identical(as.character(d$status), c("conflict", "unchanged", "unchanged"))
  expect_identical(d$scopus_id, c("3", "2", "1"))

  # A record without an identifier whose DOI two identified records carry
  # cannot be assigned to either, so all three are in conflict.
  unassigned <- scopus_diff_records(
    data.frame(scopus_id = c("1", "2"), doi = c("10.5555/x", "10.5555/x")),
    data.frame(scopus_id = NA_character_, doi = "10.5555/x")
  )
  expect_identical(as.character(unassigned$status), rep("conflict", 3L))

  # Records that share a DOI within one pull alone are not in conflict.
  added <- scopus_diff_records(
    data.frame(scopus_id = "1", doi = "10.5555/a"),
    data.frame(scopus_id = c("1", "2", "3"),
               doi = c("10.5555/a", "10.5555/b", "10.5555/b"))
  )
  expect_identical(as.character(added$status), c("added", "added", "unchanged"))
})

test_that("the record diff gives the bundled corpus the DOI diff's counts", {
  # The corpus carries no identifiers, so every record is matched on its DOI
  # and the eleven without one cannot be compared.
  baseline <- example_records[example_records$year <= 2023, ]
  later <- example_records[-1, ]
  d <- scopus_diff_records(baseline, later)
  expect_identical(as.vector(table(d$status)), c(14L, 1L, 0L, 112L))
  expect_identical(attr(d, "n_old_without_id_or_doi"), 11L)
  expect_identical(attr(d, "n_new_without_id_or_doi"), 11L)
  removed <- d[d$status == "removed", ]
  expect_identical(removed$doi, example_records$doi[1])
  expect_identical(removed$citations_old, example_records$citations[1])
})

test_that("the record diff orders its rows in byte order whatever the collation", {
  loc <- case_blind_collation()
  skip_if(is.null(loc), "no case-blind collation is available")
  fx <- diff_fixture()
  in_c <- withr::with_collate("C", scopus_diff_records(fx$old, fx$new))
  in_locale <- withr::with_collate(loc, scopus_diff_records(fx$old, fx$new))
  expect_identical(in_locale$doi, in_c$doi)
})

test_that("the record diff handles empty pulls and refuses anything but records", {
  empty <- example_records[0, ]
  d <- scopus_diff_records(empty, empty)
  expect_identical(nrow(d), 0L)
  expect_identical(attr(d, "n_old_without_id_or_doi"), 0L)
  expect_identical(
    as.character(scopus_diff_records(empty, example_records[c(1, 3), ])$status),
    c("added", "added")
  )

  expect_error(scopus_diff_records("10.1/a", empty), class = "scopus_error_bad_input")
  expect_error(scopus_diff_records(empty, data.frame(title = "x")),
               class = "scopus_error_bad_input")
})
