 import 'package:flutter/material.dart';
import 'package:daypath/models/visited_place_model.dart';
import 'package:daypath/themes/theme.dart';

class AnimatedPlaceCard extends StatefulWidget {
  final VisitedPlace place;
  final int index;
  
  const AnimatedPlaceCard({
    required this.place,
    required this.index,
    Key? key,
  }) : super(key: key);
  
  @override
  State<AnimatedPlaceCard> createState() => _AnimatedPlaceCardState();
}

class _AnimatedPlaceCardState extends State<AnimatedPlaceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: DayPathTheme.mediumAnimation,
    );
    
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Stagger the animations based on index
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  String _getPlaceIcon() {
    final name = widget.place.placeName.toLowerCase();
    
    if (name.contains('home') || name.contains('house')) {
      return '🏠';
    } else if (name.contains('office') || name.contains('work')) {
      return '🏢';
    } else if (name.contains('cafe') || name.contains('coffee')) {
      return '☕';
    } else if (name.contains('restaurant') || name.contains('food')) {
      return '🍽️';
    } else if (name.contains('park') || name.contains('garden')) {
      return '🌳';
    } else if (name.contains('gym') || name.contains('fitness')) {
      return '💪';
    } else if (name.contains('store') || name.contains('market') || name.contains('shop')) {
      return '🛍️';
    } else if (name.contains('school') || name.contains('university') || name.contains('college')) {
      return '🎓';
    } else {
      return '📍';
    }
  }
  
  Color _getCardAccentColor() {
    final name = widget.place.placeName.toLowerCase();
    
    if (name.contains('home') || name.contains('house')) {
      return const Color(0xFF8E44AD);
    } else if (name.contains('office') || name.contains('work')) {
      return const Color(0xFF3498DB);
    } else if (name.contains('cafe') || name.contains('coffee')) {
      return const Color(0xFFD35400);
    } else if (name.contains('restaurant') || name.contains('food')) {
      return const Color(0xFFE74C3C);
    } else if (name.contains('park') || name.contains('garden')) {
      return const Color(0xFF27AE60);
    } else if (name.contains('gym') || name.contains('fitness')) {
      return const Color(0xFFF39C12);
    } else if (name.contains('store') || name.contains('market') || name.contains('shop')) {
      return const Color(0xFF1ABC9C);
    } else if (name.contains('school') || name.contains('university') || name.contains('college')) {
      return const Color(0xFF34495E);
    } else {
      return DayPathTheme.primaryColor;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final placeIcon = _getPlaceIcon();
    final accentColor = _getCardAccentColor();
    
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusMedium),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? DayPathTheme.cardBackgroundDark : DayPathTheme.cardBackgroundLight,
                  borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusMedium),
                  boxShadow: DayPathTheme.lightShadow,
                  border: Border.all(
                    color: accentColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(DayPathTheme.borderRadiusMedium),
                          topRight: Radius.circular(DayPathTheme.borderRadiusMedium),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTimeColumn(widget.place),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPlaceInfo(widget.place, placeIcon, accentColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimeColumn(VisitedPlace place) {
    final timeTextStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    
    final endTimeTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).textTheme.bodySmall?.color,
      fontWeight: FontWeight.w500,
    );
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatTime(place.startTime),
          style: timeTextStyle,
        ),
        const SizedBox(height: 4),
        _buildTimeConnector(),
        const SizedBox(height: 4),
        Text(
          _formatTime(place.endTime),
          style: endTimeTextStyle,
        ),
      ],
    );
  }
  
  Widget _buildTimeConnector() {
    final accentColor = _getCardAccentColor();
    
    return SizedBox(
      height: 40,
      width: 24,
      child: CustomPaint(
        painter: TimelinePainter(
          color: accentColor,
          dotRadius: 4,
        ),
      ),
    );
  }
  
  Widget _buildPlaceInfo(VisitedPlace place, String icon, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.placeName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DayPathTheme.borderRadiusSmall),
          ),
          child: Text(
            place.formattedDuration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class TimelinePainter extends CustomPainter {
  final Color color;
  final double dotRadius;
  
  TimelinePainter({
    required this.color,
    required this.dotRadius,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;
    
    // Draw top dot
    canvas.drawCircle(
      Offset(dotRadius, dotRadius),
      dotRadius,
      paint,
    );
    
    // Draw line
    final linePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(dotRadius, dotRadius * 2),
      Offset(dotRadius, size.height - dotRadius),
      linePaint,
    );
    
    // Draw bottom dot
    final bottomDotPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(dotRadius, size.height - dotRadius),
      dotRadius * 0.75,
      bottomDotPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}