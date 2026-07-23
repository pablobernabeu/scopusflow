#' @author Pablo Bernabeu, author and maintainer
#'   (\email{pcbernabeu@gmail.com},
#'   \href{https://orcid.org/0000-0003-1083-2460}{ORCID}).
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang abort warn inform .data
## usethis namespace: end
NULL

# Quiet R CMD check for tidy-eval pronouns used in examples/vignettes, and for
# the lazy-loaded `example_records` dataset, which the app's demo mode reads
# from the package's own namespace (LazyData is on, so it is bound at run time,
# but static analysis cannot see that).
utils::globalVariables(c(".data", "example_records"))
