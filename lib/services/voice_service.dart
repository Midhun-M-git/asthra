
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isAvailable = false;

  Future<void> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (val) => print('onError: $val'),
        onStatus: (val) => print('onStatus: $val'),
      );
      
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      print("Voice Init Error: $e");
    }
  }

  String _localeId = 'en-US';

  Future<void> setLocale(String simpleCode) async {
    // Map simple code to locale ID
    switch (simpleCode) {
      case 'ml': _localeId = 'ml-IN'; break;
      case 'hi': _localeId = 'hi-IN'; break;
      case 'es': _localeId = 'es-ES'; break;
      default: _localeId = 'en-US'; 
    }
    
    await _flutterTts.setLanguage(_localeId);
    print("Voice Locale set to: $_localeId");
  }

  Future<bool> startListening(Function(String) onResult) async {
    if (!_isAvailable) {
       // Try re-init if failed first time (e.g. permission granted late)
       await init();
       if (!_isAvailable) return false;
    }

    if (!_speech.isListening) {
      _speech.listen(
        onResult: (val) {
           onResult(val.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,
      );
      return true;
    }
    return false;
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.setLanguage(_localeId); // Ensure set before speak
      await _flutterTts.speak(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }
  
  bool get isListening => _speech.isListening;
}
