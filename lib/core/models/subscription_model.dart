import 'package:flutter/material.dart';

/// Two plans only:
/// • basic   → Schedule, Documentation, My Patients (core tabs always on)
/// • premium → All features enabled
enum SubTier { basic, premium }

extension SubTierX on SubTier {
  String get label => this == SubTier.premium ? 'Premium' : 'Basic';

  Color get color =>
      this == SubTier.premium ? const Color(0xFFE65100) : const Color(0xFF546E7A);

  Color get bgColor =>
      this == SubTier.premium ? const Color(0xFFFBE9E7) : const Color(0xFFECEFF1);

  IconData get icon =>
      this == SubTier.premium ? Icons.star_rounded : Icons.star_border_rounded;
}

class SubConfig {
  final SubTier tier;
  final bool statistics;
  final bool billing;
  final bool expenses;
  // Account-level settings (managed by admin)
  final bool isEnabled;
  final bool showInSearch;
  final bool allowHomeVisit;
  final DateTime? expiresAt;
  // AI Doctor Assistant settings
  final bool aiEnabled;
  final int  aiMonthlyLimit;

  const SubConfig({
    required this.tier,
    this.statistics = false,
    this.billing    = false,
    this.expenses   = false,
    this.isEnabled    = true,
    this.showInSearch = true,
    this.allowHomeVisit = true,
    this.expiresAt,
    this.aiEnabled      = true,
    this.aiMonthlyLimit = 100,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Account is usable: admin has enabled it and it hasn't expired.
  bool get isActive => isEnabled && !isExpired;

  factory SubConfig.fromMap(Map<String, dynamic> data) {
    final tierStr = (data['subscription'] as String?) ?? 'basic';
    // Map legacy 'pro' → premium
    final tier = tierStr == 'premium' ? SubTier.premium : SubTier.basic;
    final features  = (data['features'] as Map<String, dynamic>?) ?? {};
    final defaults  = SubConfig.defaultsFor(tier);
    final expiresStr = data['expires_at'] as String?;
    return SubConfig(
      tier:         tier,
      statistics:   features['statistics'] as bool? ?? defaults.statistics,
      billing:      features['billing']    as bool? ?? defaults.billing,
      expenses:     features['expenses']   as bool? ?? defaults.expenses,
      isEnabled:    data['is_enabled']    as bool? ?? true,
      showInSearch: data['show_in_search'] as bool? ?? true,
      allowHomeVisit: data['allow_home_visit'] as bool? ?? true,
      expiresAt:    expiresStr != null ? DateTime.parse(expiresStr) : null,
      aiEnabled:      features['ai_enabled']      as bool? ?? true,
      aiMonthlyLimit: (features['ai_monthly_limit'] as num?)?.toInt() ?? 100,
    );
  }

  static SubConfig defaultsFor(SubTier tier) {
    if (tier == SubTier.premium) {
      return const SubConfig(
        tier:       SubTier.premium,
        statistics: true,
        billing:    true,
        expenses:   true,
      );
    }
    // Basic: only core tabs (schedule / documentation / my patients)
    return const SubConfig(tier: SubTier.basic);
  }

  Map<String, dynamic> toFeaturesMap() => {
    'statistics':       statistics,
    'billing':          billing,
    'expenses':         expenses,
    'ai_enabled':       aiEnabled,
    'ai_monthly_limit': aiMonthlyLimit,
  };

  static const _keep = Object();

  SubConfig copyWith({
    SubTier? tier,
    bool? statistics,
    bool? billing,
    bool? expenses,
    bool? isEnabled,
    bool? showInSearch,
    bool? allowHomeVisit,
    Object? expiresAt = _keep,
    bool? aiEnabled,
    int?  aiMonthlyLimit,
  }) =>
      SubConfig(
        tier:         tier         ?? this.tier,
        statistics:   statistics   ?? this.statistics,
        billing:      billing      ?? this.billing,
        expenses:     expenses     ?? this.expenses,
        isEnabled:    isEnabled    ?? this.isEnabled,
        showInSearch: showInSearch ?? this.showInSearch,
        allowHomeVisit: allowHomeVisit ?? this.allowHomeVisit,
        expiresAt: identical(expiresAt, _keep)
            ? this.expiresAt
            : expiresAt as DateTime?,
        aiEnabled:      aiEnabled      ?? this.aiEnabled,
        aiMonthlyLimit: aiMonthlyLimit ?? this.aiMonthlyLimit,
      );

  // Returns true when the given dashboard tab index should be locked.
  // Indices: 3=Statistics, 4=Income/Billing, 5=Expenses
  bool isLocked(int index) {
    if (index == 3) return !statistics;
    if (index == 4) return !billing;
    if (index == 5) return !expenses;
    return false;
  }

  bool featureEnabled(String key) {
    if (key == 'statistics') return statistics;
    if (key == 'billing')    return billing;
    if (key == 'expenses')   return expenses;
    if (key == 'ai_enabled') return aiEnabled;
    return false;
  }
}
