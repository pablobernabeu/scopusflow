test_that("as_bibliometrix carries a COMPLETE author list into AU", {
  # Every record used to look single-authored, because AU was read from
  # dc:creator, and bibliometrix's collaboration measures and co-authorship
  # networks were then built on first authors alone.
  fx <- complete_authors_fixture()
  recs <- scopus_records(list(entry = list(fx$entry)), view = "COMPLETE")
  expect_identical(as_bibliometrix(recs)$AU, toupper(fx$expected_authors))
})

test_that("as_bibliometrix says once that a STANDARD set names first authors only", {
  rlang::reset_warning_verbosity("scopusflow_first_author_only")
  withr::defer(rlang::reset_warning_verbosity("scopusflow_first_author_only"))
  standard <- example_records
  attr(standard, "view") <- "STANDARD"
  w <- expect_warning(as_bibliometrix(standard),
                      class = "scopus_warning_first_author_only")
  expect_identical(w$message, complete_authors_fixture()$first_author_warning)
  # The one warning covers the author tally as well.
  expect_no_warning(as_bibliometrix(standard))
  expect_no_warning(scopus_top(standard, by = "author"))
})

test_that("as_bibliometrix stays silent on sets that are not first authors only", {
  withr::local_options(rlib_warning_verbosity = "verbose")
  complete <- example_records
  attr(complete, "view") <- "COMPLETE"
  expect_no_warning(as_bibliometrix(example_records))
  expect_no_warning(as_bibliometrix(complete))
})
