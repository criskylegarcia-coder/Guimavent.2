// The one exception type every repository method should throw instead of
// letting a raw Supabase/Postgrest exception reach the UI. Screens can catch
// this and show `message` directly.
class RepositoryException implements Exception {
  final String message;

  const RepositoryException(this.message);

  @override
  String toString() => message;
}
