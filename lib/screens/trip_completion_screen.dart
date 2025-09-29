import 'dart:math';
import 'package:flutter/material.dart';
import '../models/trip.dart';

class TripCompletionScreen extends StatelessWidget {
  final Trip trip;
  final int tilesRevealed = Random().nextInt(15) + 5;
  final int explorerPoints = Random().nextInt(100) + 50;
  final String? unlockedLandmark;

  TripCompletionScreen({super.key, required this.trip}) 
    : unlockedLandmark = Random().nextBool() ? "Silcoorie Grant Park" : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.deepPurple.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                "Trip Complete!",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
              ),
              const SizedBox(height: 16),
              
              _buildRevealAnimation(),

              const SizedBox(height: 24),
              Text(
                "You've charted new territory!",
                style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 32),
              
              _buildRewardsCard(),
              
              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white, 
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text("VIEW EXPLORER MAP", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2)
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
              const Text("REWARDS EARNED", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRewardItem(Icons.hexagon_outlined, tilesRevealed.toString(), "Tiles Revealed"),
                  _buildRewardItem(Icons.star_border_purple500_outlined, "+$explorerPoints", "Explorer Points"),
                ],
              ),
              if (unlockedLandmark != null) ...[
                const Divider(height: 24),
                _buildRewardItem(Icons.verified_outlined, unlockedLandmark!, "Landmark Badge Unlocked!", isLandmark: true),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String value, String label, {bool isLandmark = false}) {
    return Column(
      children: [
        Icon(icon, color: isLandmark ? Colors.amber.shade800 : Colors.indigo, size: 32),
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