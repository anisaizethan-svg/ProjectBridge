import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  testWidgets(
    'jury scenario publishes, applies, accepts, chats, switches roles and restarts',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('test/jury_storage');
      String? disk;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'save') disk = call.arguments as String;
        return call.method == 'load' ? disk : null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final storage = DemoStorage(channel: channel);
      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> switchTo(String role) async {
        await tap('Profile');
        await tester.scrollUntilVisible(
          find.text('Switch to $role Demo'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tap('Switch to $role Demo');
      }

      await tester.pumpWidget(ProjectBridgeApp(storage: storage));
      await switchTo('Client');
      await tap('Create');
      await tap('Start Manually');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Coffee Shop Digital Menu',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'We need a digital menu website for our coffee shop. Customers should scan a QR code to view drinks, photos, and prices.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'A responsive QR menu with drinks and prices.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Customers need an accessible menu.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(4),
        'A working digital menu website.',
      );
      await tap('Continue');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Web Development, UI/UX Design',
      );
      await tap('Continue');
      await tap('Continue');
      await tap('Publish as Demo Coffee');
      expect(find.text('Create Project · Step 4 of 4'), findsNothing);
      expect(find.text('Coffee Shop Digital Menu'), findsOneWidget);
      await switchTo('Student');
      await tap('Explore');
      await tester.enterText(
        find.byType(TextField).first,
        'Coffee Shop Digital Menu',
      );
      await tester.pumpAndSettle();
      await tap('Coffee Shop Digital Menu');
      await tap('Apply to project');
      await tester.enterText(
        find.byType(TextFormField).first,
        'I would love to build this coffee shop menu.',
      );
      await tester.ensureVisible(find.text('Weekly availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5–10 hours/week').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit application'));
      await tester.pumpAndSettle();
      await tap('Submit application');
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Apply to project'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap('My Projects');
      expect(find.text('Coffee Shop Digital Menu'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      await switchTo('Client');
      await tap('Applicants');
      expect(find.text('Coffee Shop Digital Menu'), findsOneWidget);
      expect(find.text('Daria'), findsOneWidget);
      await tap('View Student Profile');
      expect(find.text('Daria · Profile'), findsOneWidget);
      expect(
        find.textContaining('Weekly availability: 5–10 hours/week'),
        findsOneWidget,
      );
      expect(
        find.textContaining('I would love to build this coffee shop menu.'),
        findsWidgets,
      );
      await tap('Close');
      await tap('Accept');
      await tap('Accept');
      expect(find.text('Accepted'), findsOneWidget);
      await tap('Dashboard');
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daria\nNo messages yet'));
      await tester.pumpAndSettle();
      expect(find.text('👋 Say hi to Daria!'), findsOneWidget);
      const hello = 'Hi Daria! Welcome to our coffee shop project.';
      const reply = "Thank you! I'm excited to work on this project.";
      await tester.enterText(find.byType(TextField), hello);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text(hello), findsOneWidget);
      expect(find.text('👋 Say hi to Daria!'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await switchTo('Student');
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(hello));
      await tester.pumpAndSettle();
      expect(find.text(hello), findsOneWidget);
      await tester.enterText(find.byType(TextField), reply);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await switchTo('Client');
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(reply));
      await tester.pumpAndSettle();
      expect(find.text(reply), findsOneWidget);
      expect(find.text(hello), findsOneWidget);
      final snapshot = await storage.load();
      expect(snapshot, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(ProjectBridgeApp(snapshot: snapshot));
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(reply));
      await tester.pumpAndSettle();
      expect(find.text(hello), findsOneWidget);
      expect(find.text(reply), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
