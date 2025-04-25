import 'package:flutter/material.dart';
import 'package:daypath/themes/theme.dart';
import 'package:daypath/models/visited_place_model.dart';

class SummaryCard extends StatelessWidget {
  final int placesCount;
  final Duration totalDuration;
  final VisitedPlace? mostVisitedPlace;

  const SummaryCard({
    Key? key,
    required this.placesCount,
    required this.totalDuration,
    this.mostVisitedPlace,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? DayPathTheme.cardBackgroundDark : DayPathTheme.cardBackgroundLight,
          borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusMedium),
          boxShadow: DayPathTheme.lightShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryStat(
                context,
                icon: Icons.place_outlined,
                label: 'Places Visited',
                value: placesCount.toString(),
                color: DayPathTheme.primaryColor,
              ),
              const SizedBox(height: 12),
              _buildSummaryStat(
                context,
                icon: Icons.access_time,
                label: 'Total Time',
                value: _formatDuration(totalDuration),
                color: const Color(0xFF3498DB),
              ),
              if (mostVisitedPlace != null) ...[
                const SizedBox(height: 12),
                _buildSummaryStat(
                  context,
                  icon: Icons.star_outline,
                  label: 'Most Visited',
                  value: mostVisitedPlace!.placeName,
                  color: const Color(0xFFE74C3C),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusSmall),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }
}