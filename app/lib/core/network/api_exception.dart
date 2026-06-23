import 'dart:io';

import 'package:dio/dio.dart';

/// Normalized exception thrown by API client for UI to consume.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  factory ApiException.fromDio(DioException e) {
    final int? code = e.response?.statusCode;
    final dynamic data = e.response?.data;
    String msg;
    if (data is Map && data['detail'] is String) {
      msg = data['detail'] as String;
    } else if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.error is SocketException) {
      msg = 'No internet connection';
    } else if (code != null) {
      msg = 'Server error ($code)';
    } else {
      msg = e.message ?? 'Unknown error';
    }
    return ApiException(msg, statusCode: code, data: data);
  }

  /// Clean message suitable for display in UI (no class-name prefix).
  String get userMessage => message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
