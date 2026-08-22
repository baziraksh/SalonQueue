import 'package:flutter/widgets.dart';

import 'auth_service.dart';

/// An [InheritedWidget] that provides [AuthService] to the widget tree.
///
/// Use [AuthScope.of(context)] to access the service anywhere below this
/// widget. Rebuilds listeners when [AuthService] notifies.
///
/// Avoids a third-party state-management package for this single scope.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.service, required super.child});

  final AuthService service;

  /// Retrieves the nearest [AuthScope] ancestor and returns its [service].
  ///
  /// If `listen` is true (default), the calling widget rebuilds when
  /// [AuthService] notifies.
  static AuthService of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AuthScope>()
        : context.getInheritedWidgetOfExactType<AuthScope>();
    if (scope == null) {
      throw StateError(
        'AuthScope not found. Wrap your app with AuthScope in main.dart.',
      );
    }
    return scope.service;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) => oldWidget.service != service;
}
