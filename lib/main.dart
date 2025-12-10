
import 'package:flutter/material.dart';
import 'pages/chat_page.dart';

void main() {
  runApp(const AIDocApp());
}

class AIDocApp extends StatelessWidget {
  const AIDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASTHRA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ChatPage(), // or Chatpage() if that's your class name
    );
  }
}

