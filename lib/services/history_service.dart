import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HistoryItem {
  final String id;
  final String prompt;
  final String vibe;
  final List<String> replies;
  final DateTime timestamp;
  final bool isFavorite;

  HistoryItem({
    required this.id,
    required this.prompt,
    required this.vibe,
    required this.replies,
    required this.timestamp,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'vibe': vibe,
    'replies': replies,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    prompt: json['prompt'],
    vibe: json['vibe'],
    replies: List<String>.from(json['replies']),
    timestamp: DateTime.parse(json['timestamp']),
    isFavorite: json['isFavorite'] ?? false,
  );
}

class HistoryService extends ChangeNotifier {
  static const String _key = 'reply_rizz_history';
  List<HistoryItem> _items = [];

  List<HistoryItem> get items => List.unmodifiable(_items);

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _items = jsonList.map((e) => HistoryItem.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> saveItem(
    String prompt,
    String vibe,
    List<String> replies,
  ) async {
    final newItem = HistoryItem(
      id: const Uuid().v4(),
      prompt: prompt,
      vibe: vibe,
      replies: replies,
      timestamp: DateTime.now(),
    );

    _items.insert(0, newItem); // Add to top
    if (_items.length > 30) {
      _items.removeLast();
    }
    notifyListeners();
    await _saveHistory();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      _items[index] = HistoryItem(
        id: item.id,
        prompt: item.prompt,
        vibe: item.vibe,
        replies: item.replies,
        timestamp: item.timestamp,
        isFavorite: !item.isFavorite,
      );
      notifyListeners();
      await _saveHistory();
    }
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      _items.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_key, jsonString);
  }
}
