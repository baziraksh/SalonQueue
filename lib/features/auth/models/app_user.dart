/// Application roles — authoritative source is the `profiles.role` column
/// (database), NOT the selected login type in the UI.
enum AppRole {
  customer,
  salonOwner;

  bool get isCustomer => this == AppRole.customer;
  bool get isSalonOwner => this == AppRole.salonOwner;

  /// Parses a string from the DB (`'CUSTOMER'` / `'SALON_OWNER'`).
  static AppRole fromDb(String? name) {
    return switch (name) {
      'SALON_OWNER' => AppRole.salonOwner,
      _ => AppRole.customer, // Default / safety
    };
  }

  /// Serializes to the DB string format.
  String get dbName => switch (this) {
    AppRole.customer => 'CUSTOMER',
    AppRole.salonOwner => 'SALON_OWNER',
  };
}

/// Represents the authenticated application user.
class AppUser {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final AppRole role;

  const AppUser({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = AppRole.customer,
  });

  bool get isAuthenticated => true;

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    AppRole? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }

  @override
  String toString() => 'AppUser(id: $id, role: $role, fullName: $fullName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Auth state change types (mirrors what the UI cares about).
enum AuthStatus {
  /// Initial state - checking for existing session.
  checking,

  /// A session exists (or has just been created).
  authenticated,

  /// No session (logged out, or session expired).
  unauthenticated,
}