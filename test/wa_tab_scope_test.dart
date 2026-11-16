import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/widgets/wa_tab_scope.dart';

// Reads the scope the way a tab screen does and records what it saw.
class _Probe extends StatefulWidget {
  const _Probe(this.seen);

  final List<bool> seen;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.seen.add(WaTabScope.isActive(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('a screen outside any tab counts as visible', (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(_Probe(seen));
    expect(seen, [true]);
  });

  testWidgets('a hidden tab is told it is inactive, then active again', (
    tester,
  ) async {
    final seen = <bool>[];
    Widget host(bool active) => WaTabScope(active: active, child: _Probe(seen));

    await tester.pumpWidget(host(true));
    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));

    expect(seen, [true, false, true]);
  });
}
