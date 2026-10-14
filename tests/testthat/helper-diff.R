# Two pulls of one search for the change-tracking tests. Rows 1 to 7 are the
# earlier pull and rows 8 to 15 the later one. Their records carry 'Scopus'
# identifiers, which the bundled corpus lacks, alongside records from another
# source that carry none, DOIs spelled as other sources spell them, a record
# re-indexed under a new identifier and records with neither key. The file is
# byte-identical to the Python twin's tests/fixtures/diff-fixture.csv, whose
# suite asserts the same results.
diff_fixture <- function() {
  fx <- read_scopus_records(test_path("fixtures", "diff-fixture.csv"))
  list(old = fx[1:7, ], new = fx[8:15, ])
}

# What printing `x` shows, on one line. cli wraps a header line longer than
# the console, so a phrase can break across lines anywhere.
printed <- function(x) {
  gsub("\\s+", " ", paste(utils::capture.output(print(x)), collapse = " "))
}

# A collation that sorts letters regardless of case, as English locales do,
# or NULL where the machine offers none. testthat runs every test under the C
# collation, so an order() that follows the locale passes there and only a
# test that sets another collation shows the difference.
case_blind_collation <- function() {
  candidates <- c("en_GB.UTF-8", "en_US.UTF-8", "English_United Kingdom.utf8",
                  "English_United Kingdom", "English_United States", "en_GB",
                  "en_US")
  for (loc in candidates) {
    blind <- suppressWarnings(
      withr::with_collate(loc, identical(order(c("a", "B")), 1:2))
    )
    if (isTRUE(blind)) return(loc)
  }
  NULL
}
