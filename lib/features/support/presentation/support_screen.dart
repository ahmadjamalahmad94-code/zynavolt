import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Placeholder for support inbox / threads.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الدعم')),
      body: const SafeArea(
        child: AppEmptyState(
          icon: Icons.support_agent_outlined,
          title: 'الدعم قيد التحضير',
          subtitle:
              'سيتم تحميل البيانات من واجهات SolarDeye API لاحقاً عبر /api/mobile/support.',
        ),
      ),
    );
  }
}
