test_that("scopus_abstract returns the abstract and core metadata", {
  local_scopus_test_env()
  httr2::local_mocked_responses(function(req) {
    mock_abstract(list(
      `dc:identifier` = "SCOPUS_ID:85000000001",
      `prism:doi` = "10.1038/s41586-019-0001-1",
      `dc:title` = "Genome editing with CRISPR-Cas9",
      `dc:description` = "We review the principles and applications of CRISPR-Cas9.",
      `prism:publicationName` = "Nature",
      `prism:coverDate` = "2019-04-12",
      `citedby-count` = "540"
    ))
  })
  ab <- scopus_abstract("10.1038/s41586-019-0001-1")
  expect_s3_class(ab, "scopus_abstracts")
  expect_equal(nrow(ab), 1L)
  expect_equal(ab$doi, "10.1038/s41586-019-0001-1")
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
