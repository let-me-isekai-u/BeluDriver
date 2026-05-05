import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureCamera() async {
    final status = await Permission.camera.status;

    if (status.isGranted) return true;

    final result = await Permission.camera.request();

    if (result.isGranted) return true;

    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }
}