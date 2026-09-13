@TestOn('browser')
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/shared/widgets/app_network_image.dart';

// A deterministic opaque orange PNG; no external API or credentials needed.
const photo =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9h'
    'AAAAGUlEQVR4nGN45qbxnxLMMGrAqAGjBgwXAwDMWFMfsUDQ0QAAAABJRU5ErkJggg==';

Future<void> waitForPhoto(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (tester
        .widgetList<RawImage>(find.byType(RawImage))
        .any((w) => w.image != null)) {
      return;
    }
  }
  fail('Photo did not decode');
}

Future<void> expectOrange(ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(bytes, isNotNull);
  final offset = (image.width * (image.height ~/ 2) + image.width ~/ 2) * 4;
  expect(bytes!.getUint8(offset), closeTo(230, 2));
  expect(bytes.getUint8(offset + 1), closeTo(70, 2));
  expect(bytes.getUint8(offset + 2), closeTo(40, 2));
  expect(bytes.getUint8(offset + 3), 255);
}

void main() {
  testWidgets('photo remains colored after route return and cache eviction', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const SizedBox(
                width: 80,
                height: 80,
                child: AppNetworkImage(imageUrl: photo),
              ),
            ),
          ),
        ),
      ),
    );
    await waitForPhoto(tester);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final screenshot = await boundary.toImage();
        await expectOrange(screenshot);
        screenshot.dispose();
      });
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpAndSettle();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await waitForPhoto(tester);
    }

    // Retain a recorded picture while releasing ALL source image handles.
    // This is the Flutter 3.47 HTML-codec regression, independent of navigation.
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImage(raw.image!, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final retainedImage = await picture.toImage(16, 16);
      await expectOrange(retainedImage);
      retainedImage.dispose();
    });
    picture.dispose();
  });
}
