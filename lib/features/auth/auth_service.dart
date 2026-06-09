import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<User?> loginAdmin(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    } catch (e) {
      if (kDebugMode) debugPrint('Login Error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('resetPassword error: $e');
      return false;
    }
  }

  // Calls the `admin-delete-user` Edge Function with the current user's own ID,
  // then signs out. The Edge Function must verify the requester matches userId
  // before invoking the Supabase Admin API to delete the auth record.
  Future<String?> deleteMyAccount() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'Not authenticated';
    try {
      final res = await _supabase.functions
          .invoke('admin-delete-user', body: {'userId': uid});
      if (res.data is Map && (res.data as Map).containsKey('error')) {
        return (res.data as Map)['error'].toString();
      }
      await _supabase.auth.signOut();
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteMyAccount error: $e');
      return e.toString();
    }
  }
}
