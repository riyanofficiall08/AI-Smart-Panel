import 'package:flutter/foundation.dart';

import '../models/history_item.dart';
import '../services/backend.dart';

class HistoryController extends ChangeNotifier {
  List<HistoryItem> items = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await Backend.history();
    } catch (e) {
      error = 'Gagal memuat riwayat. Tarik ke bawah untuk mencoba lagi.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    items = items.where((e) => e.id != id).toList();
    notifyListeners();
    try {
      await Backend.deleteHistory(id);
    } catch (_) {
      await load();
    }
  }

  Future<void> clear(String userId) async {
    await Backend.clearHistory(userId);
    items = [];
    notifyListeners();
  }

  void reset() {
    items = [];
    notifyListeners();
  }
}
