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

test_that("writing happens only to the explicit path", {
  recs <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/a"))))
  path <- withr::local_tempfile(fileext = ".csv")
  res <- scopus_extract_dois(recs, file = path)
  expect_true(file.exists(path))
  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_equal(back$doi, "10.1/a")
  expect_equal(res, "10.1/a")
})

test_that("write rejects an empty path", {
  expect_error(scopus_extract_dois("10.1/a", file = ""), class = "scopus_error_bad_input")
})

test_that("diff identifies added, removed and unchanged", {
  d <- scopus_diff_dois(c("10.1/a", "10.1/b"), c("10.1/b", "10.1/c"))
  expect_equal(d$status[d$doi == "10.1/c"], "added")
  expect_equal(d$status[d$doi == "10.1/a"], "removed")
  expect_equal(d$status[d$doi == "10.1/b"], "unchanged")
  expect_equal(nrow(d), 3L)
})

test_that("diff is case-insensitive and handles empty sets", {
  d <- scopus_diff_dois(character(0), c("10.1/a"))
  expect_equal(d$status, "added")
  d2 <- scopus_diff_dois(c("10.1/A"), c("10.1/a"))
  expect_equal(d2$status, "unchanged")
  d3 <- scopus_diff_dois(character(0), character(0))
  expect_equal(nrow(d3), 0L)
})

test_that("diff accepts scopus_records on either side", {
  old <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/a"))))
  new <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/b"))))
  d <- scopus_diff_dois(old, new)
  expect_setequal(d$doi, c("10.1/a", "10.1/b"))
})
