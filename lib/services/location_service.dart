import 'dart:async';
//import 'dart:math';
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
  // ignore: unused_field
  Position? _lastPosition;
  final List<Position> _positionBuffer = [];

  // Current visit tracking
  VisitedPlace? _currentVisit;
  Timer? _dwellTimer;

  // Configuration
  static const double _proximityThreshold = 100.0; // meters
  static const int _dwellTimeThreshold = 4; // minutes
  static const int _minSamples = 3; // minimum samples to consider a location

  // Location accuracy and interval
  final LocationSettings _locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    forceLocationManager: true,
    intervalDuration: const Duration(seconds: 10),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'Tracking your daily places',
      notificationTitle: 'DayPath is active',
      enableWakeLock: true,
    ), // ForegroundNotification Settings
  ); //Android settings

  // Public Getters
  bool get isTracking => _isTracking;
  VisitedPlace? get currentVisit => _currentVisit;

  // Constructor
  LocationService(this._storageService) {
    _initializeNotifications();
  }

  // Initialize notifications for forground service
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
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request the user to enable location services
      return false;
    }

    // Check for location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User denied location Permission permanently
      return false;
    }

    // Request background permission on Android
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

    // Start listening to positon stream
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

    // Cancel the positon Stream Subscription
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Cancel any active dwell timer
    _dwellTimer?.cancel();
    _dwellTimer = null;

    // Reset position Buffer
    _positionBuffer.clear();

    _isTracking = false;
    notifyListeners();

    if (_notificationsEnabled) {
      await _notifications?.cancel(1);
    }
  }

  // Handle new position updates
  void _onPositionUpdate(Position position) {
    _lastPosition = position;
    _positionBuffer.add(position);

    // Keep the buffer from growing too large
    if (_positionBuffer.length > 10) {
      _positionBuffer.removeAt(0);
    }

    // if not currently tracking a visit, check if to start one
    if (_currentVisit == null) {
      _checkForNewVisit();
    } else {
      _checkIfUserLeftVisit(position);
    }
    notifyListeners();
  }

  // Check if user has stayed in the same approximate location
  void _checkForNewVisit() {
    // Need enough samples to determine if stationary
    if (_positionBuffer.length < _minSamples) return;

    // Check if the last few positions are within proximity threshold
    final recentPositions = _positionBuffer.sublist(_positionBuffer.length - _minSamples);
    final isStationary = _arePositionsWithinProximity(recentPositions, _proximityThreshold);

    // If user appears to be stationary, start a dwell timer
    if (isStationary && _dwellTimer == null) {
      _dwellTimer = Timer(Duration(minutes: _dwellTimeThreshold), () async {
        // After dwell time expires, create a new visit
        await _startNewVisit(recentPositions.last);
        _dwellTimer = null;
      });
    } else if (!isStationary && _dwellTimer != null) {
      // If user moved, cancel dwell timer
      _dwellTimer?.cancel();
      _dwellTimer = null;
    }
  }

  // Check if all positions are within a certain distance of each other
  bool _arePositionsWithinProximity(List<Position> positions, double thresholdMeters) {
    if (positions.length < 2) return true;
    
    // Check all position pairs
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final distance = Geolocator.distanceBetween(
          positions[i].latitude,
          positions[i].longitude,
          positions[j].latitude,
          positions[j].longitude,
        );
        
        if (distance > thresholdMeters) {
          return false;
        }
      }
    }
    
    return true;
  }

  // Start tracking a new visit at the current location
  Future<void> _startNewVisit(Position position) async {
    // Get place name for the current position
    final placeName = await _getPlaceNameFromPosition(position);
    
    // Create a new visited place
    final now = DateTime.now();
    final id = const Uuid().v4();
    
    _currentVisit = VisitedPlace.fromLatLng(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      placeName: placeName,
      startTime: now,
      endTime: now, // Will be updated when the visit ends
    );
    
    // Save the initial visit to storage
    await _storageService.saveVisitedPlace(_currentVisit!);
    
    notifyListeners();
  }

  // Check if user has moved away from the current visit location
  void _checkIfUserLeftVisit(Position currentPosition) async {
    if (_currentVisit == null) return;
    
    // Calculate distance from current visit location
    final distance = Geolocator.distanceBetween(
      _currentVisit!.latitude,
      _currentVisit!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );
    
    // If user has moved away, finalize the visit
    if (distance > _proximityThreshold) {
      _finalizeCurrentVisit();
    } else {
      // Update visit end time as long as user stays at the location
      await _updateCurrentVisitEndTime();
    }
  }

  // Update the end time of the current visit
  Future<void> _updateCurrentVisitEndTime() async {
    if (_currentVisit == null) return;
    
    final now = DateTime.now();
    final updatedVisit = _currentVisit!.copyWith(endTime: now);
    _currentVisit = updatedVisit;
    
    // Update the visit in storage
    await _storageService.updateVisitedPlace(updatedVisit);
    
    notifyListeners();
  }

  // Finalize the current visit
  Future<void> _finalizeCurrentVisit() async {
    if (_currentVisit == null) return;
    
    // Update the end time one last time
    await _updateCurrentVisitEndTime();
    
    // Clear current visit
    _currentVisit = null;
    
    notifyListeners();
  }

  // Get human-readable place name from coordinates
  Future<String> _getPlaceNameFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        // Construct readable place name from components
        final components = <String>[];
        
        if (place.name != null && place.name!.isNotEmpty && place.name != place.street) {
          components.add(place.name!);
        }
        
        if (place.street != null && place.street!.isNotEmpty) {
          components.add(place.street!);
        }
        
        if (components.isEmpty && place.locality != null && place.locality!.isNotEmpty) {
          components.add(place.locality!);
        }
        
        return components.join(', ');
      }
    } catch (e) {
      debugPrint('Error getting place name: $e');
    }
    
    // Fallback place name
    return 'Unknown location';
  }

  // Show an ongoing notification while tracking
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
