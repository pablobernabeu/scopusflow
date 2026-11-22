# scopusflow: A Reproducible Workflow Layer for 'Scopus' Bibliographic Searches

A quota-aware workflow for the Elsevier 'Scopus' Search 'API'
<https://dev.elsevier.com/sc_apis.html>. It builds reproducible search
plans and retrieves records with rate-limit handling, retry with
back-off and optional resumable caching. It normalises results to a
stable tidy schema, extracts and tracks changes in Digital Object
Identifiers (DOIs), sizes sets of concepts and their intersections and
compares publication trends across topics. It writes the search up as a
reproducible record for a methods section following the 'PRISMA-S'
reporting standard (Rethlefsen and others, 2021)
[doi:10.1186/s13643-020-01542-z](https://doi.org/10.1186/s13643-020-01542-z)
and exports to formats that bibliometric tools read. Network and 'API'
errors are signalled as typed conditions that callers can respond to
programmatically. 'Scopus' is a trademark of Elsevier. This package is
an independent client and is not affiliated with or endorsed by
Elsevier.

## See also

Useful links:

- <https://github.com/pablobernabeu/scopusflow>

- <https://pablobernabeu.github.io/scopusflow/>

- Report bugs at <https://github.com/pablobernabeu/scopusflow/issues>

## Author

Pablo Bernabeu, author and maintainer (<pcbernabeu@gmail.com>,
[ORCID](https://orcid.org/0000-0003-1083-2460)).
