import 'dart:async';
import 'dart:convert' as convert;

import 'transport.dart';

class Doc {
  final String index;
  final String type;
  final String id;
  final Map doc;
  final double score;

  Doc(this.id, this.doc, {this.index, this.type, this.score});

  Map toMap() {
    final map = {
      '_index': index,
      '_type': type,
      '_id': id,
      '_score': score,
      'doc': doc,
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

  Future<SearchResult> search(String index, String type, Map<String, dynamic> query,
      {int offset, int limit, bool fetchSource = false, Map suggest, Map aggs, bool rawQuery = false}) async {
    final path = [index, type, '_search'];
    final map = rawQuery ? query: {
      '_source': fetchSource,
      'query': query,
      'from': offset,
      'size': limit,
      'suggest': suggest,
      'aggs' : aggs
    };
    map.removeWhere((k, v) => v == null);
    final rs = await _transport.send(new Request('POST', path,
        params: {'search_type': 'dfs_query_then_fetch'}, bodyMap: map));
    if (rs.statusCode != 200) {
      throw new Exception('Failed to search $query');
    }
    final body = convert.json.decode(rs.body);
    final hitsMap = body['hits'] ?? const {};
    final int totalCount = (hitsMap['total'] as int) ?? 0;
    final List<Map> hitsList =
        (hitsMap['hits'] as List).cast<Map>() ?? const <Map>[];
    final List<Doc> results = hitsList
        .map((Map map) => new Doc(
              map['_id'] as String,
              map['_source'] as Map,
              index: map['_index'] as String,
              type: map['_type'] as String,
              score: map['_score'] as double,
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
    return new SearchResult(totalCount, results,
        suggestHits: suggestHits.isEmpty ? null : suggestHits);
  }
}

class SearchResult {
  final int totalCount;
  final List<Doc> hits;
  final Map<String, List<SuggestHit>> suggestHits;

  SearchResult(this.totalCount, this.hits, {this.suggestHits});

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

abstract class Query {
  static Map<String, dynamic> matchAll() => {'match_all': {}};

  static Map<String, dynamic> matchNone() => {'match_none': {}};

  static Map<String, dynamic> bool({must, filter, should, mustNot}) {
    final map = {};
    if (must != null) map['must'] = must;
    if (filter != null) map['filter'] = filter;
    if (should != null) map['should'] = should;
    if (mustNot != null) map['mustNot'] = mustNot;
    return {'bool': map};
  }

  static Map<String, dynamic> exists(String field) => {
        'exists': {'field': field}
      };

  static Map<String, dynamic> term(String field, List<String> terms) => {
        'terms': {field: terms}
      };

  static Map<String, dynamic> match(String field, String text, {String minimum}) {
    final Map map = {'query': text};
    if (minimum != null) {
      map['minimum_should_match'] = minimum;
    }
    return {
      'match': {field: map}
    };
  }
}
