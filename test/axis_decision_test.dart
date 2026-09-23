import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

// Issue #4: the axis decision from accumulated movement (4777ea4) had no
// tests beyond the two headline cases. These cover the rest of the rule:
// the open-panel verdict at the moment of decision (swipe up scrolls the
// content, swipe down closes the panel) and the probe reset on cancel.

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
      'a slow vertical swipe DOWN over the carousel, content at its top, '
      'closes the panel instead of scrolling', (tester) async {
    final (pc, sc) = await _pumpOpenPanel(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    await gesture.moveBy(const Offset(0.8, 0.5)); // the same wobble, downwards
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 60; i++) {
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sc.offset, 0, reason: 'the content did not scroll');
    expect(pc.panelPosition, lessThan(1.0), reason: 'the panel followed');
  });

  testWidgets(
      'a swipe up scrolls the content and the panel stays open, even when the '
      'first moves were too small to decide', (tester) async {
    final (pc, sc) = await _pumpOpenPanel(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    // Three undecided moves (each under the 6 px decision distance) that
    // together are clearly vertical.
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0.5, -1.5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(0, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sc.offset, greaterThan(40));
    expect(pc.panelPosition, 1.0);
  });

  testWidgets('a cancelled gesture resets the probe: the next gesture is '
      'judged on its own movement', (tester) async {
    final (pc, sc) = await _pumpOpenPanel(tester);
    // Gesture 1: a few vertical pixels, undecided, then cancelled.
    final first = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    await first.moveBy(const Offset(0, -4));
    await tester.pump(const Duration(milliseconds: 16));
    await first.cancel();
    await tester.pumpAndSettle();
    expect(pc.panelPosition, 1.0);
    // While undecided the content may creep a few pixels (documented in
    // the axis probe); it must stay under the decision distance.
    final creep = sc.offset;
    expect(creep, lessThan(6));

    // Gesture 2: a clean horizontal swipe. With the banked vertical
    // movement still counted it could have been judged vertical; it must
    // leave the panel and the content alone.
    final second = await tester.startGesture(tester.getCenter(find.byKey(_carousel)));
    for (var i = 0; i < 30; i++) {
      await second.moveBy(const Offset(-6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pumpAndSettle();
    expect(pc.panelPosition, 1.0);
    expect(sc.offset, lessThanOrEqualTo(creep + 0.001));
  });
}
