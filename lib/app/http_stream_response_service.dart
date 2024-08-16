import 'dart:async';
import 'dart:convert';

// REF: https://stackoverflow.com/questions/73573957/how-to-receive-server-sent-events-sse-in-flutter-web
import 'package:flutter_openai_streaming/app/http_stream_client.dart'
    if (dart.library.js_interop) 'package:flutter_openai_streaming/app/http_stream_client_web.dart';
import 'package:flutter_openai_streaming/app/sse_transformer.dart';
import 'package:flutter_openai_streaming/app/stream_reponse_service.dart';
import 'package:http/http.dart' as http;

class HttpStreamResponseService extends StreamResponseService {
  StreamSubscription<dynamic>? _subscription;
  final _client = HttpStreamClient();

  @override
  Future<void> send(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
    void Function(String content)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) async {
    final apiUrl = Uri.parse(url);
    final request = http.Request('POST', apiUrl)
      ..headers.addAll(headers)
      ..body = json.encode(body)
      ..followRedirects = false;

    final stream = await _client.send(request);
    _subscription = stream
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .transform(const SseTransformer())
        .transform(contentTransformer)
        .listen(
          onData,
          onDone: onDone,
          onError: onError,
          cancelOnError: cancelOnError,
        );
  }

  @override
  Future<void> cancel() async {
    await _subscription?.cancel();
  }
}
