import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../models/log_entry.dart';

class HistoryService {
  static const String _prefKey = 'adeva_log_entries';
  static const int _maxEntries = 500;

  static Future<void> addEntry(LogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_prefKey) ?? [];
    list.insert(0, jsonEncode(entry.toJson()));
    if (list.length > _maxEntries) list.removeRange(_maxEntries, list.length);
    await prefs.setStringList(_prefKey, list);
  }

  static Future<List<LogEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList(_prefKey);
    if (list == null) return [];
    return list
        .map((s) {
          try {
            return LogEntry.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<LogEntry>()
        .toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  static Future<String> exportCsv() async {
    final entries = await getEntries();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/adeva_history_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = [
      ['timestamp', 'command', 'status', 'detail'],
      ...entries.map((e) => [
            e.timestamp.toIso8601String(),
            e.command,
            e.status,
            e.detail ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);
    return file.path;
  }
}
