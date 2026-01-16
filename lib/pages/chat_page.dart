import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/voice_service.dart';
import '../services/api_client.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/download_button.dart';
import '../widgets/loading_indicator.dart';
import 'cert_designer_page.dart';
import 'dashboard_page.dart';
import 'editor_page.dart';
import 'setup_page.dart';

class ChatPage extends StatefulWidget {
  final String apiKey;
  final String provider;
  final String model;

  const ChatPage({
    super.key,
    required this.apiKey,
    required this.provider,
    required this.model,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _messages = [
    {"text": "Hey, how can I help you today buddy?", "isUser": false}
  ];
  final TextEditingController _controller = TextEditingController();
  
  // State variables
  Uint8List? _csvBytes;
  String? _csvFilename;
  
  // Templates
  Uint8List? _templateBytes; // Cert Template
  String? _templateFilename;
  Uint8List? _docTemplateBytes;
  String? _docTemplateName;
  Uint8List? _pptTemplateBytes;
  String? _pptTemplateName;
  
  Map<String, dynamic>? _lastFiles;
  Map<String, dynamic>? _lastPlan; // For Editor
  bool _loading = false;
  String _mode = 'hybrid';
  bool? _aiEnabled;
  String _aiStatus = 'Checking AI...';
  
  // Certificate Settings
  Map<String, dynamic>? _certSettings;

  // Localization
  String _selectedLocale = 'en';
  final Map<String, String> _languages = {
    'en': 'English',
    'ml': 'Malayalam',
    'hi': 'Hindi',
    'es': 'Spanish',
  };
  
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'ai_enabled': 'AI enabled',
      'offline': 'Offline',
      'generate': 'Generate',
      'analyze': 'Analyze',
      'files_regen': 'Files regenerated from edits!',
      'cert_saved': 'Certificate Layout Saved! Next "Generate" will use it.',
      'voice_unavailable': 'Voice input not available',
      'static': 'Static',
      'hybrid': 'AI Hybrid',
      'input_hint': 'Type a message...',
      'listening': 'Listening...',
    },
    'ml': {
      'ai_enabled': 'AI സജീവമാണ്',
      'offline': 'ഓഫ്ലൈൻ',
      'generate': 'സൃഷ്ടിക്കുക',
      'analyze': 'വിശകലനം ചെയ്യുക',
      'files_regen': 'ഫയലുകൾ പുതുക്കി!',
      'cert_saved': 'സർട്ടിഫിക്കറ്റ് ലേഔട്ട് സേവ് ചെയ്തു.',
      'voice_unavailable': 'ശബ്ദ ഇൻപുട്ട് ലഭ്യമല്ല',
      'static': 'സ്റ്റാറ്റിക്',
      'hybrid': 'AI ഹൈബ്രിഡ്',
      'input_hint': 'സന്ദേശം ടൈപ്പ് ചെയ്യുക...',
      'listening': 'ശ്രദ്ധിക്കുന്നു...',
    },
    'hi': {
      'ai_enabled': 'AI सक्षम है',
      'offline': 'ऑफ़लाइन',
      'generate': 'उत्पन्न करें',
      'analyze': 'विश्लेषण करें',
      'files_regen': 'फाइलें पुनर्जीवित की गईं!',
      'cert_saved': 'प्रमाणपत्र लेआउट सहेजा गया.',
      'voice_unavailable': 'वॉयस इनपुट उपलब्ध नहीं है',
      'static': 'स्थिर',
      'hybrid': 'AI हाइब्रिड',
      'input_hint': 'संदेश टाइप करें...',
      'listening': 'सुन रहा हूँ...',
    },
    'es': {
      'ai_enabled': 'IA habilitada',
      'offline': 'Desconectado',
      'generate': 'Generar',
      'analyze': 'Analizar',
      'files_regen': '¡Archivos regenerados!',
      'cert_saved': 'Diseño guardado.',
      'voice_unavailable': 'Entrada de voz no disponible',
      'static': 'Estático',
      'hybrid': 'IA Híbrida',
      'input_hint': 'Escribe un mensaje...',
      'listening': 'Escuchando...',
    },
  };

  String get _t => _translations[_selectedLocale]?[_selectedLocale] ?? ''; // Helper? No, used map direct lookup better.
  String t(String key) => _translations[_selectedLocale]?[key] ?? key;

