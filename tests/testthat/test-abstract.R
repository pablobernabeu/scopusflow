test_that("scopus_abstract returns the abstract and core metadata", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract(list(
      `dc:identifier` = "SCOPUS_ID:85000000001",
      `prism:doi` = "10.5555/sf.example.0001",
      `dc:title` = "Genome editing with CRISPR-Cas9",
      `dc:description` = "We review the principles and applications of CRISPR-Cas9.",
      `prism:publicationName` = "Nature",
      `prism:coverDate` = "2019-04-12",
      `citedby-count` = "540"
    ))
  })
  ab <- scopus_abstract("10.5555/sf.example.0001")
  expect_s3_class(ab, "scopus_abstracts")
  expect_equal(nrow(ab), 1L)
  expect_equal(ab$doi, "10.5555/sf.example.0001")
  expect_equal(ab$scopus_id, "85000000001")
  expect_match(ab$abstract, "CRISPR")
  expect_equal(ab$year, 2019L)
  expect_equal(ab$citations, 540L)
})

test_that("scopus_abstract accepts several ids and a Scopus-id lookup", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract(list(`dc:title` = "A record", `prism:doi` = "10.1/a"))
  })
  ab <- scopus_abstract(c("85000000001", "SCOPUS_ID:85000000002"), by = "scopus_id")
  expect_equal(nrow(ab), 2L)
  expect_equal(ab$id, c("85000000001", "85000000002")) # prefix stripped
})

test_that("an identifier that cannot be retrieved yields an NA row with a warning", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(), status = 404L))
  expect_warning(ab <- scopus_abstract("10.1/missing"))
  expect_equal(nrow(ab), 1L)
  expect_equal(ab$id, "10.1/missing")
  expect_true(is.na(ab$title))
})

test_that("scopus_abstract validates its input", {
  local_scopus_test_env()
  expect_error(scopus_abstract(character(0)), class = "scopus_error_bad_input")
  expect_error(scopus_abstract(c("x", NA)), class = "scopus_error_bad_input")
  expect_error(scopus_abstract("x", by = "isbn"))
})

test_that("scopus_abstract aborts clearly when no key is configured", {
  withr::local_options(scopusflow.api_key = NULL)
  withr::local_envvar(SCOPUS_API_KEY = "")
  # A missing key must abort once, not degrade into a tibble of NA rows.
  expect_error(scopus_abstract(c("10.1/a", "10.1/b")), class = "scopus_error_no_key")
})

test_that("a malformed 200 body yields an NA row, not a lost batch", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 200L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw("<not json>")
    )
  })
  expect_warning(ab <- scopus_abstract("10.1/x"))
  expect_equal(nrow(ab), 1L)
  expect_true(is.na(ab$title))
})

test_that("scopus_abstract percent-encodes the identifier path", {
  local_scopus_test_env()
  seen <- NULL
  httr2::local_mocked_responses(function(req) {
    seen <<- req$url
    mock_abstract(list(`dc:title` = "x"))
  })
  scopus_abstract("10.1002/(SICI)1099", by = "doi")
  expect_match(seen, "%28SICI%29")                    # parens are encoded
  expect_match(seen, "/doi/10.1002/", fixed = TRUE)   # structural slash preserved
})

test_that("the default request names view META_ABS, and view = NULL sends none", {
  # Elsevier documents META, a view without the abstract, as the one it serves
  # when a request names none, so the default names the view that carries it.
  local_scopus_test_env()
  seen <- character()
  httr2::local_mocked_responses(function(req) {
    seen <<- c(seen, req$url)
    mock_abstract(list(`prism:doi` = "10.1/x", `dc:description` = "An abstract."))
  })
  ab <- scopus_abstract("10.1/x")
  expect_equal(httr2::url_parse(seen[1])$query, list(view = "META_ABS"))
  expect_equal(ab$abstract, "An abstract.")

  scopus_abstract("10.1/x", view = NULL)
  expect_null(httr2::url_parse(seen[2])$query)
})

