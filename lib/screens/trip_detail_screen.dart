import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../viewmodels/trip_detail_viewmodel.dart';
import '../widgets/advanced_animated_map.dart';
import '../widgets/advanced_trip_timeline.dart';

class TripDetailScreen extends StatelessWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider creates the ViewModel and provides it to all child widgets.
    // This is where the state for this specific screen is managed.
    return ChangeNotifierProvider(
      create: (_) => TripDetailViewModel(trip: trip),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Story'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 1,
        ),
        body: Column(
          children: [
            // The map will expand to fill all available vertical space.
            const Expanded(
              child: AdvancedAnimatedMap(),
            ),
            // The interactive timeline sits at the bottom.
            const AdvancedTripTimeline(),
          ],
        ),
      ),
    );
  }
}