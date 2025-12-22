import 'package:flutter/material.dart';

import '../app_theme.dart';

Future<T?> showCustomDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  required Widget child,
}) async {
  return showDialog<T>(
    barrierDismissible: barrierDismissible,
    context: context,
    barrierColor: AppTheme.secoundColor.withAlpha(51),
    builder: (context) => PopScope(
      canPop: barrierDismissible,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: ScrollConfiguration(
                behavior: NoGlowBehavior(),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
