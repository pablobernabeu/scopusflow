test_that("DOIs are extracted, cleaned and deduplicated", {
  recs <- scopus_records(list(entry = list(
    list(`prism:doi` = "10.1/AAA"),
    list(`prism:doi` = "https://doi.org/10.1/aaa"),
    list(`prism:doi` = " doi:10.1/BBB "),
    list(`prism:doi` = NULL)
  )))
  dois <- scopus_extract_dois(recs)
  expect_equal(dois, c("10.1/AAA", "10.1/BBB"))
})

test_that("dedupe can be disabled", {
  dois <- scopus_extract_dois(c("10.1/a", "10.1/a"), dedupe = FALSE)
  expect_equal(length(dois), 2L)
})

test_that("extract accepts a bare character vector", {
  expect_equal(scopus_extract_dois(c("10.1/a", NA, "")), "10.1/a")
})

test_that("resolver prefixes and 'DOI: ' labels are stripped cleanly", {
  expect_equal(
    scopus_extract_dois(c(
      "https://doi.org/10.1/a",
      "http://dx.doi.org/10.1/b",
      "https://www.doi.org/10.1/c",
      "DOI: 10.1/d",
      "doi:10.1/e",
      "doi.org/10.1/f"
    ), dedupe = FALSE),
    c("10.1/a", "10.1/b", "10.1/c", "10.1/d", "10.1/e", "10.1/f")
  )
})

test_that("a 'DOI: ' label and its bare form deduplicate together", {
  expect_equal(scopus_extract_dois(c("DOI: 10.1/x", "10.1/x")), "10.1/x")
})

test_that("writing happens only to the explicit path", {
  recs <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/a"))))
  path <- withr::local_tempfile(fileext = ".csv")
  res <- scopus_extract_dois(recs, file = path)
  expect_true(file.exists(path))
  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_equal(back$doi, "10.1/a")
  expect_equal(res, "10.1/a")
})

test_that("the DOI CSV carries LF line endings on every platform", {
  path <- withr::local_tempfile(fileext = ".csv")
  scopus_extract_dois(c("10.1/a", "10.2/b"), file = path)
  expect_false(any(readBin(path, "raw", file.size(path)) == as.raw(0x0d)))
})

test_that("write rejects an empty path", {
  expect_error(scopus_extract_dois("10.1/a", file = ""), class = "scopus_error_bad_input")
})

test_that("diff identifies added, removed and unchanged", {
  d <- scopus_diff_dois(c("10.1/a", "10.1/b"), c("10.1/b", "10.1/c"))
  expect_s3_class(d, "scopus_doi_diff")
  expect_s3_class(d$status, "factor")
  expect_equal(as.character(d$status[d$doi == "10.1/c"]), "added")
  expect_equal(as.character(d$status[d$doi == "10.1/a"]), "removed")
  expect_equal(as.character(d$status[d$doi == "10.1/b"]), "unchanged")
  expect_equal(nrow(d), 3L)
})

test_that("diff is case-insensitive and handles empty sets", {
  d <- scopus_diff_dois(character(0), c("10.1/a"))
  expect_equal(as.character(d$status), "added")
  d2 <- scopus_diff_dois(c("10.1/A"), c("10.1/a"))
  expect_equal(as.character(d2$status), "unchanged")
  d3 <- scopus_diff_dois(character(0), character(0))
  expect_equal(nrow(d3), 0L)
})

test_that("the diff prints its counts", {
  d <- scopus_diff_dois(c("10.1/a", "10.1/b"), c("10.1/b", "10.1/c"))
  out <- paste(utils::capture.output(print(d)), collapse = " ")
  expect_match(out, "added")
})

test_that("diff accepts scopus_records on either side", {
  old <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/a"))))
  new <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/b"))))
  d <- scopus_diff_dois(old, new)
  expect_setequal(d$doi, c("10.1/a", "10.1/b"))
})

test_that("the diff counts the records it could not compare for want of a DOI", {
  # The records without a DOI used to vanish from the diff without a count.
  # The Python suite asserts the same rows and counts on the same fixture.
  fx <- diff_fixture()
  d <- scopus_diff_dois(fx$old, fx$new)
  expect_identical(d$doi, c(
    "10.5555/new.8", "10.5555/new.9", "10.5555/gone.2",
    "10.5555/JOINED.5", "10.5555/SIX.6", "10.5555/kept.1", "10.5555/moved"
  ))
  expect_identical(as.character(d$status),
                   rep(c("added", "removed", "unchanged"), c(2L, 1L, 4L)))
  expect_identical(attr(d, "n_old_without_doi"), 2L)
  expect_identical(attr(d, "n_new_without_doi"), 2L)
  expect_match(printed(d), paste("2 added, 1 removed, 4 unchanged, 2 earlier and 2",
                                 "later records without a DOI not compared"), fixed = TRUE)
})

test_that("the diff names only the side that lacks DOIs, and nothing when neither does", {
  d <- scopus_diff_dois(c("10.1/a", NA), c("10.1/a", ""))
  expect_identical(attr(d, "n_old_without_doi"), 1L)
  expect_identical(attr(d, "n_new_without_doi"), 1L)
  expect_match(printed(d), "1 earlier and 1 later records without a DOI not compared",
               fixed = TRUE)

  later_only <- scopus_diff_dois("10.1/a", c("10.1/a", NA))
  expect_match(printed(later_only), "1 unchanged, 1 later record without a DOI not compared",
               fixed = TRUE)

  complete <- scopus_diff_dois("10.1/a", "10.1/a")
  expect_identical(attr(complete, "n_old_without_doi"), 0L)
  expect_no_match(printed(complete), "not compared", fixed = TRUE)
})

test_that("the diff orders its rows in byte order whatever the collation", {
  # R's order() follows the locale's collation, under which an English locale
  # sorts "10.5555/kept.1" before "10.5555/SIX.6". Python compares code points,
  # so the twins listed the same rows in different orders.
  loc <- case_blind_collation()
  skip_if(is.null(loc), "no case-blind collation is available")
  fx <- diff_fixture()
  in_c <- withr::with_collate("C", scopus_diff_dois(fx$old, fx$new))
  in_locale <- withr::with_collate(loc, scopus_diff_dois(fx$old, fx$new))
  expect_identical(in_locale$doi, in_c$doi)
  expect_identical(in_locale$doi[4:7], c("10.5555/JOINED.5", "10.5555/SIX.6",
                                         "10.5555/kept.1", "10.5555/moved"))
})
