# Test fixtures

`scopus_page.json` is a synthetic parser fixture for the offline test suite, not
a 'Scopus' harvest: its records are invented, and its identifiers are
placeholders on the reserved `10.5555` DOI prefix, which never resolves, so no
real published work is labelled by it. The bundled `example_records` dataset,
documented in `?example_records`, is the corpus of real articles the examples
and vignettes run on.
