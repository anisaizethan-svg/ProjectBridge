import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  testWidgets(
    'Stage 1 snapshot migration preserves identities and messages while saving the full professional profile',
    (tester) async {
      const channel = MethodChannel('test/stage2_persistence');
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
      final p = BridgeProject(
        'Existing project',
        'Demo Coffee',
        'Mobile Development',
        'Existing data',
        ['Flutter'],
      );
      final chats = DemoChatRepository();
      addTearDown(chats.dispose);
      p.submitApplication(
        studentId: 'student-daria',
        name: 'Daria',
        studentSkills: ['Flutter'],
        introduction: 'Hello',
        hours: '5h',
      );
      p.acceptApplication(chats);
      final chatId = chats.chatIdFor(p, ChatKind.direct);
      await chats.sendMessage(
        chatId: chatId,
        userId: p.clientId,
        displayName: 'Demo Coffee',
        content: 'Preserve this real message',
        kind: ChatMessageKind.text,
      );
      final legacy = DemoSnapshot.encode(
        [p],
        chats,
        profile: {
          'studentName': 'Daria',
          'studentSkills': ['Flutter', 'Dart'],
        },
      );
      legacy.remove(
        'professional',
      ); // Real Stage 1 schema, same version and channel.
      final storage = DemoStorage(channel: channel);
      await tester.pumpWidget(
        ProjectBridgeApp(storage: storage, snapshot: legacy),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Professional headline'),
        'Saved professional headline',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City (optional)'),
        'Taraz',
      );
      await tester.scrollUntilVisible(
        find.text('Save changes'),
        350,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final snapshot = await storage.load();
      expect(snapshot!['professional'], isNotNull);
      final restoredProjects = DemoSnapshot.projectsFrom(snapshot);
      expect(restoredProjects.single.id, p.id);
      expect(restoredProjects.single.clientId, p.clientId);
      expect(restoredProjects.single.applicationStatus, 'Accepted');
      final restoredChats = DemoChatRepository()
        ..restore(snapshot, restoredProjects);
      addTearDown(restoredChats.dispose);
      expect(
        restoredChats.findThread(chatId)!.messages.single.content,
        'Preserve this real message',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(ProjectBridgeApp(snapshot: snapshot));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Saved professional headline'), findsOneWidget);
      await tester.ensureVisible(find.text('View Professional Profile'));
      await tester.tap(find.text('View Professional Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Taraz'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
