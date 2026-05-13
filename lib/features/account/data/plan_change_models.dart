/// v91 — Dart models for the v87 subscriber-driven plan-change flow.
///
/// These mirror the JSON shape of `subscriber_plan_change.PreviewResult`
/// and `subscriber_plan_change.ConfirmResult` on the backend. The
/// policy fields (`policy_kind`, `is_eligible`, `is_recommended`,
/// `eligibility_reason`) are surfaced explicitly so the screen can
/// branch on them without inspecting both scenarios.

class PlanChangeScenarioExtra {
  PlanChangeScenarioExtra({
    required this.freeTargetDays,
    required this.targetPerDayPrice,
    required this.daysDeltaVsRemaining,
  });

  factory PlanChangeScenarioExtra.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PlanChangeScenarioExtra(
        freeTargetDays: null,
        targetPerDayPrice: null,
        daysDeltaVsRemaining: null,
      );
    }
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    double? dOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String && v.isNotEmpty) return double.tryParse(v);
      return null;
    }

    return PlanChangeScenarioExtra(
      freeTargetDays: iOrNull(json['free_target_days']),
      targetPerDayPrice: dOrNull(json['target_per_day_price']),
      daysDeltaVsRemaining: iOrNull(json['days_delta_vs_remaining']),
    );
  }

  final int? freeTargetDays;
  final double? targetPerDayPrice;
  final int? daysDeltaVsRemaining;
}

class PlanChangeScenario {
  PlanChangeScenario({
    required this.mode,
    required this.labelAr,
    required this.labelEn,
    required this.remainingDays,
    required this.targetDays,
    required this.cycleDaysCurrent,
    required this.cycleDaysTarget,
    required this.currentPlanPrice,
    required this.targetPlanPrice,
    required this.currentRemainingValue,
    required this.targetRemainingValue,
    required this.amount,
    required this.currency,
    required this.summaryAr,
    required this.summaryEn,
    required this.policyKind,
    required this.isEligible,
    required this.isRecommended,
    required this.eligibilityReason,
    required this.extra,
  });

