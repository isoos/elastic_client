part of 'elastic_client_impl.dart';

/// Client to connect to ElasticSearch.
class Client {
  final Transport _transport;

  /// Client to connect to ElasticSearch using a [Transport].
  Client(this._transport);

  /// Shorthand operations for index.
  IndexRef index({
    required String name,
    String? type,
  }) =>
      IndexRef._(this, name, type);

  /// Returns weather [index] exists.
  Future<bool> indexExists({required String index}) async {
    final rs = await _transport.send(Request('HEAD', [index]));
    return rs.statusCode == 200;
  }

  /// Updates [index] definition with [content].
  Future<void> updateIndex({
    required String index,
    Map<String, dynamic>? content,
  }) async {
    final rs = await _transport.send(Request('PUT', [index], bodyMap: content));
    rs.throwIfStatusNotOK(message: 'Index update failed.');
  }

  /// Flush [index].
  Future<void> flushIndex({required String index}) async {
    final rs = await _transport.send(Request('POST', [index, '_flush'],
        params: {'wait_if_ongoing': 'true'}));
    rs.throwIfStatusNotOK(message: 'Index flust failed.');
  }

  /// Delete [index].
  ///
  /// Returns the success status of the delete operation.
  Future<bool> deleteIndex({required String index}) async {
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
    required String alias,
    required String index,
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
    required String alias,
    required String index,
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
    required String alias,
    required String from,
    required String to,
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
    required String index,
    required Map<String, dynamic> doc,
    String? type,
    String? id,
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

  /// Bulk update of the [index].
  ///
  /// In the following order:
  /// - [updateDocs] will be updated
  /// - [deleteDocs] will be deleted
  Future<bool> bulk({
    List<Doc>? updateDocs,
    List<Doc>? deleteDocs,
    String? index,
    String? type,
    int batchSize = 100,
  }) async {
    // TODO: verify if docs.index is consistent with index.
    final pathSegments = [
      if (index != null) index,
      if (type != null) type,
      '_bulk',
    ];
    var totalCount = 0;
    var count = 0;
    final sb = StringBuffer();
    Future send([bool last = false]) async {
      if (count == 0) return;
      if (count >= batchSize || last) {
        final rs = await _transport
            .send(Request('POST', pathSegments, bodyText: sb.toString()));
        rs.throwIfStatusNotOK(
            message: 'Unable to update batch starting with $totalCount.');

        // cheap test before parsing the body
        if (rs.body.contains('"errors":true')) {
          final body = convert.json.decode(rs.body) as Map<String, dynamic>;
          if (body['errors'] == true) {
            throw TransportException('Errors detected in the bulk updated.',
                body: rs.body);
          }
        }

        totalCount += count;
        count = 0;
        sb.clear();
      }
    }

    for (final doc in updateDocs ?? const <Doc>[]) {
      sb.writeln(convert.json.encode({
        'index': {
          if (doc.index != null) '_index': doc.index,
          if (doc.type != null) '_type': doc.type,
          '_id': doc.id,
        }
      }));
      sb.writeln(convert.json.encode(doc.doc));
      count++;
      await send();
    }

    for (final doc in deleteDocs ?? const <Doc>[]) {
      sb.writeln(convert.json.encode({
        'delete': {
          if (doc.index != null) '_index': doc.index,
          if (doc.type != null) '_type': doc.type,
          '_id': doc.id,
        }
      }));
      count++;
      await send();
    }

    await send(true);
    return true;
  }

  /// Bulk update [docs] in [index].
  Future<bool> updateDocs({
    required List<Doc> docs,
    String? index,
    String? type,
    int batchSize = 100,
  }) async {
    return await bulk(
      updateDocs: docs,
      index: index,
      type: type,
      batchSize: batchSize,
    );
  }

  /// Deletes [id] from [index].
  Future<int> deleteDoc({
    required String index,
    required String id,
    String? type,
  }) async {
    final rs =
        await _transport.send(Request('DELETE', [index, type ?? '_doc', id]));
    return rs.statusCode == 200 ? 1 : 0;
  }

  /// Deletes documents from [index] using [query].
  ///
  /// Returns the number of deleted documents.
  Future<int> deleteDocs({
    required String index,
    required Map query,
  }) async {
    final rs = await _transport.send(Request(
        'POST', [index, '_delete_by_query'],
        bodyMap: {'query': query}));
    if (rs.statusCode != 200) return 0;
    return rs.bodyAsMap['deleted'] as int? ?? 0;
  }

  /// Search :-)
  Future<SearchResult> search({
    String? index,
    String? type,
    Map? query,
    // TODO: investigate if/when this should be deprecated in favour of `from`
    int? offset,
    // TODO: investigate if/when this should be deprecated in favour of `size`
    int? limit,
    List<Object>? fields,
    dynamic source,
    Map? suggest,
    List<Map>? sort,
    Map? aggregations,
    Duration? scroll,
    HighlightOptions? highlight,
    bool? trackTotalHits,
    int? size,
    double? minScore,
  }) async {
    final path = [
      if (index != null) index,
      if (type != null) type,
      '_search',
    ];

    final map = {
      if (source != null) '_source': source,
      if (fields != null) 'fields': fields,
      'query': query ?? Query.matchAll(),
      if (offset != null) 'from': offset,
      if (limit != null) 'size': limit,
      if (suggest != null) 'suggest': suggest,
      if (sort != null) 'sort': sort,
      if (aggregations != null) 'aggregations': aggregations,
      if (highlight != null) 'highlight': highlight.toMap(),
      if (trackTotalHits != null) 'track_total_hits': trackTotalHits,
      if (size != null) 'size': size,
      if (minScore != null) 'min_score': minScore,
    };
    final params = {
      'search_type': 'dfs_query_then_fetch',
      if (scroll != null) 'scroll': scroll.inSeconds.toString() + 's',
    };
    final rs = await _transport
        .send(Request('POST', path, params: params, bodyMap: map));
    rs.throwIfStatusNotOK(message: 'Failed to search $query.');
    final body = rs.bodyAsMap;
    final hitsMap = body['hits'] as Map<String, dynamic>? ?? const {};
    final totalCount = _extractTotalCount(hitsMap);
    final results = _extractDocList(hitsMap);
    final suggestMap = body['suggest'] as Map? ?? const {};
    final suggestEntries =
        suggestMap.entries.where((e) => e.value != null).map((e) {
      final list = (e.value as List).cast<Map>();
      final hits = list.map((map) {
        final optionsList = (map['options'] as List).cast<Map>();
        final options = optionsList.map((m) {
          return SuggestHitOption(
            m['text'] as String,
            m['score'] as double,
            freq: (m['freq'] ?? -1) as int,
            highlighted: m['highlighted'] as String,
          );
        }).toList();
        return SuggestHit(
          map['text'] as String,
          map['offset'] as int,
          map['length'] as int,
          options,
        );
      }).toList();
      return MapEntry('', hits);
    });
    final suggestHits = Map.fromEntries(suggestEntries);

    final aggMap = body['aggregations'] as Map<String, dynamic>? ?? const {};
    final aggResult = aggMap.map<String, Aggregation>((k, v) {
      final agg = Aggregation(k, aggregations![k] as Map<String, dynamic>,
          v as Map<String, dynamic>);
      return MapEntry(k, agg);
    });

    return SearchResult(
      totalCount,
      results,
      suggestHits: suggestHits.isEmpty ? null : suggestHits,
      aggregations: aggResult.isEmpty ? null : aggResult,
      scrollId: body['_scroll_id'] as String?,
    );
  }

  /// Discover terms in the index that match a partial String
  /// https://www.elastic.co/guide/en/elasticsearch/reference/8.1/search-terms-enum.html
  Future<TermsEnumResult> termsEnum({
    String? index,
    String? type,
    required String field,
    String? string,
    bool? caseInsensitive,
    int? size,
  }) async {
    final path = [
      if (index != null) index,
      if (type != null) type,
      '_terms_enum',
    ];

    final map = {
      'field': field ,
      if (string != null) 'string': string,
      if (caseInsensitive != null) 'case_insensitive': caseInsensitive,
      if (size != null) 'size': size,
    };
    final rs = await _transport
        .send(Request('POST', path, bodyMap: map));
    rs.throwIfStatusNotOK(message: 'Failed to retrieve term enum for $field.');
    final body = rs.bodyAsMap;

    final termsResults = (body['terms']?.whereType<String>()?.toList() ?? <String>[]) as List<String> ;

    return TermsEnumResult(
        termsResults
    );
  }

  /// Continue search using the scroll API.
  Future<SearchResult> scroll({
    required String scrollId,
    required Duration duration,
  }) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {
      'scroll_id': scrollId,
      'scroll': duration.inSeconds.toString() + 's',
    };
    final rs = await _transport.send(Request('GET', path, bodyMap: bodyMap));
    rs.throwIfStatusNotOK(message: 'Failed to search scroll.');
    final body = rs.bodyAsMap;
    final hitsMap = body['hits'] as Map<String, dynamic>? ?? const {};
    final totalCount = _extractTotalCount(hitsMap);
    final results = _extractDocList(hitsMap);

    return SearchResult(
      totalCount,
      results,
      scrollId: body['_scroll_id'] as String,
    );
  }

