import 'package:http/http.dart';

Future<ByteStream> getStream(Request request) async {
  print('sse_stream getStream');
  final client = Client();
  final response = await client.send(request);
  return response.stream;
}
