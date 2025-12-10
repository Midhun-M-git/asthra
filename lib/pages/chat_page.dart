import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../services/api_client.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/download_button.dart';
import '../widgets/loading_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _messages = [
    {"text": "Hey, how can I help you today buddy?", "isUser": false}
  ];
  final TextEditingController _controller = TextEditingController();
  Uint8List? _csvBytes;
  String? _csvFilename;
  Map<String, dynamic>? _lastFiles;
  bool _loading = false;
  String _mode = 'hybrid';
  bool? _aiEnabled;
  String _aiStatus = 'Checking AI...';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await ApiClient.status();
      setState(() {
        _aiEnabled = status['ai_enabled'] as bool?;
        final provider = status['provider'];
        final model = status['model'];
        final msg = status['message'] as String? ?? 'Status unknown';
        _aiStatus = provider != null && model != null
            ? '$provider/$model • $msg'
            : msg;
      });
    } catch (e) {
      setState(() {
        _aiEnabled = false;
        _aiStatus = 'Status error: $e';
      });
    }
  }

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _csvBytes = res.files.first.bytes;
        _csvFilename = res.files.first.name;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"text": text, "isUser": true});
      _loading = true;
      _lastFiles = null;
    });

    try {
      final response = await ApiClient.chat(
        message: text,
        mode: _mode,
        csvBytes: _csvBytes,
        csvFilename: _csvFilename,
      );
      final reply = response['reply'] as String? ?? 'Done.';
      final files = response['files'] as Map<String, dynamic>?;
      final ai = response['ai'] as Map<String, dynamic>? ?? {};

      setState(() {
        _messages.add({"text": reply, "isUser": false});
        final aiError = ai['error'] as String?;
        if (aiError != null && aiError.isNotEmpty) {
          _messages.add({"text": "AI notice: $aiError", "isUser": false});
        }
        _aiEnabled = ai['enabled'] as bool?;
        final provider = ai['provider'];
        final model = ai['model'];
        final modeUsed = ai['mode_used'];
        final status = ai['status'] ?? '';
        final modeLabel =
            modeUsed == 'hybrid' ? 'AI generated content' : 'Static content';
        _aiStatus = provider != null && model != null
            ? '$provider/$model • $modeLabel • $status'
            : '$modeLabel • $status';
        _lastFiles = files;
      });
    } catch (e) {
      setState(() {
        _messages.add({"text": "Error: $e", "isUser": false});
      });
    } finally {
      setState(() {
        _loading = false;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _aiEnabled == null
        ? Colors.grey
        : _aiEnabled == true
            ? Colors.greenAccent
            : Colors.amberAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: Shimmer.fromColors(
          baseColor: Colors.blueAccent,
          highlightColor: Colors.amberAccent,
          period: const Duration(seconds: 2),
          child: const Text(
            'ASTHRA',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                Icon(Icons.bolt, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  _aiStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                IconButton(
                  onPressed: _showCreators,
                  tooltip: 'Creators',
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                ),
                IconButton(
                  onPressed: _loadStatus,
                  tooltip: 'Refresh AI status',
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: _pickCsv,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _csvFilename == null ? 'Upload CSV' : 'CSV: $_csvFilename',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'static',
                        label: Text('Static'),
                        icon: Icon(Icons.offline_bolt),
                      ),
                      ButtonSegment(
                        value: 'hybrid',
                        label: Text('AI Hybrid'),
                        icon: Icon(Icons.smart_toy),
                      ),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      setState(() {
                        _mode = value.first;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: Colors.white10,
                  avatar: Icon(
                    _mode == 'hybrid' ? Icons.smart_toy : Icons.offline_bolt,
                    color: Colors.white,
                  ),
                  label: Text(
                    _mode == 'hybrid' ? 'AI enabled (if available)' : 'Offline static',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF2A2A3D),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return ChatBubble(text: m['text'], isUser: m['isUser']);
                },
              ),
            ),
          ),
          if (_loading) const LoadingIndicator(),
          if (_lastFiles != null)
            Container(
              color: const Color(0xFF2A2A3D),
              child: Column(
                children: [
                  FileDownloadButton(label: 'Report PDF', url: _lastFiles!['report']),
                  FileDownloadButton(label: 'Slides PPTX', url: _lastFiles!['ppt']),
                  FileDownloadButton(label: 'Patent PDF', url: _lastFiles!['patent']),
                  FileDownloadButton(
                      label: 'Certificates ZIP', url: _lastFiles!['certificates']),
                ],
              ),
            ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe your project or paste a GitHub repo URL...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2A2A3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.send),
            label: const Text(
              'Generate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showCreators() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Creators'),
          content: const Text('Midhun M\nNithya R\nRithin B'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
