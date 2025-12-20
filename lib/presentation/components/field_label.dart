import 'package:flutter/material.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: Colors.grey[800],
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

