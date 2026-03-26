import 'package:shared_preferences/shared_preferences.dart';

class SearchPathsStore {
  static const _key = 'search_paths';

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const <String>[];
    return values.where((p) => p.trim().isNotEmpty).toSet().toList();
  }

  static Future<void> save(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = paths.where((p) => p.trim().isNotEmpty).toSet().toList();
    await prefs.setStringList(_key, normalized);
  }
}
