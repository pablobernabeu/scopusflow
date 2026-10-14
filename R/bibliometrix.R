#' Convert records to a bibliometrix-compatible data frame
#'
#' Re-maps a [scopus_records] tibble to the tagged column layout used by the
#' \pkg{bibliometrix} package (and the wider ISI/Web of Science convention), so
#' results can flow into downstream science-mapping workflows. The fields
#' follow the conventions `bibliometrix::convert2df()` applies to a 'Scopus'
#' CSV export, so the two frames describe a record in the same terms.
#'
#' @param x A [scopus_records] tibble.
#' @return A data frame (classed `bibliometrixDB`) with the standard tag columns
#'   `AU` (authors), `TI` (title), `SO` (source or publication), `DI` (DOI), `PY`
#'   (publication year), `TC` (times cited), `UT` (the record's EID) and `DB`
#'   (`"SCOPUS"`). `DE` (author keywords) follows when the set carries the
#'   `authkeywords` column of a `view = "COMPLETE"` retrieval. `DT` (document
#'   type), `VL` (volume) and `IS` (issue) follow when it carries the columns
#'   of a `fields = "extended"` retrieval (see [scopus_records()]). Character
#'   tag fields other than `DI` are upper-cased, as bibliometrix upper-cases
#'   them.
#' @details
#' Each author in `AU` is written as bibliometrix writes a 'Scopus' author,
#' the surname followed by the initials without full stops. The authors are
#' joined by `";"`. A name in the `"Surname, Given"` form the `COMPLETE` view
#' gives becomes the surname followed by the initial of each given name, and a
#' hyphenated given name keeps its hyphen. `"Tour, James M."` thus becomes
#' `"TOUR JM"` and `"Lee, Chul-Hee"` becomes `"LEE C-H"`. A name without a
#' comma, such as the `STANDARD` view's `"Lee C.-H."`, loses its full stops
#' and becomes `"LEE C-H"`. Each given name yields one initial, so a name
#' that 'Scopus' abbreviates to two letters, such as `"Yu."` for Yuri, keeps
#' both under `STANDARD` and gives one under `COMPLETE`.
#'
#' `UT` holds the EID, `"2-S2.0-"` followed by the 'Scopus' identifier, as a
#' 'Scopus' import gives it, and is `NA` for a record without an identifier.
#' `sub("^2-S2.0-", "", UT)` gives back the bare identifier. `DE` holds the
#' author keywords joined by `"; "`, as in a 'Scopus' CSV export. Keywords are
#' split at the `" | "` the Search API joins them with and at the `"; "`
#' [scopus_abstract()] joins its own with, so either source can fill the
#' `authkeywords` column.
#'
#' This produces the *shape* bibliometrix expects from the descriptive
#' fields. It reconstructs only what the 'Scopus' Search API returns, so richer
#' fields that some bibliometrix analyses use, such as full author affiliations
#' or cited references, are left out. To obtain those, export a full 'Scopus'
#' CSV or BibTeX file from the web interface and read it with
#' `bibliometrix::convert2df()`.
#'
#' `AU` holds every author only for a retrieval made with
#' `view = "COMPLETE"`. Under `STANDARD` the API sends the first author alone,
#' so each document would look single-authored to the collaboration measures
#' and co-authorship networks bibliometrix builds from `AU`. Converting a set
#' retrieved under `STANDARD` therefore raises a warning of class
#' `scopus_warning_first_author_only`, once per session (see
#' [scopus_records()]).
#' @examples
#' # On the bundled corpus of real articles, which stands in for a retrieval
#' # of your own because 'Scopus' records may not be redistributed.
#' m <- as_bibliometrix(example_records)
#' head(m[, c("AU", "TI", "PY", "SO", "TC", "DB")])
#' @export
as_bibliometrix <- function(x) {
  if (!is_scopus_records(x)) {
    scopus_abort_bad_input(
      "`x` must be a `scopus_records` object."
    )
  }
  scopus_warn_first_author_only(x)
  up <- function(v) toupper(as.character(v))
  out <- data.frame(
    AU = vapply(x$authors, scopus_bibliometrix_authors, character(1), USE.NAMES = FALSE),
    TI = up(x$title),
    SO = up(x$publication),
    DI = x$doi,
    PY = x$year,
    TC = x$citations,
    UT = scopus_bibliometrix_eid(x$scopus_id),
    DB = "SCOPUS",
    stringsAsFactors = FALSE
  )
  if ("authkeywords" %in% names(x)) {
    out$DE <- vapply(x$authkeywords, function(k) {
      k <- scopus_refman_keywords(k)
      if (length(k) == 0L) NA_character_ else toupper(paste(k, collapse = "; "))
    }, character(1), USE.NAMES = FALSE)
  }
  if ("doc_type_description" %in% names(x)) out$DT <- up(x$doc_type_description)
  if ("volume" %in% names(x)) out$VL <- up(x$volume)
  if ("issue" %in% names(x)) out$IS <- up(x$issue)
  class(out) <- c("bibliometrixDB", "data.frame")
  out
}

# One record's authors as bibliometrix's AU: each name as the surname and
# initials without full stops (see as_bibliometrix()), joined by ";", which is
# how bibliometrix::convert2df() joins the authors of a 'Scopus' import.
scopus_bibliometrix_authors <- function(authors) {
  names <- scopus_refman_authors(authors)
  if (length(names) == 0L) {
    return(NA_character_)
  }
  paste(vapply(names, scopus_bibliometrix_name, character(1), USE.NAMES = FALSE),
        collapse = ";")
}

# bibliometrix strips the full stops and commas from a 'Scopus' CSV author
# ("Lee C.-H." to "LEE C-H"). A "Surname, Given" name from the COMPLETE view
# would lose its comma the same way and read as bibliometrix's full-name form,
# the given names spelled out ("PENG ZHIWEI"). Its given names are therefore
# reduced to their initials first, and each part of a hyphenated name keeps its
# hyphen.
scopus_bibliometrix_name <- function(name) {
  name <- scopus_refman_clean(name)
  pos <- regexpr(",", name, fixed = TRUE)
  if (pos > 0L) {
    surname <- substr(name, 1L, pos - 1L)
    given <- strsplit(trimws(gsub("[.,]", " ", substring(name, pos + 1L))), " +")[[1]]
    given <- given[nzchar(given)]
    initials <- vapply(strsplit(given, "-", fixed = TRUE), function(parts) {
      paste(substr(parts, 1L, 1L), collapse = "-")
    }, character(1))
    name <- paste(surname, paste(initials, collapse = ""))
  } else {
    name <- gsub(".", "", name, fixed = TRUE)
  }
  toupper(trimws(gsub(" +", " ", name)))
}

# The EID bibliometrix gives a 'Scopus' record in UT, upper-cased as it
# upper-cases every field. A missing or blank identifier stays NA, since the
# prefix alone identifies nothing.
scopus_bibliometrix_eid <- function(id) {
  id <- trimws(as.character(id))
  out <- rep(NA_character_, length(id))
  ok <- !is.na(id) & nzchar(id)
  out[ok] <- toupper(paste0("2-s2.0-", id[ok]))
  out
}
