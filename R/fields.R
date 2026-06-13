#' Recognised 'Scopus' field tags
#'
#' Lists the field tags that [scopus_plan()], [scopus_fetch()] and
#' [scopus_compare_topics()] understand, together with a short note on what each
#' one searches. Passing one of these tags as `field` restricts a query to the
#' corresponding part of a record, so `TITLE-ABS-KEY` looks in the title,
#' abstract and keywords while `AUTH` looks only at author names. Other valid
#' 'Scopus' tags are accepted too. This is a guide to the common ones.
#'
#' @return A [tibble][tibble::tibble] with a `tag` column and a `searches` column
#'   describing the scope of each tag.
#' @seealso [scopus_plan()]
#' @examples
#' scopus_field_tags()
#' @export
scopus_field_tags <- function() {
  tibble::tibble(
    tag = c(
      "TITLE", "TITLE-ABS-KEY", "TITLE-ABS-KEY-AUTH", "ABS", "KEY", "AUTH",
      "AUTHKEY", "AFFIL", "AFFILORG", "SRCTITLE", "DOI", "ALL"
    ),
    searches = c(
      "Words in the document title",
      "Title, abstract and keywords",
      "Title, abstract, keywords and author names",
      "Abstract text",
      "Indexed and author keywords",
      "Author names",
      "Author-supplied keywords",
      "Affiliation, any part",
      "Affiliation organisation name",
      "Source (publication) title",
      "Digital Object Identifier",
      "All available fields"
    )
  )
}
