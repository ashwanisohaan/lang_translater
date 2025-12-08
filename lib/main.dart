import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speak Translator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'SPEAK_TRANSLATOR'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final translator = GoogleTranslator();

  bool _isListening = false;
  String _lastWords = '';
  String _translated = '';
  String _status = 'Idle';

  // --- NEW: Add state variables for language toggling ---
  String _sourceLocaleId = 'hi_IN'; // Start with Hindi
  String _targetLanguage = 'en';     // Target is English
  String _sourceLanguageName = 'Hindi';

  @override
  void initState() {
    super.initState();
    _initTts();
    // --- Listen to TTS completion to restart listening ---
    _tts.setCompletionHandler(() {
      if (_isListening) {
        _restartListening();
      }
    });
  }

  Future<void> _initTts() async {
    // We will set language dynamically before speaking
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // --- NEW: Toggle the source and target languages ---
  void _toggleLanguages() {
    setState(() {
      if (_sourceLocaleId == 'hi_IN') {
        _sourceLocaleId = 'en_US';
        _targetLanguage = 'hi';
        _sourceLanguageName = 'English';
      } else {
        _sourceLocaleId = 'hi_IN';
        _targetLanguage = 'en';
        _sourceLanguageName = 'Hindi';
      }
      // Reset texts
      _lastWords = '';
      _translated = '';
    });
  }

  Future<void> _startListening() async {
    final hasPermission = await Permission.microphone.request().isGranted;
    if (!hasPermission) {
      setState(() => _status = 'Microphone permission denied');
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          // We'll manage the status more manually now
        },
        onError: (err) {
          setState(() => _status = 'Error: ${err.errorMsg}');
          _isListening = false;
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _status = 'Listening...';
        });
        _listen(); // Start the first listening session
      } else {
        setState(() => _status = 'Speech recognition not available');
      }
    }
  }

  // --- NEW: Logic to restart listening after TTS is done ---
  void _restartListening() async {
    setState(() => _status = 'Listening...');
    await _listen();
  }

  // --- REFACTORED: The core listening logic ---
  Future<void> _listen() async {
    await _speech.listen(
      onResult: (result) async {
        final recognized = result.recognizedWords;
        setState(() {
          _lastWords = recognized;
        });

        if (result.finalResult) {
          setState(() => _status = 'Translating...');
          try {
            final translation = await translator.translate(
              recognized,
              from: _sourceLocaleId.split('_')[0], // 'hi' or 'en'
              to: _targetLanguage, // 'en' or 'hi'
            );
            setState(() {
              _translated = translation.text;
              _status = 'Speaking...';
            });
            // Set the correct TTS language before speaking
            await _tts.setLanguage(_targetLanguage == 'hi' ? 'hi-IN' : 'en-US');
            await _tts.speak(_translated);
            // Don't set status to Idle here, wait for TTS completion
          } catch (e) {
            setState(() => _status = 'Translate/TTS error: $e');
            // If error, try restarting listening
            if (_isListening) _restartListening();
          }
        }
      },
      localeId: _sourceLocaleId,
      listenFor: const Duration(seconds: 30), // Listen for a longer period
      pauseFor: const Duration(seconds: 3),   // Time to wait after user stops talking
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    await _tts.stop(); // Also stop any ongoing speech
    setState(() {
      _isListening = false;
      _status = 'Stopped';
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            // --- NEW: Language toggle button ---
            ElevatedButton.icon(
              onPressed: _toggleLanguages,
              icon: const Icon(Icons.swap_horiz),
              label: Text('Translate from: $_sourceLanguageName'),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              child: ListTile(
                title: Text(
                  _lastWords.isEmpty ? 'Say something in $_sourceLanguageName...' : _lastWords,
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: Text(
                  _translated.isEmpty ? 'Translation will appear here' : _translated,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent : Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (_translated.isNotEmpty) {
                  // Set correct language before replaying
                  await _tts.setLanguage(_targetLanguage == 'hi' ? 'hi-IN' : 'en-US');
                  await _tts.speak(_translated);
                }
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Replay translation'),
            ),
          ],
        ),
      ),
    );
  }
}
