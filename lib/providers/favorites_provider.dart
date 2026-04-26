import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _key = 'favorite_tools';
  Set<String> _ids = {};

  Set<String> get ids => _ids;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids = (prefs.getStringList(_key) ?? []).toSet();
    notifyListeners();
  }

  bool isFavorite(String toolId) => _ids.contains(toolId);

  Future<void> toggle(String toolId) async {
    if (_ids.contains(toolId)) {
      _ids.remove(toolId);
    } else {
      _ids.add(toolId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
    notifyListeners();
  }
}
