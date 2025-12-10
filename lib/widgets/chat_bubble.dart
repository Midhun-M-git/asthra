import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {

  final String text;

  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  @override

  Widget build(BuildContext context) {

    final bg = isUser ? Colors.indigo.shade600 : Colors.grey.shade200;

    final fg = isUser ? Colors.white : Colors.black87;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(

      crossAxisAlignment: align,

      children: [

        Container(

          margin: const EdgeInsets.symmetric(vertical: 6),

          padding: const EdgeInsets.all(12),

          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),

          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),

          child: Text(text, style: TextStyle(color: fg)),

        )

      ],

    );

  }

}



