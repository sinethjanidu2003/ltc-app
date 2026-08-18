import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Directory? _dir;

Future<Directory> _ensureDir() async {
  if (_dir != null) return _dir!;
  final root = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(root.path, 'ltc_offline_cache'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  _dir = dir;
  return dir;
}

Future<File> _file(String name) async {
  final dir = await _ensureDir();
  return File(p.join(dir.path, name));
}

Future<void> writeOfflineFile(String name, String contents) async {
  final file = await _file(name);
  await file.writeAsString(contents);
}

Future<String?> readOfflineFile(String name) async {
  final file = await _file(name);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> deleteOfflineFile(String name) async {
  final file = await _file(name);
  if (await file.exists()) {
    await file.delete();
  }
}
