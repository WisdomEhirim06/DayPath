import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
//import 'package:daypath/models/visited_place_model.dart';
import 'package:daypath/services/location_service.dart';
import 'package:daypath/services/storage_service.dart';
import 'package:daypath/widgets/animated_place_card.dart' as place_card;
import 'package:daypath/widgets/summary_card.dart';
import 'package:daypath/widgets/date_selector.dart';
import 'package:daypath/themes/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isInitializing = true;
  String _selectedDate = '';
  late AnimationController _fabAnimationController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    // Initialize the selected date to today
    final now = DateTime.now();
    _selectedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: DayPathTheme.mediumAnimation,
    );

    // Start location tracking after a delay
    final locationService = Provider.of<LocationService>(context, listen: false);
    Future.delayed(const Duration(milliseconds: 500), () async {
      // Check if location permission is granted
      try {
        await locationService.requestLocationPermission();
        await locationService.startTracking();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting location tracking: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusMedium),
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isInitializing
          ? _buildLoadingScreen()
          : _buildMainScreen(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Setting up DayPath...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re preparing everything for you',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMainScreen() {
    return Consumer<StorageService>(
      builder: (context, storageService, child) {
        final visitedPlaces = storageService.getVisitedPlacesForDate(_selectedDate);
        final formattedDate = _formatDisplayDate(_selectedDate);
        final mostVisitedPlace = storageService.getMostVisitedPlaceForDate(_selectedDate);
        final totalDuration = storageService.getTotalTimeOutsideForDate(_selectedDate);

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            _isScrolled = innerBoxIsScrolled;
            if (innerBoxIsScrolled) {
              _fabAnimationController.forward();
            } else {
              _fabAnimationController.reverse();
            }
            
            return [
              SliverAppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/dayPathImage.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DayPath',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                floating: true,
                snap: true,
                actions: [
                  _buildTrackingToggle(),
                ],
              ),
            ];
          },
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AnimatedDateSelector(
                  currentDate: formattedDate,
                  onPreviousDay: _selectPreviousDay,
                  onNextDay: _selectNextDay,
                  canSelectNextDay: !_isSelectedDateToday(),
                ),
              ),
              SliverToBoxAdapter(
                child: SummaryCard(
                  placesCount: visitedPlaces.length,
                  totalDuration: totalDuration,
                  mostVisitedPlace: mostVisitedPlace,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHeader('Today\'s Timeline'),
              ),
              if (visitedPlaces.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => place_card.AnimatedPlaceCard(
                      place: visitedPlaces[index],
                      index: index,
                    ),
                    childCount: visitedPlaces.length,
                  ),
                ),
              // Add extra padding at the bottom
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackingToggle() {
    return Consumer<LocationService>(
      builder: (context, locationService, child) {
        final isTracking = locationService.isTracking;

        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            tooltip: isTracking ? 'Pause tracking' : 'Start tracking',
            icon: AnimatedSwitcher(
              duration: DayPathTheme.shortAnimation,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isTracking
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                key: ValueKey<bool>(isTracking),
                color: isTracking ? Colors.green : Colors.grey,
              ),
            ),
            onPressed: () async {
              if (isTracking) {
                await locationService.stopTracking();
                _showFeedbackSnackbar('Location tracking paused');
              } else {
                await locationService.startTracking();
                _showFeedbackSnackbar('Location tracking resumed');
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<LocationService>(
      builder: (context, locationService, child) {
        final isTracking = locationService.isTracking;

        return ScaleTransition(
          scale: _fabAnimationController,
          child: FloatingActionButton.extended(
            onPressed: () async {
              if (isTracking) {
                await locationService.stopTracking();
                _showFeedbackSnackbar('Location tracking paused');
              } else {
                await locationService.startTracking();
                _showFeedbackSnackbar('Location tracking resumed');
              }
            },
            label: Text(isTracking ? 'Pause Tracking' : 'Start Tracking'),
            icon: Icon(
              isTracking ? Icons.pause : Icons.play_arrow,
            ),
            backgroundColor: isTracking ? Colors.orange : DayPathTheme.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.map,
              size: 60,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No places visited yet',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'DayPath will automatically track your movements throughout the day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Consumer<LocationService>(
            builder: (context, locationService, child) {
              final isTracking = locationService.isTracking;
              
              return ElevatedButton.icon(
                onPressed: () async {
                  if (!isTracking) {
                    await locationService.startTracking();
                    _showFeedbackSnackbar('Location tracking started');
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Tracking Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options (could be implemented later)
            },
            tooltip: 'Filter places',
          ),
        ],
      ),
    );
  }

  void _showFeedbackSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusMedium),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDisplayDate(String dateString) {
    try {
      final dateParts = dateString.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (date.isAtSameMomentAs(today)) {
        return 'Today';
      } else if (date.isAtSameMomentAs(yesterday)) {
        return 'Yesterday';
      } else {
        return DateFormat('MMMM d, y').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  void _selectPreviousDay() {
    try {
      final dateParts = _selectedDate.split('-');
      final currentDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      final previousDay = currentDate.subtract(const Duration(days: 1));
      setState(() {
        _selectedDate =
            '${previousDay.year}-${previousDay.month.toString().padLeft(2, '0')}-${previousDay.day.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      debugPrint('Error selecting previous day: $e');
    }
  }

  void _selectNextDay() {
    try {
      final dateParts = _selectedDate.split('-');
      final currentDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Don't allow selecting future dates
      if (currentDate.isBefore(today)) {
        final nextDay = currentDate.add(const Duration(days: 1));
        setState(() {
          _selectedDate =
              '${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}';
        });
      }
    } catch (e) {
      debugPrint('Error selecting next day: $e');
    }
  }

  bool _isSelectedDateToday() {
    try {
      final dateParts = _selectedDate.split('-');
      final selectedDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return selectedDate.isAtSameMomentAs(today);
    } catch (e) {
      return false;
    }
  }
}