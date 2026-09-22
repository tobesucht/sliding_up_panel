import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

// `width` is the width of the CONTENT layers; the sheet itself (colour,
// radius, shadow) fills the box the panel is laid out in. The header and the
// footer span the sheet regardless of the width — an app that hands them a
// narrower child does not get a strip of bare sheet beside them
// (tobesucht/sliding_up_panel#2, found in location-science/auxplore#1025).

const _sheet = Key('sheet-content');
const _header = Key('header');
const _footer = Key('footer');

Future<void> _pump(WidgetTester tester, {double? width}) async {
  await tester.binding.setSurfaceSize(const Size(800, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final pc = PanelController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SlidingUpPanel(
        controller: pc,
        minHeight: 100,
        maxHeight: 500,
        width: width,
        header: Container(key: _header, height: 40, color: Colors.red),
        footer: Container(key: _footer, height: 40, color: Colors.blue),
        panelBuilder: () => Container(key: _sheet, color: Colors.green),
      ),
    ),
  ));
  await tester.pump();
  pc.open();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a width everything is as wide as the box',
      (tester) async {
    await _pump(tester);
    expect(tester.getRect(find.byKey(_sheet)).width, 800);
    expect(tester.getRect(find.byKey(_header)).width, 800);
    expect(tester.getRect(find.byKey(_footer)).width, 800);
  });

  testWidgets('a narrower width narrows the content only; header and footer '
      'still span the sheet', (tester) async {
    await _pump(tester, width: 300);
    expect(tester.getRect(find.byKey(_sheet)).width, 300);
    final header = tester.getRect(find.byKey(_header));
    final footer = tester.getRect(find.byKey(_footer));
    expect(header.left, 0);
    expect(header.width, 800);
    expect(footer.left, 0);
    expect(footer.width, 800);
  });
}
