import 'package:elastic_client/elastic_client.dart';

Future<void> main() async {
  final transport = HttpTransport(url: 'http://localhost:9200/');
  final client = Client(transport);

  await client.updateDoc(
    index: 'my_index',
    type: 'my_type',
    id: 'my_id_1',
    doc: {'some': 'data', 'name': 'Sue', 'distance': 10},
  );
  await client.updateDoc(
    index: 'my_index',
    type: 'my_type',
    id: 'my_id_2',
    doc: {'some': 'data', 'name': 'Bob', 'distance': 20},
  );
  await client.updateDoc(
    index: 'my_index',
    type: 'my_type',
    id: 'my_id_3',
    doc: {'some': 'data', 'name': 'Joe', 'distance': 10},
  );
  await client.flushIndex(index: 'my_index');

  final rs1 = await client.search(
      index: 'my_index',
      type: 'my_type',
      query: Query.term('some', ['data']),
      source: true);
  print(rs1.toMap());

  print('---');

  final rs2 = await client.search(
      index: 'my_index',
      type: 'my_type',
      query: Query.term('some', ['data']),
      source: [
        'some',
        'name'
      ],
      sort: [
        {'distance': 'asc'},
        {'name.keyword': 'asc'}
      ]);
  print(rs2.toMap());

  // Search by ids.
  final rs3 = await client.search(
    index: 'my_index',
    query: Query.ids(['1', '2', '3']),
  );
  print(rs3.toMap());

  await client.addAlias(index: 'my_index', alias: 'my_index_alias');
  await client.updateDoc(
    index: 'my_second_index',
    type: 'my_type',
    id: 'my_id_1',
    doc: {'some': 'data', 'name': 'Alice', 'distance': 10},
  );
  await client.swapAlias(
      alias: 'my_index_alias', from: 'my_index', to: 'my_second_index');
  final aliases = await client.getAliases(aliases: ['my_index_*']);
  print(aliases.map((e) => {'alias': e.alias, 'index': e.index}));
  await client.removeAlias(index: 'my_second_index', alias: 'my_index_alias');

  // Count the total items of an index.
  final total = await client.count(index: 'my_index');
  print(total);

  await transport.close();
}
