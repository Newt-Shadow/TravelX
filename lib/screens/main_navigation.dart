import 'package:flutter/material.dart';
import 'dart:async'; 
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import 'trip_capture_screen.dart';
import 'trip_history_screen.dart';
import 'trip_insights_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../models/trip.dart';
import 'trip_completion_screen.dart';

import 'trip_analytics_screen.dart';
import 'travel_buddy_screen.dart';
import 'trip_heatmap_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

// Add the `WidgetsBindingObserver` mixin to listen for app lifecycle events.
class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _idx = 0;
  late final BluetoothService _btService;
  late final DetectionService _detectionService;
  StreamSubscription<Trip>? _tripCompletionSub;

  final _screens = const [
    TripCaptureScreen(),
    TripHistoryScreen(),
    TripInsightsScreen(),
    TripAnalyticsScreen(),
    TravelBuddyScreen(),
    TripHeatmapScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Register this class as an observer.
    WidgetsBinding.instance.addObserver(this);
    // Get the BluetoothService instance from the provider.
    _btService = Provider.of<BluetoothService>(context, listen: false);
    _detectionService = Provider.of<DetectionService>(context, listen: false);
    // Start passive advertising when the app first opens.
    _startPassive();

    // Listen for completed trips
    _tripCompletionSub =
        _detectionService.tripCompletionStream.listen((trip) {
      _showTripCompletionDialog(trip);
    });
  }

  @override
  void dispose() {
    // Clean up the observer when the widget is removed.
    WidgetsBinding.instance.removeObserver(this);
    _tripCompletionSub?.cancel();
    super.dispose();
  }

  /// This method is called whenever the app's lifecycle state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // The app has come to the foreground.
      _startPassive();
    } else if (state == AppLifecycleState.paused) {
      // The app has gone to the background.
      _btService.stopPassiveAdvertising();
    }
  }

  void _showTripCompletionDialog(Trip trip) {
    showDialog(
      context: context,
      builder: (context) => TripCompletionScreen(trip: trip),
    );
  }

  /// A helper method to safely start passive advertising.
  void _startPassive() async {
    try {
      final anonId = await StorageService.getOrCreateAnonUserId();
      final userId = AuthService.currentUserId;
      if (userId != null) {
        _btService.startPassiveAdvertising(userId);
        print("App is active, started passive advertising for user $userId.");
      } else {
        print(
          "App is active, but user is not logged in. Skipping passive advertising.",
        );
      }
    } catch (e) {
      print("Error starting passive advertising from lifecycle observer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fiber_manual_record),
            label: 'Live',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Buddies',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Heatmap'),
        ],
      ),
    );
  }
}