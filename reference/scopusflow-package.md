# scopusflow: A Reproducible Workflow Layer for 'Scopus' Bibliographic Searches

A coherent, quota-aware workflow layer over the Elsevier 'Scopus' Search
'API' <https://dev.elsevier.com/sc_apis.html>. It builds reproducible
search plans, retrieves records with rate-limit handling, retry with
back-off and optional resumable caching, normalises results to a stable
tidy schema, extracts and tracks changes in Digital Object Identifiers
(DOIs), sizes sets of concepts and their intersections, compares
publication trends across topics and exports to formats compatible with
downstream bibliometric tools. Network and 'API' errors are surfaced as
typed conditions so that callers can respond to them programmatically.
'Scopus' is a trademark of Elsevier. This package is an independent
client and is not affiliated with or endorsed by Elsevier.

## See also

Useful links:

- <https://github.com/pablobernabeu/scopusflow>

- <https://pablobernabeu.github.io/scopusflow/>

- Report bugs at <https://github.com/pablobernabeu/scopusflow/issues>

## Author

Pablo Bernabeu, author and maintainer (<pcbernabeu@gmail.com>,
[ORCID](https://orcid.org/0000-0003-1083-2460)).
