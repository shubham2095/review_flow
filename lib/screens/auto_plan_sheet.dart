import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../theme/brand.dart';

/// Asks the AI for a batch of scheduled Google posts. Pops with the server's
/// confirmation message when the plan was created.
class AutoPlanSheet extends StatefulWidget {
  const AutoPlanSheet({super.key, required this.locationId});

  final String? locationId;

  @override
  State<AutoPlanSheet> createState() => _AutoPlanSheetState();
}

class _AutoPlanSheetState extends State<AutoPlanSheet> {
  double _count = 4;
  double _cadence = 3;
  bool _withImages = false;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final res = await GbpService.autoPlan(
        locationId: widget.locationId,
        count: _count.round(),
        cadenceDays: _cadence.round(),
        withImages: _withImages,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        res.message.isNotEmpty ? res.message : '${res.created} posts scheduled.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyException(e).message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'AI content plan',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The AI writes a batch of varied posts for your business and '
              'schedules them for you. Posts go live on their date.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            Text(
              'Number of posts: ${_count.round()}',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
            ),
            Slider(
              value: _count,
              min: 1,
              max: 8,
              divisions: 7,
              label: '${_count.round()}',
              onChanged: _busy ? null : (v) => setState(() => _count = v),
            ),
            Text(
              'One post every ${_cadence.round()} ${_cadence.round() == 1 ? 'day' : 'days'}',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
            ),
            Slider(
              value: _cadence,
              min: 1,
              max: 14,
              divisions: 13,
              label: '${_cadence.round()}',
              onChanged: _busy ? null : (v) => setState(() => _cadence = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create an AI image for each post'),
              subtitle: const Text('Uses extra credits and takes longer'),
              value: _withImages,
              onChanged: _busy ? null : (v) => setState(() => _withImages = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_busy ? 'Creating your plan...' : 'Generate plan'),
            ),
          ],
        ),
      ),
    );
  }
}
