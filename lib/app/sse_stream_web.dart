import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart';

Future<ByteStream> getStream(Request request) async {
  print('sse_stream_web getStream');
  final client = FetchClient(mode: RequestMode.cors);
  final response = await client.send(request);
  return response.stream;
}