test_that("default-view checkpoints are keyed META_ABS, and 0.4.0's still serve view = NULL", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_abstract(list(`prism:doi` = "10.1/a", `dc:title` = "Fetched"))
  })
  # A checkpoint as 0.4.0 wrote it for a call that named no view.
  legacy <- scopusflow:::scopus_abstract_row("10.1/a", list(`dc:title` = "Cached by 0.4.0"))
  saveRDS(legacy, file.path(cache, "id-default-none-10_1_a.rds"))

  ab <- scopus_abstract("10.1/a", cache_dir = cache)
  expect_equal(ab$title, "Fetched")
  expect_equal(calls, 1L)
  expect_true(file.exists(file.path(cache, "id-META_ABS-none-10_1_a.rds")))

  old <- scopus_abstract("10.1/a", view = NULL, cache_dir = cache)
  expect_equal(old$title, "Cached by 0.4.0")
  expect_equal(calls, 1L)
})

test_that("without view or include, output columns are exactly as before", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_abstract(list(`prism:doi` = "10.1/x")))
  ab <- scopus_abstract("10.1/x")
  expect_identical(
    names(ab),
    c("id", "scopus_id", "doi", "title", "abstract", "publication", "year", "citations")
  )
})

test_that("view and include are validated", {
  local_scopus_test_env()
  expect_error(scopus_abstract("x", view = "BOGUS"), class = "scopus_error_bad_input")
  expect_error(scopus_abstract("x", include = "wrongthing"), class = "scopus_error_bad_input")
  expect_error(
    scopus_abstract("x", include = "references"),  # no compatible view
    class = "scopus_error_bad_input"
  )
  expect_error(
    scopus_abstract("x", view = "META", include = "references"),
    class = "scopus_error_bad_input"
  )
  # Keywords need FULL: the REF response carries no author keywords, so
  # accepting REF (or the default view) would only yield a silent NA column.
  expect_error(
    scopus_abstract("x", include = "keywords"),
    class = "scopus_error_bad_input"
  )
  expect_error(
    scopus_abstract("x", view = "REF", include = "keywords"),
    class = "scopus_error_bad_input"
  )
})

test_that("include = 'keywords' under FULL view adds a populated authkeywords column", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/x"),
      authkeywords = list(`author-keyword` = list(
        list(`$` = "graphene"), list(`$` = "supercapacitor")
      ))
    )
  })
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "keywords")
  expect_true("authkeywords" %in% names(ab))
  expect_equal(ab$authkeywords, "graphene; supercapacitor")
})

test_that("a single author-keyword (collapsed to a bare object) still parses", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/x"),
      authkeywords = list(`author-keyword` = list(`$` = "graphene"))
    )
  })
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "keywords")
  expect_equal(ab$authkeywords, "graphene")
})

test_that("an author-keyword entry without text is not taken for a keyword", {
  # pybliometrics issue #436: Elsevier can send an author-keyword object that
  # carries only its attribute, {"@_fa": "true"}, which gave the keyword "true".
  local_scopus_test_env()
  keywords <- NULL
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/x"), authkeywords = keywords)
  })
  keywords <- list(`author-keyword` = list(`@_fa` = "true"))
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "keywords")
  expect_true(is.na(ab$authkeywords))

  keywords <- list(`author-keyword` = list(
    list(`@_fa` = "true", `$` = "graphene"), list(`@_fa` = "true")
  ))
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "keywords")
  expect_equal(ab$authkeywords, "graphene")
})

test_that("include = 'keywords' is NA when the API omits authkeywords", {
  # Reflects a real, observed case: a key entitled for FULL view whose
  # author-keyword field still comes back empty.
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/x"))
  })
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "keywords")
  expect_true(is.na(ab$authkeywords))
})

