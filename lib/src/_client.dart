part of 'elastic_client_impl.dart';

/// Client to connect to ElasticSearch.
class Client {
  final Transport _transport;

  /// Client to connect to ElasticSearch using a [Transport].
  Client(this._transport);

  /// Shorthand operations for index.
  IndexRef index({
    @required String name,
    String type,
  }) =>
      IndexRef._(this, name, type);

  /// Returns weather [index] exists.
  Future<bool> indexExists({@required String index}) async {
    final rs = await _transport.send(Request('HEAD', [index]));
    return rs.statusCode == 200;
  }

  /// Updates [index] definition with [content].
  Future<void> updateIndex({
    @required String index,
    Map<String, dynamic> content,
  }) async {
    final rs = await _transport.send(Request('PUT', [index], bodyMap: content));
    rs.throwIfStatusNotOK(message: 'Index update failed.');
  }

  /// Flush [index].
  Future<void> flushIndex({@required String index}) async {
    final rs = await _transport.send(Request('POST', [index, '_flush'],
        params: {'wait_if_ongoing': 'true'}));
    rs.throwIfStatusNotOK(message: 'Index flust failed.');
  }

  /// Delete [index].
  ///
  /// Returns the success status of the delete operation.
  Future<bool> deleteIndex({@required String index}) async {
    final rs = await _transport.send(Request('DELETE', [index]));
    return rs.statusCode == 200;
  }

  /// List [aliases].
  ///
  /// When [aliases] is not specified, all items will be returned.
  Future<List<Alias>> getAliases({
    List<String> aliases = const <String>[],
  }) async {
    final rs = await _transport.send(
      Request(
        'GET',
        [
          '_cat',
          'aliases',
          if (aliases.isNotEmpty) aliases.join(','),
        ],
        params: {'format': 'json'},
      ),
    );
    rs.throwIfStatusNotOK(
        message: 'Unable to get aliases information with $aliases.');
    final body = rs.bodyAsList;
    return body
        .map(
          (alias) => Alias(
            alias: alias['alias'] as String,
            index: alias['index'] as String,
            indexRouting: alias['routing.index'] as String,
            searchRouting: alias['routing.search'] as String,
            isWriteIndex: alias['is_write_index'] == 'true',
          ),
        )
        .toList();
  }

  /// Add [index] to [alias].
  Future<bool> addAlias({
    @required String alias,
    @required String index,
  }) async {
    final requestBody = {
      'actions': [
        {
          'add': {'index': index, 'alias': alias}
        }
      ]
    };
    final rs = await _transport.send(
      Request('POST', ['_aliases'], bodyMap: requestBody),
    );
    return rs.statusCode == 200;
  }

  /// Remove [index] from [alias].
  Future<bool> removeAlias({
    @required String alias,
    @required String index,
  }) async {
    final requestBody = {
      'actions': [
        {
          'remove': {'index': index, 'alias': alias}
        }
      ]
    };
    final rs = await _transport.send(
      Request('POST', ['_aliases'], bodyMap: requestBody),
    );
    return rs.statusCode == 200;
  }

  /// Changes [alias] instead of pointing to [from], it will point to [to].
  Future<bool> swapAlias({
    @required String alias,
    @required String from,
    @required String to,
  }) async {
    final requestBody = {
      'actions': [
        {
          'remove': {'index': from, 'alias': alias}
        },
        {
          'add': {'index': to, 'alias': alias}
        }
      ]
    };
    final rs = await _transport.send(
      Request('POST', ['_aliases'], bodyMap: requestBody),
    );
    return rs.statusCode == 200;
  }

  /// Update [doc] in [index].
  Future<bool> updateDoc({
    @required String index,
    @required Map<String, dynamic> doc,
    String type,
    String id,
    bool merge = false,
  }) async {
    final pathSegments = <String>[
      index,
      if (type != null) type,
      if (merge) '_update',
      if (id != null) id,
    ];
    final rs =
        await _transport.send(Request('POST', pathSegments, bodyMap: doc));
    return rs.statusCode == 200 || rs.statusCode == 201;
  }

  /// Bulk update [docs] in [index].
  Future<bool> updateDocs({
    @required List<Doc> docs,
    String index,
    String type,
    int batchSize = 100,
  }) async {
    // TODO: verify if docs.index is consistent with index.
    final pathSegments = [
      if (index != null) index,
      if (type != null) type,
      '_bulk',
    ];
    for (var start = 0; start < docs.length;) {
      final sub = docs.skip(start).take(batchSize).toList();
      final lines = sub
          .map((doc) => [
                {
                  'index': {
                    if (doc.index != null) '_index': doc.index,
                    if (doc.type != null) '_type': doc.type,
                    if (doc.id != null) '_id': doc.id,
                  }
                },
                doc.doc,
              ])
          .expand((list) => list)
          .map(convert.json.encode)
          .map((s) => '$s\n')
          .join();
      final rs =
          await _transport.send(Request('POST', pathSegments, bodyText: lines));
      rs.throwIfStatusNotOK(
          message: 'Unable to update batch starting with $start.');
      start += sub.length;
    }
    return true;
  }

  /// Deletes [id] from [index].
  Future<int> deleteDoc({
    @required String index,
    @required String id,
    String type,
  }) async {
    final rs =
        await _transport.send(Request('DELETE', [index, type ?? '_doc', id]));
    return rs.statusCode == 200 ? 1 : 0;
  }

