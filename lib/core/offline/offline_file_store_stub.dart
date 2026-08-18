/// Web / non-IO stub: offline disk cache is disabled.
Future<void> writeOfflineFile(String name, String contents) async {}

Future<String?> readOfflineFile(String name) async => null;

Future<void> deleteOfflineFile(String name) async {}
