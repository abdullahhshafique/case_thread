import 'dart:io';

/// Non-web implementation: reads a local `.env` file (dev convenience only —
/// never commit real values; see `.env.example`).
Future<Map<String, String>> readDotEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) return const {};
  final map = <String, String>{};
  for (final rawLine in await file.readAsLines()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    map[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return map;
}
