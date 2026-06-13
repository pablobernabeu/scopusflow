test_that("scopus_field_tags returns a documented reference", {
  ft <- scopus_field_tags()
  expect_s3_class(ft, "tbl_df")
  expect_named(ft, c("tag", "searches"))
  expect_true(all(c("TITLE", "TITLE-ABS-KEY", "AUTH") %in% ft$tag))
  expect_true(all(nzchar(ft$searches)))
})

test_that("the listed tags are all accepted by scopus_plan", {
  for (tag in scopus_field_tags()$tag) {
    expect_s3_class(scopus_plan("x", field = tag), "scopus_plan")
  }
})