test_that("include = 'references' under FULL view returns a structured list-column", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/x", `citedby-count` = "78713"),
      refcount = 2,
      references = list(
        list(
          `@id` = "1",
          `ref-info` = list(
            `ref-title` = list(`ref-titletext` = "ImageNet classification with deep CNNs"),
            `ref-authors` = list(author = list(
              list(`ce:surname` = "Krizhevsky", `ce:initials` = "A.")
            )),
            `ref-sourcetitle` = "Proc. NeurIPS",
            `refd-itemidlist` = list(itemid = list(
              list(`$` = "84878919540", `@idtype` = "SGR"),
              list(`$` = "10.1000/imagenet", `@idtype` = "DOI")
            )),
            `ref-publicationyear` = list(`@first` = "2012")
          )
        ),
        list(
          `@id` = "2",
          `ref-info` = list(
            `ref-title` = list(`ref-titletext` = "A second reference"),
            `ref-sourcetitle` = "Some Journal"
          )
        )
      )
    )
  })
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "references")
  expect_true("references" %in% names(ab))
  refs <- ab$references[[1]]
  expect_equal(nrow(refs), 2L)
  expect_equal(refs$title[1], "ImageNet classification with deep CNNs")
  expect_equal(refs$authors[1], "Krizhevsky, A.")
  expect_equal(refs$source[1], "Proc. NeurIPS")
  expect_equal(refs$doi[1], "10.1000/imagenet")
  expect_equal(refs$id[1], "84878919540")
  expect_equal(refs$year[1], 2012L)
  expect_true(is.na(refs$citedbycount[1]))  # FULL view: citedbycount is REF-only
})

test_that("include = 'references' under REF view uses that view's field names", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_ref(references = list(
      list(
        `@id` = "1",
        `ref-info` = list(
          `ref-title` = list(`ref-titletext` = "A REF-view reference"),
          `ce:doi` = "10.1000/refview",
          `scopus-id` = "12345",
          `ref-sourcetitle` = "Proc. Something",
          `author-list` = list(author = list(
            list(`ce:surname` = "Doe", `ce:given-name` = "A.")
          )),
          `citedby-count` = "42"
        )
      )
    ), total = 1)
  })
  ab <- scopus_abstract("10.1/x", view = "REF", include = "references")
  refs <- ab$references[[1]]
  expect_equal(nrow(refs), 1L)
  expect_equal(refs$title, "A REF-view reference")
  expect_equal(refs$doi, "10.1000/refview")
  expect_equal(refs$id, "12345")
  expect_equal(refs$authors, "Doe, A.")
  expect_equal(refs$citedbycount, 42L)
})

test_that("scopus_listify wraps a bare object and leaves an array alone", {
  listify <- scopusflow:::scopus_listify
  one <- list(`@id` = "1")
  expect_identical(listify(NULL), list())
  expect_identical(listify(one), list(one))
  expect_identical(listify(list(one, one)), list(one, one))
  expect_identical(listify(list()), list())
  expect_identical(listify(stats::setNames(list(), character())), list())
  expect_identical(listify("text"), "text")
})

test_that("an empty object adds no reference and no author", {
  # An empty JSON object carries no item. Wrapped like a bare object, it would
  # add a reference row of NAs, with a count-mismatch warning, or an author with
  # an empty name.
  local_scopus_test_env()
  empty <- stats::setNames(list(), character())
  references <- empty
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/x"), refcount = length(references),
      references = references
    )
  })
  ab <- expect_no_warning(scopus_abstract("10.1/x", view = "FULL", include = "references"))
  expect_equal(nrow(ab$references[[1]]), 0L)

  references <- list(list(`@id` = "1", `ref-info` = list(
    `ref-title` = list(`ref-titletext` = "No authors"),
    `ref-authors` = list(author = empty)
  )))
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "references")
  expect_equal(ab$references[[1]]$title, "No authors")
  expect_true(is.na(ab$references[[1]]$authors))
})

# A lone reference, or a reference with a lone author, arrives as a bare object
# (see mock_collapsed_lists()). Each used to abort the whole batch with an
# untyped "subscript out of bounds" error. pybliometrics 4.2 fixed the lone
# reference (its issue #326).
test_that("FULL-view lists collapsed to a bare object parse inside a batch", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_collapsed_lists("FULL"))
  ids <- c("10.1/arrays", "10.1/lone-reference", "10.1/lone-author")
  ab <- expect_no_warning(scopus_abstract(ids, view = "FULL", include = "references"))
  expect_equal(ab$doi, ids)
  expect_equal(vapply(ab$references, nrow, integer(1)), c(1L, 1L, 1L))
  expect_equal(ab$references[[1]]$authors, "Doe, A.; Roe, B.")
  expect_equal(ab$references[[2]]$title, "A lone reference")
  expect_equal(ab$references[[2]]$authors, "Doe, A.")
  expect_equal(ab$references[[3]]$title, "A lone author")
  expect_equal(ab$references[[3]]$authors, "Doe, A.")
})

