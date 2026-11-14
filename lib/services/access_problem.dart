import 'package:flutter/material.dart';

import 'api_service.dart';

/// Why a call was refused for reasons other than "something broke".
enum AccessKind {
  /// This team member lacks the permission (plain 403, no plan code).
  permission,

  /// The plan has ended (plan_required).
  planEnded,

  /// The plan does not include this feature (feature_not_included).
  notInPlan,
}

/// A refusal the user should read as "not allowed", with a message that never
/// points at buying (the app does not sell anything on any platform).
class AccessProblem {
  const AccessProblem(this.kind, this.title, this.text, this.icon);

  final AccessKind kind;
  final String title;
  final String text;
  final IconData icon;
}

/// Null when [error] is an ordinary failure (offline, server, validation).
AccessProblem? accessProblem(Object error) {
  final e = friendlyException(error);
  if (e.isPlanRequired) {
    return const AccessProblem(
      AccessKind.planEnded,
      'Your plan is not active',
      'This account has no active plan right now, so this is switched off.',
      Icons.lock_clock_rounded,
    );
  }
  if (e.isFeatureLocked) {
    return const AccessProblem(
      AccessKind.notInPlan,
      'Not part of your plan',
      'This feature is not included in your current plan.',
      Icons.workspace_premium_outlined,
    );
  }
  if (e.statusCode == 403) {
    return const AccessProblem(
      AccessKind.permission,
      'You do not have access',
      'Your role does not allow this. Ask the account owner to give you access.',
      Icons.lock_outline_rounded,
    );
  }
  return null;
}

/// One line for a snack bar or sheet notice: the access wording when the call
/// was refused for access, otherwise the usual friendly message.
String errorLine(Object error) =>
    accessProblem(error)?.text ?? friendlyException(error).message;
