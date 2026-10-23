import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagerx_example/main.dart';

void main() {
  testWidgets('feed loads the first page', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    // Wait for the fake API delay.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Item #1'), findsOneWidget);
    expect(find.text('Feed (20 of 100)'), findsOneWidget);
  });

  testWidgets('chat opens mid-conversation', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Page 5 of 15-message pages starts at message 76.
    expect(find.text('Message 76'), findsOneWidget);
    expect(find.text('Message 1'), findsNothing);
  });

  testWidgets('feed appends, fails on page 3, then retries', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    Future<void> scrollToBottom() async {
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await scrollToBottom(); // loads page 1
    expect(find.text('Feed (40 of 100)'), findsOneWidget);

    await scrollToBottom(); // page 2 fails once
    expect(find.text('Loading more failed — tap to retry'), findsOneWidget);

    await tester.tap(find.text('Loading more failed — tap to retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Feed (60 of 100)'), findsOneWidget);
  });

  testWidgets('chat prepends older messages', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Load older'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Page 4 (messages 61-75) now sits above page 5.
    expect(find.text('Message 61'), findsOneWidget);
  });
}