  // Voice Service
  late final VoiceService _voiceService;
  bool _isListening = false;
  bool _isTtsEnabled = true; // New State

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceService();
    _voiceService.init();
    _loadStatus();
  }

  // ... (keep _loadStatus, _pickCsv, etc.)

  void _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      final available = await _voiceService.startListening((text) {
        setState(() {
           _controller.text = text;
        });
      });
      if (!available) {
        setState(() => _isListening = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice input not available')));
      }
    }
  }

  // in _sendMessage success block
  /* 
      // ... existing setState
      _voiceService.speak(reply); // Auto-read reply
  */


  // ... (existing helper methods like _loadStatus, _pickCsv, _pickTemplate)

  Future<void> _openCertDesigner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CertificateDesignerPage(),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
         // Store settings to be sent with next chat request
         _certSettings = {
            'elements': result['elements'],
         };
         
         // If template was selected in designer, use it
         if (result['templateBytes'] != null) {
            _templateBytes = result['templateBytes'];
            _templateFilename = result['templateName'] ?? 'designer_template.png';
         }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate Layout Saved! Next "Generate" will use it.')),
      );
    }
  }

  // ... (keep _sendMessage)
  
  // Inside _sendMessage logic, update ApiClient call:
  /*
      final response = await ApiClient.chat(
        message: text,
        mode: _mode,
        apiKey: widget.apiKey,
        provider: widget.provider,
        model: widget.model,
        csvBytes: _csvBytes,
        csvFilename: _csvFilename,
        templateBytes: _templateBytes,
        templateFilename: _templateFilename,
        certSettings: _certSettings, // Pass this
      );
  */


  Future<void> _loadStatus() async {
    try {
      final status = await ApiClient.status();
      setState(() {
        _aiEnabled = status['ai_enabled'] as bool?;
         // Override status with local config info to confirm UI state
        _aiStatus = '${widget.provider}/${widget.model} • Ready';
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

  Future<void> _pickAnyFile(List<String> extensions, Function(Uint8List, String) onPicked) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (result != null && result.files.single.bytes != null) {
         onPicked(result.files.single.bytes!, result.files.single.name);
         setState(() {});
      }
    } catch (e) {
      print("Pick error: $e");
    }
  }

  void _showTemplateOptions() {
     showModalBottomSheet(
       context: context, 
       builder: (ctx) => Container(
         padding: const EdgeInsets.all(20),
         height: 350,
         color: const Color(0xFF1E1E2E),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text("Select Template Type", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 20),
             ListTile(
               leading: const Icon(Icons.verified_user, color: Colors.amber),
               title: Text(_templateFilename ?? "Certificate Template (Image)", style: const TextStyle(color: Colors.white)),
               subtitle: const Text("For generated certificates", style: TextStyle(color: Colors.white54)),
               trailing: _templateFilename != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: (){
                   setState(() { _templateBytes = null; _templateFilename = null; _certSettings = null; });
                   Navigator.pop(ctx);
               }) : null,
               onTap: () {
                   Navigator.pop(ctx);
                   _pickAnyFile(['png', 'jpg', 'jpeg', 'webp', 'bmp'], (b, n) {
                      _templateBytes = b; _templateFilename = n;
                   });
               },
             ),
             ListTile(
               leading: const Icon(Icons.description, color: Colors.blue),
               title: Text(_docTemplateName ?? "Report Template (Word)", style: const TextStyle(color: Colors.white)),
               subtitle: const Text("Use {{title}}, {{content}} placeholders", style: TextStyle(color: Colors.white54)),
                trailing: _docTemplateName != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: (){
                   setState(() { _docTemplateBytes = null; _docTemplateName = null; });
                   Navigator.pop(ctx);
               }) : null,
               onTap: () {
                   Navigator.pop(ctx);
                   _pickAnyFile(['docx'], (b, n) {
                      _docTemplateBytes = b; _docTemplateName = n;
                   });
               },
             ),
             ListTile(
               leading: const Icon(Icons.slideshow, color: Colors.orange),
               title: Text(_pptTemplateName ?? "Presentation Template (PPTX)", style: const TextStyle(color: Colors.white)),
               subtitle: const Text("Use Custom Slide Master", style: TextStyle(color: Colors.white54)),
                trailing: _pptTemplateName != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: (){
                   setState(() { _pptTemplateBytes = null; _pptTemplateName = null; });
                   Navigator.pop(ctx);
               }) : null,
               onTap: () {
                   Navigator.pop(ctx);
                   _pickAnyFile(['pptx'], (b, n) {
                      _pptTemplateBytes = b; _pptTemplateName = n;
                   });
               },
             ),
           ],
         )
       )
     );
  }

  Future<void> _pickTemplate() async {
      _showTemplateOptions(); // Trigger the menu
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"text": text, "isUser": true});
      _loading = true;
      _lastFiles = null;
      _lastPlan = null;
    });
    
    _voiceService.stopSpeaking(); // Stop previous speech
    _voiceService.stopListening();
    _isListening = false;
    try {
      final response = await ApiClient.chat(
        message: text,
        mode: _mode,
        apiKey: widget.apiKey,
        provider: widget.provider,
        model: widget.model,
        csvBytes: _csvBytes,
        csvFilename: _csvFilename,
        templateBytes: _templateBytes,
        templateFilename: _templateFilename,
        templateDocxBytes: _docTemplateBytes,
        templateDocxName: _docTemplateName,
        templatePptxBytes: _pptTemplateBytes,
        templatePptxName: _pptTemplateName,
        certSettings: _certSettings,
        language: _selectedLocale,
      );
      final reply = response['reply'] as String? ?? 'Done.';
      final files = response['files'] as Map<String, dynamic>?;
      final plan = response['plan'] as Map<String, dynamic>?;
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
        
        final modeLabel = modeUsed == 'hybrid' ? 'AI generated' : 'Static';
        if (provider != null) {
          _aiStatus = '$provider/$model • $modeLabel';
        } else {
          _aiStatus = '$modeLabel • $status';
        }
        
        _lastFiles = files;
        _lastPlan = plan;
      });

    // Auto-speak reply
    if (_isTtsEnabled) {
      _voiceService.speak(reply);
    }

      // Update Analytics
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('total_projects', (prefs.getInt('total_projects') ?? 0) + 1);
        await prefs.setInt('ai_requests', (prefs.getInt('ai_requests') ?? 0) + 1);
        
        if (files != null && files.containsKey('certificates')) {
           // Heuristic: If we generated certs, increment. Rough count.
           // Ideally backend tells us how many rows. For now, count as 1 batch.
           await prefs.setInt('certificates_generated', (prefs.getInt('certificates_generated') ?? 0) + 1); 
        }
      } catch (e) {
        print('Analytics error: $e');
      }
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
  
  void _openEditor({int initialTab = 0}) async {
    if (_lastPlan == null) return;
    
    final updatedFiles = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPage(
          plan: _lastPlan!,
          apiKey: widget.apiKey,
          provider: widget.provider,
          model: widget.model,
          initialTab: initialTab,
        ),
      ),
    );

    if (updatedFiles != null && updatedFiles is Map) {
       setState(() {
         if (updatedFiles.containsKey('files')) {
            _lastFiles = updatedFiles['files'];
         }
       });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files regenerated from edits!')));
    }

  }

  void _createNewProject(int tabIndex) {
    setState(() {
      _lastPlan = {
        'title': 'New Project',
        'summary': 'Project Summary...',
        'sections': [
          {'heading': 'Introduction', 'bullets': ['Click to edit this point.']}
        ],
        'ppt_slides': [
          {'title': 'Title Slide', 'bullets': ['Subtitle or Key Point']}
        ],
        'claims': ['Claim 1'],
        'certificate_note': 'Completion Note'
      };
      // Clear files so we don't show old downloads
      _lastFiles = null;
    });
    _openEditor(initialTab: tabIndex);
  }
  
  void _showGitHubDialog() {
    final urlController = TextEditingController();
    String selectedAction = 'Generate Report';
    final actions = ['Generate Report', 'Code Review', 'Explain Architecture', 'Generate README'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A3D),
             title: const Row(children: [Icon(Icons.code, color: Colors.white), SizedBox(width: 8), Text('GitHub Agent', style: TextStyle(color: Colors.white))]),
             content: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 TextField(
                   controller: urlController,
                   style: const TextStyle(color: Colors.white),
                   decoration: const InputDecoration(
                     labelText: 'Repository URL',
                     labelStyle: TextStyle(color: Colors.white70),
                     hintText: 'https://github.com/user/repo',
                     hintStyle: TextStyle(color: Colors.white30),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                     focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                   ),
                 ),
                 const SizedBox(height: 16),
                 DropdownButtonFormField<String>(
                   value: selectedAction,
                   dropdownColor: const Color(0xFF2A2A3D),
                   style: const TextStyle(color: Colors.white),
                   decoration: const InputDecoration(
                     labelText: 'Action',
                     labelStyle: TextStyle(color: Colors.white70),
                     enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                   ),
                   items: actions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                   onChanged: (v) => setState(() => selectedAction = v!),
                 ),
               ],
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
               ElevatedButton(
                 onPressed: () {
                    if (urlController.text.isNotEmpty) {
                       Navigator.pop(ctx);
                       _controller.text = "Analyze this GitHub repository: ${urlController.text}. Perform action: $selectedAction.";
                       _handleSend();
                    }
                 },
                 child: const Text('Analyze'),
               ),
             ],
          );
        }
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
                DropdownButton<String>(
                  value: _selectedLocale,
                  dropdownColor: const Color(0xFF2A2A3D),
                  style: const TextStyle(color: Colors.white),
                  underline: Container(),
                  icon: const Icon(Icons.language, color: Colors.white70),
                  items: _languages.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedLocale = val);
                      _voiceService.setLocale(val);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isTtsEnabled ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white70,
                  ),
                  tooltip: "Text-to-Speech",
                  onPressed: () {
                    setState(() {
                      _isTtsEnabled = !_isTtsEnabled;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  tooltip: 'Settings',
                  onSelected: (val) {
                    if (val == 'key') {
                      _clearSession();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'key',
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('Change API Key'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
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
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage())),
                  tooltip: 'Analytics Dashboard',
                  icon: const Icon(Icons.bar_chart, color: Colors.tealAccent),
                ),
                TextButton.icon(
                  onPressed: _pickCsv,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _csvFilename == null ? 'CSV' : 'CSV: $_csvFilename',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showTemplateOptions,
                  icon: const Icon(Icons.tune, color: Colors.white),
                  label: Text(
                    (_templateFilename != null || _docTemplateName != null || _pptTemplateName != null) 
                       ? "Configured" 
                       : "Template",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                   icon: const Icon(Icons.design_services, color: Colors.pinkAccent),
                   tooltip: 'Design Certificate',
                   onPressed: _openCertDesigner,
                ),
                IconButton(
                   icon: const Icon(Icons.code, color: Colors.purpleAccent), // GitHub Icon substitute
                   tooltip: 'GitHub Agent',
                   onPressed: _showGitHubDialog,
                )
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
                    segments: [
                      ButtonSegment(
                        value: 'static',
                        label: Text(t('static')),
                        icon: Icon(Icons.offline_bolt),
                      ),
                      ButtonSegment(
                        value: 'hybrid',
                        label: Text(t('hybrid')),
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
                    _mode == 'hybrid' ? t('ai_enabled') : t('offline'),
                     style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          
          if (_mode == 'static')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF2A2A3D),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildStudioButton(Icons.description, "Word Clone", () => _createNewProject(0)),
                   _buildStudioButton(Icons.slideshow, "PPT Creator", () => _createNewProject(1)),
                   _buildStudioButton(Icons.workspace_premium, "Cert Studio", () => _createNewProject(2)),
                   _buildStudioButton(Icons.code, "GitHub Agent", _showGitHubDialog),
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
                  if (_lastPlan != null)
                     Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: ElevatedButton.icon(
                         onPressed: _openEditor,
                         icon: const Icon(Icons.edit_note),
                         label: const Text('Edit Report & Regenerate'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal,
                           foregroundColor: Colors.white,
                         ),
                       ),
                     ),
                  FileDownloadButton(label: 'Report PDF', url: _lastFiles!['report']),
                  if (_lastFiles!.containsKey('report_docx'))
                    FileDownloadButton(label: 'Report DOCX (Editable)', url: _lastFiles!['report_docx']),

                  // PPT Section
                  Row(
                    children: [
                      Expanded(child: FileDownloadButton(label: 'Slides PPTX', url: _lastFiles!['ppt'])),
                      IconButton(
                        icon: const Icon(Icons.brush, color: Colors.amberAccent),
                        tooltip: 'Edit PPT Design',
                        onPressed: () => _openEditor(initialTab: 1),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  FileDownloadButton(label: 'Patent PDF', url: _lastFiles!['patent']),
                  
                  // Certificates Section
                  Row(
                    children: [
                      Expanded(child: FileDownloadButton(label: 'Certificates ZIP', url: _lastFiles!['certificates'])),
                      IconButton(
                        icon: const Icon(Icons.edit_attributes, color: Colors.cyanAccent),
                        tooltip: 'Edit Certificate',
                        onPressed: () => _openEditor(initialTab: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
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
                hintText: _isListening ? t('listening') : t('input_hint'),
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A2A3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white70),
            onPressed: _toggleListening,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _handleSend,
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
            label: Text(
              t('generate'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStudioButton(IconData icon, String label, VoidCallback onTap) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white70),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: TextButton.styleFrom(backgroundColor: Colors.white10),
      );
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('provider');
    await prefs.remove('model');
    
    if (mounted) {
       Navigator.of(context).pushReplacement(
         MaterialPageRoute(builder: (_) => const SetupPage()),
       );
    }
  }
}
