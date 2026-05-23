import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_client.dart';
import 'models/user_dto.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<TokenPair> register({
    required String email,
    required String password,
    required String fullName,
    required int age,
  }) async {
    final dynamic data = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'age': age,
    });
    final TokenPair pair = TokenPair.fromJson(data as Map<String, dynamic>);
    await _persist(pair);
    return pair;
  }

  Future<TokenPair> login({required String email, required String password}) async {
    final dynamic data = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    final TokenPair pair = TokenPair.fromJson(data as Map<String, dynamic>);
    await _persist(pair);
    return pair;
  }

  Future<TokenPair> google({required String idToken}) async {
    final dynamic data = await _api.post('/auth/google', body: {'id_token': idToken});
    final TokenPair pair = TokenPair.fromJson(data as Map<String, dynamic>);
    await _persist(pair);
    return pair;
  }

  Future<UserDto> me() async {
    final dynamic data = await _api.get('/users/me');
    return UserDto.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> hasToken() async {
    final String? t = await _storage.read(key: kAccessTokenKey);
    return t != null && t.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
  }

  Future<void> _persist(TokenPair pair) async {
    await _storage.write(key: kAccessTokenKey, value: pair.accessToken);
    await _storage.write(key: kRefreshTokenKey, value: pair.refreshToken);
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => AuthRepository(ref.read(apiClientProvider), ref.read(secureStorageProvider)),
);
