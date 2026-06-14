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
  out <- paste(cli::cli_fmt(print(d)), collapse = " ")
  expect_match(out, "added")
})

test_that("diff accepts scopus_records on either side", {
  old <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/a"))))
  new <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/b"))))
  d <- scopus_diff_dois(old, new)
  expect_setequal(d$doi, c("10.1/a", "10.1/b"))
})
