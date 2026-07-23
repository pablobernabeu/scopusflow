# Builds the bundled `example_records` dataset.
#
# The records are real publications on graphene supercapacitors. They are NOT
# retrieved from 'Scopus': the Elsevier API terms do not permit redistributing
# retrieved records, so no package can ship a genuine 'Scopus' harvest. They come
# instead from OpenAlex, whose metadata is released under CC0 and so may be
# redistributed, and are reshaped into the schema `scopus_fetch()` returns. That
# gives the examples real titles, real DOIs, real journals and real citation
# counts without breaching a licence.
#
# Retrieval, 2026-07-22, the complete result set for
#   filter=title_and_abstract.search:"graphene supercapacitor",
#          publication_year:2015-2024,
#          type:article
# 138 records. The harvest is complete rather than sampled, so the number of rows
# per year is the real number of publications per year for that query and the
# trend figures show a real publication curve. Eleven records carry no DOI and
# two no source title, exactly as they arrive; those gaps are left in place
# because a real harvest has them.
#
# `example_records.csv` is committed beside this script so the dataset rebuilds
# without network access. It is the same file the Python twin ships at
# src/scopusflow/data/example_records.csv; refresh the two together.
#
# Run with: source("data-raw/example_records.R")

pkgload::load_all(quiet = TRUE)

csv_path <- "data-raw/example_records.csv"

# Set to TRUE to re-query OpenAlex and rewrite the CSV before rebuilding.
refresh <- FALSE

if (isTRUE(refresh)) {
  query <- paste0(
    "https://api.openalex.org/works",
    "?filter=title_and_abstract.search:%22graphene%20supercapacitor%22",
    ",publication_year:2015-2024,type:article",
    "&per-page=200&sort=publication_date:asc",
    "&select=id,doi,display_name,publication_year,publication_date,",
    "primary_location,cited_by_count,authorships",
    "&mailto=pcbernabeu@gmail.com"
  )
  works <- jsonlite::fromJSON(query, simplifyVector = FALSE)[["results"]]
  blank_to_na <- function(x) if (is.null(x) || !nzchar(x)) NA_character_ else x
  # Publishers put inline markup in titles for subscripts, superscripts and
  # italics, and it arrives both as real tags and as half-escaped "$lt;inf$gt;"
  # text; neither belongs in a printed record. U+2010 is a hyphen visually
  # identical to the ASCII one, so it is normalised rather than left to split
  # the column between two indistinguishable characters. Author names are not
  # touched: their accents and non-Latin scripts are part of the name.
  tidy_title <- function(x) {
    if (is.na(x)) return(x)
    x <- gsub("</?(sub|sup|inf|i|b|em|strong)>|\\$lt;/?[a-z]+\\$gt;", "", x,
              ignore.case = TRUE, perl = TRUE)
    x <- gsub("‐", "-", x, fixed = TRUE)
    trimws(gsub("[[:space:]]{2,}", " ", x))
  }
  first_author <- function(w) {
    a <- w[["authorships"]]
    if (length(a) == 0L) NA_character_ else blank_to_na(a[[1L]][["author"]][["display_name"]])
  }
  source_name <- function(w) {
    s <- w[["primary_location"]][["source"]]
    if (is.null(s)) NA_character_ else blank_to_na(s[["display_name"]])
  }
  frame <- data.frame(
    entry_number = seq_along(works),
    scopus_id = NA_character_,
    doi = vapply(works, function(w) {
      sub("^https://doi.org/", "", blank_to_na(w[["doi"]]))
    }, character(1)),
    title = vapply(works, function(w) tidy_title(blank_to_na(w[["display_name"]])), character(1)),
    authors = vapply(works, first_author, character(1)),
    year = vapply(works, function(w) as.integer(w[["publication_year"]]), integer(1)),
    date = vapply(works, function(w) blank_to_na(w[["publication_date"]]), character(1)),
    publication = vapply(works, source_name, character(1)),
    citations = vapply(works, function(w) as.integer(w[["cited_by_count"]]), integer(1)),
    query = "graphene supercapacitor",
    stringsAsFactors = FALSE
  )
  utils::write.csv(frame, csv_path, row.names = FALSE, na = "")
}

raw <- utils::read.csv(csv_path, colClasses = "character", na.strings = "",
                       fileEncoding = "UTF-8")

# U+2010 HYPHEN is a distinct code point that renders identically to the ASCII
# hyphen-minus, and the source uses the two interchangeably in both titles and
# author names. Normalise it so one visible character is not stored two ways.
# Everything else non-ASCII is left exactly as it arrives: the accents, the
# Cyrillic and the en dashes belong to real people's names and real titles, and
# transliterating them would misspell published work.
unify_hyphen <- function(x) gsub("‐", "-", x, fixed = TRUE)

# The remaining non-ASCII strings must be MARKED as UTF-8, not left in the
# session's native encoding. Unmarked non-ASCII in a shipped dataset is
# ambiguous across locales and R CMD check flags it; marked UTF-8 is portable
# and reduces the check to the routine "marked UTF-8 strings" note.
as_utf8 <- function(x) {
  x <- unify_hyphen(x)
  x <- enc2utf8(x)
  Encoding(x) <- ifelse(is.na(x), "unknown", "UTF-8")
  x
}

example_records <- tibble::new_tibble(
  list(
    entry_number = as.integer(raw$entry_number),
    # Empty by construction: these records did not come from 'Scopus', so they
    # carry no 'Scopus' identifier. De-duplication falls back to the DOI.
    scopus_id = rep(NA_character_, nrow(raw)),
    doi = as_utf8(raw$doi),
    title = as_utf8(raw$title),
    authors = as_utf8(raw$authors),
    year = as.integer(raw$year),
    date = as_utf8(raw$date),
    publication = as_utf8(raw$publication),
    citations = as.integer(raw$citations),
    query = as_utf8(raw$query)
  ),
  nrow = nrow(raw),
  class = "scopus_records"
)

stopifnot(
  identical(names(example_records), scopusflow:::scopus_records_columns()),
  nrow(example_records) == 138L
)

save(example_records, file = "data/example_records.rda", version = 2, compress = "xz")
