import 'package:http_client/console.dart';

import 'src/http_transport.dart';

export 'src/http_transport.dart';
export 'elastic_client.dart';

class ConsoleHttpTransport extends HttpTransport {
  ConsoleHttpTransport(Uri uri, {BasicAuth basicAuth})
      : super(ConsoleClient(), uri, basicAuth: basicAuth);
}
