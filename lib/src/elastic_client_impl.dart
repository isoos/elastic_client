import 'dart:async';
import 'dart:convert' as convert;

import 'transport.dart';

class Doc {
  final String index;
  final String type;
  final String id;
  final Map doc;
  final double score;
  final List<dynamic> sort;

  Doc(this.id, this.doc, {this.index, this.type, this.score, this.sort});

  Map toMap() {
    final map = {
      '_index': index,
      '_type': type,
      '_id': id,
      '_score': score,
      'doc': doc,
      'sort': sort,
    };
    map.removeWhere((k, v) => v == null);
    return map;
  }
}

class Client {
  final Transport _transport;

  Client(this._transport);

  Future<bool> indexExists(String index) async {
    final rs = await _transport.send(Request('HEAD', [index]));
    return rs.statusCode == 200;
  }

  Future updateIndex(String index, Map<String, dynamic> content) async {
    await _transport.send(Request('PUT', [index], bodyMap: content));
  }

  Future flushIndex(String index) async {
    await _transport.send(Request('POST', [index, '_flush'],
        params: {'wait_if_ongoing': 'true'}));
  }

  Future<bool> deleteIndex(String index) async {
    final rs = await _transport.send(Request('DELETE', [index]));
    return rs.statusCode == 200;
  }

