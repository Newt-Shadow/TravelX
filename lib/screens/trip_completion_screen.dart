import 'dart:math';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/storage_service.dart';

class TripCompletionScreen extends StatefulWidget {
  final Trip trip;

  const TripCompletionScreen({super.key, required this.trip});

  @override
  State<TripCompletionScreen> createState() => _TripCompletionScreenState();
}

class _TripCompletionScreenState extends State<TripCompletionScreen> {
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  late final int tilesRevealed;
  late final int explorerPoints;
  late final String? unlockedLandmark;

  @override
  void initState() {
    super.initState();
    tilesRevealed = Random().nextInt(15) + 5;
    explorerPoints = Random().nextInt(100) + 50;
    unlockedLandmark = Random().nextBool() ? "Silcoorie Grant Park" : null;
  }

  @override
  void dispose() {
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveDetails() {
    final cost = double.tryParse(_costController.text);
    final notes = _notesController.text;
    widget.trip.cost = cost;
    widget.trip.notes = notes;
    StorageService.updateTrip(widget.trip.id, {'cost': cost, 'notes': notes});
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 👈 prevents bottom overflow
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.deepPurple.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // 👈 makes content scrollable if keyboard opens
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Trip Complete!",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRevealAnimation(),
                const SizedBox(height: 24),
                Text(
                  "You've charted new territory!",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 32),
                _buildRewardsCard(),
                const SizedBox(height: 32),

                // Cost + Notes form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            "Add Trip Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cost of Trip',
                              prefixIcon: Icon(Icons.monetization_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes (e.g., Trip to the market)',
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("CLOSE",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _saveDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text("SAVE & CLOSE",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealAnimation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: const Icon(Icons.map_outlined, size: 80, color: Colors.white),
    );
  }

  Widget _buildRewardsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Text(
                "REWARDS EARNED",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1,
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRewardItem(Icons.hexagon_outlined,
                      tilesRevealed.toString(), "Tiles Revealed"),
                  _buildRewardItem(Icons.star_border_purple500_outlined,
                      "+$explorerPoints", "Explorer Points"),
                ],
              ),
              if (unlockedLandmark != null) ...[
                const Divider(height: 24),
                _buildRewardItem(Icons.verified_outlined, unlockedLandmark!,
                    "Landmark Badge Unlocked!",
                    isLandmark: true),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String value, String label,
      {bool isLandmark = false}) {
    return Column(
      children: [
        Icon(
          icon,
          color: isLandmark ? Colors.amber.shade800 : Colors.indigo,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isLandmark ? Colors.amber.shade900 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }
}
