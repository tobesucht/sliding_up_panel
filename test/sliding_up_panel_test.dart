import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

// The panel slides from a raw pointer listener and decides a gesture's axis
// itself. It used to take the FIRST pointer delta as the verdict — a slow
// vertical swipe starting with a tiny sideways wobble was classified
// horizontal, the panel then ignored the whole gesture over a
// HorizontalScrollableWidget, and the content never scrolled (its scroll is
// snapped back until a vertical slide enables it). The axis is now decided
// from the movement accumulated over the first few pixels.

const _carousel = Key('carousel');

Future<(PanelController, ScrollController)> _pumpOpenPanel(
    WidgetTester tester) async {
  final pc = PanelController();
  final sc = ScrollController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SlidingUpPanel(
        controller: pc,
        scrollController: sc,
        minHeight: 100,
        maxHeight: 500,
        body: const SizedBox.expand(),
        panelBuilder: () => ListView(
          controller: sc,
          children: [
            HorizontalScrollableWidget(
              child: Container(key: _carousel, height: 200, color: Colors.red),
            ),
            for (var i = 0; i < 20; i++) SizedBox(height: 100, child: Text('$i')),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
  pc.open();
  await tester.pumpAndSettle();
  expect(pc.panelPosition, 1.0);
  return (pc, sc);
}

void main() {
  testWidgets(
      'a slow vertical swipe over a HorizontalScrollableWidget scrolls the '
      'content, even when its first delta leans sideways', (tester) async {
    final (_, sc) = await _pumpOpenPanel(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    // The wobble: more horizontal than vertical, well under the slop.
    await gesture.moveBy(const Offset(1.0, -0.6));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(0, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sc.offset, greaterThan(40));
  });

  testWidgets(
      'a horizontal swipe over a HorizontalScrollableWidget leaves the panel '
      'where it is', (tester) async {
    final (pc, sc) = await _pumpOpenPanel(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    for (var i = 0; i < 30; i++) {
      // Sideways with vertical jitter — the case the widget exists for.
      await gesture.moveBy(Offset(-8, i.isEven ? 2 : -2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pc.panelPosition, 1.0);
    expect(sc.offset, 0);
  });
}
