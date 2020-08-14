import 'package:elastic_client/console_http_transport.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;

Future<void> main() async {
  final transport = ConsoleHttpTransport(Uri.parse('http://localhost:9200/'));
  final client = elastic.Client(transport);

  await client.updateDoc('my_index', 'my_type', 'my_id_1',
      {'some': 'data', 'name': 'Sue', 'distance': 10});
  await client.updateDoc('my_index', 'my_type', 'my_id_2',
      {'some': 'data', 'name': 'Bob', 'distance': 20});
  await client.updateDoc('my_index', 'my_type', 'my_id_3',
      {'some': 'data', 'name': 'Joe', 'distance': 10});
  await client.flushIndex('my_index');

  final rs1 = await client.search(
      'my_index', 'my_type', elastic.Query.term('some', ['data']),
      source: true);
  print(rs1.toMap());

  print('---');

  final rs2 = await client.search(
      'my_index', 'my_type', elastic.Query.term('some', ['data']),
      source: [
        'some',
        'name'
      ],
      sort: [
        {'distance': 'asc'},
        {'name.keyword': 'asc'}
      ]);
  print(rs2.toMap());

  await client.addAlias('my_index', 'my_index_alias');
  await client.updateDoc('my_second_index', 'my_type', 'my_id_1',
      {'some': 'data', 'name': 'Alice', 'distance': 10});
  await client.swapAlias(
      alias: 'my_index_alias', from: 'my_index', to: 'my_second_index');
  final aliases = await client.getAliases(aliases: ['my_index_*']);
  print(aliases.map((e) => {'alias': e.alias, 'index': e.index}));
  await client.removeAlias('my_second_index', 'my_index_alias');

  await transport.close();
}
