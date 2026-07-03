test_that("records normalise from the static fixture", {
  results <- load_page_fixture()[["search-results"]]
  recs <- scopus_records(results, query = "TITLE(example)")
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 6L)
  expect_equal(recs$scopus_id, paste0("8500000000", 1:6))
  expect_equal(recs$doi[1], "10.1038/s41586-019-0001-1")
  expect_equal(recs$year, c(2019L, 2020L, 2018L, 2021L, 2020L, 2016L))
  expect_equal(recs$citations, c(540L, 210L, 122L, 45L, 388L, 4200L))
  expect_equal(recs$entry_number, 1:6)
  expect_true(all(recs$query == "TITLE(example)"))
})

test_that("missing fields become NA", {
  recs <- scopus_records(list(entry = list(list(`prism:doi` = "10.1/x"))))
  expect_equal(recs$doi, "10.1/x")
  expect_true(is.na(recs$title))
  expect_true(is.na(recs$year))
  expect_true(is.na(recs$citations))
})

test_that("the empty-result sentinel yields zero rows", {
  recs <- scopus_records(list(entry = list(list(error = "Result set was empty"))))
  expect_equal(nrow(recs), 0L)
  expect_equal(names(recs), scopusflow:::scopus_records_columns())
})

test_that("an empty entry list yields a typed zero-row tibble", {
  recs <- scopus_records(list(entry = list()))
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 0L)
  expect_type(recs$year, "integer")
})

test_that("scopus_records is idempotent", {
  recs <- scopus_records(load_page_fixture()[["search-results"]])
  expect_identical(scopus_records(recs), recs)
})

test_that("is_scopus_records discriminates", {
  expect_true(is_scopus_records(scopus_records(list(entry = list()))))
  expect_false(is_scopus_records(data.frame(a = 1)))
})

test_that("bad input is rejected", {
  expect_error(scopus_records(42), class = "scopus_error_bad_input")
})

test_that("multiple authors are kept, not truncated to the first", {
  recs <- scopus_records(list(entry = list(
    list(`dc:creator` = list("Smith J.", "Doe A.", "Lee K."))
  )))
  expect_equal(recs$authors, "Smith J.; Doe A.; Lee K.")
})

test_that("a list-of-objects field becomes NA rather than garbage", {
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = list(list(x = 1), list(y = 2)), `prism:doi` = "10.1/x")
  )))
  expect_true(is.na(recs$title))
  expect_equal(recs$doi, "10.1/x")
})

test_that("a real record carrying an error annotation is not dropped", {
  recs <- scopus_records(list(entry = list(
    list(`dc:identifier` = "SCOPUS_ID:1", `prism:doi` = "10.1/a",
         error = "Resource not found for this entry")
  )))
  expect_equal(nrow(recs), 1L)
  expect_equal(recs$doi, "10.1/a")
})

test_that("the empty-result sentinel (error, no identifier) still yields zero rows", {
  recs <- scopus_records(list(entry = list(list(error = "Result set was empty"))))
  expect_equal(nrow(recs), 0L)
})

test_that("year is the leading four digits, or NA when malformed", {
  recs <- scopus_records(list(entry = list(
    list(`prism:coverDate` = "2020"),
    list(`prism:coverDate` = "c2020"),
    list(`prism:coverDate` = "")
  )))
  expect_equal(recs$year, c(2020L, NA_integer_, NA_integer_))
})

test_that("STANDARD view (and the view-less default) never carry authkeywords", {
  entry <- list(`prism:doi` = "10.1/x", authkeywords = "graphene | supercapacitor")
  recs_default <- scopus_records(list(entry = list(entry)))
  recs_standard <- scopus_records(list(entry = list(entry)), view = "STANDARD")
  expect_false("authkeywords" %in% names(recs_default))
  expect_false("authkeywords" %in% names(recs_standard))
  expect_identical(names(recs_default), scopusflow:::scopus_records_columns())
})

test_that("COMPLETE view adds a populated authkeywords column", {
  recs <- scopus_records(
    list(entry = list(list(
      `prism:doi` = "10.1/x",
      authkeywords = "graphene | supercapacitor | energy storage"
    ))),
    view = "COMPLETE"
  )
  expect_true("authkeywords" %in% names(recs))
  expect_equal(recs$authkeywords, "graphene | supercapacitor | energy storage")
})

test_that("COMPLETE view adds an NA authkeywords column when the API omits it", {
  # Reflects a real, observed case: a key entitled for COMPLETE view whose
  # author-keyword field still comes back empty for every document.
  recs <- scopus_records(
    list(entry = list(list(`prism:doi` = "10.1/x"))),
    view = "COMPLETE"
  )
  expect_true("authkeywords" %in% names(recs))
  expect_true(is.na(recs$authkeywords))
})

test_that("an empty result under COMPLETE view still types the authkeywords column", {
  recs <- scopus_records(list(entry = list()), view = "COMPLETE")
  expect_equal(nrow(recs), 0L)
  expect_true("authkeywords" %in% names(recs))
  expect_type(recs$authkeywords, "character")
})
