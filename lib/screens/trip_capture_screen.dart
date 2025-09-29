import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/detection_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/status_card.dart';
import '../widgets/live_samples_card.dart';
import '../widgets/latest_trip_card.dart';
import '../widgets/travel_buddies_grid.dart';

class TripCaptureScreen extends StatefulWidget {
  const TripCaptureScreen({super.key});

  @override
  State<TripCaptureScreen> createState() => _TripCaptureScreenState();
}

class _TripCaptureScreenState extends State<TripCaptureScreen> {
  late DetectionService _detection;
  bool _collecting = false;
  Timer? _uiTimer;

  final List<String> _modes = [
    'auto-detect',
    'walk',
    'run',
    'bike',
    'car',
    'bus',
    'train',
    'stationary',
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _detection = Provider.of<DetectionService>(context, listen: false);
    _startUiTicker();
  }

  Future<void> _requestPermissions() async {
    final locStatus = await Permission.locationWhenInUse.request();
    final actStatus = await Permission.activityRecognition.request();

    if (locStatus.isDenied || actStatus.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location or Activity permission denied! Some features may not work.',
          ),
        ),
      );
    }
  }

  void _startUiTicker() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _collecting = _detection.collecting;
      });
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final locStatus = await Permission.locationWhenInUse.status;
    final actStatus = await Permission.activityRecognition.status;

    if (!locStatus.isGranted || !actStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot start recording: Location or Activity permission denied!',
          ),
        ),
      );
      return;
    }

    if (_detection.collecting) {
      await _detection.stopManual();
    } else {
      await _detection.startManual();
    }
    if (!mounted) return;
    setState(() {
      _collecting = _detection.collecting;
    });
  }

  Future<void> _syncNow() async {
    final keys = StorageService.box.keys.cast<String>().toList();
    for (final k in keys) {
      await SyncService.instance.enqueueAndSync(k);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sync requested')));
  }

  void _selectMode(String mode) async {
    if (!_detection.collecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start recording to override mode')),
      );
      return;
    }
    await _detection.overrideMode(mode);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = _detection.currentMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Capture'),
        actions: [
          IconButton(onPressed: _syncNow, icon: const Icon(Icons.cloud_upload)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'Trip Capture',
                  applicationVersion: '1.0',
                  children: const [Text('Advanced Trip Capture')],
                );
              } else if (v == 'clear') {
                showDialog(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        title: const Text('Clear local trips?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              StorageService.box.clear();
                              if (!mounted) return;
                              setState(() {});
                              Navigator.pop(c);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                );
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 'about', child: Text('About')),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear local trips'),
                  ),
                ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Main start/stop button
          GestureDetector(
            onTap: _toggleRecording,
            child: StatusCard(collecting: _collecting, mode: currentMode),
          ),
          if (_collecting)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    _modes.map((m) {
                      final isSelected = m == currentMode;
                      return ChoiceChip(
                        label: Text(m),
                        selected: isSelected,
                        onSelected: (_) => _selectMode(m),
                      );
                    }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          const LiveSamplesCard(),
          const SizedBox(height: 12),
          const TravelBuddiesGrid(),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Latest Trip',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          
          const SizedBox(height: 6),
          // Using a SizedBox with a fixed height ensures the map has enough space
          // and works correctly within the ListView.
          SizedBox(height: 300, child: LatestTripCard()),
          // const Align(
          //   alignment: Alignment.centerLeft,
          //   child: Text(
          //     'Latest Trip',
          //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          //   ),
          // ),
          // const SizedBox(height: 6),
          // const LatestTripCard(),
        ],
      ),
    );
  }
}

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:permission_handler/permission_handler.dart';

// import '../services/detection_service.dart';
// import '../services/storage_service.dart';
// import '../services/sync_service.dart';
// import '../widgets/status_card.dart';
// import '../widgets/live_samples_card.dart';
// import '../widgets/latest_trip_card.dart';
// import '../widgets/travel_buddies_grid.dart';
// import '../theme/app_theme.dart';

// class TripCaptureScreen extends StatefulWidget {
//   const TripCaptureScreen({super.key});

//   @override
//   State<TripCaptureScreen> createState() => _TripCaptureScreenState();
// }

// class _TripCaptureScreenState extends State<TripCaptureScreen> with TickerProviderStateMixin {
//   late DetectionService _detection;
//   bool _collecting = false;
//   Timer? _uiTimer;
//   late AnimationController _pulseController;
//   late Animation<double> _pulseAnimation;

//   final List<String> _modes = [
//     'auto-detect',
//     'walk',
//     'run',
//     'bike',
//     'car',
//     'bus',
//     'train',
//     'stationary'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//     _detection = Provider.of<DetectionService>(context, listen: false);
//     _startUiTicker();

//     _pulseController = AnimationController(
//       duration: const Duration(milliseconds: 1500),
//       vsync: this,
//     )..repeat(reverse: true);

//     _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );
//   }

//   Future<void> _requestPermissions() async {
//     final locStatus = await Permission.locationWhenInUse.request();
//     final actStatus = await Permission.activityRecognition.request();

