import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartland_photo_app/annotation_screen.dart';
import 'package:heartland_photo_app/claimsready_screen.dart';
import 'package:heartland_photo_app/hours_tracker.dart';
import 'package:image_picker/image_picker.dart';
import 'media_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  final String? initialFolderId; // Add these parameters
  final String? initialFolderName;
  final String? initialSubFolder;

  const HomeScreen({
    Key? key,
    this.initialFolderId,
    this.initialFolderName,
    this.initialSubFolder,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMainFolderId = ''; // Store the ID
  String _selectedMainFolderName = ''; // Store the display name
  String _selectedSubFolder = '';
  List<Map<String, String>> _mainFolders =
      []; // Changed to store both id and name
  List<String> _subFolders = [
    'Initial Assessment',
    'Stabilization',
    'Mitigation',
    'Restoration'
  ];
  late ScrollController _scrollController;
  List<CameraDescription> _cameras = [];
  bool _camerasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadMainFolders();
    _initializeCameras();

    // Set initial values if provided
    if (widget.initialFolderId != null) {
      _selectedMainFolderId = widget.initialFolderId!;
      _selectedMainFolderName = widget.initialFolderName ?? '';
      _selectedSubFolder = widget.initialSubFolder ?? '';
    }
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

  Future<void> _loadMainFolders() async {
    try {
      final foldersSnapshot =
          await FirebaseFirestore.instance.collection('folders').get();
      setState(() {
        _mainFolders = foldersSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['folderName'] as String? ??
                      doc.id, // Fallback to id if name not found
                })
            .toList();
      });
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  Future<void> _refreshFolders() async {
    await _loadMainFolders();
  }

  Future<void> _selectOrCreateMainFolder() async {
    String? resultId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Main Folder'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _selectedMainFolderId.isNotEmpty
                        ? _selectedMainFolderId
                        : null,
                    hint: const Text('Select a folder'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedMainFolderId = newValue!;
                      });
                    },
                    items: _mainFolders.map<DropdownMenuItem<String>>((folder) {
                      return DropdownMenuItem<String>(
                        value: folder['id'],
                        child: Text(
                          folder['name']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    isExpanded: true,
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
                Navigator.of(context).pop(_selectedMainFolderId);
              },
            ),
          ],
        );
      },
    );

    if (resultId != null && resultId.isNotEmpty) {
      // Find the corresponding folder name
      final selectedFolder = _mainFolders.firstWhere(
        (folder) => folder['id'] == resultId,
        orElse: () => {'id': resultId},
      );

      setState(() {
        _selectedMainFolderId = resultId;
        _selectedMainFolderName = selectedFolder['name']!;
        _selectedSubFolder = '';
      });

      // Check if folder exists, if not create it
      if (!_mainFolders.any((folder) => folder['id'] == resultId)) {
        await FirebaseFirestore.instance
            .collection('folders')
            .doc(resultId)
            .set({
          'folderName': _selectedMainFolderName,
          'id': resultId,
          'subFolders': {
            'Initial Assessment': {'photoDescriptions': {}, 'photos': []},
            'Stabilization': {'photoDescriptions': {}, 'photos': []},
            'Mitigation': {'photoDescriptions': {}, 'photos': []},
            'Restoration': {'photoDescriptions': {}, 'photos': []},
          },
        });
        _loadMainFolders();
      }
    }
  }

  Future<void> _selectSubFolder() async {
    String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Sub-Folder'),
          content: DropdownButton<String>(
            value: _selectedSubFolder.isNotEmpty ? _selectedSubFolder : null,
            hint: const Text('Select a sub-folder'),
            onChanged: (String? newValue) {
              Navigator.of(context).pop(newValue);
            },
            items: _subFolders.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedSubFolder = result;
      });
    }
  }

  Future<void> _captureMedia(bool isVideo) async {
    if (_selectedMainFolderId.isEmpty || _selectedSubFolder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a main folder and sub-folder first')),
      );
      return;
    }

    if (!_camerasInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera is not initialized')),
      );
      return;
    }

    final mediaPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => MediaScreen(
          camera: _cameras.first,
          isVideo: isVideo,
          mainFolderName: _selectedMainFolderName,
          mainFolder: _selectedMainFolderId,
          subFolder: _selectedSubFolder,
        ),
      ),
    );

    if (mediaPath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotationScreen(
            mediaPath: mediaPath,
            mainFolderName: _selectedMainFolderName, // Pass name instead of ID
            mainFolder: _selectedMainFolderId, // Pass ID instead of name
            subFolder: _selectedSubFolder,
            cameras: _cameras,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  Future<void> _pickMedia(bool isVideo) async {
    if (_selectedMainFolderId.isEmpty || _selectedSubFolder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a main folder and sub-folder first')),
      );
      return;
    }

    final ImagePicker _picker = ImagePicker();
    if (isVideo) {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnnotationScreen(
              mediaPath: video.path,
              mainFolderName: _selectedMainFolderName,
              mainFolder: _selectedMainFolderId,
              subFolder: _selectedSubFolder,
              cameras: _cameras,
              isVideo: true,
            ),
          ),
        );
      }
    } else {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnnotationScreen(
              mediaPath: images[0].path,
              mainFolder: _selectedMainFolderId,
              mainFolderName: _selectedMainFolderName,
              subFolder: _selectedSubFolder,
              cameras: _cameras,
              isVideo: false,
              additionalImages: images.sublist(1), // Pass remaining images
            ),
          ),
        );
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
              leading: const Icon(Icons.punch_clock_rounded),
              title: const Text('Time Clock'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return HoursTrackerPage();
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
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Triage Projects/Referrals'),
              onTap: () async {
                final Uri uri =
                    Uri.parse('https://heartland-data-utils.vercel.app');
                if (await canLaunch(uri.toString())) {
                  await launch(uri.toString());
                } else {
                  throw 'Could not launch $uri';
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('ClaimReady+ Inspection'),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (BuildContext context) {
                  return const ClaimsreadyScreen();
                }));
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Select a main folder and sub-folder to begin',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder),
                    label: Text(_selectedMainFolderName.isEmpty
                        ? 'Select Main Folder'
                        : 'Main Folder: $_selectedMainFolderName'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _selectOrCreateMainFolder,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.subdirectory_arrow_left),
                    label: Text(_selectedSubFolder.isEmpty
                        ? 'Select Sub-Folder'
                        : 'Sub-Folder: $_selectedSubFolder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed:
                        _selectedMainFolderId.isEmpty ? null : _selectSubFolder,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: (_selectedMainFolderId.isEmpty ||
                                _selectedSubFolder.isEmpty ||
                                !_camerasInitialized)
                            ? null
                            : () => _captureMedia(false),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text('Take Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: (_selectedMainFolderId.isEmpty ||
                                _selectedSubFolder.isEmpty ||
                                !_camerasInitialized)
                            ? null
                            : () => _captureMedia(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: (_selectedMainFolderId.isEmpty ||
                                _selectedSubFolder.isEmpty)
                            ? null
                            : () => _pickMedia(false),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text('Upload Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: (_selectedMainFolderId.isEmpty ||
                                _selectedSubFolder.isEmpty)
                            ? null
                            : () => _pickMedia(true),
                      ),
                    ],
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
