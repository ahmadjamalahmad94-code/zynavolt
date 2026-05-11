import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solardeye_mobile/app/app_theme.dart';
import 'package:solardeye_mobile/core/api/api_exception.dart';
import 'package:solardeye_mobile/core/widgets/app_empty_state.dart';
import 'package:solardeye_mobile/core/widgets/app_error_state.dart';
import 'package:solardeye_mobile/core/widgets/app_loading.dart';

void main() {
  testWidgets('AppLoading shows the message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: AppLoading(message: 'جارٍ التحميل...')),
    ));
    expect(find.text('جارٍ التحميل...'), findsOneWidget);
  });

  testWidgets('AppEmptyState shows title + subtitle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: AppEmptyState(
          title: 'لا توجد بيانات',
          subtitle: 'لم يتم تحميل أي عناصر بعد.',
        ),
      ),
    ));
    expect(find.text('لا توجد بيانات'), findsOneWidget);
    expect(find.text('لم يتم تحميل أي عناصر بعد.'), findsOneWidget);
  });

  testWidgets('AppErrorState surfaces the ApiException message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AppErrorState(
          error: ApiException(
            message: 'تعذّر الاتصال بالخادم.',
            kind: ApiErrorKind.network,
          ),
        ),
      ),
    ));
    expect(find.text('تعذّر الاتصال بالخادم.'), findsOneWidget);
  });
}
