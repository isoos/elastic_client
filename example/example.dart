import 'package:elastic_client/console_http_transport.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;

main() async {
  final transport =
      new ConsoleHttpTransport(Uri.parse('http://10.2.0.4:29200/'));
  final client = new elastic.Client(transport);

//  await client.updateDoc('my_index', 'my_type', 'my_id', {'some': 'data'});
//  await client.flushIndex('my_index');

  final rs = await client.search(
      'drive_mk_v1_text', 'doc', elastic.Query.term('some', ['data']));
  print(rs.toMap());

  await transport.close();
}
