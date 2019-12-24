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
    final rs = await _transport.send(new Request('HEAD', [index]));
    return rs.statusCode == 200;
  }

  Future updateIndex(String index, Map<String, dynamic> content) async {
    await _transport.send(new Request('PUT', [index], bodyMap: content));
  }

  Future flushIndex(String index) async {
    await _transport.send(new Request('POST', [index, '_flush'],
        params: {'wait_if_ongoing': 'true'}));
  }

  Future<bool> deleteIndex(String index) async {
    final rs = await _transport.send(new Request('DELETE', [index]));
    return rs.statusCode == 200;
  }

  Future<bool> updateDoc(
      String index, String type, String id, Map<String, dynamic> doc) async {
    final pathSegments = [index, type];
    if (id != null) pathSegments.add(id);
    final rs =
        await _transport.send(new Request('POST', pathSegments, bodyMap: doc));
    return rs.statusCode == 200 || rs.statusCode == 201;
  }

  Future<bool> updateDocs(String index, String type, List<Doc> docs,
      {int batchSize = 100}) async {
    final pathSegments = [index, type, '_bulk']..removeWhere((v) => v == null);
    for (int start = 0; start < docs.length;) {
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
      final rs = await _transport
          .send(new Request('POST', pathSegments, bodyText: lines));
      if (rs.statusCode != 200) {
        throw new Exception(
            'Unable to update batch starting with $start. ${rs.statusCode} ${rs.body}');
      }
      start += sub.length;
    }
    return true;
  }

  Future<int> deleteDoc(String index, String type, String id) async {
    final rs = await _transport.send(new Request('DELETE', [index, type, id]));
    return rs.statusCode == 200 ? 1 : 0;
  }

  Future<int> deleteDocs(String index, Map query) async {
    final rs = await _transport.send(new Request(
        'POST', [index, '_delete_by_query'],
        bodyMap: {'query': query}));
    if (rs.statusCode != 200) return 0;
    return rs.bodyAsMap['deleted'] as int ?? 0;
  }

  Future<SearchResult> search(
    String index,
    String type,
    Map query, {
    int offset,
    int limit,
    @Deprecated("Use 'source' instead") bool fetchSource = false,
    dynamic source,
    Map suggest,
    List<Map> sort,
    Map aggregations,
  }) async {
    final path = [index, type, '_search'];
    final map = {
      '_source': source ?? fetchSource,
      'query': query,
      'from': offset,
      'size': limit,
      'suggest': suggest,
      'sort': sort,
      'aggregations': aggregations,
    };
    map.removeWhere((k, v) => v == null);
    final rs = await _transport.send(new Request('POST', path,
        params: {'search_type': 'dfs_query_then_fetch'}, bodyMap: map));
    if (rs.statusCode != 200) {
      throw new Exception('Failed to search $query');
    }
    final body = convert.json.decode(rs.body);
    final hitsMap = body['hits'] ?? const {};
    final hitsTotal = hitsMap['total'];
    int totalCount = 0;
    if (hitsTotal is int) {
      totalCount = hitsTotal;
    } else if (hitsTotal is Map) {
      totalCount = (hitsTotal['value'] as int) ?? 0;
    }
    final List<Map> hitsList =
        (hitsMap['hits'] as List).cast<Map>() ?? const <Map>[];
    final List<Doc> results = hitsList
        .map((Map map) => new Doc(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String,
              type: map['_type'] as String,
              score: map['_score'] as double,
              sort: map['sort'] as List<dynamic>,
            ))
        .toList();
    final suggestMap = body['suggest'] as Map ?? const {};
    final suggestHits = suggestMap.map<String, List<SuggestHit>>((k, v) {
      if (v == null) return null;
      final list = (v as List).cast<Map>();
      final hits = list
          .map((map) {
            final optionsList = (map['options'] as List).cast<Map>();
            final options = optionsList?.map((m) {
              return new SuggestHitOption(
                m['text'] as String,
                m['score'] as double,
                freq: m['freq'] as int,
                highlighted: m['highlighted'] as String,
              );
            })?.toList();
            return new SuggestHit(
              map['text'] as String,
              map['offset'] as int,
              map['length'] as int,
              options,
            );
          })
          .where((x) => x != null)
          .toList();
      return new MapEntry('', hits);
    });
    suggestHits.removeWhere((k, v) => v == null);

    final aggMap = body['aggregations'] as Map<String, dynamic> ?? const {};
    final aggResult = aggMap.map<String, Aggregation>((k, v) {
      return MapEntry(
          k,
          Aggregation(k, aggregations[k] as Map<String, dynamic>,
              v as Map<String, dynamic>));
    });

    return new SearchResult(
      totalCount,
      results,
      suggestHits: suggestHits.isEmpty ? null : suggestHits,
      aggregations: aggResult.isEmpty ? null : aggResult,
    );
  }
}

class SearchResult {
  final int totalCount;
  final List<Doc> hits;
  final Map<String, List<SuggestHit>> suggestHits;
  final Map<String, Aggregation> aggregations;

  SearchResult(this.totalCount, this.hits,
      {this.suggestHits, this.aggregations});

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
    this.value = m['value'];
    this.values = m['values'] as Map;
    this.docCountErrorUpperBound = m['doc_count_error_upper_bound'] as int;
    this.sumOtherDocCount = m['sum_other_doc_count'] as int;

    final hitsMap = m['hits'] ?? const {};
    final List<Map> hitsList =
        ((hitsMap['hits'] ?? []) as List).cast<Map>() ?? const <Map>[];
    this.hits = hitsList
        .map((map) => new Doc(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String,
              type: map['_type'] as String,
              score: map['_score'] as double,
              sort: map['sort'] as List<dynamic>,
            ))
        .toList();

    final bucketMapList = ((m['buckets'] ?? []) as List).cast<Map>() ?? <Map>[];
    final buckets = bucketMapList.map<Bucket>((bucketMap) {
      Bucket bucket = Bucket()
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

abstract class Query {
  static Map matchAll() => {'match_all': {}};

  static Map matchNone() => {'match_none': {}};

  static Map bool({must, filter, should, mustNot}) {
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
    final Map map = {'query': text};
    if (minimum != null) {
      map['minimum_should_match'] = minimum;
    }
    return {
      'match': {field: map}
    };
  }
}
