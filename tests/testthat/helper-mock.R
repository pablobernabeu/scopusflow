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

# A corpus served under either paging mode: by cursor when a request carries
# one, by offset otherwise. A plan can then be fetched both ways from one mock.
mock_paged_corpus <- function(total) {
  by_offset <- mock_corpus(total)
  by_cursor <- mock_cursor_corpus(total)
  function(req) {
    if (is.null(httr2::url_parse(req$url)$query$cursor)) by_offset(req) else by_cursor(req)
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

# An Abstract Retrieval response carrying the full top-level shape (coredata
# plus, optionally, authkeywords and a FULL-view bibliography), for view =
# "FULL" tests.
mock_abstract_full <- function(core = list(), authkeywords = NULL,
                               references = NULL, refcount = NULL, status = 200L) {
  full <- list(coredata = core)
  if (!is.null(authkeywords)) full$authkeywords <- authkeywords
  if (!is.null(references) || !is.null(refcount)) {
    bib <- list()
    if (!is.null(refcount)) bib[["@refcount"]] <- as.character(refcount)
    if (!is.null(references)) bib$reference <- references
    full$item <- list(bibrecord = list(tail = list(bibliography = bib)))
  }
  mock_json_response(
    list(`abstracts-retrieval-response` = full),
    status = status
  )
}

# An Abstract Retrieval response under view = "REF": only `references`, no
# `coredata`, matching this view's distinct, leaner top-level shape.
mock_abstract_ref <- function(references = list(), total = length(references), status = 200L) {
  mock_json_response(
    list(`abstracts-retrieval-response` = list(references = list(
      `@total-references` = as.character(total),
      reference = references
    ))),
    status = status
  )
}

# A REF-view server that pages a bibliography of `total` references, numbered
# "1" to `total` in `@id`, `page_size` at a time. `startref` is read as
# one-based, as pybliometrics reads it (its live test fetches 48 of 48 with
# startref = 41 after a page of 40). `base = 0L` reads it as zero-based, as the
# Scopus API Guide states, and `ignore_startref = TRUE` serves the first page
# whatever is asked. Every request URL is appended to `log$urls`, so a test can
# check which pages were asked for.
mock_ref_pages <- function(total, page_size = 40L, base = 1L,
                           ignore_startref = FALSE, log = new.env()) {
  log$urls <- character()
  function(req) {
    log$urls <- c(log$urls, req$url)
    startref <- httr2::url_parse(req$url)$query$startref
    first <- if (is.null(startref) || ignore_startref) {
      1L
    } else {
      as.integer(startref) + (1L - base)
    }
    positions <- seq.int(first, length.out = max(0L, min(page_size, total - first + 1L)))
    references <- lapply(positions, function(i) {
      list(`@id` = as.character(i), `ref-info` = list(
        `ref-title` = list(`ref-titletext` = paste("Reference", i))
      ))
    })
    mock_abstract_ref(references = references, total = total)
  }
}

# The DOI an Abstract Retrieval request asks for, read from the request path,
# so the query string the request also carries does not leak into it.
mock_request_doi <- function(req) {
  utils::URLdecode(sub("^.*/doi/", "", httr2::url_parse(req$url)$path))
}

# Abstract Retrieval responses for a batch of three DOIs under view "FULL" or
# "REF". Elsevier's XML-to-JSON conversion sends a one-item array as a bare
# object. "10.1/lone-reference" carries its only reference that way,
# "10.1/lone-author" a reference whose only author arrives that way, and
# "10.1/arrays" keeps both lists as arrays.
mock_collapsed_lists <- function(view) {
  given <- if (identical(view, "REF")) "ce:given-name" else "ce:initials"
  author <- function(surname, initials) {
    stats::setNames(list(surname, initials), c("ce:surname", given))
  }
  reference <- function(title, authors) {
    info <- list(`ref-title` = list(`ref-titletext` = title))
    list_name <- if (identical(view, "REF")) "author-list" else "ref-authors"
    info[[list_name]] <- list(author = authors)
    list(`@id` = "1", `ref-info` = info)
  }
  doe <- author("Doe", "A.")
  roe <- author("Roe", "B.")
  references <- list(
    `10.1/arrays` = list(reference("Two authors", list(doe, roe))),
    `10.1/lone-reference` = reference("A lone reference", list(doe)),
    `10.1/lone-author` = list(reference("A lone author", doe))
  )
  function(req) {
    doi <- mock_request_doi(req)
    if (identical(view, "REF")) {
      mock_abstract_ref(references = references[[doi]], total = 1)
    } else {
      mock_abstract_full(
        core = list(`prism:doi` = doi), refcount = 1, references = references[[doi]]
      )
    }
  }
}

# Load the bundled static page fixture as a parsed list.
load_page_fixture <- function() {
  path <- system.file("extdata", "scopus_page.json", package = "scopusflow")
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

# The COMPLETE-view entry the Python suite reads too, byte for byte, with the
# authors string and the first-author warning both twins must produce.
complete_authors_fixture <- function() {
  jsonlite::fromJSON(test_path("fixtures", "complete-authors.json"),
                     simplifyVector = FALSE)
}

# Parse one Search API entry from JSON, as a response body is parsed.
parse_entry <- function(json) {
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

# One synthetic record as the STANDARD and the COMPLETE view return it, with
# the row both twins build from it under fields = "extended". The Python suite
# reads the same file, byte for byte.
extended_fixture <- function() {
  jsonlite::fromJSON(test_path("fixtures", "extended-entry.json"),
                     simplifyVector = FALSE)
}

# Check a one-row record set against a row read from that fixture: the same
# columns in the same order, whole numbers as integers and a JSON null as a
# missing value.
expect_record_row <- function(recs, expected) {
  expect_identical(names(recs), names(expected))
  for (col in names(expected)) {
    want <- expected[[col]]
    if (is.null(want)) {
      expect_true(is.na(recs[[col]]), info = col)
    } else if (is.numeric(want)) {
      expect_identical(recs[[col]], as.integer(want), info = col)
    } else {
      expect_identical(recs[[col]], want, info = col)
    }
  }
}
