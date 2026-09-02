test_that("records normalise from the static fixture", {
  results <- load_page_fixture()[["search-results"]]
  recs <- scopus_records(results, query = "TITLE(example)")
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), 6L)
  expect_equal(recs$scopus_id, paste0("8500000000", 1:6))
  # The fixture is synthetic: its identifiers sit on the reserved 10.5555 DOI
  # prefix, which never resolves, so it labels no real published work.
  expect_equal(recs$doi[1], "10.5555/sf.example.0001")
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

test_that("a query of several strings is refused, not spread over the records", {
  raw <- list(entry = list(list(`prism:doi` = "10.1/a"), list(`prism:doi` = "10.1/b")))
  expect_error(scopus_records(raw, query = c("q1", "q2")),
               class = "scopus_error_bad_input")
  expect_error(scopus_records(as.data.frame(example_records)[1:2, ],
                              query = c("q1", "q2")),
               class = "scopus_error_bad_input")
  expect_equal(scopus_records(raw, query = "q")$query, c("q", "q"))
  expect_true(all(is.na(scopus_records(raw, query = NULL)$query)))
  expect_true(all(is.na(scopus_records(raw)$query)))
  # A bare NA is accepted, and has to reach the schema as a character column.
  expect_type(scopus_records(raw, query = NA)$query, "character")
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

test_that("a data frame in the schema is coerced, not read as a list of columns", {
  # A data frame is a list of columns, so it used to be taken for a list of
  # entries: one all-NA row per column, which looks like a result and is not.
  frame <- tibble::as_tibble(example_records)
  recs <- scopus_records(frame)
  expect_s3_class(recs, "scopus_records")
  expect_equal(nrow(recs), nrow(example_records))
  expect_equal(recs$doi, example_records$doi)
  expect_identical(names(recs), names(example_records))
  # Coercing again changes nothing.
  expect_identical(scopus_records(recs), recs)

  # A frame holding only part of the schema is filled out to it.
  partial <- data.frame(doi = c("10.1/x", "10.1/y"), title = c("T1", "T2"),
                        year = 2020:2021, stringsAsFactors = FALSE)
  recs <- scopus_records(partial, query = "graphene")
  expect_equal(nrow(recs), 2L)
  expect_equal(recs$title, c("T1", "T2"))
  expect_type(recs$year, "integer")
  expect_equal(recs$query, rep("graphene", 2L))
  expect_true(all(is.na(recs$publication)))
})

test_that("a data frame that is not a record set is refused", {
  expect_error(scopus_records(data.frame(a = 1, b = 2)),
               class = "scopus_error_bad_input")
  expect_error(scopus_records(data.frame(a = 1, b = 2)),
               "Neither `doi` nor `title` is present.", fixed = TRUE)
})

test_that("a large entry list normalises to the same columns as one row at a time", {
  # The columns are pulled across all entries at once rather than built as a
  # data frame per entry; a harvest of tens of thousands of records used to
  # spend the better part of a minute here.
  n <- 2000L
  entries <- lapply(seq_len(n), function(k) {
    entry <- list(
      `dc:identifier` = paste0("SCOPUS_ID:", 84000000000 + k),
      `prism:doi` = sprintf("10.1000/x.%04d", k),
      `dc:title` = sprintf("Article %d", k),
      `dc:creator` = "Tester T.",
      `prism:publicationName` = "Journal of Mocking",
      `prism:coverDate` = sprintf("%d-01-01", 2000L + (k %% 20L)),
      `citedby-count` = as.character(k)
    )
    # A fifth of the entries carry no date and no count, as real ones do not.
    if (k %% 5L == 0L) entry[c("prism:coverDate", "citedby-count")] <- NULL
    entry
  })
  recs <- scopus_records(list(entry = entries), query = "q")
  expect_equal(nrow(recs), n)
  expect_identical(names(recs), scopusflow:::scopus_records_columns())
  expect_equal(recs$entry_number, seq_len(n))
  expect_equal(recs$scopus_id, as.character(84000000000 + seq_len(n)))
  expect_equal(recs$doi, sprintf("10.1000/x.%04d", seq_len(n)))
  expect_equal(recs$authors, rep("Tester T.", n))
  expect_equal(recs$query, rep("q", n))
  expect_type(recs$year, "integer")
  expect_type(recs$citations, "integer")
  bare <- seq_len(n) %% 5L == 0L
  expect_true(all(is.na(recs$year[bare])))
  expect_true(all(is.na(recs$citations[bare])))
  expect_equal(recs$year[!bare], 2000L + (seq_len(n)[!bare] %% 20L))
  expect_equal(recs$citations[!bare], seq_len(n)[!bare])
})
