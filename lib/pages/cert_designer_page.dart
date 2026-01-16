
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CertificateDesignerPage extends StatefulWidget {
  const CertificateDesignerPage({super.key});

  @override
  State<CertificateDesignerPage> createState() => _CertificateDesignerPageState();
}

class _CertificateDesignerPageState extends State<CertificateDesignerPage> {
  Uint8List? _templateBytes;
  String? _templateName;
  
  // Elements to place
  List<CertElement> _elements = [];
  
  // CSV Headers to select from
  List<String> _availableHeaders = [];
  String? _csvName;

  // Selected element for editing
  CertElement? _selectedElement;

  // Canvas Size (simulation) plays a role in coord mapping
  // We'll normalize to a standard width (e.g. 842 for A4 landscape PDF)
  final double _pdfWidth = 842.0; 
  final double _pdfHeight = 595.0;

  Future<void> _pickTemplate() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
    );
    if (res != null) {
      setState(() {
        _templateBytes = res.files.first.bytes;
        _templateName = res.files.first.name;
      });
    }
  }

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (res != null) {
      final bytes = res.files.first.bytes;
      if (bytes != null) {
        final content = utf8.decode(bytes);
        final lines = content.split('\n');
        if (lines.isNotEmpty) {
          final headerLine = lines.first;
          final headers = headerLine.split(',').map((e) => e.trim()).toList();
          setState(() {
            _availableHeaders = headers;
            _csvName = res.files.first.name;
            // Clear existing auto-elements if any? Or keep them.
          });
        }
      }
    }
  }

  void _addElement(String header) {
    setState(() {
      _elements.add(
        CertElement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '{$header}',
          x: 100,
          y: 100,
          type: 'text',
          fontSize: 24,
          color: Colors.black,
        ),
      );
    });
  }

  void _saveDesign() {
    if (_templateBytes == null && _elements.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to save!')));
       return;
    }

    // Convert elements to backend schema
    // Backend expects 'elements' list with x, y, size, color, font
    // Coordinates need to be mapped from UI canvas to PDF coords.
    // PDF (ReportLab) has (0,0) at BOTTOM-LEFT usually, but implementation might use Top-Left logic?
    // Let's check app.py logic. Default drawing uses c.drawString(x, y). 
    // ReportLab canvas (0,0) is Bottom-Left. 
    // UI (0,0) is Top-Left. 
    // We need to invert Y.
    
    final layout = <String, dynamic>{
      'layout': {}, // Flattened properties
    };
    
    // We actually need to pass the FULL list of dynamic elements, but app.py currently 
    // uses a fixed list [title, presented_to, name, etc.] controlled by 'layout' dict keys (e.g. 'name_x').
    // BUT checking the code, app.py ALSO had a check: "if not elements: ... create default".
    // This implies if we pass 'elements', it uses them!
    // Let's check _build_certificates_zip ... 
    // "elements: List[Dict] = []" in conditional.
    // If we pass 'elements' in settings, we should be able to override.
    // Actually `_build_certificates_zip` signature: `settings: Dict[str, Any]`
    // Inside: `elements = settings.get("elements")` ?? NO.
    // The viewing showed: `def _build_certificates_zip(..., settings=None): settings = settings or {}`
    // Then `elements = [ ... default ... ]`
    // Wait, the viewed code in previous turns showed hardcoded elements list construction based on settings keys.
    // It did NOT seem to support arbitrary list input from settings directly in the viewed snippet (lines 559-...).
    // "if not elements:" -> means if the FUNCTION argument `data` (renamed?) no. function signature `names: List[str]`.
    // Wait, I need to verify if `app.py` supports arbitrary elements list in settings.
    // The previous view of lines 559-583 suggests validation logic creates defaults if generic "elements" list is missing.
    // But does it READ it from settings? 
    // "elements" does not appear to be read from settings in that snippet, only specific keys "layout".
    // HOWEVER, I can MODIFY app.py to respect `settings['elements']` if present.
    // That gives full flexibility.
    
    // Let's assume for now I will produce a JSON that matches the "defaults" mapped from `layout` keys 
    // OR I will update app.py to accept raw elements.
    // Updating app.py to accept raw elements is cleaner for "Free Draw".
    
    final List<Map<String, dynamic>> exportElements = _elements.map((e) {
       // Map UI Y to PDF Y
       // PDF Height ~ 595.
       // PDF Y = 595 - UI_Y (roughly, ignoring margins/scaling for now)
       // We'll normalize coordinates later.
       return {
         "type": "text",
         "text": e.text,
         "x": e.x.toInt(),
         "y": (_pdfHeight - e.y).toInt(), // Invert Y
         "size": e.fontSize.toInt(),
         "color": '#${e.color.value.toRadixString(16).substring(2)}',
         "font": "Helvetica-Bold", 
         "align": "left" 
       };
    }).toList();

    Navigator.pop(context, {
      'elements': exportElements,
      'templateBytes': _templateBytes,
      'templateName': _templateName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Certificate Designer'),
        backgroundColor: const Color(0xFF1E1E2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveDesign,
            tooltip: 'Save Design',
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          
          final tools = Container(
            width: isMobile ? double.infinity : 200,
            height: isMobile ? 300 : double.infinity,
            color: const Color(0xFF2A2A3D),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text('Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blueAccent),
                  title: const Text('Template', style: TextStyle(color: Colors.white70)),
                  onTap: _pickTemplate,
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.greenAccent),
                  title: const Text('Load CSV', style: TextStyle(color: Colors.white70)),
                  subtitle: _csvName != null ? Text(_csvName!, style: const TextStyle(color: Colors.white30, fontSize: 10)) : null,
                  onTap: _pickCsv,
                ),
                const Divider(color: Colors.white10),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Drag Fields:', style: TextStyle(color: Colors.white54)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableHeaders.length,
                    itemBuilder: (context, index) {
                      final h = _availableHeaders[index];
                      // On mobile Draggable might behave effectively, but let's keep it.
                      // Long press to drag?
                      return Draggable<String>(
                        data: h,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Chip(label: Text('{$h}'), backgroundColor: Colors.orangeAccent),
                        ),
                        child: ListTile(
                          title: Text(h, style: const TextStyle(color: Colors.white)),
                          leading: const Icon(Icons.drag_indicator, color: Colors.white24),
                          onTap: () => _addElement(h), // Click to add
                        ),
                      );
                    },
                  ),
                ),
                // Manual Text
                 ListTile(
                  leading: const Icon(Icons.text_fields, color: Colors.white),
                  title: const Text('Add Text', style: TextStyle(color: Colors.white70)),
                  onTap: () => _addElement('Text'),
                ),
              ],
            ),
          );

          final canvasArea = Container(
              color: Colors.grey[900],
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.414, // A4 Landscape roughly
                  child: DragTarget<String>(
                    onAcceptWithDetails: (details) {
                         _addElement(details.data);
                    },
                    builder: (context, _, __) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          image: _templateBytes != null 
                             ? DecorationImage(image: MemoryImage(_templateBytes!), fit: BoxFit.fill)
                             : null,
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
                          ]
                        ),
                        child: Stack(
                          children: [
                             ..._elements.map((e) => Positioned(
                               left: e.x,
                               top: e.y,
                               child: GestureDetector(
                                 onPanUpdate: (details) {
                                   setState(() {
                                     e.x += details.delta.dx;
                                     e.y += details.delta.dy;
                                   });
                                 },
                                 onTap: () {
                                   setState(() {
                                      _selectedElement = e;
                                   });
                                   _showEditDialog(e);
                                 },
                                 child: Container(
                                   padding: const EdgeInsets.all(4),
                                   decoration: BoxDecoration(
                                     border: Border.all(color: Colors.blueAccent, width: 1),
                                     color: Colors.black12,
                                   ),
                                   child: Text(
                                     e.text, 
                                     style: TextStyle(
                                       fontSize: e.fontSize,
                                       color: e.color,
                                       fontWeight: FontWeight.bold,
                                       fontFamily: 'Arial', // Fallback
                                     )
                                   ),
                                 ),
                               ),
                             )).toList()
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ),
            );

          if (isMobile) {
            return Column(
               children: [
                  Expanded(flex: 3, child: canvasArea),
                  Expanded(flex: 2, child: tools),
               ],
            );
          } else {
             return Row(
               children: [
                  tools,
                  Expanded(child: canvasArea),
               ],
             );
          }
        }
      ),
    );
  }

  void _showEditDialog(CertElement e) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Edit Element'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: e.text,
            decoration: const InputDecoration(labelText: 'Text Content'),
            onChanged: (v) => setState(() => e.text = v),
          ),
          Slider(
            label: 'Font Size',
            min: 8, max: 72, 
            value: e.fontSize,
            onChanged: (v) => setState(() => e.fontSize = v),
          ),
          // Color picker simplified
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorBtn(Colors.black, e),
              _colorBtn(Colors.white, e),
              _colorBtn(Colors.red, e),
              _colorBtn(Colors.blue, e),
              _colorBtn(Colors.amber, e),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () {
           setState(() => _elements.remove(e));
           Navigator.pop(context);
        }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    ));
  }
  
  Widget _colorBtn(Color c, CertElement e) {
    return InkWell(
      onTap: () => setState(() => e.color = c),
      child: Container(width: 30, height: 30, color: c, margin: const EdgeInsets.all(4)),
    );
  }
}

class CertElement {
  String id;
  String text;
  double x;
  double y;
  String type;
  double fontSize;
  Color color;

  CertElement({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.type,
    this.fontSize = 20,
    this.color = Colors.black,
  });
}
