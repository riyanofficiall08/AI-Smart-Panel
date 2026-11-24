class AccountStatus {
  const AccountStatus({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.expiresAt,
    required this.mustChangePassword,
    required this.licenseState,
    required this.daysLeft,
    required this.usedToday,
    required this.dailyLimit,
    this.tokenHint,
    this.tokenDays,
    this.tokenStatus,
  });

  final String id;
  final String username;
  final String? displayName;
  final String role; // admin | user
  final bool isActive;
  final DateTime? expiresAt;
  final bool mustChangePassword;
  final String licenseState; // active | expired | no_license | disabled | admin
  final int daysLeft;
  final int usedToday;
  final int dailyLimit;
  final String? tokenHint;
  final int? tokenDays;
  final String? tokenStatus;

  bool get isAdmin => role == 'admin';
  bool get canUseAi => licenseState == 'active' && !mustChangePassword;
  String get shownName => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : username;

  String get stateLabel => switch (licenseState) {
    'active' => 'Aktif',
    'expired' => 'Kedaluwarsa',
    'no_license' => 'Belum ada lisensi',
    'disabled' => 'Dinonaktifkan',
    _ => 'Admin',
  };

  factory AccountStatus.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from(j['profile'] as Map);
    final u = Map<String, dynamic>.from((j['usage'] as Map?) ?? const {});
    final lic = j['license'] is Map
        ? Map<String, dynamic>.from(j['license'] as Map)
        : null;
    return AccountStatus(
      id: p['id'] as String,
      username: p['username'] as String,
      displayName: p['display_name'] as String?,
      role: p['role'] as String,
      isActive: p['is_active'] as bool? ?? true,
      expiresAt: p['expires_at'] == null
          ? null
          : DateTime.parse(p['expires_at'] as String).toLocal(),
      mustChangePassword: p['must_change_password'] as bool? ?? false,
      licenseState: j['license_state'] as String? ?? 'no_license',
      daysLeft: (j['days_left'] as num?)?.toInt() ?? 0,
      usedToday: (u['used_today'] as num?)?.toInt() ?? 0,
      dailyLimit: (u['limit'] as num?)?.toInt() ?? 0,
      tokenHint: lic?['token_hint'] as String?,
      tokenDays: (lic?['duration_days'] as num?)?.toInt(),
      tokenStatus: lic?['status'] as String?,
    );
  }
}
