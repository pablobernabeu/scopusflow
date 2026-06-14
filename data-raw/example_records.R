# Builds the bundled `example_records` dataset from the static page fixture, so
# the data is reproducible from source. Run with: source("data-raw/example_records.R")

pkgload::load_all(quiet = TRUE)

fixture <- system.file("extdata", "scopus_page.json", package = "scopusflow")
parsed <- jsonlite::fromJSON(fixture, simplifyVector = FALSE)

example_records <- scopus_records(
  parsed[["search-results"]],
  query = "illustrative multi-disciplinary sample"
)

save(example_records, file = "data/example_records.rda", version = 2, compress = "xz")
