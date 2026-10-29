import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';

// Staff sign-in for the admin portal (lib/main_admin.dart). Deliberately
// separate from the tourist app's auth flow (register_screen.dart /
// login_screen.dart) — there's no admin signup; staff accounts are the same
// Supabase Auth users as tourists, distinguished only by profiles.staff.
abstract class AdminAuthRepository {
  /// Signs in with email/password, then checks profiles.staff for the
  /// signed-in user. If they're not staff, signs them back out immediately
  /// and throws — an admin session is never left active for a non-staff
  /// account, even though the underlying Supabase Auth credentials were
  /// valid.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAdminAuthRepository implements AdminAuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const RepositoryException('Sign in failed. Please try again.');
      }
      final profileRow = await _client
          .from('profiles')
          .select('staff')
          .eq('id', user.id)
          .maybeSingle();
      final isStaff = profileRow?['staff'] == true;
      if (!isStaff) {
        await _client.auth.signOut();
        throw const RepositoryException(
          'This account is not authorized for the admin portal.',
        );
      }
    } on AuthException catch (e) {
      throw RepositoryException(e.message);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not sign in: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

// For tests/previews — no real Supabase connection needed.
class MockAdminAuthRepository implements AdminAuthRepository {
  final bool isStaffAccount;
  bool signedIn = false;

  MockAdminAuthRepository({this.isStaffAccount = true});

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!isStaffAccount) {
      throw const RepositoryException(
        'This account is not authorized for the admin portal.',
      );
    }
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}
