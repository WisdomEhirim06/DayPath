import 'package:hive_flutter/hive_flutter.dart';
import 'package:daypath/models/visited_place_model.dart';
import 'package:flutter/foundation.dart';

class StorageService extends ChangeNotifier {
  static const String _visitedPlacesBoxName = 'visited_places';
  static const String _settingsBoxName = 'settings'; // New Box for app settings
  static const String _isFirstLaunchKey = 'isFirstLaunch'; // Key for first launch

  
  late Box<VisitedPlace> _visitedPlacesBox;
  late Box _settingsBox;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    Hive.registerAdapter(VisitedPlaceAdapter());

    // Open boxes
    _visitedPlacesBox = await Hive.openBox<VisitedPlace>(_visitedPlacesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    
    _isInitialized = true;
    notifyListeners();
  }

  // Check if this is the first launch
  bool isFirstLaunch() {
    // Check if the flag exists in the settings Box
    final isFirstLaunch = _settingsBox.get(_isFirstLaunchKey, defaultValue: true);

    // if it's first, set the flag to false for the more changes
    if (isFirstLaunch) {
      _settingsBox.put(_isFirstLaunchKey, false);
    }

    return isFirstLaunch;
  }

  // Save a new visited place
  Future<void> saveVisitedPlace(VisitedPlace place) async {
    await _visitedPlacesBox.put(place.id, place);
    notifyListeners();
  }

  // Update existing vistd place (mainly to update the endtime)
  Future<void> updateVisitedPlace(VisitedPlace place) async {
    await _visitedPlacesBox.put(place.id, place);
    notifyListeners();
  }

  // Get all visited places
  List<VisitedPlace> getAllVisitedPlaces() {
    return _visitedPlacesBox.values.toList();
  }

  // Get Visited places for a specific date (YYY-MM-DD)
  List<VisitedPlace> getVisitedPlacesForDate(String date) {
    return _visitedPlacesBox.values
      .where((place) => place.date == date)
      .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

  }

  // Get Visited Places for today
  List<VisitedPlace> getTodayVisitedPlaces() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return getVisitedPlacesForDate(today);

  }

  // Get the most visited place for a specific date (by duration)
  VisitedPlace? getMostVisitedPlaceForDate(String date) {
    final places = getVisitedPlacesForDate(date);
    if (places.isEmpty) return null;

    return places.reduce((curr, next) => curr.duration > next.duration ? curr : next);
  }

  // Get the most visited place for today
  VisitedPlace? getTodayMostVisitedPlace() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return getMostVisitedPlaceForDate(today);
  }

  // Get total time spent outside home for a date
  Duration getTotalTimeOutsideForDate(String date) {
    final places = getVisitedPlacesForDate(date);
    Duration total = Duration.zero;
    for (var place in places) {
      total += place.duration;
    }
    return total;
  }

  // Delete a visited place
  Future<void> deleteVisitedPlace(String id) async {
    await _visitedPlacesBox.delete(id);
    notifyListeners();
  }
  
  // Clear all data (for debugging)
  Future<void> clearAllData() async {
    await _visitedPlacesBox.clear();
    notifyListeners();  
    }
}