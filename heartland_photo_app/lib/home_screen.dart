import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartland_photo_app/annotation_screen.dart';
import 'package:heartland_photo_app/loc_track_screen.dart';
import 'photo_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFolder = '';
  List<String> _folders = [];
  late ScrollController _scrollController;
  List<CameraDescription> _cameras = [];
  bool _camerasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadFolders();
    _initializeCameras();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      setState(() {
        _camerasInitialized = true;
      });
    } on CameraException catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  Future<void> _loadFolders() async {
    try {
      final foldersSnapshot =
          await FirebaseFirestore.instance.collection('folders').get();
      setState(() {
        _folders = foldersSnapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      print('Error loading folders: $e');
      // Optionally show an error message to the user
    }
  }

  Future<void> _refreshFolders() async {
    await _loadFolders();
  }

  Future<void> _selectOrCreateFolder() async {
    String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String newFolder = '';
        return AlertDialog(
          title: const Text('Select or Create Folder'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _selectedFolder.isNotEmpty ? _selectedFolder : null,
                    hint: const Text('Select a folder'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFolder = newValue!;
                      });
                    },
                    items:
                        _folders.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                        labelText: 'Or create a new folder'),
                    onChanged: (value) {
                      newFolder = value;
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context)
                    .pop(newFolder.isNotEmpty ? newFolder : _selectedFolder);
              },
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedFolder = result;
      });
      if (!_folders.contains(result)) {
        // Create new folder with name field
        await FirebaseFirestore.instance.collection('folders').doc(result).set({
          'name': result,
          'photoDescriptions': {},
          'photos': [],
        });
        _loadFolders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Heartland Workforce Solutions',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey[800],
              ),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_city),
              title: const Text('Job tracking'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return LocationTrackingPage();
                }));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Manage/View Folders'),
              onTap: () async {
                final Uri uri =
                    Uri.parse('https://photo-viewer-eight.vercel.app');
                if (await canLaunch(uri.toString())) {
                  await launch(uri.toString());
                } else {
                  throw 'Could not launch $uri';
                }
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFolders,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Capture and Annotate',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select a folder and take a photo',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder),
                    label: Text(_selectedFolder.isEmpty
                        ? 'Select Folder'
                        : 'Folder: $_selectedFolder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _selectOrCreateFolder,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: (_selectedFolder.isEmpty || !_camerasInitialized)
                        ? null
                        : () async {
                            final imagePath = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PhotoScreen(camera: _cameras.first),
                              ),
                            );
                            if (imagePath != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnnotationScreen(
                                    imagePath: imagePath,
                                    folder: _selectedFolder,
                                    cameras: _cameras,
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}