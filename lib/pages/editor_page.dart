import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../widgets/loading_indicator.dart';

class EditorPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String? apiKey;
  final String? provider;
  final String? model;
  final int initialTab;

  const EditorPage({
    super.key,
    required this.plan,
    this.apiKey,
    this.provider,
    this.model,
    this.initialTab = 0,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late Map<String, dynamic> _plan;
  bool _loading = false;
  
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  String _selectedFont = 'Arial';
  final List<String> _fonts = const [
    'Arial', 'Calibri', 'Times New Roman', 'Courier New', 
    'Verdana', 'Georgia', 'Garamond', 'Comic Sans MS'
  ];
  
  String _titleColor = '#000000';
  String _bodyColor = '#333333';
  String? _pptBgImageBase64;
  String _bgFileName = '';
  String? _certBgImageBase64;
  String _certBgFileName = '';
  
  final Map<String, String> _colors = {
    'Black': '#000000',
    'Dark Grey': '#333333',
    'Grey': '#666666',
    'Blue': '#0000FF',
    'Navy': '#000080',
    'Red': '#FF0000',
    'Green': '#008000',
    'Purple': '#800080',
    'Orange': '#FFA500',
    'Teal': '#008080',
    'Maroon': '#800000',
  };
  
  // Dynamic Elements
  List<Map<String, dynamic>> _certElements = [];

  @override
  void initState() {
    super.initState();
    _plan = Map.from(widget.plan);
    _titleController = TextEditingController(text: _plan['title']);
    _summaryController = TextEditingController(text: _plan['summary']);
    
    // Initialize Default Cert Elements (Backward Comp.)
    _certElements = [
      {'type': 'text', 'text': 'Certificate of Completion', 'x': 421, 'y': 480, 'size': 36, 'color': '#000080', 'align': 'center'},
      {'type': 'text', 'text': 'This is presented to', 'x': 421, 'y': 420, 'size': 18, 'color': '#666666', 'align': 'center'},
      {'type': 'text', 'text': '{name}', 'x': 421, 'y': 350, 'size': 40, 'color': '#000000', 'align': 'center'},
      {'type': 'text', 'text': 'For successful contribution to:', 'x': 421, 'y': 280, 'size': 18, 'color': '#666666', 'align': 'center'},
      {'type': 'text', 'text': _plan['title'] ?? 'Project Name', 'x': 421, 'y': 230, 'size': 24, 'color': '#000080', 'align': 'center'},
      {'type': 'text', 'text': 'Date: {date}', 'x': 100, 'y': 100, 'size': 14, 'color': '#000000', 'align': 'left'},
      {'type': 'text', 'text': 'Program Director', 'x': 650, 'y': 95, 'size': 16, 'color': '#000000', 'align': 'center'},
    ];

    if (_plan['ppt_slides'] == null) {
      _plan['ppt_slides'] = jsonDecode(jsonEncode(_plan['sections'])); 
    }
  }

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    
    // Update plan from controllers
    _plan['title'] = _titleController.text;
    _plan['summary'] = _summaryController.text;
    
    // Note: Sections are updated in-place by their controllers/logic
    // (Simpler implementation: we rely on direct object modification for list items in this Widget tree)

    try {
      final res = await ApiClient.regenerate(
        _plan, 
        pptSettings: {
           'font_name': _selectedFont,
           'title_color': _titleColor,
           'body_color': _bodyColor,
           'background_image': _pptBgImageBase64,
        },
        certSettings: {
           'background_image': _certBgImageBase64,
           'elements': _certElements,
        }
      );
      if (mounted) {
        Navigator.pop(context, res); // Return the result (files) to ChatPage
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _aiAssist(String text, String instruction, Function(String) onUpdate) async {
    if (widget.apiKey == null || widget.provider == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI keys required for Assist')));
      return;
    }
    
    setState(() => _loading = true);
    try {
      final newText = await ApiClient.aiAssist(
        text: text,
        instruction: instruction,
        apiKey: widget.apiKey,
        provider: widget.provider,
        model: widget.model,
      );
      onUpdate(newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAiPopup(String currentText, Function(String) onUpdate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A3D),
      builder: (ctx) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.short_text, color: Colors.white),
              title: const Text('Summarize', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _aiAssist(currentText, "Summarize this text in 1-2 sentences.", onUpdate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Expand', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _aiAssist(currentText, "Expand this text with more details.", onUpdate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school, color: Colors.white),
              title: const Text('Formalize', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _aiAssist(currentText, "Rewrite this in a formal, glossier tone.", onUpdate);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickPptBg() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      setState(() {
        _bgFileName = result.files.single.name;
        _pptBgImageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _pickCertBg() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      setState(() {
        _certBgFileName = result.files.single.name;
        _certBgImageBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Edit Report'),
        backgroundColor: const Color(0xFF1E1E2E),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_done),
              label: const Text('Generate'),
              onPressed: _regenerate,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          )
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : DefaultTabController(
              length: 3,
              initialIndex: widget.initialTab,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Colors.amberAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: "Content"),
                      Tab(text: "PPT Design"),
                      Tab(text: "Certificate"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: CONTENT EDITOR
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Project Title'),
                              _buildTextField(_titleController, aiEnabled: false),
                              const SizedBox(height: 16),
                              
                              _buildLabel('Executive Summary'),
                              _buildTextField(_summaryController, maxLines: 5, onUpdate: (val) => _summaryController.text = val),

                              const SizedBox(height: 24),
                              const Text('Sections (Long press to reorder)', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                              const Divider(color: Colors.white24),
                              
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: (_plan['sections'] as List).length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = (_plan['sections'] as List).removeAt(oldIndex);
                                    (_plan['sections'] as List).insert(newIndex, item);
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final section = (_plan['sections'] as List)[index] as Map<String, dynamic>;
                                  return Container(
                                    key: ValueKey(section.hashCode.toString() + index.toString()),
                                    child: _buildSectionEditor(section, index),
                                  );
                                },
                              ),
                              
                              Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      (_plan['sections'] as List).add({
                                        'heading': 'New Section',
                                        'bullets': ['New point']
                                      });
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                                  label: const Text('Add Section', style: TextStyle(color: Colors.blueAccent)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // TAB 2: PPT DESIGN
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const Text('Presentation Content (Slides)', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                               const Divider(color: Colors.white24),
                               
                               ...(_plan['ppt_slides'] as List).asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final section = entry.value as Map<String, dynamic>;
                                  return _buildSectionEditor(section, index, label: "Slide ${index + 1}");
                               }),
                               
                               Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      (_plan['ppt_slides'] as List).add({
                                        'title': 'New Slide',
                                        'bullets': ['New point']
                                      });
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle, color: Colors.amberAccent),
                                  label: const Text('Add Slide', style: TextStyle(color: Colors.amberAccent)),
                                ),
                              ),
                               
                               const SizedBox(height: 32),
                               const Text('Presentation Styling', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              
                              _buildLabel('Font Family'),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A3D),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedFont,
                                  dropdownColor: const Color(0xFF2A2A3D),
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(color: Colors.white),
                                  items: _fonts.map((f) => DropdownMenuItem(
                                    value: f, 
                                    child: Text(f, style: const TextStyle(color: Colors.white)),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedFont = val!),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                   Expanded(child: _buildColorDropdown('Title Color', _titleColor, (v) => setState(() => _titleColor = v))),
                                   const SizedBox(width: 12),
                                   Expanded(child: _buildColorDropdown('Body Color', _bodyColor, (v) => setState(() => _bodyColor = v))),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              const Divider(color: Colors.white24),
                              _buildLabel('Slide Background'),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickPptBg,
                                    icon: const Icon(Icons.image),
                                    label: Text(_bgFileName.isEmpty ? 'Upload Image' : 'Change Image'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2A2A3D),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_bgFileName.isNotEmpty)
                                    Expanded(child: Text(_bgFileName, style: const TextStyle(color: Colors.white70, overflow: TextOverflow.ellipsis))),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              const Divider(color: Colors.white24),
                              const Text('Tips:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                '- Choose high contrast colors for better readability.\n(e.g., Light text on Dark background, or vice versa)\n- Stick to standard fonts for max compatibility.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        
                        // TAB 3: CERTIFICATE DESIGN
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const Text('Certificate Studio', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 16),
                               
                               _buildLabel('Certificate Elements (Layers)'),
                               const SizedBox(height: 8),
                               _buildElementsList(),
                               
                               const SizedBox(height: 16),
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   ElevatedButton.icon(
                                     onPressed: _addTextElement,
                                     icon: const Icon(Icons.add),
                                     label: const Text('Add Text'),
                                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                                   ),
                                   const SizedBox(width: 12),
                                   ElevatedButton.icon(
                                     onPressed: _addImageElement,
                                     icon: const Icon(Icons.add_photo_alternate),
                                     label: const Text('Add Image'),
                                     style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                   ),
                                 ],
                               ),
                               
                               const SizedBox(height: 32),
                               const Divider(color: Colors.white24),
                               Center(
                                 child: ElevatedButton.icon(
                                   onPressed: _regenerate,
                                   icon: const Icon(Icons.check_circle, size: 28),
                                   label: const Text('Save & Generate Certificates', style: TextStyle(fontSize: 18)),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.amber,
                                     foregroundColor: Colors.black,
                                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildElementsList() {
      return Column(
        children: _certElements.asMap().entries.map((entry) {
          final index = entry.key;
          final el = entry.value;
          return Card(
            key: ObjectKey(el),
            color: Colors.white10,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
               title: Text(
                 el['type'] == 'text' ? (el['text'] as String) : 'Image Element',
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 maxLines: 1, overflow: TextOverflow.ellipsis,
               ),
               leading: Icon(el['type'] == 'text' ? Icons.text_fields : Icons.image, color: Colors.amberAccent),
               trailing: IconButton(
                 icon: const Icon(Icons.delete, color: Colors.redAccent),
                 onPressed: () => setState(() => _certElements.removeAt(index)),
               ),
               children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                       children: [
                          if (el['type'] == 'text')
                            TextFormField(
                               initialValue: el['text'],
                               style: const TextStyle(color: Colors.white),
                               decoration: const InputDecoration(labelText: 'Text Content (Use {name}, {date}, or CSV columns like {Grade})', labelStyle: TextStyle(color: Colors.white30)),
                               onChanged: (v) => el['text'] = v,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildNumInput(el, 'x', 'X Pos')),
                              const SizedBox(width: 8),
                              Expanded(child: _buildNumInput(el, 'y', 'Y Pos')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (el['type'] == 'text')
                            Row(
                               children: [
                                  Expanded(child: _buildNumInput(el, 'size', 'Size', def: 12)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildColorDropdown('Color', el['color'], (v) => setState(() => el['color'] = v))),
                               ],
                            ),
                          if (el['type'] == 'image')
                            Row(
                               children: [
                                  Expanded(child: _buildNumInput(el, 'width', 'Width', def: 100)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildNumInput(el, 'height', 'Height', def: 100)),
                               ],
                            ),
                          
                          if (el['type'] == 'image')
                             Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: ElevatedButton(
                                  onPressed: () async {
                                     final res = await FilePicker.platform.pickFiles(type: FileType.image);
                                     if (res != null) {
                                        setState(() => el['value'] = base64Encode(res.files.single.bytes!));
                                     }
                                  },
                                  child: const Text('Change Image'),
                               ),
                             )
                       ],
                    ),
                  )
               ],
            ),
          );
        }).toList(),
      );
  }

  Widget _buildNumInput(Map<String, dynamic> map, String key, String label, {int def=0}) {
      return TextFormField(
          initialValue: map[key]?.toString() ?? def.toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
             labelText: label,
             labelStyle: const TextStyle(color: Colors.white30),
             filled: true,
             fillColor: Colors.black26,
             isDense: true,
          ),
          onChanged: (v) => map[key] = int.tryParse(v) ?? def,
      );
  }

  void _addTextElement() {
      setState(() {
         _certElements.add({
            'type': 'text',
            'text': 'New Text',
            'x': 421, 'y': 300,
            'size': 24,
            'color': '#000000',
            'align': 'center'
         });
      });
  }

  Future<void> _addImageElement() async {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res != null && res.files.single.bytes != null) {
         setState(() {
            _certElements.add({
               'type': 'image',
               'value': base64Encode(res.files.single.bytes!),
               'x': 421, 'y': 300,
               'width': 100, 'height': 100
            });
         });
      }
  }

  Widget _buildSectionEditor(Map<String, dynamic> section, int index, {String? label}) {
    // Note: For a robust app we'd use controllers for every field. 
    // Here we assume direct map editing for brevity in this complex list.
    
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             TextFormField(
               initialValue: section['heading'] ?? section['title'],
               style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
               decoration: InputDecoration(
                 border: InputBorder.none,
                 hintText: label ?? 'Section Title',
                 hintStyle: const TextStyle(color: Colors.white30),
               ),
               onChanged: (val) {
                 section['heading'] = val;
                 section['title'] = val;
               },
             ),
             const SizedBox(height: 8),
             ...((section['bullets'] as List).asMap().entries.map((entry) {
               final bIndex = entry.key;
               final bullet = entry.value as String;
               return Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Padding(
                     padding: EdgeInsets.only(top: 8, right: 8),
                     child: Icon(Icons.circle, size: 8, color: Colors.white54),
                   ),
                   Expanded(
                     child: TextFormField(
                       initialValue: bullet,
                       style: const TextStyle(color: Colors.white70),
                       maxLines: null,
                       decoration: const InputDecoration(border: InputBorder.none),
                       onChanged: (val) => (section['bullets'] as List)[bIndex] = val,
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.auto_fix_high, color: Colors.amberAccent, size: 20),
                     onPressed: () => _showAiPopup(bullet, (newVal) {
                        setState(() {
                           (section['bullets'] as List)[bIndex] = newVal;
                           // Force rebuild? 
                        });
                     }),
                   )
                 ],
               );
             })),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1, bool aiEnabled = true, Function(String)? onUpdate}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A2A3D),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (aiEnabled && onUpdate != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Colors.amberAccent),
              onPressed: () => _showAiPopup(controller.text, onUpdate),
            ),
          )
      ],
    );
  }
  Widget _buildColorDropdown(String label, String currentVal, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButton<String>(
            value: currentVal,
            dropdownColor: const Color(0xFF2A2A3D),
            isExpanded: true,
            underline: const SizedBox(),
            items: _colors.entries.map((e) => DropdownMenuItem(
              value: e.value,
              child: Row(
                children: [
                   Container(width: 16, height: 16, color: Color(int.parse(e.value.substring(1), radix: 16) + 0xFF000000)),
                   const SizedBox(width: 8),
                   Text(e.key, style: const TextStyle(color: Colors.white)),
                ],
              ),
            )).toList(),
            onChanged: (val) => onChanged(val!),
          ),
        ),
      ],
    );
  }
}
