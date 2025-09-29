import 'package:flutter/material.dart';
import '../models/trip.dart';

/// Manages the interactive state for viewing a single trip's details.
class TripDetailViewModel extends ChangeNotifier {
  final Trip trip;
  TripSegment? _selectedSegment;
  double _animationProgress = 0.0; // From 0.0 to 1.0

  TripDetailViewModel({required this.trip}) {
    // Initially, select the first segment if it exists.
    if (trip.segments.isNotEmpty) {
      _selectedSegment = trip.segments.first;
    }
  }

  TripSegment? get selectedSegment => _selectedSegment;
  double get animationProgress => _animationProgress;

  /// Called by the timeline when a user taps or scrubs to a segment.
  void selectSegment(TripSegment segment) {
    if (_selectedSegment?.id != segment.id) {
      _selectedSegment = segment;
      // Optional: Could also seek the animation to the start of this segment.
      notifyListeners();
    }
  }

  /// Called by the animation controller in the map to update the timeline.
  void updateAnimationProgress(double progress) {
    _animationProgress = progress;
    notifyListeners();
  }
}