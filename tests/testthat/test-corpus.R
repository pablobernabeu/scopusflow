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
  expect_equal(names(corpus), c("id", "scopus_id", "title", "year", "keywords", "references"))
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

test_that("under REF view a paged reference list reaches the corpus whole", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(mock_ref_pages(103L))
  corpus <- expect_no_warning(scopus_corpus(records, view = "REF"))
  expect_equal(nrow(corpus$references[[1]]), 103L)
})

test_that("a lone reference or a keyword without text no longer aborts the corpus", {
  # The lone reference arrives as a bare object, and the keyword object carries
  # only its attribute (pybliometrics issue #436).
  local_scopus_test_env()
  records <- tibble::tibble(doi = c("10.1/a", "10.1/b"), title = c("A", "B"), year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = mock_request_doi(req)),
      authkeywords = list(`author-keyword` = list(`@_fa` = "true")),
      refcount = 1,
      references = list(
        `@id` = "1",
        `ref-info` = list(`ref-title` = list(`ref-titletext` = "A lone reference"))
      )
    )
  })
  corpus <- expect_no_warning(scopus_corpus(records, view = "FULL"))
  expect_equal(corpus$id, c("10.1/a", "10.1/b"))
  expect_equal(corpus$keywords, list(character(), character()))
  expect_equal(corpus$references[[2]]$title, "A lone reference")
})

test_that("keywords = 'index' and 'both' draw on the index keywords", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/a"),
      authkeywords = list(`author-keyword` = list(
        list(`$` = "graphene"), list(`$` = "Supercapacitors")
      )),
      idxterms = list(mainterm = list(
        list(`$` = "Supercapacitors"), list(`$` = "Graphene"), list(`$` = "Electrodes")
      )),
      refcount = 0
    )
  })
  # The default is unchanged: the author keywords alone.
  expect_identical(scopus_corpus(records)$keywords[[1]], c("graphene", "Supercapacitors"))
  expect_identical(
    scopus_corpus(records, keywords = "index")$keywords[[1]],
    c("Supercapacitors", "Graphene", "Electrodes")
  )
  # Author keywords first, then each index keyword not already among them. The
  # match is on the exact text, so "graphene" and "Graphene" are both kept.
  expect_identical(
    scopus_corpus(records, keywords = "both")$keywords[[1]],
    c("graphene", "Supercapacitors", "Graphene", "Electrodes")
  )
})

test_that("each keywords choice asks scopus_abstract() for what it needs", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/a"), refcount = 0)
  })
  for (k in c("author", "index", "both")) {
    scopus_corpus(records, cache_dir = cache, keywords = k)
  }
  expect_setequal(
    sub("-10_1_a\\.rds$", "", list.files(cache)),
    c("id-FULL-keywords-references", "id-FULL-index_terms-references",
      "id-FULL-index_terms-keywords-references")
  )
})

test_that("index keywords need view = 'FULL', and REF refuses them before a request", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A study", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    stop("no request should be made", call. = FALSE)
  })
  for (k in c("index", "both")) {
    expect_error(
      scopus_corpus(records, view = "REF", keywords = k),
      class = "scopus_error_bad_input",
      regexp = "FULL"
    )
  }
  expect_error(
    scopus_corpus(records, keywords = "authors"),
    class = "scopus_error_bad_input"
  )
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