  factory PlanChangeScenario.fromJson(Map<String, dynamic> json) {
    int iOrZero(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double dOrZero(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return PlanChangeScenario(
      mode: (json['mode'] ?? '').toString(),
      labelAr: (json['label_ar'] ?? '').toString(),
      labelEn: (json['label_en'] ?? '').toString(),
      remainingDays: iOrZero(json['remaining_days']),
      targetDays: iOrZero(json['target_days']),
      cycleDaysCurrent: iOrZero(json['cycle_days_current']),
      cycleDaysTarget: iOrZero(json['cycle_days_target']),
      currentPlanPrice: dOrZero(json['current_plan_price']),
      targetPlanPrice: dOrZero(json['target_plan_price']),
      currentRemainingValue: dOrZero(json['current_remaining_value']),
      targetRemainingValue: dOrZero(json['target_remaining_value']),
      amount: dOrZero(json['amount']),
      currency: (json['currency'] ?? 'USD').toString(),
      summaryAr: (json['summary_ar'] ?? '').toString(),
      summaryEn: (json['summary_en'] ?? '').toString(),
      policyKind: (json['policy_kind'] ?? 'lateral').toString(),
      isEligible: json['is_eligible'] == true,
      isRecommended: json['is_recommended'] == true,
      eligibilityReason: (json['eligibility_reason'] ?? 'ok').toString(),
      extra: PlanChangeScenarioExtra.fromJson(
        (json['extra'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  final String mode; // 'same_duration' | 'reduced_days'
  final String labelAr;
  final String labelEn;
  final int remainingDays;
  final int targetDays;
  final int cycleDaysCurrent;
  final int cycleDaysTarget;
  final double currentPlanPrice;
  final double targetPlanPrice;
  final double currentRemainingValue;
  final double targetRemainingValue;
  final double amount;
  final String currency;
  final String summaryAr;
  final String summaryEn;
  final String policyKind; // 'upgrade' | 'downgrade' | 'lateral'
  final bool isEligible;
  final bool isRecommended;
  final String eligibilityReason;
  final PlanChangeScenarioExtra extra;
}

class PlanChangePreview {
  PlanChangePreview({
    required this.targetPlanId,
    required this.targetPlanLabel,
    required this.currentPlanId,
    required this.currentPlanLabel,
    required this.remainingDays,
    required this.currency,
    required this.sameDuration,
    required this.reducedDays,
    required this.canApplyDirectly,
    required this.blockedReason,
    required this.policyKind,
  });

  factory PlanChangePreview.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    int iOrZero(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return PlanChangePreview(
      targetPlanId: iOrZero(json['target_plan_id']),
      targetPlanLabel: (json['target_plan_label'] ?? '—').toString(),
      currentPlanId: iOrNull(json['current_plan_id']),
      currentPlanLabel: (json['current_plan_label'] ?? '—').toString(),
      remainingDays: iOrZero(json['remaining_days']),
      currency: (json['currency'] ?? 'USD').toString(),
      sameDuration: PlanChangeScenario.fromJson(
        (json['same_duration'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      reducedDays: PlanChangeScenario.fromJson(
        (json['reduced_days'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      canApplyDirectly: json['can_apply_directly'] == true,
      blockedReason: (json['blocked_reason'] as String?)?.trim().isEmpty == true
          ? null
          : (json['blocked_reason'] as String?),
      policyKind: (json['policy_kind'] ?? 'lateral').toString(),
    );
  }

  final int targetPlanId;
  final String targetPlanLabel;
  final int? currentPlanId;
  final String currentPlanLabel;
  final int remainingDays;
  final String currency;
  final PlanChangeScenario sameDuration;
  final PlanChangeScenario reducedDays;
  final bool canApplyDirectly;
  final String? blockedReason;
  final String policyKind; // 'upgrade' | 'downgrade' | 'lateral'

  bool get isBlocked => blockedReason != null && blockedReason!.isNotEmpty;
}

class PlanChangeConfirmResult {
  PlanChangeConfirmResult({
    required this.outcome,
    required this.caseId,
    required this.caseStatus,
    required this.targetPlanId,
    required this.scenarioMode,
    required this.amount,
    required this.currency,
    required this.invoiceReference,
    required this.ledgerEntryId,
    required this.blockedReason,
    required this.extra,
  });

  factory PlanChangeConfirmResult.fromJson(Map<String, dynamic> json) {
    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) return int.tryParse(v);
      return null;
    }

    double dOrZero(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return PlanChangeConfirmResult(
      outcome: (json['outcome'] ?? '').toString(),
      caseId: iOrNull(json['case_id']),
      caseStatus: (json['case_status'] as String?)?.trim(),
      targetPlanId: iOrNull(json['target_plan_id']),
      scenarioMode: (json['scenario_mode'] as String?)?.trim(),
      amount: dOrZero(json['amount']),
      currency: (json['currency'] ?? 'USD').toString(),
      invoiceReference: (json['invoice_reference'] as String?)?.trim(),
      ledgerEntryId: iOrNull(json['ledger_entry_id']),
      blockedReason: (json['blocked_reason'] as String?)?.trim(),
      extra: (json['extra'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  final String outcome; // 'applied' | 'payment_required' | 'blocked'
  final int? caseId;
  final String? caseStatus;
  final int? targetPlanId;
  final String? scenarioMode;
  final double amount;
  final String currency;
  final String? invoiceReference;
  final int? ledgerEntryId;
  final String? blockedReason;
  final Map<String, dynamic> extra;

  bool get isApplied => outcome == 'applied';
  bool get needsPayment => outcome == 'payment_required';
  bool get isBlocked => outcome == 'blocked';
}

class PlanChangeCheckoutSession {
  PlanChangeCheckoutSession({
    required this.url,
    required this.sessionId,
    required this.invoiceReference,
    required this.amount,
    required this.currency,
  });

  factory PlanChangeCheckoutSession.fromJson(Map<String, dynamic> json) {
    double dOrZero(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return PlanChangeCheckoutSession(
      url: (json['url'] ?? '').toString(),
      sessionId: (json['session_id'] ?? '').toString(),
      invoiceReference: (json['invoice_reference'] ?? '').toString(),
      amount: dOrZero(json['amount']),
      currency: (json['currency'] ?? 'USD').toString(),
    );
  }

  final String url;
  final String sessionId;
  final String invoiceReference;
  final double amount;
  final String currency;
}
