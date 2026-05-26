import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when at least one connectivity type is available.
final StreamProvider<bool> isOnlineProvider = StreamProvider<bool>((Ref ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none));
});

/// Synchronous snapshot helper — returns last known state (defaults to true).
extension IsOnlineX on WidgetRef {
  bool get isOnline => watch(isOnlineProvider).valueOrNull ?? true;
}

Future<bool> checkOnline() async {
  final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
  return result.any((c) => c != ConnectivityResult.none);
}