test_that("scopus_corpus reports its requests and quota, and each document's Scopus identifier", {
  # The Python twin always carried n_requests and quota. R built a fresh
  # tibble and dropped them, and neither twin returned the document's own
  # identifier, which the corpus writer keys records on.
  local_scopus_test_env()
  records <- tibble::tibble(
    scopus_id = c("85000000001", "85000000009"),
    doi = c("10.1/a", "10.1/missing"),
    title = c("A", "B"),
    year = c(2020L, 2021L)
  )
  httr2::local_mocked_responses(function(req) {
    if (identical(mock_request_doi(req), "10.1/missing")) {
      return(mock_json_response(list(`service-error` = list()), status = 404L))
    }
    mock_json_response(
      list(`abstracts-retrieval-response` = list(
        coredata = list(`prism:doi` = "10.1/a", `dc:identifier` = "SCOPUS_ID:85000000002"),
        item = list(bibrecord = list(tail = list(bibliography = list(`@refcount` = "0"))))
      )),
      headers = list(`X-RateLimit-Limit` = "10000", `X-RateLimit-Remaining` = "9998",
                     `X-RateLimit-Reset` = "1700000000")
    )
  })
  expect_warning(corpus <- scopus_corpus(records), "missing")
  expect_named(corpus, c("id", "scopus_id", "title", "year", "keywords", "references"))
  # The abstract's own identifier where the lookup succeeded, and the records'
  # where it failed.
  expect_identical(corpus$scopus_id, c("85000000002", "85000000009"))
  expect_identical(attr(corpus, "n_requests"), 2L)
  expect_equal(attr(corpus, "quota")$remaining, 9998)
})

test_that("scopus_corpus leaves scopus_id NA when neither source has one", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A", year = 2020L)
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/a"), refcount = 0)
  })
  expect_identical(scopus_corpus(records)$scopus_id, NA_character_)
})

test_that("scopus_corpus carries the search expression, its date and the kind of keyword", {
  local_scopus_test_env()
  records <- tibble::tibble(doi = "10.1/a", title = "A", year = 2020L)
  attr(records, "plan") <- scopus_plan("graphene", years = 2020, field = "TITLE-ABS-KEY")
  stamp <- as.POSIXct("2026-10-02 09:15:00", tz = "UTC")
  attr(records, "retrieved_at") <- stamp
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/a"), refcount = 0)
  })
  corpus <- scopus_corpus(records, keywords = "index")
  expect_identical(attr(corpus, "query"), "TITLE-ABS-KEY(graphene)")
  expect_identical(attr(corpus, "retrieved_at"), stamp)
  expect_identical(attr(corpus, "keywords"), "index")

  # Without a plan, the records' own query column states the expression, as
  # it does in the search record. With neither, nothing is recorded.
  records <- tibble::tibble(doi = "10.1/a", title = "A", year = 2020L,
                            query = "TITLE(graphene)")
  expect_identical(attr(scopus_corpus(records), "query"), "TITLE(graphene)")
  records$query <- NULL
  corpus <- scopus_corpus(records)
  expect_null(attr(corpus, "query"))
  expect_null(attr(corpus, "retrieved_at"))
})

test_that("write_scopus_corpus() writes the shared golden, which theoryforge's schema accepts", {
  fx <- corpus_writer_fixture()
  path <- withr::local_tempfile(fileext = ".json")
  expect_warning(
    write_scopus_corpus(fx$corpus, path, id = fx$id),
    class = "scopus_warning_dropped_references"
  )
  golden <- rawToChar(readBin(test_path("golden-corpus.json"), "raw", 1e5))
  Encoding(golden) <- "UTF-8"
  expect_identical(read_corpus_golden_form(path), golden)

  doc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_identical(schema_errors(doc, corpus_schema()), character())
  expect_identical(
    doc$provenance$source,
    paste("Scopus via scopusflow", utils::packageVersion("scopusflow"))
  )
})

