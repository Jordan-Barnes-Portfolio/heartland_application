import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'package:heartland_photo_app/photo_screen.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AnnotationScreen extends StatefulWidget {
  final String imagePath;
  final String mainFolder;
  final String subFolder;
  final List<CameraDescription> cameras;

  const AnnotationScreen({
    Key? key,
    required this.imagePath,
    required this.mainFolder,
    required this.subFolder,
    required this.cameras,
  }) : super(key: key);

  @override
  _AnnotationScreenState createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isUploading = false;

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
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
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

  Future<void> _uploadPhotoAndAnnotation() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final String uniqueId = const Uuid().v4();
      final String fileName = '$uniqueId.jpg';
      final String storagePath =
          '${widget.mainFolder}/${widget.subFolder}/$fileName';

      // Upload the image to Firebase Storage
      final Reference storageRef =
          FirebaseStorage.instance.ref().child(storagePath);
      await storageRef.putFile(File(widget.imagePath));
      final String imageUrl = await storageRef.getDownloadURL();

      // Update Firestore
      final DocumentReference folderRef = FirebaseFirestore.instance
          .collection('folders')
          .doc(widget.mainFolder);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot folderSnapshot = await transaction.get(folderRef);

        if (!folderSnapshot.exists) {
          throw Exception('Main folder does not exist');
        }

        Map<String, dynamic> data =
            folderSnapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> subFolders =
            Map<String, dynamic>.from(data['subFolders'] ?? {});

        if (!subFolders.containsKey(widget.subFolder)) {
          throw Exception('Sub-folder does not exist');
        }

        Map<String, dynamic> subFolderData =
            Map<String, dynamic>.from(subFolders[widget.subFolder]);
        Map<String, dynamic> photoDescriptions =
            Map<String, dynamic>.from(subFolderData['photoDescriptions'] ?? {});
        List<dynamic> photos =
            List<dynamic>.from(subFolderData['photos'] ?? []);

        photoDescriptions[imageUrl] = _textController.text;
        photos.add(imageUrl);

        subFolders[widget.subFolder] = {
          ...subFolderData,
          'photoDescriptions': photoDescriptions,
          'photos': photos,
        };

        transaction.update(folderRef, {'subFolders': subFolders});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload successful!')),
      );

      // Redirect to PhotoScreen after successful upload
      if (!mounted) return;
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoScreen(camera: widget.cameras.first),
        ),
      );
      if (imagePath != null) {
        // If a new photo was taken, replace the current AnnotationScreen with a new one
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnnotationScreen(
              imagePath: imagePath,
              mainFolder: widget.mainFolder,
              subFolder: widget.subFolder,
              cameras: widget.cameras,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error uploading: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
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
          title: const Text('Annotate Image'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              if (_isListening) await _speech.stop();
              // Navigate back to HomeScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(),
                ),
                (Route<dynamic> route) => false,
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
                  margin: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
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
                          borderSide: const BorderSide(color: Colors.blueGrey),
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                          _isListening ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isListening ? Colors.red : Colors.blueGrey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _toggleListening,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Main Folder: ${widget.mainFolder}\nSub-Folder: ${widget.subFolder}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          _isUploading ? null : _uploadPhotoAndAnnotation,
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
