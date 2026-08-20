# Shared plumbing for the package's print methods ---------------------------
#
# cli emits its output as a condition that the default handler writes to the
# message stream, while an object printed with `print()` goes to standard
# output. knitr collects the two streams separately, so a print method that
# wrote its header with `cli::cli_text()` and then printed a tibble produced two
# output blocks on the documentation site for a single printed object.
#
# `scopus_print_line()` formats the cli string first and writes the result to
# standard output, so every print method emits one stream and knitr renders one
# block. Formatting through cli, and never `sprintf()`, keeps inline styling,
# pluralisation and the wrapping at the console width exactly as before.

scopus_print_line <- function(..., .envir = parent.frame()) {
  cat(cli::cli_fmt(cli::cli_text(..., .envir = .envir)), sep = "\n")
  invisible(NULL)
}
