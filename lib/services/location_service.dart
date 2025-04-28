import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:daypath/models/visited_place_model.dart';
import 'package:daypath/services/storage_service.dart';

class LocationService extends ChangeNotifier {
  // Services and State
  final StorageService _storageService;
  StreamSubscription<Position>? _positionStreamSubscription;
  FlutterLocalNotificationsPlugin? _notifications;
  final bool _notificationsEnabled = true;

  // Tracking Store
  bool _isTracking = false;
  Position? _lastPosition;
  final List<Position> _positionBuffer = [];

  // Current visit tracking
  VisitedPlace? _currentVisit;
  Timer? _dwellTimer;
  DateTime? _potentialVisitStartTime;
  
  // Visited places memory
  final Map<String, VisitedPlace> _recentlyVisitedPlaces = {};

  // Configuration - Improved parameters
  static const double _proximityThreshold = 200.0; // meters, increased from 100m
  static const int _dwellTimeThreshold = 10; // minutes, increased from 4 min
  static const int _minSamples = 5; // minimum samples, increased from 3
  static const double _accuracyThreshold = 50.0; // meters, filter poor GPS readings
  static const int _significantVisitMinDuration = 5; // minutes, for filtering short visits
  static const int _maxPositionBufferSize = 20; // Store more positions for better analysis
  static const double _mergeVisitDistance = 300.0; // meters, for merging nearby locations

