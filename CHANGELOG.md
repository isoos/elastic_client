## 0.1.5

- Add dynamic `source` param for Client.search() method. This is a replacement for the boolean `fetchSource` to allow _source to be a boolean, a string or a list of strings as per the Elasticsearch spec.
- Deprecate `fetchSource` param in the Client.search() method.

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
