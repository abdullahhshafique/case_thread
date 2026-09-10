/// Stub used on platforms without dart:io or dart:html — always yields an
/// empty map (web config must come via --dart-define).
Future<Map<String, String>> readDotEnv(String path) async => const {};
