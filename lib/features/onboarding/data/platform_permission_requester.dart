import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../core/utils/logger.dart';
import '../domain/permission_storytelling.dart';

final _log = KitaLogger('Onboarding');

/// Maps [KitaPermission] to platform [ph.Permission].
ph.Permission _toPlatform(KitaPermission permission) {
  return switch (permission) {
    KitaPermission.camera => ph.Permission.camera,
    KitaPermission.microphone => ph.Permission.microphone,
    KitaPermission.location => ph.Permission.locationWhenInUse,
  };
}

/// Maps platform [ph.PermissionStatus] to [PermissionRequestStatus].
PermissionRequestStatus _fromPlatform(ph.PermissionStatus status) {
  if (status.isGranted || status.isLimited) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  if (status.isRestricted) {
    return PermissionRequestStatus.restricted;
  }
  return PermissionRequestStatus.denied;
}

/// [PermissionRequester] backed by the `permission_handler` package.
class PlatformPermissionRequester implements PermissionRequester {
  @override
  Future<PermissionRequestStatus> request(KitaPermission permission) async {
    final platformPerm = _toPlatform(permission);
    _log.info('Requesting platform permission: ${permission.name}');
    final status = await platformPerm.request();
    final result = _fromPlatform(status);
    _log.info('Permission ${permission.name} result: ${result.name}');
    return result;
  }

  @override
  Future<void> openSettings() async {
    _log.info('Opening app settings');
    await ph.openAppSettings();
  }
}
