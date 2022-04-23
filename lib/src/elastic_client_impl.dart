import 'dart:async';
import 'dart:convert' as convert;

part '_client.dart';
part '_index.dart';
part '_query.dart';
part '_search.dart';
part '_transport.dart';

class Doc {
  final String? index;
  final String? type;
  final String id;
  final Map doc;
  final double? score;
  final List<dynamic>? sort;

  Doc(
    this.id,
    this.doc, {
    this.index,
    this.type,
    this.score,
    this.sort,
  });

  Map<String, dynamic> toMap() {
    return {
      if (index != null) '_index': index,
      if (type != null) '_type': type,
      '_id': id,
      if (score != null) '_score': score,
      'doc': doc,
      if (sort != null) 'sort': sort,
    };
  }
}

class Hit extends Doc {
  final Map<String, List<dynamic>>? fields;
  final Map<String, List<String>>? highlight;

  Hit(
    String id,
    Map doc, {
    String? index,
    String? type,
    double? score,
    List<dynamic>? sort,
    this.fields,
    this.highlight,
  }) : super(id, doc, index: index, type: type, score: score, sort: sort);

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      if (fields != null) 'fields': fields,
      if (highlight != null) 'highlight': highlight,
    };
  }
}

class SearchResult {
  final int totalCount;
  final List<Hit> hits;
  final Map<String, List<SuggestHit>>? suggestHits;
  final Map<String, Aggregation>? aggregations;
  final String? scrollId;

  SearchResult(this.totalCount, this.hits,
      {this.suggestHits, this.aggregations, this.scrollId});

  Map<String, dynamic> toMap() => {
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
  final int? freq;
  final String? highlighted;

  SuggestHitOption(this.text, this.score, {this.freq, this.highlighted});
}

class ElasticDocHit {
  final String id;
  final double score;

  ElasticDocHit(this.id, this.score);

  Map<String, dynamic> toMap() => {'id': id, 'score': score};
}

class Aggregation {
  String? name;
  Object? value;
  Map? values;
  int? docCountErrorUpperBound;
  int? sumOtherDocCount;
  int? docCount;
  List<Doc>? hits;
  List<Bucket>? buckets;

  Map<String, dynamic> toMap() {
    return {
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (values != null) 'values': values,
      if (docCountErrorUpperBound != null)
        'docCountErrorUpperBound': docCountErrorUpperBound,
      if (sumOtherDocCount != null) 'sumOtherDocCount': sumOtherDocCount,
      if (docCount != null) 'docCount': docCount,
      if (hits != null) 'hits': hits!.map((i) => i.toMap()).toList(),
      if (buckets != null) 'buckets': buckets!.map((i) => i.toMap()).toList(),
    };
  }

  Aggregation(String name, Map<String, dynamic> param, Map<String, dynamic> m) {
    this.name = name;
    value = m['value'];
    values = m['values'] as Map?;
    docCountErrorUpperBound = m['doc_count_error_upper_bound'] as int?;
    sumOtherDocCount = m['sum_other_doc_count'] as int?;
    docCount = m['doc_count'] as int?;

    final hitsMap = m['hits'] ?? const {};
    final hitsList = (hitsMap['hits'] as List?)?.cast<Map>() ?? const <Map>[];
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

    final bucketMapList = (m['buckets'] as List?)?.cast<Map>() ?? <Map>[];
    final buckets = bucketMapList.map<Bucket>((bucketMap) {
      final bucket = Bucket()
        ..key = bucketMap['key']
        ..docCount = bucketMap['doc_count'] as int;
      final aggMap = param['aggs'] as Map<String, dynamic>? ?? const {};
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
  Object? key;
  int? docCount;
  Map<String, Aggregation>? aggregations;

  Map<String, dynamic> toMap() {
    return {
      if (key != null) 'key': key,
      if (docCount != null) 'docCount': docCount,
      if (aggregations != null)
        'aggregations': aggregations!.map((k, v) => MapEntry(k, v.toMap())),
    };
  }
}

class Alias {
  final String? alias;
  final String? index;
  final String? indexRouting;
  final String? searchRouting;
  final bool? isWriteIndex;

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

  Map<String, dynamic> toMap() =>
      {'succeeded': succeeded, 'numFreed': numFreed};
}

class TermsEnumResult {
  final List<String> terms;

  TermsEnumResult(this.terms);
}
