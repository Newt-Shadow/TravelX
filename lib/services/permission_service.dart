import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests all necessary permissions for the app to function.
  /// This should be called once when the app starts up.
  static Future<void> requestAll() async {
    // A map of all permissions your app requires to function fully.
    final permissionsToRequest = [
      Permission.location,
      Permission.activityRecognition,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    // Request all permissions in the list at once.
    Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();

    // You can optionally check the statuses here and show a dialog
    // if a critical permission was denied.
    statuses.forEach((permission, status) {
      if (status.isPermanentlyDenied) {
        // If a permission is permanently denied, the user must go to settings
        // to enable it. You can show a dialog guiding them there.
        print("Permission ${permission.toString()} was permanently denied.");
        // Example: openAppSettings();
      }
    });
  }
}