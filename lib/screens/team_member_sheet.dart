import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/team_models.dart';
import '../services/access_problem.dart';
import '../services/team_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// What is wrong with the form, or null. A new person needs a name, an email
/// and a password of at least 8 characters. When editing, the password may be
/// left empty (it then stays as it was) but not be too short.
String? teamMemberProblem({
  required bool isNew,
  required String name,
  required String email,
  required String password,
}) {
  if (name.trim().isEmpty) return 'Write the person\'s name.';
  if (isNew) {
    final e = email.trim();
    if (e.isEmpty || !e.contains('@') || !e.contains('.')) {
      return 'Write a valid email address.';
    }
  }
  if (isNew && password.isEmpty) return 'Choose a password.';
  if (password.isNotEmpty && password.length < 8) {
    return 'The password must be at least 8 characters.';
  }
  return null;
}

/// Adds a person (as an agent) or edits one: name, a new password, and which
/// features an agent can use. Pops with a message when something was saved.
class TeamMemberSheet extends StatefulWidget {
  const TeamMemberSheet({super.key, required this.features, this.member});

  /// Everything that can be ticked (from GET /team).
  final List<TeamFeature> features;

  /// Null to add someone new.
  final TeamMember? member;

  @override
  State<TeamMemberSheet> createState() => _TeamMemberSheetState();
}

class _TeamMemberSheetState extends State<TeamMemberSheet> {
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _email = TextEditingController(text: widget.member?.email ?? '');
  final _password = TextEditingController();
  late final Set<String> _ticked = {...?widget.member?.features};
  bool _busy = false;
  bool _showPassword = false;
  String? _notice;

  bool get _isNew => widget.member == null;
  bool get _isAdmin => widget.member?.isAdmin ?? false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = teamMemberProblem(
      isNew: _isNew,
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    // Keep the catalog order so the server sees a stable list.
    final features = [
      for (final f in widget.features)
        if (_ticked.contains(f.key)) f.key,
    ];
    try {
      if (_isNew) {
        await TeamService.create(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          features: features,
        );
      } else {
        await TeamService.update(
          widget.member!.id,
          name: _name.text.trim(),
          password: _password.text,
          // An Admin has full access: there is no list to change.
          features: _isAdmin ? null : features,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(_isNew ? 'Agent added.' : 'Changes saved.');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _ticked.length == widget.features.length;
    return AppSheet(
      title: _isNew ? 'Add an agent' : 'Edit ${widget.member!.name}',
      subtitle: _isNew
          ? 'An agent signs in with this email and password and only sees '
                'what you tick.'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            // The email is the person's sign-in and cannot be changed here.
            enabled: !_busy && _isNew,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: waInputDecoration(
              'Email',
              helper: _isNew ? null : 'The email cannot be changed.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: !_showPassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration:
                waInputDecoration(
                  _isNew ? 'Password' : 'New password (optional)',
                  helper: _isNew
                      ? 'At least 8 characters. Tell the person to change it '
                            'after signing in.'
                      : 'Leave empty to keep the current password.',
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            Text(
              'Admins can use everything in the business, so there is nothing '
              'to tick.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: muted,
                height: 1.4,
              ),
            ),
          ] else if (widget.features.isNotEmpty) ...[
            SectionTitle(
              'What this agent can use',
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        if (all) {
                          _ticked.clear();
                        } else {
                          _ticked.addAll(widget.features.map((f) => f.key));
                        }
                      }),
                child: Text(all ? 'Clear all' : 'Tick all'),
              ),
            ),
            for (final f in widget.features)
              CheckboxListTile(
                value: _ticked.contains(f.key),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  f.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _ticked.add(f.key);
                        } else {
                          _ticked.remove(f.key);
                        }
                      }),
              ),
          ],
          const SizedBox(height: 12),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Text(_isNew ? 'Add agent' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
