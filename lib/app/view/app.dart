import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_openai_streaming/app/dio_stream_response_service.dart';
import 'package:flutter_openai_streaming/app/http_stream_response_service.dart';
import 'package:flutter_openai_streaming/app/stream_reponse_service.dart';

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
  final String apiUrl = 'http://192.168.1.3:11434/v1/chat/completions';

  String responseText = '';
  bool isHttpGenerating = false;
  bool isDioGenerating = false;
  final httpStreamResponseService = HttpStreamResponseService();
  final dioStreamResponseService = DioStreamResponseService();
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_API_KEY_HERE',
    //'Accept': 'text/event-stream',
  };
  final body = {
    'model': 'tinyllama',
    'messages': [
      {'role': 'user', 'content': 'Tell me a short story'},
    ],
    'stream': true,
  };

  Future<void> streamCompletion(
    StreamResponseService service, {
    required void Function() onStart,
    required void Function() onDone,
  }) async {
    onStart();
    await service.send(
      apiUrl,
      headers,
      body,
      (content) {
        setState(() {
          responseText += content;
        });
      },
      onDone: onDone,
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
              onPressed: () {
                if (isDioGenerating) {
                  setState(() {
                    isDioGenerating = false;
                  });
                  dioStreamResponseService.cancel();
                } else {
                  streamCompletion(
                    dioStreamResponseService,
                    onStart: () {
                      setState(() {
                        isDioGenerating = true;
                        responseText = '';
                      });
                    },
                    onDone: () {
                      setState(() {
                        isDioGenerating = false;
                      });
                    },
                  );
                }
              },
              child:
                  Text('${isDioGenerating ? 'Stop' : 'Start'} Dio Streaming'),
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              onPressed: () {
                if (isHttpGenerating) {
                  setState(() {
                    isHttpGenerating = false;
                  });
                  httpStreamResponseService.cancel();
                } else {
                  streamCompletion(
                    httpStreamResponseService,
                    onStart: () {
                      setState(() {
                        isHttpGenerating = true;
                        responseText = '';
                      });
                    },
                    onDone: () {
                      setState(() {
                        isHttpGenerating = false;
                      });
                    },
                  );
                }
              },
              child:
                  Text('${isHttpGenerating ? 'Stop' : 'Start'} Http Streaming'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    responseText.isEmpty && (isDioGenerating | isHttpGenerating)
                        ? 'Generating...'
                        : responseText,
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
}
