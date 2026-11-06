import 'package:flutter/material.dart';

/// Asks before something goes live on the person's public Google profile.
/// Returns true only when they choose to publish.
Future<bool> confirmPublish(
  BuildContext context, {
  required String what,
  String? where,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Publish this $what?'),
      content: Text(
        where == null || where.isEmpty
            ? 'It goes live on your Google Business Profile right away.'
            : 'It goes live on your Google Business Profile for $where right away.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Publish'),
        ),
      ],
    ),
  );
  return ok == true;
}