test_that("REF-view lists collapsed to a bare object parse inside a batch", {
  local_scopus_test_env()
  httr2::local_mocked_responses(mock_collapsed_lists("REF"))
  ids <- c("10.1/arrays", "10.1/lone-reference", "10.1/lone-author")
  ab <- expect_no_warning(scopus_abstract(ids, view = "REF", include = "references"))
  expect_equal(ab$id, ids)
  expect_equal(vapply(ab$references, nrow, integer(1)), c(1L, 1L, 1L))
  expect_equal(ab$references[[1]]$authors, "Doe, A.; Roe, B.")
  expect_equal(ab$references[[2]]$title, "A lone reference")
  expect_equal(ab$references[[2]]$authors, "Doe, A.")
  expect_equal(ab$references[[3]]$title, "A lone author")
  expect_equal(ab$references[[3]]$authors, "Doe, A.")
})

test_that("a batch holding a collapsed list completes, and resumes from its checkpoints", {
  # The abort recurred on every resume, spending the request again each time.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  serve <- mock_collapsed_lists("FULL")
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    serve(req)
  })
  ids <- c("10.1/arrays", "10.1/lone-reference", "10.1/lone-author")
  first <- scopus_abstract(ids, view = "FULL", include = "references", cache_dir = cache)
  expect_equal(calls, 3L)
  expect_length(list.files(cache, pattern = "^id-FULL-references-"), 3L)

  again <- scopus_abstract(ids, view = "FULL", include = "references", cache_dir = cache)
  expect_equal(calls, 3L)
  expect_equal(again$references, first$references)
})

test_that("a reference list the parser cannot read costs its own row, not the batch", {
  # Any error while the keywords or references are parsed is raised as a typed
  # condition, which the per-identifier handler turns into an NA row with a
  # warning. Like any failed retrieval, the row is not checkpointed.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  unreadable <- list(list(
    `@id` = "1",
    `ref-info` = list(`ref-authors` = list(author = "Doe"))
  ))
  httr2::local_mocked_responses(function(req) {
    doi <- mock_request_doi(req)
    if (doi == "10.1/bad") {
      return(mock_abstract_full(
        core = list(`prism:doi` = doi), refcount = 1, references = unreadable
      ))
    }
    mock_abstract_full(core = list(`prism:doi` = doi), refcount = 0)
  })
  expect_warning(
    ab <- scopus_abstract(
      c("10.1/bad", "10.1/good"), view = "FULL", include = "references",
      cache_dir = cache
    ),
    "reference list"
  )
  expect_equal(ab$id, c("10.1/bad", "10.1/good"))
  expect_true(is.na(ab$doi[1]))
  expect_equal(ab$doi[2], "10.1/good")
  expect_equal(attr(ab, "n_requests"), 2L)
  expect_length(list.files(cache, pattern = "^id-"), 1L)

  full <- list(item = list(bibrecord = list(tail = list(bibliography = list(
    reference = unreadable
  )))))
  err <- expect_error(
    scopusflow:::scopus_abstract_row(
      "10.1/bad", list(), full = full, view = "FULL", include = "references"
    ),
    class = "scopus_error_malformed"
  )
  expect_s3_class(err, "scopus_error")
  expect_false(is.null(err$parent))
})

test_that("a document with no resolvable references yields a zero-row data frame", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(core = list(`prism:doi` = "10.1/x"), refcount = 0)
  })
  ab <- scopus_abstract("10.1/x", view = "FULL", include = "references")
  refs <- ab$references[[1]]
  expect_s3_class(refs, "data.frame")
  expect_equal(nrow(refs), 0L)
})

test_that("a reference-count mismatch warns rather than silently truncating", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_ref(references = list(
      list(`@id` = "1", `ref-info` = list(`ref-title` = list(`ref-titletext` = "Only one")))
    ), total = 103)  # claims 103 but only 1 is returned
  })
  expect_warning(
    ab <- scopus_abstract("10.1/x", view = "REF", include = "references"),
    class = "scopus_warning_incomplete_references"
  )
  expect_equal(nrow(ab$references[[1]]), 1L)
})

