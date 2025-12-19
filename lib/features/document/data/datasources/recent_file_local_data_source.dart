import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';

class RecentFileLocalDataSource {
  Future<List<String>> loadRecentDocuments() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> storedPaths =
        prefs.getStringList(keyListRecentFile) ?? [];

    final filteredPaths =
        storedPaths.where((p) => File(p).existsSync()).toList();

    if (filteredPaths.length != storedPaths.length) {
      await prefs.setStringList(keyListRecentFile, filteredPaths);
    }

    return filteredPaths;
  }

  Future<void> saveRecentDocuments(List<String> documentPaths) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyListRecentFile, documentPaths);
  }
}
