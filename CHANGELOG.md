## 0.3.8

- Support `query` parameter on `Client.count` method.

## 0.3.7

- Added `Query.matchPhrase` method to support [match_phrase query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-match-query-phrase.html).
  ([#54](https://github.com/isoos/elastic_client/pull/54) by [sota1235](https://github.com/sota1235))

## 0.3.6

- Added `Query.regexp` method to support [regexp query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-regexp-query.html). ([#52](https://github.com/isoos/elastic_client/pull/52) by [sota1235](https://github.com/sota1235))

## 0.3.5

- Added the very basics of `Function score query` to `Query` with the function `functionScore`. ([#50](https://github.com/isoos/elastic_client/pull/50) by [Cronos87](https://github.com/Cronos87))

## 0.3.4

- `Client.minScore` and `Index.minScore`:
  - Added method to filter results using a minimum score. ([#49](https://github.com/isoos/elastic_client/pull/49) by [Cronos87](https://github.com/Cronos87)).
- Added missing `size` property in `Index`. ([#49](https://github.com/isoos/elastic_client/pull/49) by [Cronos87](https://github.com/Cronos87)).

## 0.3.3

- Added `docCount` property on aggregations. ([#47](https://github.com/isoos/elastic_client/pull/47) by [Cronos87](https://github.com/Cronos87)).
- Added `size` option to search. ([#47](https://github.com/isoos/elastic_client/pull/47) by [Cronos87](https://github.com/Cronos87)).

## 0.3.2

- `Client.count` and `Index.count`:
  - Added method to count the total items of an index. ([#46](https://github.com/isoos/elastic_client/pull/46) by [Cronos87](https://github.com/Cronos87)).


## 0.3.1

- Query support for ids. ([#40](https://github.com/isoos/elastic_client/pull/40) by [Cronos87](https://github.com/Cronos87)).
- Allowing null in cast for aggregates. ([#42](https://github.com/isoos/elastic_client/pull/42) by [fpause](https://github.com/fpause)).

## 0.3.0

- Updated dependency, finalizing release.

## 0.3.0-null-safety.1

- Migrated to null safety.

## 0.2.2

- `SearchResult.hits` has a separate `Hit` type, extending `Doc` for backwards compatibility.
- `Client.search` and `Index.search`:
  - highlighting support with `HighlightOptions`, `HighlightField`
  - `trackTotalHits` to optionally disable calculating the total hit counting
  - requested `fields` are returned separately from `source`
- `Query.range`

## 0.2.1

- `Query.queryString`.
- `Client.bulk` and `Index.bulk` support delete and batch size.

## 0.2.0

**Breaking changes:**
- `Client` methods updated:
  - every parameter is a named parameter,
  - required parameters are marked as such,
  - `search`: removed `fetchSource` parameter, use `source instead,
  - `clearScroll` was renamed to `clearScrollIds`,
  - `scroll`'s `scroll` parameter renamed to `duration`.
- Removed `ConsoleHttpTransport`, use `HttpTransport` instead.
- Removed `BasicAuth`, use `basicAuthorization` instead.
- `HttpTransport` changed:
  - Constructor accepts `client` from both `package:http` or `package:http_client`.
  - Constructor accepts `url` as `String` or `Uri`.
  - Constructor accepts `authorization` header as a pass-through value.
  - Closes HTTP client if and only if there was none provided.

Updates:
- `Client.clearScrollId` for deleting a single scroll id.
- `TransportException` when we've got unexpected status code from ElasticSearch.
- `Client.index(name: 'index-name')` creates a shortcut to access index-based operations.
- Minimal test! yay!

## 0.1.15

- The `type` parameter in the index may be null. ([#25](https://github.com/isoos/elastic_client/pull/25) by [fabiocarneiro](https://github.com/fabiocarneiro))

## 0.1.14

- Support scroll API. ([#24](https://github.com/isoos/elastic_client/pull/24) by [swdyh](https://github.com/swdyh))

## 0.1.13

- Support getAliases operation ([#22](https://github.com/isoos/elastic_client/pull/22) by [asayamakk](https://github.com/asayamakk)).

## 0.1.12

- Support aliases operation ([#21](https://github.com/isoos/elastic_client/pull/21) by [asayamakk](https://github.com/asayamakk)).

## 0.1.11

- Enabled merging documents with `updateDoc` ([#19](https://github.com/isoos/elastic_client/pull/19) by [jodinathan](https://github.com/jodinathan)).

## 0.1.10

- Updated code to latest Dart style guides.

## 0.1.9

- Typed aggregations ([#13](https://github.com/isoos/elastic_client/pull/13) by [swdyh](https://github.com/swdyh)).

## 0.1.8

- `Query.prefix`

## 0.1.7

- Handle `'hits': {'total': {'value': 1}}}` in the search response format.

## 0.1.6

- Fix HTTP transport: preserve original uri's relative path segments.

## 0.1.5

- Add dynamic `source` param for Client.search() method. This is a replacement for the boolean `fetchSource` to allow _source to be a boolean, a string or a list of strings as per the Elasticsearch spec.
- Deprecate `fetchSource` param in the Client.search() method.
- Support sorting of search results.

## 0.1.4

- Fixed `_mergeHeader` function.
- Using `pedantic` analysis options.

## 0.1.3

- Upgrade `http_client` dependency.

## 0.1.2

- `BasicAuth` option for `HttpTransport`.

## 0.1.1

- Support suggest queries.

## 0.1.0

- First public version.
