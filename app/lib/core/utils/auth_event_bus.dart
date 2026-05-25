import 'dart:async';

/// Emits an event when the session has expired (both access and refresh tokens
/// are invalid). Listeners should call [AuthController.logout] in response.
class AuthEventBus {
  AuthEventBus._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get onSessionExpired => _controller.stream;

  static void sessionExpired() => _controller.add(null);
}
