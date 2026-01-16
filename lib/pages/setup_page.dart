import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import 'chat_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _keyController = TextEditingController();
  String _provider = 'openrouter'; // default
  String? _selectedModel;
  List<Map<String, dynamic>> _openRouterModels = [];
  bool _loadingModels = false;
  String _statusMsg = '';

  final List<String> _providers = ['openrouter', 'openai', 'gemini', 'bedrock'];

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('api_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      final savedProvider = prefs.getString('provider') ?? 'openrouter';
      final savedModel = prefs.getString('model') ?? 'default';
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
             builder: (_) => ChatPage(
               apiKey: savedKey,
               provider: savedProvider,
               model: savedModel,
             ),
          ),
        );
      }
    }
  }

  Future<void> _fetchModels() async {
    setState(() {
      _loadingModels = true;
      _statusMsg = 'Fetching models...';
    });
    try {
      final models = await ApiClient.getModels('openrouter');
      setState(() {
        _openRouterModels = models;
        if (models.isNotEmpty) {
          _selectedModel = models.first['id'];
        }
        _statusMsg = 'Fetched ${models.length} models.';
      });
    } catch (e) {
      setState(() {
        _statusMsg = 'Error fetching models: $e';
      });
    } finally {
      setState(() {
        _loadingModels = false;
      });
    }
  }

  void _startApp() {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API Key')),
      );
      return;
    }

    // Determine model
    String model = 'default';
    if (_provider == 'openrouter') {
      if (_selectedModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a model (fetch first)')),
        );
        return;
      }
      model = _selectedModel!;
    } else if (_provider == 'openai') {
      model = 'gpt-4o-mini';
    } else if (_provider == 'gemini') {
      model = 'gemini-1.5-flash';
    } else if (_provider == 'bedrock') {
      model = 'anthropic.claude-3-haiku-20240307-v1:0'; 
    }

    _saveSession(key, _provider, model);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          apiKey: key,
          provider: _provider,
          model: model,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('AI Configuration'),
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your AI Credentials',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _keyController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'API Key',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'sk-or-v1-...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF2A2A3D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _provider,
              dropdownColor: const Color(0xFF2A2A3D),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Provider',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2A2A3D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _providers.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _provider = val!;
                  _selectedModel = null; // reset model
                });
              },
            ),
            const SizedBox(height: 24),
            if (_provider == 'openrouter') ...[
              Row(
                children: [
                  Expanded(
                    child: _openRouterModels.isEmpty
                        ? const Text('Load models to select', style: TextStyle(color: Colors.grey))
                        : DropdownButtonFormField<String>(
                            value: _selectedModel,
                            dropdownColor: const Color(0xFF2A2A3D),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Model (Free listed first)',
                              labelStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF2A2A3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _openRouterModels.map((m) {
                              final name = m['name'];
                              final isFree = m['is_free'] == true;
                              return DropdownMenuItem<String>(
                                value: m['id'],
                                child: Text(
                                  '$name ${isFree ? "(FREE)" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedModel = val),
                          ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loadingModels ? null : _fetchModels,
                    child: _loadingModels
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_statusMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_statusMsg, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
            ] else ...[
               // Static hint for other providers
               Text(
                 'Using default model for $_provider',
                 style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
               ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _startApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start ASTHRA', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  Future<void> _saveSession(String key, String provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    await prefs.setString('provider', provider);
    await prefs.setString('model', model);
  }
}
