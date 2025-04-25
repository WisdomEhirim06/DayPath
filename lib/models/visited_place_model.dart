import 'package:hive/hive.dart';

part 'visited_place_model.g.dart';

@HiveType(typeId: 0)
class VisitedPlace {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final String placeName;

  @HiveField(4)
  final DateTime startTime;

  @HiveField(5)
  final DateTime endTime;

  @HiveField(6)
  final String date; // YYYY-MM-DD format for easy grouping

  VisitedPlace({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.startTime,
    required this.endTime,
    required this.date
  });

  // Duration of stay at this place
  Duration get duration => endTime.difference(startTime);

  // Helper for a human-readable duration
  String get formattedDuration {
    final dur = duration;
    if (dur.inHours > 0) {
      return '${dur.inHours}h ${dur.inMinutes % 60}m';
    }
    return '${dur.inMinutes}m';
  }

  // Helper for a human-readable time range
  String get timeRange {
    final start = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  factory VisitedPlace.fromLatLng({
    required String id,
    required double latitude,
    required double longitude,
    required String placeName,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    // Format date as YYYY-MM-DD for grouping purposes
    final date = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
    
    return VisitedPlace(
      id: id,
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      startTime: startTime,
      endTime: endTime,
      date: date,
    );
  }

  VisitedPlace copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? placeName,
    DateTime? startTime,
    DateTime? endTime,
    String? date,
  }) {
    return VisitedPlace(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
    );
  }
}