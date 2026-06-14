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

test_that("invalid input is rejected", {
  expect_error(scopus_query(), class = "scopus_error_bad_input")
  expect_error(scopus_query(""), class = "scopus_error_bad_input")
  expect_error(scopus_query("a", .field = "bad tag"), class = "scopus_error_bad_input")
  expect_error(scopus_query("a", .op = "XOR"))
})