//     if (locStatus.isDenied || actStatus.isDenied) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//               'Location or Activity permission denied! Some features may not work.'),
//         ),
//       );
//     }
//   }

//   void _startUiTicker() {
//     _uiTimer?.cancel();
//     _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!mounted) return;
//       setState(() {
//         _collecting = _detection.collecting;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _uiTimer?.cancel();
//     _pulseController.dispose();
//     super.dispose();
//   }

//   Future<void> _toggleRecording() async {
//     final locStatus = await Permission.locationWhenInUse.status;
//     final actStatus = await Permission.activityRecognition.status;

//     if (!locStatus.isGranted || !actStatus.isGranted) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//               'Cannot start recording: Location or Activity permission denied!'),
//         ),
//       );
//       return;
//     }

//     if (_detection.collecting) {
//       await _detection.stopManual();
//     } else {
//       await _detection.startManual();
//     }
//     if (!mounted) return;
//     setState(() {
//       _collecting = _detection.collecting;
//     });
//   }

//   Future<void> _syncNow() async {
//     final keys = StorageService.box.keys.cast<String>().toList();
//     for (final k in keys) {
//       await SyncService.instance.enqueueAndSync(k);
//     }
//     if (!mounted) return;
//     ScaffoldMessenger.of(context)
//         .showSnackBar(const SnackBar(content: Text('Sync requested')));
//   }

//   void _selectMode(String mode) async {
//     if (!_detection.collecting) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Start recording to override mode')));
//       return;
//     }
//     await _detection.overrideMode(mode);
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentMode = _detection.currentMode;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard'),
//         actions: [
//           IconButton(onPressed: _syncNow, icon: const Icon(Icons.cloud_upload)),
//           PopupMenuButton<String>(
//             onSelected: (v) {
//               if (v == 'about') {
//                 showAboutDialog(
//                     context: context,
//                     applicationName: 'TravelX',
//                     applicationVersion: '1.0',
//                     children: const [Text('Your personal journey companion.')]);
//               } else if (v == 'clear') {
//                 showDialog(
//                     context: context,
//                     builder: (c) => AlertDialog(
//                           title: const Text('Clear local trips?'),
//                           actions: [
//                             TextButton(
//                                 onPressed: () => Navigator.pop(c),
//                                 child: const Text('Cancel')),
//                             TextButton(
//                                 onPressed: () {
//                                   StorageService.box.clear();
//                                   if (!mounted) return;
//                                   setState(() {});
//                                   Navigator.pop(c);
//                                 },
//                                 child: const Text('Clear')),
//                           ],
//                         ));
//               }
//             },
//             itemBuilder: (_) => const [
//               PopupMenuItem(value: 'about', child: Text('About')),
//               PopupMenuItem(value: 'clear', child: Text('Clear local trips')),
//             ],
//           )
//         ],
//       ),
//       body: Stack(
//         children: [
//           ListView(
//             padding: const EdgeInsets.all(16.0),
//             children: [
//               StatusCard(collecting: _collecting, mode: currentMode),
//               if (_collecting)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8.0),
//                   child: Wrap(
//                     spacing: 8,
//                     runSpacing: 4,
//                     children: _modes.map((m) {
//                       final isSelected = m == currentMode;
//                       return ChoiceChip(
//                         label: Text(m),
//                         selected: isSelected,
//                         onSelected: (_) => _selectMode(m),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               const SizedBox(height: 12),
//               LiveSamplesCard(),
//               const SizedBox(height: 12),
//               TravelBuddiesGrid(),
//               const SizedBox(height: 18),
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text('Latest Trip',
//                     style: AppTheme.textTheme.headlineSmall?.copyWith(color: Colors.black)),
//               ),
//               const SizedBox(height: 6),
//               // Using a SizedBox with a fixed height ensures the map has enough space
//               // and works correctly within the ListView.
//               SizedBox(
//                 height: 300,
//                 child: LatestTripCard(),
//               ),
//               const SizedBox(height: 100), // Space for the floating button
//             ],
//           ),
//           // Positioned(
//           //   bottom: 30,
//           //   left: 0,
//           //   right: 0,
//           //   child: Center(
//           //     child: GestureDetector(
//           //       onTap: _toggleRecording,
//           //       child: ScaleTransition(
//           //         scale: _pulseAnimation,
//           //         child: Container(
//           //           width: 150,
//           //           height: 150,
//           //           decoration: BoxDecoration(
//           //             gradient: const LinearGradient(
//           //               colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
//           //               begin: Alignment.topLeft,
//           //               end: Alignment.bottomRight,
//           //             ),
//           //             shape: BoxShape.circle,
//           //             boxShadow: [
//           //               BoxShadow(
//           //                 color: AppTheme.primaryColor.withOpacity(0.5),
//           //                 blurRadius: 20,
//           //                 spreadRadius: 5,
//           //               ),
//           //             ],
//           //           ),
//           //           child: Center(
//           //             child: Text(
//           //               _collecting ? 'STOP' : 'START',
//           //               style: AppTheme.textTheme.headlineSmall?.copyWith(color: Colors.white),
//           //             ),
//           //           ),
//           //         ),
//           //       ),
//           //     ),
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
// }
