import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:8000'; // change when deployed

  static Future<Map<String, dynamic>> chat({
    required String message,
    required String mode,
    List<int>? csvBytes,
    String? csvFilename,
  }) async {
    final uri = Uri.parse('$baseUrl/chat');
    final request = http.MultipartRequest('POST', uri);

    request.fields['message'] = message;
    request.fields['mode'] = mode;

    if (csvBytes != null && csvFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          csvBytes,
          filename: csvFilename,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Chat API error: ${response.statusCode} ${response.body}');
  }

  static Future<Map<String, dynamic>> status() async {
    final response = await http.get(Uri.parse('$baseUrl/status'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Status API error: ${response.statusCode} ${response.body}');
  }
}
