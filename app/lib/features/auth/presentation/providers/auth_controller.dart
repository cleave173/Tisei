import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/offline/local_cache.dart';
import '../../data/auth_repository.dart';
import '../../data/models/user_dto.dart';

/// Tri-state auth: unknown (loading) → unauthenticated → authenticated.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserDto user;
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthInitial());

  final AuthRepository _repo;

  Future<void> bootstrap() async {
    if (!await _repo.hasToken()) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final UserDto u = await _repo.me();
      state = AuthAuthenticated(u);
    } catch (_) {
      try {
        await _repo.logout();
      } finally {
        await (await LocalCache.instance).clear();
        state = const AuthUnauthenticated();
      }
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _repo.login(email: email, password: password);
      await (await LocalCache.instance).clear();
      final UserDto u = await _repo.me();
      state = AuthAuthenticated(u);
    } catch (e) {
      state = AuthFailure(e.toString());
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required int age,
  }) async {
    try {
      await _repo.register(email: email, password: password, fullName: fullName, age: age);
      await (await LocalCache.instance).clear();
      final UserDto u = await _repo.me();
      state = AuthAuthenticated(u);
    } catch (e) {
      state = AuthFailure(e.toString());
      rethrow;
    }
  }

  Future<void> loginWithGoogle(String idToken) async {
    try {
      await _repo.google(idToken: idToken);
      await (await LocalCache.instance).clear();
      final UserDto u = await _repo.me();
      state = AuthAuthenticated(u);
    } catch (e) {
      state = AuthFailure(e.toString());
      rethrow;
    }
  }

  /// Re-fetch the current user (e.g. after XP changes).
  /// Silently no-ops if unauthenticated or request fails.
  Future<void> refresh() async {
    if (state is! AuthAuthenticated) return;
    try {
      final UserDto u = await _repo.me();
      state = AuthAuthenticated(u);
    } catch (_) {
      // keep previous state on transient errors
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      await (await LocalCache.instance).clear();
      state = const AuthUnauthenticated();
    }
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (Ref ref) => AuthController(ref.read(authRepositoryProvider)),
);
