# Dart bindings for ElasticSearch HTTP API.

[ElasticSearch](https://www.elastic.co/) is a full-text search engine based
on [Lucene](http://lucene.apache.org/).

## Roadmap

The package's API is expected to change, and feature requests and PRs are welcome.

Please use [this issue](https://github.com/isoos/elastic_client/issues/29) to discuss
new requests for breaking changes.

Planned features:
- More types in the API (instead of the `Map` entries).
- Data types should convert to/from JSON.
- Fluent APIs (similar to `IndexRef`).
- Cluster-aware transport: round-robin, latency-aware, or routing-aware selection of the target node.
