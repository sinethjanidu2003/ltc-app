import 'dart:convert';

import 'offline_file_store.dart';

enum SyncMutationType {
  createFacility,
  addPatient,
  createSession,
  enrollPatients,
  saveAssessment,
}

class SyncMutation {
  SyncMutation({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final SyncMutationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    return SyncMutation(
      id: '${json['id']}',
      type: SyncMutationType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => SyncMutationType.saveAssessment,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.now(),
    );
  }
}

/// Persistent FIFO queue of offline writes waiting to hit the API.
///
/// On web, persistence is disabled (in-memory only for the session).
class SyncQueue {
  final List<SyncMutation> _items = [];

  List<SyncMutation> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;
  bool get hasPending => _items.isNotEmpty;

  Future<void> load() async {
    _items.clear();
    final rawText = await readOfflineFile('sync_queue.json');
    if (rawText == null || rawText.isEmpty) return;
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          _items.add(
            SyncMutation.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    } catch (_) {
      _items.clear();
    }
  }

  Future<void> _persist() async {
    await writeOfflineFile(
      'sync_queue.json',
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> persist() => _persist();

  Future<void> enqueue(SyncMutation mutation) async {
    _items.add(mutation);
    await _persist();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
  }
}
