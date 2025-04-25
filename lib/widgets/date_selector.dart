import 'package:flutter/material.dart';
import 'package:daypath/themes/theme.dart';
// import 'package:intl/intl.dart';

class AnimatedDateSelector extends StatefulWidget {
  final String currentDate;
  final Function() onPreviousDay;
  final Function() onNextDay;
  final bool canSelectNextDay;

  const AnimatedDateSelector({
    required this.currentDate,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.canSelectNextDay,
    Key? key,
  }) : super(key: key);

  @override
  State<AnimatedDateSelector> createState() => _AnimatedDateSelectorState();
}

class _AnimatedDateSelectorState extends State<AnimatedDateSelector> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String _displayDate = '';
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _displayDate = widget.currentDate;

    _controller = AnimationController(
      vsync: this,
      duration: DayPathTheme.shortAnimation,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(AnimatedDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDate != widget.currentDate && !_isAnimating) {
      _animateChange(widget.currentDate);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateChange(String newDate) async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    await _controller.forward();

    setState(() {
      _displayDate = newDate;
    });

    await _controller.reverse();

    setState(() {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavigationButton(
            Icons.chevron_left,
            widget.onPreviousDay,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _displayDate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildNavigationButton(
            Icons.chevron_right,
            widget.canSelectNextDay ? widget.onNextDay : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(IconData icon, Function()? onPressed) {
    final color = onPressed == null
        ? Colors.grey.withOpacity(0.5)
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
      ),
    );
  }
}

