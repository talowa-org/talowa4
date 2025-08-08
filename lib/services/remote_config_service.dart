import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../config/app_config.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _rc;

  static Future<void> init() async {
    try {
      _rc = FirebaseRemoteConfig.instance;
      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ));
      await _rc!.setDefaults({
        'aiBackendEnabled': false,
        'aiBackendBaseUrl': AppConfig.aiBackendBaseUrl,
        'aiTimeoutMs': AppConfig.aiTimeoutMs,
      });
      await _rc!.fetchAndActivate();
    } catch (_) {
      // Fail silently; getters will use defaults
    }
  }

  static bool get aiEnabled => _getBool('aiBackendEnabled', false);
  static String get aiUrl => _getString('aiBackendBaseUrl', AppConfig.aiBackendBaseUrl);
  static int get aiTimeoutMs => _getInt('aiTimeoutMs', AppConfig.aiTimeoutMs);

  static bool _getBool(String key, bool fallback) {
    try { return _rc?.getBool(key) ?? fallback; } catch (_) { return fallback; }
  }

  static String _getString(String key, String fallback) {
    try { return _rc?.getString(key).isNotEmpty == true ? _rc!.getString(key) : fallback; } catch (_) { return fallback; }
  }

  static int _getInt(String key, int fallback) {
    try { return _rc?.getInt(key) ?? fallback; } catch (_) { return fallback; }
  }
}