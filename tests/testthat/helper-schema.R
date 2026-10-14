# A validator for the part of JSON Schema (draft 2020-12) that theoryforge's
# corpus schema uses, so the R suite checks the writer's output against the
# vendored copy in fixtures/ without a dependency. The Python suite validates
# the same output with the jsonschema package. `x` is JSON parsed with
# jsonlite::fromJSON(simplifyVector = FALSE), where an object is a named list,
# an array an unnamed one and null is NULL. A keyword this does not implement
# is reported as an error, so a newer schema cannot pass unchecked.
schema_errors <- function(x, schema, where = "$") {
  annotations <- c("$schema", "$id", "$comment", "title", "description", "format")
  checked <- c("type", "required", "properties", "additionalProperties", "items",
               "pattern", "minLength", "minimum")
  unknown <- setdiff(names(schema), c(annotations, checked))
  if (length(unknown) > 0L) {
    return(sprintf("%s: unsupported keyword %s", where, paste(unknown, collapse = ", ")))
  }
  if (!is.null(schema$type)) {
    types <- unlist(schema$type)
    if (!any(vapply(types, json_has_type, logical(1), x = x))) {
      return(sprintf("%s: not of type %s", where, paste(types, collapse = " or ")))
    }
  }
  errors <- character()
  if (json_has_type(x, "string")) {
    if (!is.null(schema$minLength) && nchar(x) < schema$minLength) {
      errors <- c(errors, sprintf("%s: shorter than %d", where, schema$minLength))
    }
    if (!is.null(schema$pattern) && !grepl(schema$pattern, x, perl = TRUE)) {
      errors <- c(errors, sprintf("%s: does not match %s", where, schema$pattern))
    }
  }
  if (json_has_type(x, "number") && !is.null(schema$minimum) && x < schema$minimum) {
    errors <- c(errors, sprintf("%s: below %s", where, schema$minimum))
  }
  if (json_has_type(x, "object")) {
    for (name in unlist(schema$required)) {
      if (!name %in% names(x)) errors <- c(errors, sprintf("%s: lacks %s", where, name))
    }
    for (name in intersect(names(schema$properties), names(x))) {
      errors <- c(errors, schema_errors(x[[name]], schema$properties[[name]],
                                        paste0(where, ".", name)))
    }
    extra <- setdiff(names(x), names(schema$properties))
    if (isFALSE(schema$additionalProperties) && length(extra) > 0L) {
      errors <- c(errors, sprintf("%s: unexpected %s", where, paste(extra, collapse = ", ")))
    }
  }
  if (json_has_type(x, "array") && !is.null(schema$items)) {
    for (i in seq_along(x)) {
      errors <- c(errors, schema_errors(x[[i]], schema$items, sprintf("%s[%d]", where, i)))
    }
  }
  errors
}

json_has_type <- function(x, type) {
  scalar <- length(x) == 1L && is.atomic(x)
  switch(type,
    null = is.null(x),
    object = is.list(x) && !is.null(names(x)),
    array = is.list(x) && is.null(names(x)),
    string = scalar && is.character(x),
    integer = scalar && (is.integer(x) || (is.double(x) && x == round(x))),
    number = scalar && is.numeric(x),
    boolean = scalar && is.logical(x),
    stop("unknown JSON type ", type, call. = FALSE)
  )
}

# The vendored copy of theoryforge's corpus schema.
corpus_schema <- function() {
  jsonlite::fromJSON(test_path("fixtures", "corpus.schema.json"), simplifyVector = FALSE)
}
