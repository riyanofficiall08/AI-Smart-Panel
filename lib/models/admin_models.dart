DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.expiredUsers,
    required this.disabledUsers,
    required this.unusedTokens,
    required this.requestsToday,
    required this.errorsToday,
    required this.requests7d,
    required this.openaiConfigured,
  });
  final int totalUsers,
      activeUsers,
      expiredUsers,
      disabledUsers,
      unusedTokens,
      requestsToday,
      errorsToday,
      requests7d;
  final bool openaiConfigured;

  factory AdminStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return AdminStats(
      totalUsers: n('total_users'),
      activeUsers: n('active_users'),
      expiredUsers: n('expired_users'),
      disabledUsers: n('disabled_users'),
      unusedTokens: n('unused_tokens'),
      requestsToday: n('requests_today'),
      errorsToday: n('errors_today'),
      requests7d: n('requests_7d'),
      openaiConfigured: j['openai_configured'] as bool? ?? false,
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isActive,
    required this.expiresAt,
    required this.dailyLimit,
    required this.state,
    required this.usedToday,
    required this.createdAt,
  });
  final String id, username, state;
  final String? displayName;
  final bool isActive;
  final DateTime? expiresAt;
  final int? dailyLimit;
  final int usedToday;
  final DateTime? createdAt;

  String get stateLabel => switch (state) {
    'active' => 'Aktif',
    'expired' => 'Kedaluwarsa',
    'no_license' => 'Tanpa lisensi',
    'disabled' => 'Nonaktif',
    _ => state,
  };

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as String,
    username: j['username'] as String,
    displayName: j['display_name'] as String?,
    isActive: j['is_active'] as bool? ?? true,
    expiresAt: _dt(j['expires_at']),
    dailyLimit: (j['daily_limit'] as num?)?.toInt(),
    state: j['state'] as String? ?? 'no_license',
    usedToday: (j['used_today'] as num?)?.toInt() ?? 0,
    createdAt: _dt(j['created_at']),
  );
}

class LicenseRow {
  const LicenseRow({
    required this.id,
    required this.hint,
    required this.days,
    required this.status,
    required this.createdAt,
    required this.redeemedAt,
    required this.username,
  });
  final String id, hint, status;
  final int days;
  final DateTime? createdAt, redeemedAt;
  final String? username;

  String get statusLabel => switch (status) {
    'unused' => 'Belum dipakai',
    'redeemed' => 'Terpakai',
    _ => 'Dicabut',
  };

  factory LicenseRow.fromJson(Map<String, dynamic> j) => LicenseRow(
    id: j['id'] as String,
    hint: j['token_hint'] as String? ?? '????',
    days: (j['duration_days'] as num).toInt(),
    status: j['status'] as String,
    createdAt: _dt(j['created_at']),
    redeemedAt: _dt(j['redeemed_at']),
    username: j['username'] as String?,
  );
}

class UsageLog {
  const UsageLog({
    required this.id,
    required this.username,
    required this.action,
    required this.status,
    required this.mode,
    required this.model,
    required this.latencyMs,
    required this.detail,
    required this.createdAt,
  });
  final int id;
  final String? username, mode, model, detail;
  final String action, status;
  final int? latencyMs;
  final DateTime? createdAt;

  factory UsageLog.fromJson(Map<String, dynamic> j) => UsageLog(
    id: (j['id'] as num).toInt(),
    username: j['username'] as String?,
    action: j['action'] as String? ?? '',
    status: j['status'] as String? ?? '',
    mode: j['mode'] as String?,
    model: j['model'] as String?,
    latencyMs: (j['latency_ms'] as num?)?.toInt(),
    detail: j['detail'] as String?,
    createdAt: _dt(j['created_at']),
  );
}

class GlobalSettings {
  const GlobalSettings({
    required this.fast,
    required this.accurate,
    required this.study,
    required this.dailyLimit,
    required this.rateLimit,
    required this.openaiConfigured,
    required this.openaiHint,
    required this.openaiSource,
    required this.openaiUpdatedAt,
  });
  final String fast, accurate, study, openaiSource;
  final int dailyLimit, rateLimit;
  final bool openaiConfigured;
  final String? openaiHint;
  final DateTime? openaiUpdatedAt;

  factory GlobalSettings.fromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from((j['models'] as Map?) ?? const {});
    return GlobalSettings(
      fast: m['fast'] as String? ?? 'gpt-4o-mini',
      accurate: m['accurate'] as String? ?? 'gpt-4o',
      study: m['study'] as String? ?? 'gpt-4o',
      dailyLimit: (j['daily_limit'] as num?)?.toInt() ?? 100,
      rateLimit: (j['rate_limit_per_minute'] as num?)?.toInt() ?? 6,
      openaiConfigured: j['openai_configured'] as bool? ?? false,
      openaiHint: j['openai_hint'] as String?,
      openaiSource: j['openai_source'] as String? ?? 'none',
      openaiUpdatedAt: _dt(j['openai_updated_at']),
    );
  }
}
