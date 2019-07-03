import 'package:elastic_client/console_http_transport.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;

main() async {
  final transport =
      new ConsoleHttpTransport(Uri.parse('http://localhost:9200/'));
  final client = new elastic.Client(transport);

  await client.updateDoc('my_index', 'my_type', 'my_id_1', {'some': 'data', 'name':'Sue', 'distance': 10});
  await client.updateDoc('my_index', 'my_type', 'my_id_2', {'some': 'data', 'name':'Bob', 'distance': 20});
  await client.updateDoc('my_index', 'my_type', 'my_id_3', {'some': 'data', 'name':'Joe', 'distance': 10});
  await client.flushIndex('my_index');

  final rs1 = await client.search(
      'my_index',
      'my_type',
      elastic.Query.term('some', ['data']),
      source: true
    );
  print(rs1.toMap());

  print("---");

  final rs2 = await client.search(
      'my_index',
      'my_type',
      elastic.Query.term('some', ['data']),
      source: ['some', 'name'],
      sort: [{ "distance" : "asc" }, { "name.keyword" : "asc" }]
    );
  print(rs2.toMap());

  await transport.close();
}