  Future<List<Alias>> getAliases({List<String> aliases = const []}) async {
    final rs = await _transport.send(
      Request(
        'GET',
        ['_cat', 'aliases', aliases.join(',')],
        params: {'format': 'json'},
      ),
    );
    if (rs.statusCode != 200) {
      throw Exception(
          'Unable to get aliases information with $aliases. ${rs.statusCode} ${rs.body}');
    }
    final body = convert.json.decode(rs.body) as List;
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

  Future<bool> addAlias(String index, String alias) async {
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

  Future<bool> removeAlias(String index, String alias) async {
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

  Future<bool> swapAlias({String alias, String from, String to}) async {
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

  Future<bool> updateDoc(
      String index, String type, String id, Map<String, dynamic> doc,
      {bool merge = false}) async {
    final pathSegments = [index, type];
    if (id != null) pathSegments.add(id);
    if (merge) pathSegments.add('_update');
    final rs =
        await _transport.send(Request('POST', pathSegments, bodyMap: doc));
    return rs.statusCode == 200 || rs.statusCode == 201;
  }

  Future<bool> updateDocs(String index, String type, List<Doc> docs,
      {int batchSize = 100}) async {
    final pathSegments = [index, type, '_bulk']..removeWhere((v) => v == null);
    for (var start = 0; start < docs.length;) {
      final sub = docs.skip(start).take(batchSize).toList();
      final lines = sub
          .map((doc) => [
                {
                  'index': {
                    '_index': doc.index,
                    '_type': doc.type,
                    '_id': doc.id
                  }..removeWhere((k, v) => v == null)
                },
                doc.doc,
              ])
          .expand((list) => list)
          .map(convert.json.encode)
          .map((s) => '$s\n')
          .join();
      final rs =
          await _transport.send(Request('POST', pathSegments, bodyText: lines));
      if (rs.statusCode != 200) {
        throw Exception(
            'Unable to update batch starting with $start. ${rs.statusCode} ${rs.body}');
      }
      start += sub.length;
    }
    return true;
  }

  Future<int> deleteDoc(String index, String type, String id) async {
    final rs = await _transport.send(Request('DELETE', [index, type, id]));
    return rs.statusCode == 200 ? 1 : 0;
  }

  Future<int> deleteDocs(String index, Map query) async {
    final rs = await _transport.send(Request(
        'POST', [index, '_delete_by_query'],
        bodyMap: {'query': query}));
    if (rs.statusCode != 200) return 0;
    return rs.bodyAsMap['deleted'] as int ?? 0;
  }

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
      'query': query ?? {},
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
    if (rs.statusCode != 200) {
      throw Exception('Failed to search $query');
    }
    final body = convert.json.decode(rs.body) as Map<String, dynamic>;
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

  Future<SearchResult> scroll(String scrollId, Duration scroll) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {
      'scroll_id': scrollId,
      'scroll': scroll.inSeconds.toString() + 's',
    };
    final rs = await _transport.send(Request('GET', path, bodyMap: bodyMap));
    if (rs.statusCode != 200) {
      throw Exception('Failed to search scroll');
    }
    final body = convert.json.decode(rs.body) as Map<String, dynamic>;
    final hitsMap = body['hits'] as Map<String, dynamic> ?? const {};
    final totalCount = _extractTotalCount(hitsMap);
    final results = _extractDocList(hitsMap);

    return SearchResult(
      totalCount,
      results,
      scrollId: body['_scroll_id'] as String,
    );
  }

  Future<ClearScrollResult> clearScroll(List<String> scrollIdList) async {
    final path = ['_search', 'scroll'];
    final bodyMap = {'scroll_id': scrollIdList};
    final rs = await _transport.send(Request('DELETE', path, bodyMap: bodyMap));
    if (rs.statusCode != 200 && rs.statusCode != 404) {
      throw Exception('Failed to search scroll');
    }
    final body = convert.json.decode(rs.body);
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

class SearchResult {
  final int totalCount;
  final List<Doc> hits;
  final Map<String, List<SuggestHit>> suggestHits;
  final Map<String, Aggregation> aggregations;
  final String scrollId;

  SearchResult(this.totalCount, this.hits,
      {this.suggestHits, this.aggregations, this.scrollId});

  Map toMap() => {
        'totalCount': totalCount,
        'hits': hits.map((h) => h.toMap()).toList(),
      };
}

class SuggestHit {
  final String text;
  final int offset;
  final int length;
  final List<SuggestHitOption> options;

  SuggestHit(this.text, this.offset, this.length, this.options);
}

class SuggestHitOption {
  final String text;
  final double score;
  final int freq;
  final String highlighted;

  SuggestHitOption(this.text, this.score, {this.freq, this.highlighted});
}

class ElasticDocHit {
  final String id;
  final double score;

  ElasticDocHit(this.id, this.score);

  Map toMap() => {'id': id, 'score': score};
}

class Aggregation {
  String name;
  dynamic value;
  Map values;
  int docCountErrorUpperBound;
  int sumOtherDocCount;
  List<Doc> hits;
  List<Bucket> buckets;

  Map toMap() {
    final map = {
      'name': name,
      'value': value,
      'values': values,
      'docCountErrorUpperBound': docCountErrorUpperBound,
      'sumOtherDocCount': sumOtherDocCount,
      'hits': hits?.map((i) => i.toMap()),
      'buckets': buckets?.map((i) => i.toMap()),
    };
    map.removeWhere((k, v) => v == null);
    return map;
  }

  Aggregation(String name, Map<String, dynamic> param, Map<String, dynamic> m) {
    this.name = name;
    value = m['value'];
    values = m['values'] as Map;
    docCountErrorUpperBound = m['doc_count_error_upper_bound'] as int;
    sumOtherDocCount = m['sum_other_doc_count'] as int;

    final hitsMap = m['hits'] ?? const {};
    final hitsList =
        ((hitsMap['hits'] ?? []) as List).cast<Map>() ?? const <Map>[];
    final hits = hitsList
        .map((map) => Doc(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String,
              type: map['_type'] as String,
              score: map['_score'] as double,
              sort: map['sort'] as List<dynamic>,
            ))
        .toList();
    this.hits = hits.isEmpty ? null : hits;

    final bucketMapList = ((m['buckets'] ?? []) as List).cast<Map>() ?? <Map>[];
    final buckets = bucketMapList.map<Bucket>((bucketMap) {
      final bucket = Bucket()
        ..key = bucketMap['key']
        ..docCount = bucketMap['doc_count'] as int;
      final aggMap = param['aggs'] as Map<String, dynamic> ?? const {};
      final aggs = aggMap.map<String, Aggregation>((subName, subParam) {
        final subMap = bucketMap[subName] as Map<String, dynamic>;
        return MapEntry(subName,
            Aggregation(subName, subParam as Map<String, dynamic>, subMap));
      });
      bucket.aggregations = aggs.isEmpty ? null : aggs;
      return bucket;
    }).toList();
    this.buckets = buckets.isEmpty ? null : buckets;
  }
}

class Bucket {
  dynamic key;
  int docCount;
  Map<String, Aggregation> aggregations;

  Map toMap() {
    final map = {
      'key': key,
      'docCount': docCount,
      'aggregations': aggregations?.map((k, v) => MapEntry(k, v.toMap())),
    };
    map.removeWhere((k, v) => v == null);
    return map;
  }
}

class Alias {
  final String alias;
  final String index;
  final String indexRouting;
  final String searchRouting;
  final bool isWriteIndex;

  Alias({
    this.alias,
    this.index,
    this.indexRouting,
    this.searchRouting,
    this.isWriteIndex,
  });
}

class ClearScrollResult {
  final bool succeeded;
  final int numFreed;
  ClearScrollResult(this.succeeded, this.numFreed);

  Map toMap() => {'succeeded': succeeded, 'numFreed': numFreed};
}

abstract class Query {
  static Map matchAll() => {'match_all': {}};

  static Map matchNone() => {'match_none': {}};

  static Map bool({
    dynamic must,
    dynamic filter,
    dynamic should,
    dynamic mustNot,
  }) {
    final map = {};
    if (must != null) map['must'] = must;
    if (filter != null) map['filter'] = filter;
    if (should != null) map['should'] = should;
    if (mustNot != null) map['mustNot'] = mustNot;
    return {'bool': map};
  }

  static Map exists(String field) => {
        'exists': {'field': field}
      };

  static Map term(String field, List<String> terms) => {
        'terms': {field: terms}
      };

  static Map prefix(String field, String value) => {
        'prefix': {field: value},
      };

  static Map match(String field, String text, {String minimum}) {
    final map = {'query': text};
    if (minimum != null) {
      map['minimum_should_match'] = minimum;
    }
    return {
      'match': {field: map}
    };
  }
}
