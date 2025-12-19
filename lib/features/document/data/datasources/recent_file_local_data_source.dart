import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

class RecentFileLocalDataSource {
  Future<List<String>> loadRecentDocuments({
    required String tenantId,
    required String userId,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storageKey =
        recentDocumentsStorageKey(tenantId: tenantId, userId: userId);
    final List<String> storedPaths =
        prefs.getStringList(storageKey) ?? [];

    final filteredPaths =
        storedPaths.where((p) => File(p).existsSync()).toList();

    if (filteredPaths.length != storedPaths.length) {
      await prefs.setStringList(storageKey, filteredPaths);
    }

    return filteredPaths;
  }

  Future<void> saveRecentDocuments({
    required String tenantId,
    required String userId,
    required List<String> documentPaths,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storageKey =
        recentDocumentsStorageKey(tenantId: tenantId, userId: userId);
    await prefs.setStringList(storageKey, documentPaths);
  }
}
