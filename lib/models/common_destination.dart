import 'package:latlong2/latlong.dart';

class CommonDestination {
  final String id; // A unique ID, e.g., a hash of the coordinates
  String label;    // User-defined label: "Home", "Work"
  final LatLng center;
  int visitCount;

  CommonDestination({
    required this.id,
    required this.label,
    required this.center,
    required this.visitCount,
  });
}