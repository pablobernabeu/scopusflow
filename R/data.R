#' Example set of normalised 'Scopus' records
#'
#' A small set of three records in the shape that [scopus_fetch()] returns,
#' provided so that the package can be explored and its examples run without a
#' 'Scopus' API key. The records were normalised from the static page fixture
#' bundled in `inst/extdata`.
#'
#' @format A [scopus_records] tibble with three rows and the standard schema:
#' \describe{
#'   \item{entry_number}{Position within the retrieval.}
#'   \item{scopus_id}{The 'Scopus' record identifier.}
#'   \item{doi}{Digital Object Identifier.}
#'   \item{title}{Document title.}
#'   \item{authors}{First or corresponding author.}
#'   \item{year}{Publication year.}
#'   \item{date}{Cover date in ISO form.}
#'   \item{publication}{Source title.}
#'   \item{citations}{Citation count.}
#'   \item{query}{The query that produced the record.}
#' }
#' @source Synthetic example data, illustrative only.
#' @examples
#' example_records
#' summary(example_records)
"example_records"