test_that("the writer keys a cited work on its Scopus identifier however its DOI is written", {
  # Keyed on the DOI where present, as theoryforge's earlier recipe did, W and
  # X split into two nodes each and the co-citation edge between them was lost.
  fx <- corpus_writer_fixture()
  expect_warning(
    doc <- as_theoryforge_corpus(fx$corpus, id = fx$id),
    "1 reference",
    class = "scopus_warning_dropped_references"
  )
  expect_identical(doc$schema_version, "1.0")
  expect_identical(doc$id, "graphene-supercapacitors")
  ids <- vapply(doc$records, function(r) r$id, character(1))
  # B carries no identifier of its own, and takes the one A's bibliography
  # gives its DOI, so a citation of B and B itself are one key.
  expect_identical(ids, c("scopus:85000000001", "scopus:85000000002"))
  refs <- lapply(doc$records, function(r) as.character(r$references))
  expect_identical(
    refs[[1]],
    c("scopus:111", "scopus:222", "doi:10.5555/z", "scopus:85000000002")
  )
  expect_identical(refs[[2]], c("scopus:111", "scopus:222", "scopus:85000000001"))
  expect_identical(as.character(doc$records[[1]]$keywords),
                   c("graphene", "supercapacitors", "électrodes"))
  expect_identical(doc$provenance$n_references_dropped, 1L)
  expect_identical(doc$provenance$n_records_without_keywords, 1L)
})

test_that("a lone keyword or reference stays an array, and a numeric identifier stays whole", {
  corpus <- tibble::tibble(
    id = 85000000001, title = "A", year = 2020,
    keywords = list("Graphene"),
    references = list(data.frame(id = 1e5, doi = NA_character_))
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_scopus_corpus(corpus, path, id = "lone")
  written <- read_corpus_golden_form(path)
  expect_match(written, '"keywords":["graphene"]', fixed = TRUE)
  expect_match(written, '"references":["scopus:100000"]', fixed = TRUE)
  expect_match(written, '"id":"scopus:85000000001"', fixed = TRUE)
  expect_match(written, '"year":2020}', fixed = TRUE)
  expect_true(endsWith(written, "}\n"))
})

test_that("the provenance block gives null for what the corpus does not record", {
  corpus <- tibble::tibble(
    id = "10.1/A", title = "A", year = NA_integer_,
    keywords = list(character()),
    references = list(data.frame(id = character(), doi = character()))
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_scopus_corpus(corpus, path, id = "bare")
  written <- read_corpus_golden_form(path)
  expect_match(written, '"keywords":null', fixed = TRUE)
  expect_match(written, '"query":null', fixed = TRUE)
  expect_match(written, '"retrieved_at":null', fixed = TRUE)
  expect_match(written, '"n_records_without_keywords":1', fixed = TRUE)
  expect_match(written, '{"id":"doi:10.1/a","keywords":[],"references":[],"title":"A","year":null}',
               fixed = TRUE)

  # Several expressions, as a combined set records, are written as an array,
  # and a retrieval time in any zone is written in UTC.
  attr(corpus, "query") <- c("TITLE(a)", "TITLE(b)")
  attr(corpus, "retrieved_at") <- as.POSIXct("2026-10-02 10:15:00", tz = "Europe/London")
  write_scopus_corpus(corpus, path, id = "bare")
  written <- read_corpus_golden_form(path)
  expect_match(written, '"query":["TITLE(a)","TITLE(b)"]', fixed = TRUE)
  expect_match(written, '"retrieved_at":"2026-10-02T09:15:00Z"', fixed = TRUE)
})

test_that("the writer refuses a missing id, a malformed corpus or a record it cannot key", {
  corpus <- tibble::tibble(
    id = "10.1/a", title = "A", year = 2020L, keywords = list("x"),
    references = list(data.frame(id = character(), doi = character()))
  )
  expect_error(as_theoryforge_corpus(corpus), class = "scopus_error_bad_input")
  for (bad in list(NULL, NA_character_, "", "  ", c("a", "b"), 1)) {
    expect_error(as_theoryforge_corpus(corpus, id = bad), class = "scopus_error_bad_input")
  }
  expect_error(
    as_theoryforge_corpus(corpus[c("id", "title")], id = "x"),
    class = "scopus_error_bad_input"
  )
  unkeyable <- corpus
  unkeyable$id <- "W2741809807"
  expect_error(
    as_theoryforge_corpus(unkeyable, id = "x"),
    class = "scopus_error_bad_input",
    regexp = "neither"
  )
  expect_error(write_scopus_corpus(corpus, NA_character_, id = "x"),
               class = "scopus_error_bad_input")
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