  /// Clear scroll ids.
  Future<ClearScrollResult> clearScrollId({required String scrollId}) =>
      clearScrollIds(scrollIds: [scrollId]);

  /// Clear scroll ids.
  Future<ClearScrollResult> clearScrollIds(
      {required List<String> scrollIds}) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {'scroll_id': scrollIds};
    final rs = await _transport.send(Request('DELETE', path, bodyMap: bodyMap));
    if (rs.statusCode != 200 && rs.statusCode != 404) {
      throw Exception('Failed to search scroll');
    }
    final body = rs.bodyAsMap;
    return ClearScrollResult(
        body['succeeded'] as bool? ?? false, body['num_freed'] as int? ?? 0);
  }

  /// Count the total items for the given [index].
  Future<int> count({required String index, Map? query}) async {
    final bodyMap = {
      if (query != null) 'query': query,
    };
    final rs = await _transport.send(Request(
      'GET',
      [index, '_count'],
      params: {'format': 'json'},
      bodyMap: bodyMap,
    ));
    rs.throwIfStatusNotOK(message: 'Unable to count the total of items.');
    final body = rs.bodyAsMap;
    return body['count'] as int;
  }

  int _extractTotalCount(Map<String, dynamic> hitsMap) {
    final hitsTotal = hitsMap['total'];
    var totalCount = 0;
    if (hitsTotal is int) {
      totalCount = hitsTotal;
    } else if (hitsTotal is Map) {
      totalCount = hitsTotal['value'] as int? ?? 0;
    }
    return totalCount;
  }

  List<Hit> _extractDocList(Map<String, dynamic> hitsMap) {
    final hitsList = (hitsMap['hits'] as List?)?.cast<Map>() ?? const <Map>[];
    final results = hitsList
        .map((Map map) => Hit(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String?,
              type: map['_type'] as String?,
              score: map['_score'] as double?,
              sort: map['sort'] as List<dynamic>?,
              fields: _extractFields(map['fields']),
              highlight: _extractHighlight(map['highlight']),
            ))
        .toList();
    return results;
  }

  Map<String, List<dynamic>>? _extractFields(value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      final fields = <String, List<dynamic>>{};
      value.forEach((k, v) {
        if (v == null) return;

        final list = [];
        if (v is String) {
          list.add(v);
        } else if (v is List) {
          list.addAll(v);
        } else {
          throw FormatException('Unknown format for fields value: $v');
        }
        fields[k] = list;
      });
      return fields;
    }
    throw FormatException('Unknown format for fields value: $value');
  }

  Map<String, List<String>>? _extractHighlight(value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final highlights = <String, List<String>>{};
      value.forEach((k, v) {
        if (v == null) return;

        final list = <String>[];
        if (v is String) {
          list.add(v);
        } else if (v is List) {
          list.addAll(v.map((x) => x.toString()));
        } else {
          throw FormatException('Unknown format for highlight field: $v');
        }
        highlights[k] = list;
      });
      return highlights;
    }
    throw FormatException('Unknown format for highlight value: $value');
  }
}
