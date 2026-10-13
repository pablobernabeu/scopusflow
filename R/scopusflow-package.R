#' @author Pablo Bernabeu, author and maintainer
#'   (\email{pcbernabeu@gmail.com},
#'   \href{https://orcid.org/0000-0003-1083-2460}{ORCID}).
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang abort warn inform .data
## usethis namespace: end
NULL

# Quiet R CMD check for tidy-eval pronouns used in examples/vignettes. The
# lazy-loaded `example_records` dataset is read in package code as
# scopusflow::example_records, because a bare name finds it only when the
# package is attached, so it needs no entry here.
utils::globalVariables(".data")
