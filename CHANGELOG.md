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
