test_that("scopus_corpus assembles id, title, year, keywords and references", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/a"),
      authkeywords = list(`author-keyword` = list(
        list(`$` = "graphene"), list(`$` = "supercapacitor")
      )),
      refcount = 1,
      references = list(list(
        `@id` = "1",
        `ref-info` = list(
          `ref-title` = list(`ref-titletext` = "A cited work"),
          `ref-sourcetitle` = "Some Journal"
        )
      ))
    )
  })
  corpus <- scopus_corpus(records, view = "FULL")
  expect_equal(nrow(corpus), 1L)
  expect_equal(names(corpus), c("id", "title", "year", "keywords", "references"))
  expect_equal(corpus$id, "10.1/a")
  expect_equal(corpus$title, "A study")
  expect_equal(corpus$year, 2020L)
  expect_equal(corpus$keywords[[1]], c("graphene", "supercapacitor"))
  expect_equal(nrow(corpus$references[[1]]), 1L)
  expect_equal(corpus$references[[1]]$title, "A cited work")
})

test_that("a document with no keywords gets an empty (not NA) keywords vector", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/a"), refcount = 0)
  })
  corpus <- scopus_corpus(records, view = "FULL")
  expect_equal(corpus$keywords[[1]], character())
})

test_that("under REF view only references are requested and keywords are empty", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_ref(references = list(
      list(`@id` = "1", `ref-info` = list(`ref-title` = list(`ref-titletext` = "A cited work")))
    ), total = 1)
  })
  corpus <- scopus_corpus(records, view = "REF")
  expect_equal(corpus$keywords[[1]], character())
  expect_equal(nrow(corpus$references[[1]]), 1L)
})

test_that("records with a missing identifier are dropped with a warning", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = c("10.1/a", NA), title = c("A", "B"), year = c(2020L, 2021L))
  httr2::local_mocked_responses(function(req) mock_abstract(list(`prism:doi` = "10.1/a")))
  expect_warning(
    corpus <- scopus_corpus(records, view = "FULL"),
    class = "scopus_warning_dropped_records"
  )
  expect_equal(nrow(corpus), 1L)
  expect_equal(corpus$title, "A")
})

test_that("scopus_corpus validates its input shape", {
  expect_error(scopus_corpus(data.frame(x = 1)), class = "scopus_error_bad_input")
  # Every identifier missing warns once per dropped record, then still
  # aborts, since nothing is left to look up.
  expect_error(
    suppressWarnings(scopus_corpus(tibble::tibble(doi = NA_character_, title = "x", year = 2020L))),
    class = "scopus_error_bad_input"
  )
})

test_that("scopus_corpus does not alter as_bibliometrix output", {
  local_scopus_test_env()
  cmp <- tibble::tibble(
    entry_number = 1L, scopus_id = "1", doi = "10.1/a", title = "A study",
    authors = "Doe J.", year = 2020L, date = "2020-01-01",
    publication = "Journal", citations = 3L, query = "x"
  )
  class(cmp) <- c("scopus_records", class(cmp))
  before <- as_bibliometrix(cmp)
  expect_true(all(c("AU", "TI", "SO", "DI", "PY", "TC", "UT", "DB") %in% names(before)))
})
