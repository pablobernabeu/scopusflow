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

test_that("COMPLETE records list every author, as the Python twin does", {
  # dc:creator is the first author under either view, and the author list is
  # the `author` array, which only the COMPLETE view carries. The column was
  # read from dc:creator alone, so this record gave "Cong L.". The Python suite
  # reads the same fixture and must return the same string.
  fx <- complete_authors_fixture()
  recs <- scopus_records(list(entry = list(fx$entry)), view = "COMPLETE")
  expect_identical(recs$authors, fx$expected_authors)

  # A null or empty given name, which pybliometrics writes as the surname and
  # a bare comma, leaves the surname alone in both twins.
  blank <- fx$entry
  blank$author <- fx$blank_given_names$author
  recs <- scopus_records(list(entry = list(blank)), view = "COMPLETE")
  expect_identical(recs$authors, fx$blank_given_names$expected_authors)
})

test_that("STANDARD records hold the first author, as dc:creator gives it", {
  fx <- complete_authors_fixture()
  standard <- fx$entry[setdiff(names(fx$entry), c("author", "author-count"))]
  recs <- scopus_records(list(entry = list(standard)), view = "STANDARD")
  expect_identical(recs$authors, "Cong L.")
  # Only the COMPLETE view reads the author array, so the view-less default
  # keeps the original column even for an entry that carries one.
  expect_identical(scopus_records(list(entry = list(fx$entry)))$authors, "Cong L.")
})

test_that("an author's name falls back as far as the entry allows", {
  complete_authors <- function(authors) {
    entry <- parse_entry(sprintf('{"dc:creator": "First F.", "author": %s}', authors))
    scopus_records(list(entry = list(entry)), view = "COMPLETE")$authors
  }
  # A missing or blank given name leaves the surname alone.
  expect_identical(
    complete_authors('[{"surname": "Cong"}, {"surname": "Zhang", "given-name": " "}]'),
    "Cong; Zhang"
  )
  # A missing or null surname falls back to authname, the indexed form.
  expect_identical(
    complete_authors(paste0('[{"authname": "Cong L.", "given-name": "Le"}, ',
                            '{"authname": "Zhang F.", "surname": null, "given-name": "Feng"}]')),
    "Cong L.; Zhang F."
  )
  # A lone author sent as a bare object, as Elsevier's JSON sends a one-item
  # array, is still read.
  expect_identical(complete_authors('{"surname": "Cong", "given-name": "Le"}'), "Cong, Le")
  # Only exact copies are dropped, as pybliometrics drops them, so the twins
  # agree on an author the array lists in two positions.
  expect_identical(
    complete_authors(paste0('[{"@seq": "1", "surname": "Cong", "given-name": "Le"}, ',
                            '{"@seq": "2", "surname": "Cong", "given-name": "Le"}]')),
    "Cong, Le; Cong, Le"
  )
  # With no author left to name, the column falls back to dc:creator.
  expect_identical(complete_authors("[]"), "First F.")
  expect_identical(complete_authors('[{"authid": "1"}]'), "First F.")
})

test_that("R names every author at the edges where pybliometrics builds no list", {
  # The Python twin reads pybliometrics' author_names, which is not built when
  # an author object lacks a surname or given-name key, and which writes a null
  # surname after a bare comma. R reads the author array itself. Both twins
  # document the difference, and test_pyb.py holds the Python side of it on
  # the same entry.
  fx <- complete_authors_fixture()
  with_last_author <- function(edit) {
    entry <- fx$entry
    entry$author[[4]] <- edit(entry$author[[4]])
    scopus_records(list(entry = list(entry)), view = "COMPLETE")$authors
  }
  expect_identical(with_last_author(function(a) a[names(a) != "given-name"]),
                   "Cong, Le; Zhang, Feng; Doudna")
  expect_identical(with_last_author(function(a) a[names(a) != "surname"]),
                   "Cong, Le; Zhang, Feng; Doudna J.A.")
  expect_identical(with_last_author(function(a) {
    a["surname"] <- list(NULL)
    a
  }), "Cong, Le; Zhang, Feng; Doudna J.A.")
})

test_that("an array of scalars is collapsed, not cut to its first element", {
  # None of the fields the records read is sent this way, but should one be,
  # every value is kept.
  recs <- scopus_records(list(entry = list(
    list(`dc:title` = list("Part one", "part two"), `prism:doi` = "10.1/x")
  )))
  expect_identical(recs$title, "Part one; part two")
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

test_that("extended fields keep what both views send, and the COMPLETE abstract", {
  # The Search API sends these fields in every response, at no extra quota,
  # and the records discarded them. The Python suite reads the same fixture
  # through pybliometrics and must return the same rows.
  fx <- extended_fixture()
  standard <- scopus_records(list(entry = list(fx$standard)), query = fx$query,
                             view = "STANDARD", fields = "extended")
  expect_record_row(standard, fx$expected$standard)
  complete <- scopus_records(list(entry = list(fx$complete)), query = fx$query,
                             view = "COMPLETE", fields = "extended")
  expect_record_row(complete, fx$expected$complete)
})

test_that("the core fields stay the default, so existing output is unchanged", {
  fx <- extended_fixture()
  core <- scopus_records(list(entry = list(fx$complete)), view = "COMPLETE")
  expect_identical(names(core),
                   c(scopusflow:::scopus_records_columns(), "authkeywords"))
  expect_identical(names(scopus_records(list(entry = list(fx$standard)))),
                   scopusflow:::scopus_records_columns())
})

test_that("an empty extended result types every extended column", {
  fx <- extended_fixture()
  complete <- scopus_records(list(entry = list()), view = "COMPLETE",
                             fields = "extended")
  expect_identical(names(complete), names(fx$expected$complete))
  expect_type(complete$open_access, "integer")
  expect_type(complete$issn, "character")
  expect_type(complete$abstract, "character")
  standard <- scopus_records(list(entry = list()), fields = "extended")
  expect_identical(names(standard), names(fx$expected$standard))
})

test_that("open_access keeps the status code Scopus sends", {
  # Elsevier's guide gives 0 for not open access, 1 for gold and 2 for green,
  # so the column holds a status code that can exceed 1, as pybliometrics' int
  # does.
  with_status <- function(value) list(`prism:doi` = "10.5555/x", openaccess = value)
  recs <- scopus_records(
    list(entry = list(with_status("2"), with_status("0"), list(`prism:doi` = "10.5555/y"))),
    fields = "extended"
  )
  expect_identical(recs$open_access, c(2L, 0L, NA_integer_))
})

test_that("fields must be core or extended", {
  expect_error(scopus_records(list(entry = list()), fields = "all"),
               class = "scopus_error_bad_input")
})
