// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
// REF: https://stackoverflow.com/questions/73573957/how-to-receive-server-sent-events-sse-in-flutter-web
import 'package:flutter_openai_streaming/app/sse_stream.dart'
    if (dart.library.js_interop) 'package:flutter_openai_streaming/app/sse_stream_web.dart';
import 'package:flutter_openai_streaming/app/sse_transformer.dart';
import 'package:http/http.dart' as http;

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        useMaterial3: true,
      ),
      home: const OpenAIStreamExample(),
    );
  }
}

class OpenAIStreamExample extends StatefulWidget {
  const OpenAIStreamExample({super.key});

  @override
  State<OpenAIStreamExample> createState() => _OpenAIStreamExampleState();
}

class _OpenAIStreamExampleState extends State<OpenAIStreamExample> {
  final String apiKey = 'YOUR_API_KEY_HERE';
  final String apiUrl = 'http://192.168.1.3:11434/v1/chat/completions';

  String responseText = '';
  bool isLoading = false;
  StreamSubscription<dynamic>? _subscription;

  Future<void> streamCompletion() async {
    setState(() {
      isLoading = true;
      responseText = '';
    });

    final dio = Dio();

    try {
      final response = await dio.post<ResponseBody>(
        apiUrl,
        data: {
          'model': 'tinyllama',
          'messages': [
            {'role': 'user', 'content': 'Tell me a short story'},
          ],
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            'Accept': 'text/event-stream',
          },
        ),
        onReceiveProgress: (count, total) => debugPrint('$count/$total'),
      );
      final uint8Transformer =
          StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sink.add(List<int>.from(data));
        },
      );
      final byteStream = response.data?.stream.transform(uint8Transformer);
      final stringStream = byteStream?.transform(utf8.decoder);
      final lineStream = stringStream?.transform(const LineSplitter());

      // DOESN'T WORK
      // await for (var line in lineStream) {
      // REF: https://github.com/cfug/dio/issues/1279#issuecomment-1150634592
      lineStream?.listen((line) {
        if (line.startsWith('data: ')) {
          final jsonString = line.substring(6);
          if (jsonString.trim() != '[DONE]') {
            try {
              final data = json.decode(jsonString);
              if (data['choices'] != null &&
                  data['choices'][0]['delta'] != null &&
                  data['choices'][0]['delta']['content'] != null) {
                final content =
                    data['choices'][0]['delta']['content'] as String;
                setState(() {
                  responseText += content;
                });
              }
            } catch (e) {
              debugPrint('Error parsing JSON: $e');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        responseText = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> streamCompletionHttp() async {
    setState(() {
      isLoading = true;
      responseText = '';
    });

    final url = Uri.parse(apiUrl);
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'Accept': 'text/event-stream',
    });
    request
      ..body = json.encode({
        'model': 'tinyllama',
        'messages': [
          {'role': 'user', 'content': 'Tell me a short story'},
        ],
        'stream': true,
      })
      ..followRedirects = false;

    final stream = await getStream(request);
    _subscription = stream
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .transform(const SseTransformer())
        .transform(_contentTransformer)
        .listen(
      (content) {
        setState(() {
          responseText += content;
        });
      },
      onDone: () {
        setState(() {
          isLoading = false;
        });
      },
    );

    /*await for (final content in stream
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .transform(const SseTransformer())
        .transform(_contentTransformer)) {
      try {
        setState(() {
          responseText += content;
        });
      } catch (e) {
        debugPrint('Error: $e');
        setState(() {
          responseText = 'An error occurred: $e';
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } */
  }

  /*
  --SUBSCRIBING TO SSE---
  ---ERROR---
  ClientException: XMLHttpRequest error.,
  uri=http://192.168.1.3:11434/v1/chat/completions
  ---RETRY CONNECTION---
  */
  Future<void> streamCompletionSse() async {
    setState(() {
      isLoading = true;
      responseText = '';
    });

    ///POST REQUEST
    SSEClient.subscribeToSSE(
      method: SSERequestType.POST,
      url: apiUrl,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
      body: {
        'model': 'tinyllama',
        'messages': [
          {'role': 'user', 'content': 'Tell me a short story'},
        ],
        'stream': true,
      },
    ).listen(
      (event) {
        debugPrint('Id: ${event.id!}');
        debugPrint('Event: ${event.event!}');
        debugPrint('Data: ${event.data!}');
        try {
          event.data!.split('\n').forEach((msg) {
            if (!msg.startsWith('data: ')) {
              return;
            }

            final jsonMsg = msg.replaceFirst(RegExp('^data: '), '');

            if (jsonMsg == '[DONE]') {
              return;
            }

            final data = json.decode(jsonMsg);

            final content = data['choices'][0]['delta']['content'];
            if (content == null) {
              return;
            } else {
              setState(() {
                responseText += content.toString();
              });
            }
          });
        } catch (e) {
          debugPrint('Error: $e');
          setState(() {
            responseText = 'An error occurred: $e';
          });
        } finally {
          setState(() {
            isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI Stream Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : streamCompletion,
              child: const Text('Start Dio Streaming'),
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              onPressed: () {
                if (isLoading) {
                  setState(() {
                    isLoading = false;
                  });
                  _subscription?.cancel();
                } else {
                  streamCompletionHttp();
                }
              },
              child: Text('${isLoading ? 'Stop' : 'Start'} Http Streaming'),
            ),

            const SizedBox(height: 5),
            // DOESN'T WORK! SEE ERROR AT THE FUNCTION
            ElevatedButton(
              onPressed: isLoading ? null : streamCompletionSse,
              child: const Text('Start SSE Streaming'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    responseText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final StreamTransformer<SseMessage, String> _contentTransformer =
      StreamTransformer.fromHandlers(
    handleData: (message, sink) {
      final dataLine = message.data;
      if (dataLine.isNotEmpty &&
          !dataLine.startsWith(': ping') && // modal_llama-cpp-python
          !dataLine.contains('[DONE]')) {
        //final map = dataLine.replaceAll('data: ', '');
        final data = Map<String, dynamic>.from(jsonDecode(dataLine) as Map);
        final choices = List<dynamic>.from(data['choices'] as List);
        final choice = Map<String, dynamic>.from(choices[0] as Map);
        if (choice['finish_reason'] == null) {
          final delta = Map<String, dynamic>.from(choice['delta'] as Map);
          final content = delta['content'] as String;
          sink.add(content);
        }
      }
    },
  );
}