test_that("a response omitting its reference count is parsed, not fatal", {
  # An absent count attribute made `as.integer(NULL)` an integer(0) that the
  # mismatch guard fed straight into `if`, aborting on a zero-length condition.
  # The error was a bare simpleError, so scopus_abstract()'s per-identifier
  # handler could not catch it and one malformed document lost the whole batch.
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(list(`abstracts-retrieval-response` = list(
      references = list(reference = list(
        list(`@id` = "1", `ref-info` = list(`ref-title` = list(`ref-titletext` = "Uncounted")))
      ))
    )))
  })
  ab <- expect_no_warning(
    scopus_abstract("10.1/x", view = "REF", include = "references")
  )
  expect_equal(nrow(ab$references[[1]]), 1L)
  expect_equal(ab$references[[1]]$title, "Uncounted")
})

test_that("a FULL-view response omitting @refcount is parsed, not fatal", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/x"),
      references = list(list(
        `@id` = "1",
        `ref-info` = list(`ref-title` = list(`ref-titletext` = "Uncounted"))
      ))
    )
  })
  ab <- expect_no_warning(
    scopus_abstract("10.1/x", view = "FULL", include = "references")
  )
  expect_equal(nrow(ab$references[[1]]), 1L)
})

test_that("an entitlement 403 stops the batch with a clear, actionable message", {
  local_scopus_test_env()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_json_response(list(), status = 403L)
  })
  err <- tryCatch(
    scopus_abstract(c("10.1/a", "10.1/b", "10.1/c"), view = "FULL", include = "references"),
    error = function(e) e
  )
  expect_s3_class(err, "scopus_error_forbidden")
  expect_match(conditionMessage(err), "entitlement", ignore.case = TRUE)
  expect_match(conditionMessage(err), "FULL", fixed = TRUE)
  # Stops at the first 403 rather than repeating the same failure three times.
  expect_equal(calls, 1L)
})

test_that("a 403 suggests the fallback that suits the refused view", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) mock_json_response(list(), status = 403L))
  refusal <- function(...) {
    tryCatch(
      scopus_abstract(c("10.1/a", "10.1/b"), ...),
      scopus_error_forbidden = conditionMessage
    )
  }
  # The default, META_ABS: the request 0.4.0 made still gives the metadata.
  meta_abs <- refusal()
  expect_match(meta_abs, "view = \"META_ABS\"", fixed = TRUE)
  expect_match(meta_abs, "view = NULL", fixed = TRUE)
  expect_no_match(meta_abs, "FULL", fixed = TRUE)
  # FULL or REF: the other of the two.
  expect_match(
    refusal(view = "REF", include = "references"),
    "the other of \"FULL\"/\"REF\"", fixed = TRUE
  )
  # No view sent: the message still names the view Elsevier documents as the
  # default, since sprintf() would print nothing for NULL. It suggests neither
  # a reference view nor the request just refused.
  no_view <- refusal(view = NULL)
  expect_match(no_view, "view = \"META\"", fixed = TRUE)
  expect_no_match(no_view, "FULL", fixed = TRUE)
  expect_no_match(no_view, "view = NULL", fixed = TRUE)
})

test_that("caching writes per-identifier files and resume avoids re-fetching", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    mock_abstract(list(`prism:doi` = "10.1/a"))
  })
  scopus_abstract(c("10.1/a", "10.1/b"), cache_dir = cache, resume = TRUE)
  first_calls <- calls
  expect_equal(length(list.files(cache, pattern = "^id-")), 2L)

  ab <- scopus_abstract(c("10.1/a", "10.1/b"), cache_dir = cache, resume = TRUE)
  expect_equal(calls, first_calls)  # served from cache, no new requests
  expect_equal(nrow(ab), 2L)
})