  /// Deletes documents from [index] using [query].
  ///
  /// Returns the number of deleted documents.
  Future<int> deleteDocs({
    @required String index,
    @required Map query,
  }) async {
    final rs = await _transport.send(Request(
        'POST', [index, '_delete_by_query'],
        bodyMap: {'query': query}));
    if (rs.statusCode != 200) return 0;
    return rs.bodyAsMap['deleted'] as int ?? 0;
  }

  /// Search :-)
  Future<SearchResult> search({
    String index,
    String type,
    Map query,
    int offset,
    int limit,
    dynamic source,
    Map suggest,
    List<Map> sort,
    Map aggregations,
    Duration scroll,
  }) async {
    final path = [
      if (index != null) index,
      if (type != null) type,
      '_search',
    ];

    final map = {
      if (source != null) '_source': source,
      'query': query ?? Query.matchAll(),
      if (offset != null) 'from': offset,
      if (limit != null) 'size': limit,
      if (suggest != null) 'suggest': suggest,
      if (sort != null) 'sort': sort,
      if (aggregations != null) 'aggregations': aggregations,
    };
    final params = {
      'search_type': 'dfs_query_then_fetch',
      if (scroll != null) 'scroll': scroll.inSeconds.toString() + 's',
    };
    final rs = await _transport
        .send(Request('POST', path, params: params, bodyMap: map));
    rs.throwIfStatusNotOK(message: 'Failed to search $query.');
    final body = rs.bodyAsMap;
    final hitsMap = body['hits'] as Map<String, dynamic> ?? const {};
    final totalCount = _extractTotalCount(hitsMap);
    final results = _extractDocList(hitsMap);
    final suggestMap = body['suggest'] as Map ?? const {};
    final suggestHits = suggestMap.map<String, List<SuggestHit>>((k, v) {
      if (v == null) return null;
      final list = (v as List).cast<Map>();
      final hits = list
          .map((map) {
            final optionsList = (map['options'] as List).cast<Map>();
            final options = optionsList?.map((m) {
              return SuggestHitOption(
                m['text'] as String,
                m['score'] as double,
                freq: m['freq'] as int,
                highlighted: m['highlighted'] as String,
              );
            })?.toList();
            return SuggestHit(
              map['text'] as String,
              map['offset'] as int,
              map['length'] as int,
              options,
            );
          })
          .where((x) => x != null)
          .toList();
      return MapEntry('', hits);
    });
    suggestHits.removeWhere((k, v) => v == null);

    final aggMap = body['aggregations'] as Map<String, dynamic> ?? const {};
    final aggResult = aggMap.map<String, Aggregation>((k, v) {
      final agg = Aggregation(k, aggregations[k] as Map<String, dynamic>,
          v as Map<String, dynamic>);
      return MapEntry(k, agg);
    });

    return SearchResult(
      totalCount,
      results,
      suggestHits: suggestHits.isEmpty ? null : suggestHits,
      aggregations: aggResult.isEmpty ? null : aggResult,
      scrollId: body['_scroll_id'] as String,
    );
  }

  /// Continue search using the scroll API.
  Future<SearchResult> scroll({
    @required String scrollId,
    @required Duration duration,
  }) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {
      'scroll_id': scrollId,
      'scroll': duration.inSeconds.toString() + 's',
    };
    final rs = await _transport.send(Request('GET', path, bodyMap: bodyMap));
    rs.throwIfStatusNotOK(message: 'Failed to search scroll.');
    final body = rs.bodyAsMap;
    final hitsMap = body['hits'] as Map<String, dynamic> ?? const {};
    final totalCount = _extractTotalCount(hitsMap);
    final results = _extractDocList(hitsMap);

    return SearchResult(
      totalCount,
      results,
      scrollId: body['_scroll_id'] as String,
    );
  }

  /// Clear scroll ids.
  Future<ClearScrollResult> clearScrollId({@required String scrollId}) =>
      clearScrollIds(scrollIds: [scrollId]);

  /// Clear scroll ids.
  Future<ClearScrollResult> clearScrollIds(
      {@required List<String> scrollIds}) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {'scroll_id': scrollIds};
    final rs = await _transport.send(Request('DELETE', path, bodyMap: bodyMap));
    if (rs.statusCode != 200 && rs.statusCode != 404) {
      throw Exception('Failed to search scroll');
    }
    final body = rs.bodyAsMap;
    return ClearScrollResult(
        body['succeeded'] as bool ?? false, body['num_freed'] as int ?? 0);
  }

  int _extractTotalCount(Map<String, dynamic> hitsMap) {
    final hitsTotal = hitsMap['total'];
    var totalCount = 0;
    if (hitsTotal is int) {
      totalCount = hitsTotal;
    } else if (hitsTotal is Map) {
      totalCount = (hitsTotal['value'] as int) ?? 0;
    }
    return totalCount;
  }

  List<Doc> _extractDocList(Map<String, dynamic> hitsMap) {
    final hitsList = (hitsMap['hits'] as List).cast<Map>() ?? const <Map>[];
    final results = hitsList
        .map((Map map) => Doc(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String,
              type: map['_type'] as String,
              score: map['_score'] as double,
              sort: map['sort'] as List<dynamic>,
            ))
        .toList();
    return results;
  }
}
