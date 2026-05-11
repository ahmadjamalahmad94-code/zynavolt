import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Placeholder for the notifications feed (v37 ships infrastructure only).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الإشعارات')),
      body: const SafeArea(
        child: AppEmptyState(
          icon: Icons.notifications_none_outlined,
          title: 'الإشعارات قيد التحضير',
          subtitle:
              'سيتم تحميل البيانات من واجهات SolarDeye API لاحقاً. ملاحظة: إعدادات الإشعارات حالياً عامة على مستوى الحساب، وليست لكل جهاز.',
        ),
      ),
    );
  }
}
