import 'package:flutter/material.dart';

/// Shared AppBar refresh action (v61).
///
/// Bundles the IconButton + SnackBar feedback pattern that several
/// screens had hand-rolled inconsistently. The `Builder` wrapper gives
/// the IconButton its own context with access to the surrounding
/// `ScaffoldMessenger`, so screens can drop one of these into `actions:`
/// without the snackbar plumbing.
class AppRefreshButton extends StatelessWidget {
  const AppRefreshButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'تحديث',
    this.message = 'جارٍ التحديث...',
  });

  final VoidCallback onPressed;
  final String tooltip;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => IconButton(
        tooltip: tooltip,
        icon: const Icon(Icons.refresh),
        onPressed: () {
          onPressed();
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(message),
              ),
            );
        },
      ),
    );
  }
}
