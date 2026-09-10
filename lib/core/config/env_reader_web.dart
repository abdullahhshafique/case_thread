/// Web implementation: no runtime file access — config must arrive via
/// --dart-define at build time.
Future<Map<String, String>> readDotEnv(String path) async => const {};
