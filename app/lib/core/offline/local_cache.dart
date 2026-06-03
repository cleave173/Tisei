import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Persistent key-value cache backed by SQLite.
/// Used by [CacheInterceptor] to store API GET responses for offline use.
class LocalCache {
  LocalCache._(this._db);
  final Database _db;

  static LocalCache? _instance;

  static Future<LocalCache> get instance async {
    if (_instance != null) return _instance!;
    final String dbPath = p.join(await getDatabasesPath(), 'tisei_cache.db');
    final Database db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int _) async {
        await db.execute('''
          CREATE TABLE cache (
            key    TEXT    PRIMARY KEY,
            data   TEXT    NOT NULL,
            exp_at INTEGER NOT NULL
          )
        ''');
      },
    );
    _instance = LocalCache._(db);
    return _instance!;
  }

  /// Store [data] under [key] for [ttl] duration.
  Future<void> put(
    String key,
    dynamic data, {
    Duration ttl = const Duration(days: 30),
  }) async {
    final int exp = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await _db.insert(
      'cache',
      <String, Object>{'key': key, 'data': jsonEncode(data), 'exp_at': exp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Return cached value for [key], or null if missing / expired.
  Future<dynamic> get(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'cache',
      where: 'key = ? AND exp_at > ?',
      whereArgs: <Object>[key, DateTime.now().millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String);
  }

  /// Return cached value even if expired. Useful when the network fails and
  /// showing older learning content is better than an empty screen.
  Future<dynamic> getStale(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'cache',
      where: 'key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String);
  }

  Future<void> invalidate(String key) async =>
      _db.delete('cache', where: 'key = ?', whereArgs: <Object>[key]);

  Future<void> clear() async => _db.delete('cache');
}

final FutureProvider<LocalCache> localCacheProvider =
    FutureProvider<LocalCache>((Ref _) => LocalCache.instance);
