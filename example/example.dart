import 'package:elastic_client/console_http_transport.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;

main() async {
  final transport =
      new ConsoleHttpTransport(Uri.parse('http://localhost:9200/'));
  final client = new elastic.Client(transport);

  await client.updateDoc('my_index', 'my_type', 'my_id', {'some': 'data'});
  await client.flushIndex('my_index');

  final rs = await client.search(
      'my_index', 'my_type', elastic.Query.term('some', ['data']));
  print(rs.toMap());

  await transport.close();
}