  // Location accuracy and interval - Adjusted for better battery life
  final LocationSettings _locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20, // Increased from 10m to reduce unnecessary updates
    forceLocationManager: true,
    intervalDuration: const Duration(seconds: 30), // Increased from 10s to reduce battery usage
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'Tracking your daily places',
      notificationTitle: 'DayPath is active',
      enableWakeLock: true,
    ),
  );

  // Public Getters
  bool get isTracking => _isTracking;
  VisitedPlace? get currentVisit => _currentVisit;

  // Constructor
  LocationService(this._storageService) {
    _initializeNotifications();
  }

  // Initialize notifications for foreground service
  Future<void> _initializeNotifications() async {
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('app_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications!.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings)
    );
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    // Method unchanged - permission handling works well
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.locationAlways.status;
      if (status.isDenied) {
        final result = await Permission.locationAlways.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }

  // Start tracking location
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    // Start listening to position stream
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_onPositionUpdate);

    _isTracking = true;
    notifyListeners();

    if (_notificationsEnabled) {
      await _showOngoingNotification();
    }
  }

  // Stop tracking Location
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    // If there's an active visit, finalize it
    if (_currentVisit != null) {
      await _finalizeCurrentVisit();
    }

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _dwellTimer?.cancel();
    _dwellTimer = null;

    _positionBuffer.clear();
    _potentialVisitStartTime = null;

    _isTracking = false;
    notifyListeners();

    if (_notificationsEnabled) {
      await _notifications?.cancel(1);
    }
  }

  // Handle new position updates with improved filtering
  void _onPositionUpdate(Position position) {
    // Filter out inaccurate readings
    if (position.accuracy > _accuracyThreshold) {
      debugPrint('Skipping inaccurate position: ${position.accuracy}m');
      return;
    }

    _lastPosition = position;
    _positionBuffer.add(position);

    // Keep buffer size manageable but sufficient for analysis
    if (_positionBuffer.length > _maxPositionBufferSize) {
      _positionBuffer.removeAt(0);
    }

    // If not currently tracking a visit, check if to start one
    if (_currentVisit == null) {
      _checkForNewVisit();
    } else {
      _checkIfUserLeftVisit(position);
    }
    
    notifyListeners();
  }

  // Improved stationary detection with cluster analysis
  void _checkForNewVisit() {
    // Need enough samples
    if (_positionBuffer.length < _minSamples) return;

    // Get the most recent positions for analysis
    final recentPositions = _positionBuffer.sublist(
        _positionBuffer.length - min(_minSamples, _positionBuffer.length));
    
    // Calculate the centroid of recent positions
    final centroid = _calculateCentroid(recentPositions);
    
    // Check if positions form a cluster (are stationary)
    final isStationary = _isClusterStationary(recentPositions, centroid);

    // Stationary detection with better timing logic
    if (isStationary) {
      // If we just detected potential visit, record the start time
      if (_potentialVisitStartTime == null) {
        _potentialVisitStartTime = DateTime.now();
        debugPrint('Potential visit detected, monitoring dwell time...');
      }
      
      // Check if we've stayed long enough to consider it a visit
      final dwellTimeSoFar = DateTime.now().difference(_potentialVisitStartTime!).inMinutes;
      
      if (dwellTimeSoFar >= _dwellTimeThreshold && _dwellTimer == null) {
        // Start dwell timer to confirm this is a significant place
        _dwellTimer = Timer(const Duration(minutes: 1), () async {
          // Verify we're still stationary after timer ends
          if (_positionBuffer.isNotEmpty) {
            final currentCentroid = _calculateCentroid(_positionBuffer.sublist(
                _positionBuffer.length - min(_minSamples, _positionBuffer.length)));
                
            // Only start a visit if we're near the same location
            if (_calculateDistance(centroid, currentCentroid) < _proximityThreshold / 2) {
              await _startNewVisit(recentPositions.last, _potentialVisitStartTime!);
            }
          }
          _dwellTimer = null;
        });
      }
    } else {
      // Reset potential visit if we've moved
      _potentialVisitStartTime = null;
      _dwellTimer?.cancel();
      _dwellTimer = null;
    }
  }

  // Calculate centroid from a list of positions
  Map<String, double> _calculateCentroid(List<Position> positions) {
    double sumLat = 0;
    double sumLng = 0;
    
    for (final position in positions) {
      sumLat += position.latitude;
      sumLng += position.longitude;
    }
    
    return {
      'latitude': sumLat / positions.length,
      'longitude': sumLng / positions.length
    };
  }

  // Determine if a cluster of points is stationary using standard deviation
  bool _isClusterStationary(List<Position> positions, Map<String, double> centroid) {
    double totalDistance = 0;
    final distances = <double>[];
    
    // Calculate distance of each point to centroid
    for (final position in positions) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        centroid['latitude']!,
        centroid['longitude']!,
      );
      
      distances.add(distance);
      totalDistance += distance;
    }
    
    // Calculate mean distance and standard deviation
    final meanDistance = totalDistance / positions.length;
    
    double sumSquaredDiff = 0;
    for (final distance in distances) {
      sumSquaredDiff += pow(distance - meanDistance, 2);
    }
    
    final stdDev = sqrt(sumSquaredDiff / positions.length);
    
    // Consider stationary if standard deviation and mean are both below thresholds
    return stdDev < (_proximityThreshold / 4) && meanDistance < (_proximityThreshold / 2);
  }

  // Calculate distance between two centroids
  double _calculateDistance(Map<String, double> point1, Map<String, double> point2) {
    return Geolocator.distanceBetween(
      point1['latitude']!,
      point1['longitude']!,
      point2['latitude']!,
      point2['longitude']!,
    );
  }

  // Improved visit starting that considers visit history
  Future<void> _startNewVisit(Position position, DateTime actualStartTime) async {
    // Enhanced place name retrieval
    final placeName = await _getEnhancedPlaceNameFromPosition(position);
    
    // Check if this location is near a recently visited place
    final String? existingPlaceId = _findNearbyVisitedPlace(position);
    
    if (existingPlaceId != null) {
      // This is a return to a previously visited place
      debugPrint('Returned to previously visited place: $placeName');
      final existingPlace = _recentlyVisitedPlaces[existingPlaceId]!;
      
      _currentVisit = existingPlace.copyWith(
        startTime: actualStartTime,
        endTime: DateTime.now(),
      );
    } else {
      // This is a new place
      final now = DateTime.now();
      final id = const Uuid().v4();
      
      _currentVisit = VisitedPlace.fromLatLng(
        id: id,
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
        startTime: actualStartTime, // Use the actual time we became stationary
        endTime: now,
      );
      
      // Add to recently visited places for future reference
      _recentlyVisitedPlaces[id] = _currentVisit!;
    }
    
    // Cap the memory of recent places
    if (_recentlyVisitedPlaces.length > 20) {
      final oldestKey = _recentlyVisitedPlaces.keys.first;
      _recentlyVisitedPlaces.remove(oldestKey);
    }
    
    // Save the visit to storage
    await _storageService.saveVisitedPlace(_currentVisit!);
    
    // Reset potential visit tracking
    _potentialVisitStartTime = null;
    
    notifyListeners();
  }

  // Find if current position is near a recently visited place
  String? _findNearbyVisitedPlace(Position position) {
    for (final entry in _recentlyVisitedPlaces.entries) {
      final place = entry.value;
      final distance = Geolocator.distanceBetween(
        place.latitude,
        place.longitude,
        position.latitude,
        position.longitude,
      );
      
      if (distance < _mergeVisitDistance) {
        return entry.key;
      }
    }
    return null;
  }

  // Improved check for leaving a visit with better movement detection
  void _checkIfUserLeftVisit(Position currentPosition) async {
    if (_currentVisit == null) return;
    
    // We need more than just one position to confirm movement
    if (_positionBuffer.length < 3) {
      await _updateCurrentVisitEndTime();
      return;
    }
    
    // Get the most recent positions
    final recentPositions = _positionBuffer.sublist(_positionBuffer.length - 3);
    
    // Check if all recent positions are outside the visit radius
    bool hasDefinitelyLeft = true;
    for (final pos in recentPositions) {
      final distance = Geolocator.distanceBetween(
        _currentVisit!.latitude,
        _currentVisit!.longitude,
        pos.latitude,
        pos.longitude,
      );
      
      if (distance <= _proximityThreshold) {
        hasDefinitelyLeft = false;
        break;
      }
    }
    
    if (hasDefinitelyLeft) {
      // Filter out extremely short visits
      final visitDuration = _currentVisit!.endTime.difference(_currentVisit!.startTime).inMinutes;
      
      if (visitDuration < _significantVisitMinDuration) {
        debugPrint('Discarding short visit (${visitDuration}m): ${_currentVisit!.placeName}');
        await _storageService.deleteVisitedPlace(_currentVisit!.id);
        _recentlyVisitedPlaces.remove(_currentVisit!.id);
      } else {
        await _finalizeCurrentVisit();
      }
      
      _currentVisit = null;
      _potentialVisitStartTime = null;
    } else {
      // Still at this location, update the end time
      await _updateCurrentVisitEndTime();
    }
  }

  // Update current visit end time
  Future<void> _updateCurrentVisitEndTime() async {
    if (_currentVisit == null) return;
    
    final now = DateTime.now();
    final updatedVisit = _currentVisit!.copyWith(endTime: now);
    _currentVisit = updatedVisit;
    
    // Update in memory cache and storage
    _recentlyVisitedPlaces[_currentVisit!.id] = _currentVisit!;
    await _storageService.updateVisitedPlace(updatedVisit);
    
    notifyListeners();
  }

  // Enhanced place name resolution
  Future<String> _getEnhancedPlaceNameFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        // Try to create a more meaningful and hierarchical place name
        // First check for point of interest
        if (place.name != null && place.name!.isNotEmpty && 
            place.name != place.street && 
            !place.name!.contains(RegExp(r'^\d+'))) {
          // Likely a named building or POI
          return place.name!;
        }
        
        // Next, try street address
        final components = <String>[];
        
        if (place.street != null && place.street!.isNotEmpty) {
          // Format house number + street name nicely
          if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
            components.add('${place.subThoroughfare} ${place.street}');
          } else {
            components.add(place.street!);
          }
          
          // Add neighborhood or district if available
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            components.add(place.subLocality!);
          }
          
          return components.join(', ');
        }
        
        // Fallback to area name
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (place.subLocality != null && place.subLocality!.isNotEmpty &&
              place.subLocality != place.locality) {
            return '${place.subLocality}, ${place.locality}';
          }
          return place.locality!;
        }
      }
    } catch (e) {
      debugPrint('Error getting place name: $e');
    }
    
    // Fallback place name
    return 'Unknown location';
  }

  // Finalize the current visit
  Future<void> _finalizeCurrentVisit() async {
    if (_currentVisit == null) return;
    
    // Update the end time one last time
    await _updateCurrentVisitEndTime();
    
    debugPrint('Visit finalized: ${_currentVisit!.placeName} (${_currentVisit!.endTime.difference(_currentVisit!.startTime).inMinutes}m)');
    
    // Clear current visit
    _currentVisit = null;
    
    notifyListeners();
  }

  // Show ongoing notification - unchanged
  Future<void> _showOngoingNotification() async {
    if (_notifications == null) return;
    
    const androidDetails = AndroidNotificationDetails(
      'location_tracking_channel',
      'Location Tracking',
      channelDescription: 'Used for the ongoing location tracking service',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    
    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notifications!.show(
      1,
      'DayPath is active',
      'Tracking your visited places',
      notificationDetails,
    );
  }

  // Clean up resources
  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _dwellTimer?.cancel();
    super.dispose();
  }
}