import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

BridgeProject coffeeProject() =>
    BridgeProject(
        'Coffee Shop Digital Menu',
        'Demo Coffee',
        'Web Development',
        'Customers scan a QR code to view drinks, photos, and prices.',
        ['Web Development', 'UI/UX Design'],
      )
      ..estimatedTimeline = '4 weeks'
      ..expectedResult = 'A responsive digital menu website.';

bool apply(BridgeProject p) => p.submitApplication(
  studentId: 'student-daria',
  name: 'Daria',
  studentSkills: ['Flutter', 'Dart'],
  introduction: 'I would love to design your digital menu.',
  hours: '5 hours weekly',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full shared workflow restores projects, applications, chats and actual messages', () async {
    final projects = <BridgeProject>[];
    final chats = DemoChatRepository();
    addTearDown(chats.dispose);
    final p = coffeeProject();
    projects.add(p);
    expect(p.lifecycleStatus, 'Published');
    expect(apply(p), isTrue);
    final appliedAt = p.appliedAt;
    expect(apply(p), isFalse);
    expect(p.appliedAt, appliedAt);
    expect(p.applicationStatus, 'Pending');
    expect(await chats.watchChats(p.clientId).first, isEmpty);
    expect(await chats.watchChats('student-daria').first, isEmpty);
    expect(p.acceptApplication(chats), isTrue);
    expect(p.applicationStatus, 'Accepted');
    expect(p.acceptedParticipantIds, ['student-daria']);
    final clientChats = await chats.watchChats(p.clientId).first;
    final studentChats = await chats.watchChats('student-daria').first;
    expect(
      clientChats.map((c) => c.id).toSet(),
      studentChats.map((c) => c.id).toSet(),
    );
    expect(
      clientChats,
      hasLength(2),
    ); // One direct chat and one project team chat.
    expect(p.acceptApplication(chats), isTrue);
    expect(await chats.watchChats(p.clientId).first, hasLength(2));
    final id = chats.chatIdFor(p, ChatKind.direct);
    p.title = 'Renamed menu';
    expect(chats.chatIdFor(p, ChatKind.direct), id);
    final history = <List<ChatMessage>>[];
    final subscription = chats
        .watchMessages(id, userId: 'student-daria')
        .listen(history.add);
    await Future<void>.delayed(Duration.zero);
    await chats.sendMessage(
      chatId: id,
      userId: p.clientId,
      displayName: 'Demo Coffee',
      content: 'Hi Daria! Welcome to our coffee shop project.',
      kind: ChatMessageKind.text,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      history.last.single.content,
      'Hi Daria! Welcome to our coffee shop project.',
    );
    await chats.sendMessage(
      chatId: id,
      userId: 'student-daria',
      displayName: 'Daria',
      content: "Thank you! I'm excited to work on this project.",
      kind: ChatMessageKind.text,
    );
    await Future<void>.delayed(Duration.zero);
    expect(history.last, hasLength(2));
    expect(history.last.last.senderId, 'student-daria');
    await subscription.cancel();

    const channel = MethodChannel('test/projectbridge_storage');
    String? disk;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'save') disk = call.arguments as String;
          if (call.method == 'load') return disk;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final storage = DemoStorage(channel: channel);
    await storage.save(DemoSnapshot.encode(projects, chats));
    final snapshot = await DemoStorage(channel: channel).load();
    final restored = DemoSnapshot.projectsFrom(snapshot!);
    final restoredChats = DemoChatRepository()..restore(snapshot, restored);
    addTearDown(restoredChats.dispose);
    expect(restored.single.id, p.id);
    expect(restored.single.applicationStatus, 'Accepted');
    expect(restored.single.expectedResult, p.expectedResult);
    expect(restored.single.estimatedTimeline, '4 weeks');
    final restoredThread = restoredChats.findThread(id)!;
    expect(
      restoredThread.messages.map((m) => m.content),
      history.last.map((m) => m.content),
    );
    expect(restoredThread.unread[p.clientId], 1);
    expect(restoredThread.createdAt, chats.findThread(id)!.createdAt);
    expect(
      await restoredChats.watchMessages(id, userId: 'student-daria').first,
      hasLength(2),
    );
    expect(
      await restoredChats.watchMessages(id, userId: 'intruder').first,
      isEmpty,
    );
    await restoredChats.markRead(id, p.clientId);
    expect(restoredThread.unread[p.clientId], 0);
  });

  test(
    'pending, rejected, removed and unrelated accounts cannot send',
    () async {
      final chats = DemoChatRepository();
      addTearDown(chats.dispose);
      final p = coffeeProject();
      apply(p);
      final id = chats.chatIdFor(p, ChatKind.direct);
      Future<void> send(String user) => chats.sendMessage(
        chatId: id,
        userId: user,
        displayName: user,
        content: 'Not authorized',
        kind: ChatMessageKind.text,
      );
      await expectLater(send('student-daria'), throwsStateError);
      p.rejectApplication();
      expect(p.applicationStatus, 'Rejected');
      expect(p.acceptApplication(chats), isFalse);
      chats.ensureProjectChats(p);
      expect(await chats.watchChats('student-daria').first, isEmpty);
      await expectLater(send('student-daria'), throwsStateError);
      final accepted = coffeeProject();
      apply(accepted);
      accepted.acceptApplication(chats);
      final acceptedId = chats.chatIdFor(accepted, ChatKind.direct);
      await expectLater(
        chats.sendMessage(
          chatId: acceptedId,
          userId: 'intruder',
          displayName: 'Intruder',
          content: 'No',
          kind: ChatMessageKind.text,
        ),
        throwsStateError,
      );
      accepted.accepted = false;
      accepted.applicationStatus = 'Removed';
      expect(await chats.watchChats('student-daria').first, isEmpty);
      await expectLater(
        chats.sendMessage(
          chatId: acceptedId,
          userId: 'student-daria',
          displayName: 'Daria',
          content: 'No',
          kind: ChatMessageKind.text,
        ),
        throwsStateError,
      );
      // Reaccepting a legitimate application repairs stale thread membership.
      accepted.applicationStatus = 'Pending';
      chats.revokeProjectMember(accepted, 'student-daria');
      accepted.acceptApplication(chats);
      await chats.sendMessage(
        chatId: acceptedId,
        userId: 'student-daria',
        displayName: 'Daria',
        content: 'Authorized again',
        kind: ChatMessageKind.text,
      );
      expect(
        chats.findThread(acceptedId)!.messages.single.content,
        'Authorized again',
      );
    },
  );

  test('same-title projects have distinct stable conversation IDs', () {
    final chats = DemoChatRepository();
    addTearDown(chats.dispose);
    final a = coffeeProject(), b = coffeeProject();
    apply(a);
    apply(b);
    a.acceptApplication(chats);
    b.acceptApplication(chats);
    expect(
      chats.chatIdFor(a, ChatKind.direct),
      isNot(chats.chatIdFor(b, ChatKind.direct)),
    );
    a.title = 'Edited';
    expect(
      chats.findThread(chats.chatIdFor(a, ChatKind.direct))!.project,
      same(a),
    );
  });

  testWidgets(
    'role-specific greeting is a placeholder and disappears after a real send',
    (tester) async {
      final chats = DemoChatRepository();
      addTearDown(chats.dispose);
      final p = coffeeProject();
      apply(p);
      p.acceptApplication(chats);
      final id = chats.chatIdFor(p, ChatKind.direct);
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectChatScreen(
            repository: chats,
            chatId: id,
            userId: p.clientId,
            displayName: 'Demo Coffee',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('👋 Say hi to Daria!'), findsOneWidget);
      expect(chats.findThread(id)!.messages, isEmpty);
      await tester.enterText(find.byType(TextField), 'Hi Daria!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('👋 Say hi to Daria!'), findsNothing);
      expect(find.text('Hi Daria!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectChatScreen(
            repository: chats,
            chatId: id,
            userId: 'student-daria',
            displayName: 'Daria',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hi Daria!'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Thank you!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(chats.findThread(id)!.messages.last.senderId, 'student-daria');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'app restart loads the same accepted project and shared conversations',
    (tester) async {
      final p = coffeeProject();
      apply(p);
      final chats = DemoChatRepository();
      addTearDown(chats.dispose);
      p.acceptApplication(chats);
      final snapshot = jsonDecode(
        jsonEncode(DemoSnapshot.encode([p], chats)),
      ) as Map<String, dynamic>;
      await tester.pumpWidget(ProjectBridgeApp(snapshot: snapshot));
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee Shop Digital Menu'), findsNWidgets(2));
      await tester.tap(find.textContaining('Demo Coffee\nNo messages yet'));
      await tester.pumpAndSettle();
      expect(find.text('👋 Say hi to Demo Coffee!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
