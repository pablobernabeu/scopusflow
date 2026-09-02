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

test_that("an HTTP-date retry_after is read whatever the session's LC_TIME is", {
  resp <- httr2::response(
    status_code = 429L,
    headers = list(`Retry-After` = "Tue, 15 Nov 2044 08:12:31 GMT")
  )
  target <- as.POSIXct("2044-11-15 08:12:31", tz = "GMT")
  seconds_away <- function() {
    as.numeric(difftime(target, Sys.time(), units = "secs"))
  }
  expect_equal(scopus_quota(resp)$retry_after, seconds_away(), tolerance = 1e-4)

  # The header is English by RFC 7231, so a session whose LC_TIME is not English
  # has to read it too. Only the C locales are installed on some machines.
  withr::local_locale(c(LC_TIME = "C"))
  candidates <- c("fr_FR.UTF-8", "de_DE.UTF-8", "es_ES.UTF-8")
  installed <- Filter(
    function(l) !identical(suppressWarnings(Sys.setlocale("LC_TIME", l)), ""),
    candidates
  )
  skip_if(length(installed) == 0L, "no non-English LC_TIME locale is installed")
  Sys.setlocale("LC_TIME", installed[[1]])
  expect_equal(scopus_quota(resp)$retry_after, seconds_away(), tolerance = 1e-4)
})

test_that("non-response input is rejected", {
  expect_error(scopus_quota(list()), class = "scopus_error_bad_input")
})
