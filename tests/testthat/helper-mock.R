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

# A mock corpus served via cursor pagination: each response carries the next
# cursor until the corpus is exhausted.
mock_cursor_corpus <- function(total) {
  function(req) {
    q <- httr2::url_parse(req$url)$query
    count <- as.integer(if (is.null(q$count)) 25L else q$count)
    cur <- q$cursor
    offset <- if (is.null(cur) || identical(cur, "*")) 0L else as.integer(cur)
    avail <- max(0L, total - offset)
    n <- min(count, avail)
    entries <- if (n > 0L) mock_entries(n, offset = offset) else {
      list(list(error = "Result set was empty"))
    }
    next_off <- offset + n
    cursor <- if (next_off < total && n > 0L) {
      list(`@next` = as.character(next_off))
    } else {
      list()
    }
    body <- list(`search-results` = list(
      `opensearch:totalResults` = as.character(total),
      entry = entries,
      cursor = cursor
    ))
    mock_json_response(body)
  }
}

# A misbehaving cursor mock that NEVER signals the end: every page is full and
# carries a fresh, ever-advancing `@next`, and no total is reported. Only the
# package's own page ceiling can stop a fetch against this.
mock_cursor_runaway <- function() {
  function(req) {
    q <- httr2::url_parse(req$url)$query
    count <- as.integer(if (is.null(q$count)) 25L else q$count)
    cur <- q$cursor
    offset <- if (is.null(cur) || identical(cur, "*")) 0L else as.integer(cur)
    body <- list(`search-results` = list(
      # No opensearch:totalResults, so the total stays unknown.
      entry = mock_entries(count, offset = offset),
      cursor = list(`@next` = as.character(offset + count))
    ))
    mock_json_response(body)
  }
}

# An Abstract Retrieval response carrying the given coredata.
mock_abstract <- function(core, status = 200L) {
  mock_json_response(
    list(`abstracts-retrieval-response` = list(coredata = core)),
    status = status
  )
}

# Load the bundled static page fixture as a parsed list.
load_page_fixture <- function() {
  path <- system.file("extdata", "scopus_page.json", package = "scopusflow")
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}
