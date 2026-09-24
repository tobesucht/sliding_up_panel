import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

// Issue #4: `enableFling` (a2e40bd) and the animated `hide()` / `show()`
// with a snap point (81d46bd) had no tests.

const _sheet = Key('sheet');

Future<PanelController> _pump(WidgetTester tester,
    {bool enableFling = true, double? snapPoint}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final pc = PanelController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SlidingUpPanel(
        controller: pc,
        minHeight: 100,
        maxHeight: 500,
        snapPoint: snapPoint,
        enableFling: enableFling,
        body: const SizedBox.expand(),
        panelBuilder: () => Container(key: _sheet, color: Colors.green),
      ),
    ),
  ));
  await tester.pump();
  return pc;
}

/// A short, fast upward flick on the collapsed panel: 40 px in 40 ms —
/// far above the 365 px/s fling threshold, but only a tenth of the travel,
/// so without a fling the nearest position is still "closed".
Future<void> _flickUp(WidgetTester tester) async {
  // The collapsed sheet shows the top 100 px of its 500 px content; start
  // inside that visible band.
  final start = tester.getTopLeft(find.byKey(_sheet)) + const Offset(200, 50);
  final gesture = await tester.startGesture(start);
  // Test gestures stamp events at time zero unless told otherwise — the
  // velocity tracker then sees no time pass and no fling. Stamp them.
  for (var i = 1; i <= 4; i++) {
    await gesture.moveBy(const Offset(0, -10),
        timeStamp: Duration(milliseconds: 10 * i));
    await tester.pump(const Duration(milliseconds: 10));
  }
  await gesture.up(timeStamp: const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  group('enableFling', () {
    testWidgets('on (default): a fast short flick opens the panel',
        (tester) async {
      final pc = await _pump(tester);
      expect(pc.panelPosition, 0.0);
      await _flickUp(tester);
      expect(pc.panelPosition, 1.0);
    });

    testWidgets('off: the same flick snaps back to the nearest position',
        (tester) async {
      final pc = await _pump(tester, enableFling: false);
      await _flickUp(tester);
      expect(pc.panelPosition, 0.0);
    });
  });

  group('hide / show', () {
    testWidgets('hide animates closed and takes the sheet off screen',
        (tester) async {
      final pc = await _pump(tester);
      pc.open();
      await tester.pumpAndSettle();
      expect(pc.panelPosition, 1.0);

      final done = pc.hide();
      await tester.pumpAndSettle();
      await done;
      expect(pc.isPanelShown, isFalse);
      expect(pc.panelPosition, 0.0);
      expect(find.byKey(_sheet), findsNothing);
    });

    testWidgets('show without a snap point returns to the collapsed position',
        (tester) async {
      final pc = await _pump(tester);
      pc.hide();
      await tester.pumpAndSettle();
      final done = pc.show();
      await tester.pumpAndSettle();
      await done;
      expect(pc.isPanelShown, isTrue);
      expect(pc.panelPosition, 0.0);
      expect(find.byKey(_sheet), findsOneWidget);
    });

    testWidgets('show with a snap point animates to it', (tester) async {
      final pc = await _pump(tester, snapPoint: 0.5);
      pc.hide();
      await tester.pumpAndSettle();
      final done = pc.show();
      await tester.pumpAndSettle();
      await done;
      expect(pc.isPanelShown, isTrue);
      expect(pc.panelPosition, closeTo(0.5, 0.001));
    });
  });
}
