import 'dart:async';

import 'package:elastic_client/elastic_client.dart';

Future<void> main() async {
  final transport = HttpTransport(url: 'http://localhost:9042/');
  final client = Client(transport);

  // bucket aggregation
  final rs3 = await client.search(
      index: 'my_index',
      type: 'my_type',
      query: Query.matchAll(),
      aggregations: {
        'agg1': {
          'terms': {'field': 'name.keyword'}
        }
      });
  rs3.aggregations['agg1'].buckets.forEach((i) => print(i.toMap()));
  // {key: Bob, docCount: 1}
  // {key: Joe, docCount: 1}
  // {key: Sue, docCount: 1}

  // metric aggregation (value)
  final rs4 = await client.search(
      index: 'my_index',
      type: 'my_type',
      query: Query.matchAll(),
      aggregations: {
        'agg1': {
          'avg': {'field': 'distance'}
        }
      });
  print(rs4.aggregations['agg1'].value);
  // 13.333333333333334

  // metric aggregation (values)
  final rs5 = await client.search(
      index: 'my_index',
      type: 'my_type',
      query: Query.matchAll(),
      aggregations: {
        'agg1': {
          'percentiles': {'field': 'distance'}
        }
      });
  print(rs5.aggregations['agg1'].values);
  // {1.0: 9.999999999999998, 5.0: 10.0, 25.0: 10.0, 50.0: 10.0, 75.0: 17.5, 95.0: 20.0, 99.0: 20.0}

  // bucket aggregation (nested)
  final rs6 = await client.search(
    index: 'my_index',
    type: 'my_type',
    query: Query.matchAll(),
    aggregations: {
      'agg1': {
        'terms': {'field': 'distance'},
        'aggs': {
          'agg1_agg1': {
            'terms': {'field': 'name.keyword'}
          }
        }
      }
    },
  );
  rs6.aggregations['agg1'].buckets.forEach((b) {
    b.aggregations['agg1_agg1'].buckets.forEach((b2) {
      print('${b.key} ${b2.toMap()}');
    });
  });
  // 10 {key: Joe, docCount: 1}
  // 10 {key: Sue, docCount: 1}
  // 20 {key: Bob, docCount: 1}

  // bucket aggregation (top_hits)
  final rs7 = await client.search(
    index: 'my_index',
    type: 'my_type',
    query: Query.matchAll(),
    aggregations: {
      'agg1': {
        'terms': {'field': 'distance'},
        'aggs': {
          'agg1_agg1': {
            'top_hits': {'size': 1}
          }
        }
      }
    },
  );
  rs7.aggregations['agg1'].buckets.forEach((i) {
    print(i.aggregations['agg1_agg1'].hits.map((doc) => doc.toMap()));
  });
  // ({_index: my_index, _type: my_type, _id: my_id_1, _score: 1.0, doc: {some: data, name: Sue, distance: 10}})
  // ({_index: my_index, _type: my_type, _id: my_id_2, _score: 1.0, doc: {some: data, name: Bob, distance: 20}})
  await transport.close();
}
