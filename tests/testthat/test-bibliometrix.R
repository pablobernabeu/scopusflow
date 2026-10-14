test_that("as_bibliometrix carries a COMPLETE author list into AU", {
  # Every record used to look single-authored, because AU was read from
  # dc:creator, and bibliometrix's collaboration measures and co-authorship
  # networks were then built on first authors alone.
  fx <- complete_authors_fixture()
  recs <- scopus_records(list(entry = list(fx$entry)), view = "COMPLETE")
  expect_identical(as_bibliometrix(recs)$AU, "CONG L;ZHANG F;DOUDNA JA")
})

test_that("as_bibliometrix says once that a STANDARD set names first authors only", {
  rlang::reset_warning_verbosity("scopusflow_first_author_only")
  withr::defer(rlang::reset_warning_verbosity("scopusflow_first_author_only"))
  standard <- example_records
  attr(standard, "view") <- "STANDARD"
  w <- expect_warning(as_bibliometrix(standard),
                      class = "scopus_warning_first_author_only")
  expect_identical(w$message, complete_authors_fixture()$first_author_warning)
  # The one warning covers the author tally as well.
  expect_no_warning(as_bibliometrix(standard))
  expect_no_warning(scopus_top(standard, by = "author"))
})

test_that("as_bibliometrix stays silent on sets that are not first authors only", {
  withr::local_options(rlib_warning_verbosity = "verbose")
  complete <- example_records
  attr(complete, "view") <- "COMPLETE"
  expect_no_warning(as_bibliometrix(example_records))
  expect_no_warning(as_bibliometrix(complete))
})

# The frame bibliometrix::convert2df() builds from a 'Scopus' CSV export of the
# same record. Authors are written as surname and initials without full stops
# and joined by ";". UT holds the upper-cased EID, and DE, DT, VL and IS the
# upper-cased author keywords, document type, volume and issue.
test_that("as_bibliometrix gives the frame bibliometrix builds for STANDARD and COMPLETE records", {
  rlang::reset_warning_verbosity("scopusflow_first_author_only")
  withr::defer(rlang::reset_warning_verbosity("scopusflow_first_author_only"))
  fx <- extended_fixture()
  shared <- list(
    TI = "SCREENING A HARVEST BY DOCUMENT TYPE",
    SO = "JOURNAL OF MOCKING",
    DI = "10.5555/sf.extended.0001",
    PY = 2021L,
    TC = 17L,
    UT = "2-S2.0-85000000201",
    DB = "SCOPUS"
  )
  standard <- scopus_records(list(entry = list(fx$standard)), view = "STANDARD",
                             fields = "extended")
  attr(standard, "view") <- "STANDARD"
  m <- suppressWarnings(as_bibliometrix(standard))
  expected <- data.frame(
    c(list(AU = "OKAFOR C"), shared, list(DT = "ARTICLE", VL = "12", IS = "3")),
    stringsAsFactors = FALSE
  )
  class(expected) <- c("bibliometrixDB", "data.frame")
  expect_identical(m, expected)

  complete <- scopus_records(list(entry = list(fx$complete)), view = "COMPLETE",
                             fields = "extended")
  m <- as_bibliometrix(complete)
  expected <- data.frame(
    c(list(AU = "OKAFOR C;LINDQVIST M"), shared,
      list(DE = "SCREENING; DOCUMENT TYPES", DT = "ARTICLE", VL = "12", IS = "3")),
    stringsAsFactors = FALSE
  )
  class(expected) <- c("bibliometrixDB", "data.frame")
  expect_identical(m, expected)
})

test_that("as_bibliometrix writes each name as surname and initials without full stops", {
  cases <- c(
    "Tour, James M." = "TOUR JM",
    "Lee, Chul-Hee" = "LEE C-H",
    "Doudna, Jennifer A." = "DOUDNA JA",
    "Kitchin, J.R." = "KITCHIN JR",
    "van der Berg, Jan-Pieter" = "VAN DER BERG J-P",
    "Lee C.-H." = "LEE C-H",
    "Zhang F." = "ZHANG F",
    "Kitchin J.R." = "KITCHIN JR",
    "Fisher D. J." = "FISHER D J",
    "van der Berg J.-P." = "VAN DER BERG J-P",
    "Okafor" = "OKAFOR",
    "Zhiwei Peng" = "ZHIWEI PENG"
  )
  recs <- scopusflow:::scopus_coerce_records(
    data.frame(authors = names(cases), stringsAsFactors = FALSE)
  )
  expect_identical(as_bibliometrix(recs)$AU, unname(cases))
  recs <- scopusflow:::scopus_coerce_records(
    data.frame(authors = c("Tour, James M.; Lee C.-H.", NA), stringsAsFactors = FALSE)
  )
  expect_identical(as_bibliometrix(recs)$AU, c("TOUR JM;LEE C-H", NA))
})

test_that("as_bibliometrix gives the EID as UT and keeps a missing identifier missing", {
  recs <- scopusflow:::scopus_coerce_records(
    data.frame(scopus_id = c("85000000201", NA, ""), stringsAsFactors = FALSE)
  )
  ut <- as_bibliometrix(recs)$UT
  expect_identical(ut, c("2-S2.0-85000000201", NA, NA))
  # The documented way back to the bare identifier.
  expect_identical(sub("^2-S2.0-", "", ut[1]), "85000000201")
})

test_that("as_bibliometrix reads DE from the keywords of a search or of Abstract Retrieval", {
  recs <- scopusflow:::scopus_coerce_records(data.frame(
    authkeywords = c("CRISPR | Cas9", "graphene; supercapacitor", NA),
    stringsAsFactors = FALSE
  ))
  expect_identical(
    as_bibliometrix(recs)$DE,
    c("CRISPR; CAS9", "GRAPHENE; SUPERCAPACITOR", NA)
  )
})

test_that("as_bibliometrix adds DE, DT, VL and IS only when the set carries their columns", {
  m <- as_bibliometrix(example_records)
  expect_identical(names(m), c("AU", "TI", "SO", "DI", "PY", "TC", "UT", "DB"))
})
