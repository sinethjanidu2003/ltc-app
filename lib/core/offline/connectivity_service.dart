import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has a usable network path.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool _ready = false;

  bool get isOnline => _online;
  bool get isReady => _ready;

  Future<void> start() async {
    final current = await _connectivity.checkConnectivity();
    _online = _hasConnection(current);
    _ready = true;
    notifyListeners();

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final next = _hasConnection(results);
      if (next == _online) return;
      _online = next;
      notifyListeners();
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
