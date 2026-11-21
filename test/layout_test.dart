import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosimetro/main.dart';

void main() {
  for (final size in const [Size(360, 640), Size(320, 568), Size(412, 915)]) {
    testWidgets('sin desbordes en $size', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const DosimetroApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
