import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

class SessionLocalDataSource {
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAccessToken);
  }

  Future<String?> getTenant() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyTenantId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserId);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserEmail);
  }

  Future<void> setSession({
    required String accessToken,
    required String tenant,
    required String userId,
    required String userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAccessToken, accessToken);
    await prefs.setString(keyTenantId, tenant);
    await prefs.setString(keyUserId, userId);
    await prefs.setString(keyUserEmail, userEmail);
  }

  Future<void> clearSession({required bool keepTenant}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyUserId);
    await prefs.remove(keyUserEmail);
    if (!keepTenant) {
      await prefs.remove(keyTenantId);
    }
  }

  Future<void> setLastTenant(String tenant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTenantId, tenant);
  }
}

