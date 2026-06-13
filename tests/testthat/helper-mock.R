# Test helpers for offline HTTP mocking. No test in this suite touches the
# network: every request is intercepted by httr2::local_mocked_responses().

# A configured key + fast, deterministic retries for the duration of a test.
local_scopus_test_env <- function(.env = parent.frame()) {
  withr::local_options(
    list(
      scopusflow.api_key = "test-key",
      scopusflow.max_tries = 3L,
      scopusflow.retry_backoff = function(i) 0
    ),
    .local_envir = .env
  )
  withr::local_envvar(c(SCOPUS_INST_TOKEN = ""), .local_envir = .env)
}

# Build a mock httr2 response carrying a JSON body and optional headers.
mock_json_response <- function(body, status = 200L, headers = list()) {
  hdrs <- utils::modifyList(list(`Content-Type` = "application/json"), headers)
  httr2::response(
    status_code = status,
    headers = hdrs,
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE))
  )
}

# A Scopus "search-results" envelope with the given entries and total.
mock_search_results <- function(entries, total = length(entries),
                                status = 200L, headers = list()) {
  body <- list(`search-results` = list(
    `opensearch:totalResults` = as.character(total),
    entry = entries
  ))
  mock_json_response(body, status = status, headers = headers)
}

# Generate `n` synthetic entries with sequential ids and DOIs.
mock_entries <- function(n, offset = 0L) {
  lapply(seq_len(n), function(i) {
    k <- i + offset
    list(
      `dc:identifier` = paste0("SCOPUS_ID:", 85000000000 + k),
      `prism:doi` = sprintf("10.1000/mock.%04d", k),
      `dc:title` = sprintf("Mock article %d", k),
      `dc:creator` = "Tester T.",
      `prism:publicationName` = "Journal of Mocking",
      `prism:coverDate` = sprintf("20%02d-01-01", (k %% 20) + 1),
      `citedby-count` = as.character(k)
    )
  })
}

# A mock that serves a virtual corpus of `total` records, honouring the
# `start`/`count` paging parameters of each incoming request.
mock_corpus <- function(total, headers = list()) {
  function(req) {
    q <- httr2::url_parse(req$url)$query
    start <- as.integer(if (is.null(q$start)) 0L else q$start)
    count <- as.integer(if (is.null(q$count)) 25L else q$count)
    avail <- max(0L, total - start)
    n <- min(count, avail)
    entries <- if (n > 0L) mock_entries(n, offset = start) else {
      list(list(error = "Result set was empty"))
    }
    mock_search_results(entries, total = total, headers = headers)
  }
}

# Load the bundled static page fixture as a parsed list.
load_page_fixture <- function() {
  path <- system.file("extdata", "scopus_page.json", package = "scopusflow")
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}
