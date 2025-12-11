import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SpeechTranslate(),
    );
  }
}


class SpeechTranslate extends StatefulWidget {
  @override
  _SpeechTranslateState createState() => _SpeechTranslateState();
}

class _SpeechTranslateState extends State<SpeechTranslate> {
  SpeechToText speech = SpeechToText();
  bool isListening = false;
  String hindiText = "";
  String englishText = "";
  bool translateToEnglish = true; // true: Hindi -> English, false: English -> Hindi


  final translator = GoogleTranslator();
  final tts = FlutterTts();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Speak Translator"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  translateToEnglish = !translateToEnglish;
                });
              },
              child: Text(translateToEnglish ? "Hindi → English" : "English → Hindi"),
            ),
            SizedBox(height: 20,),


              Text("Hindi: $hindiText"),


              const SizedBox(height: 10),
              Text("English: $englishText",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 40),

            // Mic Button
            GestureDetector(
              onTap: startListening,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening ? Colors.red : Colors.blue),
                child: Icon(Icons.mic, size: 40, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Start Listening
  void startListening() async {
    bool available = await speech.initialize(
      onStatus: (val) => print("STATUS: $val"),
      onError: (val) => print("ERROR: $val"),
    );

    if (available) {
      setState(() => isListening = true);

      speech.listen(
        localeId: translateToEnglish ? "hi-IN" : "en-US",
        onResult: (val) {
          setState(() {
            if (translateToEnglish) {
              hindiText = val.recognizedWords;
            } else {
              englishText = val.recognizedWords;
            }
          });

          if (val.finalResult) translateAndSpeak(val.recognizedWords);
        },
      );
    } else {
      print("Speech not available");
    }
  }

  /// Translate to English & Speak
  void translateAndSpeak(String text) async {
    if (translateToEnglish) {
      var translation = await translator.translate(text, from: 'hi', to: 'en');
      englishText = translation.text;
      setState(() {});
      await tts.setLanguage("en-US");
      await tts.speak(englishText);
    } else {
      var translation = await translator.translate(text, from: 'en', to: 'hi');
      hindiText = translation.text;
      setState(() {});
      await tts.setLanguage("hi-IN");
      await tts.speak(hindiText);
    }

    speech.stop();
    setState(() => isListening = false);
  }

}
