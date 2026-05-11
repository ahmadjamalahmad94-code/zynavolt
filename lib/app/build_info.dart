/// Single source of truth for the visible "what build is this" label.
///
/// Every commit in the v81→v90 product/visual block updates this constant
/// so the user can confirm at a glance which build is running on their
/// device. It's surfaced calmly in:
///   * App Settings → app-info card
///   * More tab → "حول التطبيق" card
///
/// Do not hard-code the value at call sites — always reference
/// [BuildInfo.label].
class BuildInfo {
  const BuildInfo._();

  /// Short, human-readable build label. Format: `vNN-short-kebab-summary`.
  static const String label = 'v94-notifications-feed-fix';
}
