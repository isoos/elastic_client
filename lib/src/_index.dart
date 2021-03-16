part of 'elastic_client_impl.dart';

/// Shorthand for index-related operations.
class IndexRef {
  final Client _client;
  final String name;
  final String? type;

  IndexRef._(this._client, this.name, this.type);

  /// Returns weather the index exists.
  Future<bool> exists() => _client.indexExists(index: name);

  /// Updates index definition with [content].
  Future<void> update({
    Map<String, dynamic>? content,
  }) =>
      _client.updateIndex(index: name, content: content);

  /// Flush index.
  Future<void> flush() => _client.flushIndex(index: name);

  /// Delete index.
  ///
  /// Returns the success status of the delete operation.
  Future<bool> delete() => _client.deleteIndex(index: name);

  /// Add index to [alias].
  Future<bool> addToAlias({required String alias}) =>
      _client.addAlias(alias: alias, index: name);

  /// Remove index from [alias].
  Future<bool> removeFromAlias({required String alias}) =>
      _client.removeAlias(alias: alias, index: name);

  /// Update [doc] in index.
  Future<bool> updateDoc({
    required Map<String, dynamic> doc,
    String? id,
    bool merge = false,
  }) =>
      _client.updateDoc(
        index: name,
        doc: doc,
        type: type ?? '_doc',
        id: id,
        merge: merge,
      );

  /// Bulk update of the current index.
  ///
  /// In the following order:
  /// - [updateDocs] will be updated
  /// - [deleteDocs] will be deleted
  Future<bool> bulk({
    List<Doc>? updateDocs,
    List<Doc>? deleteDocs,
    int batchSize = 100,
  }) =>
      _client.bulk(
        updateDocs: updateDocs,
        deleteDocs: deleteDocs,
        batchSize: batchSize,
        index: name,
        type: type,
      );

  /// Bulk update [docs] in index.
  Future<bool> updateDocs({
    required List<Doc> docs,
    int batchSize = 100,
  }) =>
      _client.updateDocs(
        docs: docs,
        batchSize: batchSize,
        index: name,
        type: type,
      );

  /// Deletes [id] from index.
  Future<int> deleteDoc({required String id}) =>
      _client.deleteDoc(index: name, id: id, type: type);

  /// Deletes documents from index using [query].
  ///
  /// Returns the number of deleted documents.
  Future<int> deleteDocs({required Map query}) =>
      _client.deleteDocs(index: name, query: query);

  /// Search :-)
  Future<SearchResult> search({
    Map? query,
    int? offset,
    int? limit,
    List<Object>? fields,
    dynamic source,
    Map? suggest,
    List<Map>? sort,
    Map? aggregations,
    Duration? scroll,
    HighlightOptions? highlight,
    bool? trackTotalHits,
  }) async {
    return await _client.search(
      index: name,
      type: type,
      query: query,
      offset: offset,
      limit: limit,
      fields: fields,
      source: source,
      suggest: suggest,
      sort: sort,
      aggregations: aggregations,
      scroll: scroll,
      highlight: highlight,
      trackTotalHits: trackTotalHits,
    );
  }

  /// Get the index mapping.
  ///
  /// WARNING: this is not a finalized API, may change in the future.
  Future<Map<String, dynamic>> getMapping() async {
    final rs =
        await _client._transport.send(Request('GET', [name, '_mapping']));
    rs.throwIfStatusNotOK(message: 'Failed to get mapping for $name.');
    return rs.bodyAsMap;
  }
}