test_that("a failed retrieval is not checkpointed, so a resumed run retries it", {
  # The all-NA row a failure degrades to keeps the batch alive, but written to
  # the cache it would be served back as data on resume, never retried.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  fail <- TRUE
  httr2::local_mocked_responses(function(req) {
    if (fail) {
      mock_json_response(list(), status = 500L)
    } else {
      mock_abstract(list(`prism:doi` = "10.1/a", `dc:title` = "Recovered"))
    }
  })

  expect_warning(
    first <- scopus_abstract("10.1/a", cache_dir = cache, resume = TRUE)
  )
  expect_true(is.na(first$title))
  expect_equal(length(list.files(cache, pattern = "^id-")), 0L)

  fail <- FALSE
  second <- scopus_abstract("10.1/a", cache_dir = cache, resume = TRUE)
  expect_equal(second$title, "Recovered")
  expect_equal(length(list.files(cache, pattern = "^id-")), 1L)
})

test_that("identifiers colliding on one cache filename are never served each other's row", {
  # scopus_safe_filename() maps every non-alphanumeric to "_", so these two
  # distinct identifiers share a checkpoint path.
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  ids <- c("10.1/a.b", "10.1/a-b")
  expect_identical(scopusflow:::scopus_safe_filename(ids[1]),
                   scopusflow:::scopus_safe_filename(ids[2]))

  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    doi <- mock_request_doi(req)
    mock_abstract(list(`prism:doi` = doi, `dc:title` = doi))
  })

  # Within one batch the second id finds the first's row in the shared file
  # and must refetch rather than serve it.
  expect_warning(
    first <- scopus_abstract(ids, cache_dir = cache, resume = TRUE),
    class = "scopus_warning_cache_mismatch"
  )
  expect_equal(calls, 2L)
  expect_equal(first$title, ids)   # each identifier got its own record

  # On resume the shared file holds the other id's row for whichever is asked,
  # so both are misses again, and neither is handed the wrong record.
  mismatches <- 0L
  withCallingHandlers(
    again <- scopus_abstract(ids, cache_dir = cache, resume = TRUE),
    scopus_warning_cache_mismatch = function(w) {
      mismatches <<- mismatches + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(mismatches, 2L)
  expect_equal(again$id, ids)
  expect_equal(again$title, ids)
})

test_that("the cache key carries the include set, so extras are not served stale", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/a"),
      authkeywords = list(`author-keyword` = list(list(`$` = "graphene")))
    )
  })
  scopus_abstract("10.1/a", view = "FULL", cache_dir = cache, resume = TRUE)
  # The same identifier with extras requested is a different cache entry, so
  # the keywords arrive rather than the cached keyword-less row being served.
  ab <- scopus_abstract(
    "10.1/a", view = "FULL", include = "keywords",
    cache_dir = cache, resume = TRUE
  )
  expect_true("authkeywords" %in% names(ab))
  expect_equal(ab$authkeywords, "graphene")
})

test_that("rows with differing columns are filled to the union, not a bind error", {
  local_scopus_test_env()
  cache <- withr::local_tempdir()
  httr2::local_mocked_responses(function(req) {
    mock_abstract_full(
      core = list(`prism:doi` = "10.1/b"),
      authkeywords = list(`author-keyword` = list(list(`$` = "graphene")))
    )
  })
  # A hand-migrated or legacy cache entry can hold a row with fewer columns
  # than a freshly fetched one; the batch must bind on the column union
  # rather than erroring, as scopus_bind_records() already does for plans.
  legacy <- scopusflow:::scopus_abstract_row("10.1/a", list())
  saveRDS(legacy, file.path(
    cache,
    sprintf("id-FULL-keywords-%s.rds", scopusflow:::scopus_safe_filename("10.1/a"))
  ))
  ab <- scopus_abstract(
    c("10.1/a", "10.1/b"), view = "FULL", include = "keywords",
    cache_dir = cache, resume = TRUE
  )
  expect_equal(nrow(ab), 2L)
  expect_true(is.na(ab$authkeywords[1]))
  expect_equal(ab$authkeywords[2], "graphene")
})

test_that("n_requests and quota are attached, since this is quota-costly per document", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_json_response(
      list(`abstracts-retrieval-response` = list(coredata = list(`prism:doi` = "10.1/a"))),
      headers = list(`X-RateLimit-Remaining` = "4321")
    )
  })
  ab <- scopus_abstract(c("10.1/a", "10.1/b"))
  expect_equal(attr(ab, "n_requests"), 2L)
  expect_equal(attr(ab, "quota")$remaining, 4321)
})
