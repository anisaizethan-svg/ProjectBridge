import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  testWidgets(
    'both profile overviews connect details, settings, notifications and role switching on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> tap(String label) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(label),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text(label).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      const channel = MethodChannel('test/profile-redesign-storage');
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
      await tester.pumpWidget(ProjectBridgeApp(storage: storage));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      for (final client in [false, true]) {
        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.tap(find.byTooltip('Notifications'));
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tap(
          client ? 'View Organization Profile' : 'View Professional Profile',
        );
        expect(
          find.text(client ? 'Organization Profile' : 'Professional Profile'),
          findsOneWidget,
        );
        if (client) {
          await tester.scrollUntilVisible(
            find.text('Verification status'),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        expect(
          find.text(client ? 'Verification status' : 'About'),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        for (final label in [
          'Account Settings',
          'Notifications',
          'Notification Settings',
          'Privacy & Safety',
          'Help & Support',
          'About ProjectBridge',
        ]) {
          await tap(label);
          expect(find.byType(AppBar), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tap(client ? 'Organization Information' : 'Personal Information');
        if (client) {
          final name = find.widgetWithText(TextFormField, 'Organization name');
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          await tester.enterText(name, '');
          await tap('Save');
          await tester.scrollUntilVisible(
            find.text('Enter an organization name.'),
            -180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Enter an organization name.'), findsOneWidget);
          await tester.enterText(
            name,
            'A long organization name for the local demo',
          );
          await tap('Save');
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          final saved = await storage.load();
          expect(
            (saved!['profile'] as Map)['clientOrganization'],
            'A long organization name for the local demo',
          );
        } else {
          expect(
            find.widgetWithText(TextFormField, 'Full name'),
            findsOneWidget,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tap(client ? 'Switch to Student Demo' : 'Switch to Client Demo');
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Your professional profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
