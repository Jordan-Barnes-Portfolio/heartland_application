import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AnnotationScreen extends StatefulWidget {
  final String imagePath;

  const AnnotationScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _AnnotationScreenState createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initSpeech();
    }
  }

  void _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        print('onStatus: $status');
        print('Mounted: $mounted');
        if (status == 'done' && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (errorNotification) {
        print('onError: $errorNotification');
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (!_speechInitialized) {
      _initSpeech();
    }

    if (_speechInitialized) {
      if (_isListening) {
        await _speech.stop();
        if (mounted) setState(() => _isListening = false);
      } else {
        setState(
            () => _isListening = true); // Set to true before starting to listen
        try {
          var result = await _speech.listen(
            onResult: (result) {
              if (mounted) {
                setState(() {
                  if (result.finalResult) {
                    _textController.text += ' ' + result.recognizedWords;
                  }
                });
              }
            },
            listenMode: stt.ListenMode.confirmation,
            cancelOnError: true,
            listenFor: Duration(seconds: 30),
            pauseFor: Duration(seconds: 3),
          );
          // If listen returns false, set _isListening back to false
          if (result == false) {
            if (mounted) setState(() => _isListening = false);
          }
        } catch (e) {
          print('Error starting to listen: $e');
          if (mounted) setState(() => _isListening = false);
        }
      }
    } else {
      print('Speech recognition not initialized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (bool value) {
        if (_isListening) _speech.stop();
        _isListening = false;
        print('Pop invoked: $value');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Annotate Image'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (_isListening) await _speech.stop();
              // Navigate back to the HomeScreen
              final cameras = await availableCameras();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      HomeScreen(cameras: cameras),
                ),
              );
            },
          ),
        ),
        body: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Your speech will appear here',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blueGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.blueGrey[800]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                          _isListening ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isListening ? Colors.red : Colors.blueGrey[800],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _toggleListening,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
