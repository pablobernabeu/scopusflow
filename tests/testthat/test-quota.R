test_that("scopus_quota parses rate-limit headers", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list(
      `X-RateLimit-Limit` = "20000",
      `X-RateLimit-Remaining` = "19987",
      `X-RateLimit-Reset` = "1700000000",
      `X-ELS-Status` = "OK"
    )
  )
  q <- scopus_quota(resp)
  expect_equal(q$limit, 20000)
  expect_equal(q$remaining, 19987)
  expect_s3_class(q$reset, "POSIXct")
  expect_equal(as.numeric(q$reset), 1700000000)
  expect_equal(q$status, "OK")
})

test_that("missing headers yield NA", {
  resp <- httr2::response(status_code = 200L)
  q <- scopus_quota(resp)
  expect_true(is.na(q$limit))
  expect_true(is.na(q$remaining))
  expect_true(is.na(q$reset))
  expect_true(is.na(q$retry_after))
})

test_that("retry_after is parsed when present", {
  resp <- httr2::response(status_code = 429L, headers = list(`Retry-After` = "7"))
  q <- scopus_quota(resp)
  expect_equal(q$retry_after, 7)
})

test_that("non-response input is rejected", {
  expect_error(scopus_quota(list()), class = "scopus_error_bad_input")
})
