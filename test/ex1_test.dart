import 'package:docker_process/docker_process.dart';
import 'package:test/test.dart';

import 'package:elastic_client/elastic_client.dart';

void main() {
  group('ex1', () {
    DockerProcess? dp;
    HttpTransport? httpTransport;
    late Client client;

    test('setup', () async {
      final port = 13131;
      dp = await DockerProcess.start(
        image: 'docker.elastic.co/elasticsearch/elasticsearch:7.9.3',
        name: 'elasticsearch_$port',
        cleanup: true,
        ports: ['127.0.0.1:$port:9200'],
        environment: {
          'discovery.type': 'single-node',
        },
        readySignal: (line) {
          return line.contains('publish_address') &&
              line.contains('bound_addresses') &&
              line.contains('9200');
        },
        timeout: Duration(seconds: 110),
      );
      httpTransport = HttpTransport(url: 'http://127.0.0.1:$port/');
      client = Client(httpTransport!);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('index does not exists', () async {
      expect(await client.indexExists(index: 'test-ex1'), isFalse);
    });

    test('create index and add document', () async {
      final index = client.index(name: 'test-ex1');
      await index.update(
        content: {
          'settings': {
            'index': {
              'number_of_shards': 1,
              'number_of_replicas': 0,
            },
          },
          'mappings': {
            'properties': {
              'field1': {'type': 'text'},
            },
          },
        },
      );
      expect(await index.exists(), isTrue);

      expect(
          await index.updateDoc(
            id: 'id-1',
            doc: {
              'field1': 'abcd12',
              'field2': ['abab', 'cd'],
            },
          ),
          isTrue);
      await index.flush();
      await Future.delayed(Duration(seconds: 2));

      final rs = await index.search(
        query: Query.prefix('field2.keyword', 'aba'),
      );
      expect(rs.totalCount, 1);
      expect(rs.hits, hasLength(1));
      expect(rs.hits.single.id, 'id-1');
    });

    tearDownAll(() async {
      await httpTransport?.close();
      await dp?.stop();
      await dp?.kill();
    });
  });
}
