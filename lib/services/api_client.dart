import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:8000'; // change when deployed

  static Future<Map<String, dynamic>> chat({
    required String message,
    required String mode,
    String? apiKey,
    String? provider,
    String? model,
    Uint8List? csvBytes,
    String? csvFilename,
    Uint8List? templateBytes,
    String? templateFilename,
    Uint8List? templateDocxBytes,
    String? templateDocxName,
    Uint8List? templatePptxBytes,
    String? templatePptxName,
    Map<String, dynamic>? certSettings,
    String? language,
  }) async {
    final uri = Uri.parse('$baseUrl/chat');
    final request = http.MultipartRequest('POST', uri);

    request.fields['message'] = message;
    request.fields['mode'] = mode;
    if (apiKey != null) request.fields['api_key'] = apiKey;
    if (provider != null) request.fields['provider'] = provider;
    if (model != null) request.fields['model'] = model;
    if (language != null) request.fields['language'] = language;
    
    if (certSettings != null) {
      request.fields['cert_settings'] = jsonEncode(certSettings);
    }

    if (csvBytes != null && csvFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          csvBytes,
          filename: csvFilename,
        ),
      );
    }
    
    // Cert Template
    if (templateBytes != null && templateFilename != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'template_file',
          templateBytes,
          filename: templateFilename,
        ),
      );
    }

    // DOCX Template
    if (templateDocxBytes != null && templateDocxName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'template_docx',
          templateDocxBytes,
          filename: templateDocxName,
        ),
      );
    }

    // PPTX Template
    if (templatePptxBytes != null && templatePptxName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'template_pptx',
          templatePptxBytes,
          filename: templatePptxName,
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
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

  static Future<List<Map<String, dynamic>>> getModels(String provider) async {
    final uri = Uri.parse('$baseUrl/models?provider=$provider');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['models'] as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Models API error: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> regenerate(Map<String, dynamic> plan, {Map<String, dynamic>? pptSettings, Map<String, dynamic>? certSettings}) async {
    final uri = Uri.parse('$baseUrl/regenerate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plan': plan,
        'ppt_settings': pptSettings,
        'cert_settings': certSettings,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Regenerate API error: ${response.statusCode}');
  }

  static Future<String> aiAssist({
    required String text,
    required String instruction,
    String? apiKey,
    String? provider,
    String? model,
  }) async {
    final uri = Uri.parse('$baseUrl/ai_assist');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'instruction': instruction,
        'api_key': apiKey,
        'provider': provider,
        'model': model,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] as String;
    }
    throw Exception('AI Assist error: ${response.statusCode}');
  }
}
