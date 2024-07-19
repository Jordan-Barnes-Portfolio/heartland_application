import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:heartland_photo_app/home_screen.dart';
import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationTrackingPage extends StatefulWidget {
  @override
  _LocationTrackingPageState createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage> {
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  String _address = '';
  Set<Polyline> _polylines = {};
  String _estimatedTime = '';
  String _currentDistance = '';
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isTracking = false;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return HomeScreen();
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter destination address',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchAddress,
                ),
              ),
              onChanged: (value) => _address = value,
            ),
            SizedBox(height: 16),
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? LatLng(0, 0),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _createMarkers(),
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Time: $_estimatedTime',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Distance: $_currentDistance',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking ? null : _startTracking,
                    child: _isTracking
                        ? Text('Tracking..')
                        : Text('Start tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.grey : Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      textStyle: TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_isTracking) SizedBox(width: 16),
                if (_isTracking)
                  InkWell(
                    onTap: _stopTracking,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.close, color: Colors.grey[700], size: 24),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _createMarkers() {
    Set<Marker> markers = {};
    if (_destinationPosition != null) {
      markers.add(Marker(
        markerId: MarkerId('destination'),
        position: _destinationPosition!,
        infoWindow: InfoWindow(title: 'Destination'),
      ));
    }
    return markers;
  }

  void _getCurrentLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentPosition =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        if (_mapController != null) {
          _mapController!
              .animateCamera(CameraUpdate.newLatLng(_currentPosition!));
        }
      });
    });
  }

  Future<bool> _searchAddress() async {
    List<geocoding.Location> locations =
        await geocoding.locationFromAddress(_address);
    if (locations.isNotEmpty) {
      setState(() {
        _destinationPosition =
            LatLng(locations.first.latitude, locations.first.longitude);
      });
      _getPolyline();
      return true;
    }
    return false;
  }

  void _getPolyline() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyDHnX59kZ00Ttpj0xF93je8EzwnmFVhva4', // Replace with your API key
      PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      PointLatLng(
          _destinationPosition!.latitude, _destinationPosition!.longitude),
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        ));
      });

      _calculateEstimatedTimeAndDistance(polylineCoordinates);
    }
  }

  void _calculateEstimatedTimeAndDistance(List<LatLng> polylineCoordinates) {
    double totalDistance = 0;
    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      totalDistance += _calculateDistance(
        polylineCoordinates[i],
        polylineCoordinates[i + 1],
      );
    }

    // Assuming an average speed of 30 mph
    double estimatedTimeInHours = totalDistance / 30;
    int estimatedTimeInMinutes = (estimatedTimeInHours * 60).round();

    setState(() {
      _estimatedTime = '$estimatedTimeInMinutes minutes';
      _currentDistance = '${totalDistance.toStringAsFixed(2)} miles';
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 3959; // Earth's radius in miles

    double lat1 = start.latitude * (pi / 180);
    double lon1 = start.longitude * (pi / 180);
    double lat2 = end.latitude * (pi / 180);
    double lon2 = end.longitude * (pi / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in miles
  }

  void _startTracking() async {
    if (_destinationPosition == null) {
      if (_address.isNotEmpty) {
        try {
          await _searchAddress();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to find the destination address.'),
          ));
          return;
        }
      }

      if (_destinationPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please enter a valid destination address.')));
        return;
      }
    }

    // Clear existing data
    _clearTrackingData();

    setState(() {
      _isTracking = true;
    });

    // Cancel any existing subscription
    _locationSubscription?.cancel();

    // Start listening to location changes
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentPosition =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      });

      // Update the camera position
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));

      // Update the polyline
      _getPolyline();

      // Check if we've reached the destination
      double distanceToDestination =
          _calculateDistance(_currentPosition!, _destinationPosition!);
      if (distanceToDestination < 0.0621371) {
        // If within 100 meters (approx. 0.0621371 miles) of the destination
        _stopTracking();
      }
    });
  }

  void _stopTracking() {
    // Cancel the location subscription
    _locationSubscription?.cancel();
    _locationSubscription = null;

    // Clear all tracking data
    _clearTrackingData();

    setState(() {
      _isTracking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tracking stopped.')),
    );
  }

  void _clearTrackingData() {
    setState(() {
      _polylines.clear();
      _estimatedTime = '';
      _currentDistance = '';
      // Consider if you want to clear these as well:
      _destinationPosition = null;
      _address = '';
    });

    // Optionally, reset the map camera to the current position
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }
}
