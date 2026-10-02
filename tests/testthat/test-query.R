test_that("scopus_query joins and field-wraps terms", {
  expect_equal(
    scopus_query("language learning", "effect size", .field = "TITLE-ABS-KEY"),
    "TITLE-ABS-KEY(language learning) AND TITLE-ABS-KEY(effect size)"
  )
  expect_equal(scopus_query("CRISPR", "Cas9", .op = "OR"), "CRISPR OR Cas9")
  expect_equal(scopus_query("a", "b", .op = "AND NOT"), "a AND NOT b")
})

test_that("a single term is returned wrapped", {
  expect_equal(scopus_query("x", .field = "TITLE"), "TITLE(x)")
})

# The fixture is shared byte for byte with the Python suite, so both twins are
# held to one set of expected strings. A term written as an object stands for
# the scopus_query() call that produces it. The needs_group cases belong to the
# Python year fold and are not read here.
grouping_fixture_query <- function(case) {
  terms <- vapply(case$terms, function(term) {
    if (is.list(term)) grouping_fixture_query(term) else term
  }, character(1))
  do.call(scopus_query, c(as.list(terms), list(.op = case$op, .field = case$field)))
}

test_that("scopus_query matches the shared grouping fixture", {
  # Scopus joins the words of an unquoted term with AND, so a bare join of
  # multi-word terms regrouped them: "machine learning OR deep learning" read
  # as machine AND (learning OR deep) AND learning.
  fixture <- jsonlite::fromJSON(
    test_path("fixtures", "query-grouping.json"),
    simplifyVector = FALSE
  )
  expect_gt(length(fixture$scopus_query), 0L)
  for (case in fixture$scopus_query) {
    expect_identical(grouping_fixture_query(case), case$expected, label = case$id)
  }
})

test_that("terms are trimmed as the Python twin trims them", {
  expect_identical(scopus_query(" a ", "b"), "a AND b")
  expect_identical(scopus_query(" a ", .field = "TITLE"), "TITLE(a)")
  # Python's str.strip() also removes the no-break space, the ideographic space,
  # the form feed and the vertical tab, which trimws() keeps by default. A term
  # made of them alone is empty in both twins.
  expect_identical(scopus_query("\u00a0a\u3000", "\fb\v"), "a AND b")
  expect_identical(scopus_query("\u00a0a b", .field = "TITLE"), "TITLE(a b)")
  expect_error(scopus_query("\u00a0", "b"), class = "scopus_error_bad_input")
})

test_that("invalid input is rejected", {
  expect_error(scopus_query(), class = "scopus_error_bad_input")
  expect_error(scopus_query(""), class = "scopus_error_bad_input")
  expect_error(scopus_query("a", .field = "bad tag"), class = "scopus_error_bad_input")
  expect_error(scopus_query("a", .op = "XOR"))
})
