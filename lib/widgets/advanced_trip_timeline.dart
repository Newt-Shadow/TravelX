import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../viewmodels/trip_detail_viewmodel.dart';

class AdvancedTripTimeline extends StatelessWidget {
  const AdvancedTripTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens to the ViewModel to highlight the selected segment.
    final viewModel = context.watch<TripDetailViewModel>();
    final trip = viewModel.trip;
    final timelineItems = _buildTimelineItems(trip);
    final totalDuration = timelineItems.fold<Duration>(Duration.zero, (prev, e) => prev + e.duration);
    
    // UI constants
    const double pixelsPerMinute = 2.5;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.black.withOpacity(0.05),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: timelineItems.map((item) {
            final isSelected = viewModel.selectedSegment?.id == item.segment?.id;
            return Tooltip(
              message: "${item.mode.toUpperCase()}\n${item.duration.inMinutes} minutes",
              child: GestureDetector(
                onTap: () => item.segment != null ? viewModel.selectSegment(item.segment!) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (item.duration.inMinutes * pixelsPerMinute).clamp(40.0, 400.0),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getColorForMode(item.mode).withOpacity(0.7),
                        _getColorForMode(item.mode),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(_getIconForMode(item.mode), color: Colors.white, size: 28),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_TimelineItem> _buildTimelineItems(Trip trip) {
    final items = <_TimelineItem>[];
    DateTime? lastSegmentEndTime;

    for (final segment in trip.segments) {
      if (lastSegmentEndTime != null) {
        final idleDuration = segment.start.difference(lastSegmentEndTime);
        if (idleDuration.inMinutes > 2) {
          items.add(_TimelineItem(
            mode: 'stationary', 
            duration: idleDuration
          ));
        }
      }
      items.add(_TimelineItem(
        mode: segment.mode, 
        duration: (segment.end ?? segment.start).difference(segment.start),
        segment: segment
      ));
      lastSegmentEndTime = segment.end;
    }
    return items;
  }

  IconData _getIconForMode(String mode) {
    switch (mode) {
      case 'walk': return Icons.directions_walk;
      case 'run': return Icons.directions_run;
      case 'bike': return Icons.directions_bike;
      case 'car': return Icons.directions_car;
      case 'bus': return Icons.directions_bus;
      case 'train': return Icons.train;
      case 'stationary': return Icons.pause;
      default: return Icons.device_unknown;
    }
  }

  Color _getColorForMode(String mode) {
    switch (mode) {
      case 'walk': return Colors.green;
      case 'run': return Colors.orange;
      case 'bike': return Colors.blue;
      case 'car': return Colors.purple;
      case 'bus': return Colors.red;
      case 'train': return Colors.teal;
      case 'stationary': return Colors.grey.shade600;
      default: return Colors.black;
    }
  }
}

// A helper class to unify segments and idle periods for the timeline.
class _TimelineItem {
  final String mode;
  final Duration duration;
  final TripSegment? segment; // Null for idle periods

  _TimelineItem({required this.mode, required this.duration, this.segment});
}