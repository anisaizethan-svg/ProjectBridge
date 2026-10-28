import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

const file = LocalAttachment(
  id: '11111111-1111-4111-8111-111111111111.png',
  name: 'menu.png',
  size: 68,
  mime: 'image/png',
);
const document = LocalAttachment(
  id: '22222222-2222-4222-8222-222222222222.txt',
  name: 'brief.txt',
  size: 20,
  mime: 'text/plain',
);
BridgeProject project() =>
    BridgeProject('Menu', 'Demo Coffee', 'Web', 'A menu project', ['HTML']);
BridgeProject accepted() {
  final p = project();
  p.submitApplication(
    studentId: 'student-daria',
    name: 'Daria',
    studentSkills: ['HTML'],
    introduction: 'I can build an accessible menu for your customers.',
    hours: '5–10 hours/week',
  );
  return p;
}

class FakeFiles implements AttachmentRepository {
  LocalAttachment? selected = file;
  String path = '';
  bool fail = false, viewer = true;
  final sources = <String>[];
  @override
  Future<LocalAttachment?> pick(String source) async {
    sources.add(source);
    return selected;
  }

  @override
  Future<String> resolve(LocalAttachment attachment) async {
    if (fail) throw StateError('missing');
    return path;
  }

  @override
  Future<bool> open(LocalAttachment attachment) async => viewer;
  @override
  Future<void> delete(LocalAttachment attachment) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real events, independent notification preferences, role categories and restart', () async {
    final p = project(),
        chats = DemoChatRepository(),
        settings = SettingsRepository();
    addTearDown(chats.dispose);
    addTearDown(settings.dispose);
    settings.observe([p], chats);
    expect(settings.notices, isEmpty);
    p.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: ['HTML'],
      introduction: 'I can build your accessible project.',
      hours: '5–10 hours/week',
    );
    settings.observe([p], chats);
    expect(settings.notices.single.category, NoticeCategory.applications);
    settings.account('student-daria').notifications['decisions'] = false;
    p.acceptApplication(chats);
    settings.observe([p], chats);
    expect(
      settings.notices.where((n) => n.category == NoticeCategory.decisions),
      isEmpty,
    );
    await chats.sendMessage(
      chatId: chats.chatIdFor(p, ChatKind.direct),
      userId: p.clientId,
      displayName: 'Coffee',
      content: 'Welcome',
      kind: ChatMessageKind.text,
    );
    settings.observe([p], chats);
    expect(settings.notices.last.chatId, chats.chatIdFor(p, ChatKind.direct));
    expect(settings.notices.last.recipient, 'student-daria');
    final count = settings.notices.length;
    settings.observe([p], chats);
    expect(settings.notices.length, count);
    final restored = SettingsRepository()
      ..restore(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
    addTearDown(restored.dispose);
    restored.observe([p], chats);
    expect(restored.notices.length, count);
    expect(
      restored.enabled('student-daria', NoticeCategory.decisions),
      isFalse,
    );
    expect(
      restored.categories(false),
      isNot(contains(NoticeCategory.applications)),
    );
    expect(
      restored.categories(true),
      isNot(contains(NoticeCategory.decisions)),
    );
  });
  test(
    'privacy, contact default, block/unblock and private passports',
    () async {
      final p = accepted(), settings = SettingsRepository();
      final chats = DemoChatRepository()..settings = settings;
      final professional = ProfessionalRepository(projects: () => [p])
        ..settings = settings;
      addTearDown(settings.dispose);
      addTearDown(chats.dispose);
      addTearDown(professional.dispose);
      settings.account('student-daria')
        ..limitedProfile = true
        ..privatePortfolio = true;
      expect(
        settings.canViewProfile(p.clientId, 'student-daria', [p]),
        isFalse,
      );
      expect(
        settings.canViewContact(p.clientId, 'student-daria', [p]),
        isFalse,
      );
      p.acceptApplication(chats);
      expect(settings.canViewProfile(p.clientId, 'student-daria', [p]), isTrue);
      expect(settings.canViewPortfolio(p.clientId, 'student-daria'), isFalse);
      settings.account('student-daria').shareContact = true;
      expect(settings.canViewContact(p.clientId, 'student-daria', [p]), isTrue);
      settings.account('student-daria').showAvailability = false;
      expect(
        settings.canViewAvailability(p.clientId, 'student-daria', [p]),
        isFalse,
      );
      settings.account('student-daria').blocked.add(p.clientId);
      await expectLater(
        chats.sendMessage(
          chatId: chats.chatIdFor(p, ChatKind.direct),
          userId: p.clientId,
          displayName: 'Coffee',
          content: 'Hi',
          kind: ChatMessageKind.text,
        ),
        throwsStateError,
      );
      expect(
        chats.canAccess(
          chats.findThread(chats.chatIdFor(p, ChatKind.direct))!,
          p.clientId,
        ),
        isTrue,
      );
      settings.account('student-daria').blocked.add('student-dias');
      expect(
        () =>
            professional.sendConnectionRequest('student-dias', 'student-daria'),
        throwsStateError,
      );
      settings.account('student-daria').blocked.clear();
      await chats.sendMessage(
        chatId: chats.chatIdFor(p, ChatKind.direct),
        userId: p.clientId,
        displayName: 'Coffee',
        content: 'Hi',
        kind: ChatMessageKind.text,
      );
      expect(
        chats.findThread(chats.chatIdFor(p, ChatKind.direct))!.messages,
        hasLength(1),
      );
    },
  );
  test('attachments check authorization, failure, duplicates and snapshot persistence', () async {
    final p = accepted(), chats = DemoChatRepository(), files = FakeFiles();
    addTearDown(chats.dispose);
    chats.attachments = files;
    Future<void> send(String user) => chats.sendAttachment(
      chatId: chats.chatIdFor(p, ChatKind.direct),
      userId: user,
      displayName: user,
      attachment: file,
      caption: 'Updated menu',
    );
    await expectLater(send('student-daria'), throwsStateError);
    p.acceptApplication(chats);
    await expectLater(send('outsider'), throwsStateError);
    files.fail = true;
    await expectLater(send('student-daria'), throwsStateError);
    final thread = chats.findThread(chats.chatIdFor(p, ChatKind.direct))!;
    expect(thread.messages, isEmpty);
    files.fail = false;
    chats.saveConfirmed = () async => throw StateError('disk full');
    await expectLater(send('student-daria'), throwsStateError);
    expect(thread.messages, isEmpty);
    expect(thread.unread, isEmpty);
    final completer = Completer<void>();
    chats.saveConfirmed = () => completer.future;
    final first = send('student-daria');
    await Future<void>.delayed(Duration.zero);
    await expectLater(send('student-daria'), throwsStateError);
    completer.complete();
    await first;
    expect(thread.messages, hasLength(1));
    final snapshot = jsonDecode(
      jsonEncode(DemoSnapshot.encode([p], chats)),
    ) as Map<String, dynamic>;
    final restored = DemoChatRepository();
    addTearDown(restored.dispose);
    restored.restore(snapshot, DemoSnapshot.projectsFrom(snapshot));
    final restoredThread = restored.findThread(thread.id)!;
    expect(restoredThread.messages.single.attachment!.id, file.id);
    expect(restoredThread.messages.single.content, 'Updated menu');
    expect(
      await restored.watchMessages(thread.id, userId: p.clientId).first,
      hasLength(1),
    );
    expect(
      await restored.watchMessages(thread.id, userId: 'outsider').first,
      isEmpty,
    );
    final other = accepted();
    other.id = 'another-project';
    other.acceptApplication(chats);
    expect(
      await chats
          .watchMessages(
            chats.chatIdFor(other, ChatKind.direct),
            userId: p.clientId,
          )
          .first,
      isEmpty,
    );
  });
  test(
    'native picker gallery/files, cancel, size/type and path rejection',
    () async {
      const channel = MethodChannel('test/attachments');
      Map<String, dynamic>? selection = file.toJson();
      final sources = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'pick') {
              sources.add((call.arguments as Map)['source'] as String);
              return selection;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final files = NativeAttachmentRepository(channel: channel);
      for (final source in ['gallery', 'files']) {
        expect((await files.pick(source))!.id, file.id);
      }
      expect(sources, ['gallery', 'files']);
      selection = null;
      expect(await files.pick('files'), isNull);
      for (final invalid in [
        file.toJson()..['id'] = '../secret.png',
        file.toJson()..['size'] = NativeAttachmentRepository.maxBytes + 1,
        file.toJson()..['mime'] = 'text/plain',
        file.toJson()..['id'] = '11111111-1111-4111-8111-111111111111.exe',
      ]) {
        selection = invalid;
        await expectLater(files.pick('files'), throwsArgumentError);
      }
    },
  );
  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 10 && find.text(text).hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(text).hitTestable().last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'settings navigation, save name/headline and restart preserve account identity',
    (tester) async {
      final photoDirectory = (await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp(
          'bridge-profile-photo',
        );
        await File('${dir.path}/photo.png').writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
          ),
        );
        return dir;
      }))!;
      addTearDown(() => photoDirectory.delete(recursive: true));
      const photoChannel = MethodChannel('projectbridge/attachments');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        photoChannel,
        (call) async => call.method == 'pick'
            ? file.toJson()
            : '${photoDirectory.path}/photo.png',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          photoChannel,
          null,
        ),
      );
      const channel = MethodChannel('test/settings-storage');
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
      await tester.pumpWidget(
        ProjectBridgeApp(storage: DemoStorage(channel: channel)),
      );
      await tap(tester, 'Profile');
      await tester.scrollUntilVisible(
        find.text('Account Settings'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(tester, 'Account Settings');
      await tap(tester, 'Choose profile photo');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Student Renamed',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Professional headline'),
        'Accessible web developer',
      );
      await tap(tester, 'Save changes');
      await tester.scrollUntilVisible(
        find.text('Student Renamed'),
        -300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('Student Renamed'), findsWidgets);
      final snapshot = jsonDecode(disk!) as Map<String, dynamic>;
      expect(
        snapshot['settings']['accounts']['student-daria']['photo']['id'],
        file.id,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProjectBridgeApp(
          storage: DemoStorage(channel: channel),
          snapshot: snapshot,
        ),
      );
      await tap(tester, 'Profile');
      expect(find.text('Student Renamed'), findsWidgets);
      expect(find.text('Accessible web developer'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Switch to Client Demo'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(tester, 'Switch to Client Demo');
      await tap(tester, 'Profile');
      await tap(tester, 'Account Settings');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Coffee Renamed',
      );
      await tap(tester, 'Save changes');
      expect(find.widgetWithText(TextFormField, 'Display name'), findsNothing);
      expect(
        (jsonDecode(disk!) as Map)['profile']['clientOrganization'],
        'Coffee Renamed',
      );
      await tester.scrollUntilVisible(
        find.text('Coffee Renamed'),
        -300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('Coffee Renamed'), findsWidgets);
    },
  );
  testWidgets('privacy hides full profile from unrelated account', (
    tester,
  ) async {
    final repository = ProfessionalRepository(projects: () => []),
        settings = SettingsRepository();
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    repository.settings = settings;
    settings.account('student-daria').limitedProfile = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfessionalProfileBody(
            repository: repository,
            profileId: 'student-daria',
            actorId: 'student-dias',
          ),
        ),
      ),
    );
    expect(find.text('Limited profile'), findsOneWidget);
    expect(find.text('Flutter Developer | UI/UX Enthusiast'), findsNothing);
  });
  testWidgets(
    'notification save, support validation, FAQ and offline support persistence',
    (tester) async {
      final settings = SettingsRepository();
      addTearDown(settings.dispose);
      Map<String, dynamic>? saved;
      settings.save = () async {
        saved =
            jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationSettingsScreen(
                      repository: settings,
                      accountId: 'student-daria',
                      client: false,
                    ),
                  ),
                ),
                child: const Text('Open preferences'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Open preferences');
      await tap(tester, 'New project messages');
      await tap(tester, 'Save preferences');
      expect(
        settings.enabled('student-daria', NoticeCategory.messages),
        isFalse,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HelpAboutScreen(
            repository: settings,
            accountId: 'student-daria',
          ),
        ),
      );
      await tap(tester, 'How do project chats work?');
      expect(
        find.textContaining('Acceptance unlocks the shared project chat.'),
        findsOneWidget,
      );
      await tap(tester, 'Report a problem');
      await tap(tester, 'Submit report');
      expect(
        find.text('Add a subject of at least three characters.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Subject'),
        'Cannot open menu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'The menu project link does not open on my device.',
      );
      await tap(tester, 'Submit report');
      expect(saved!['reports'], hasLength(1));
      expect(settings.supportReports.single['status'], 'Saved on this device');
      final restored = SettingsRepository()..restore(saved);
      addTearDown(restored.dispose);
      expect(restored.supportReports.single['subject'], 'Cannot open menu');
    },
  );
  testWidgets(
    'paperclip preview sends image, other role views image and document gracefully',
    (tester) async {
      final directory = (await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'bridge-attachment-test',
        );
        await File('${directory.path}/menu.png').writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
          ),
        );
        return directory;
      }))!;
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/menu.png');
      final files = FakeFiles()..path = image.path;
      final p = accepted(), chats = DemoChatRepository()..attachments = files;
      addTearDown(chats.dispose);
      p.acceptApplication(chats);
      final id = chats.chatIdFor(p, ChatKind.direct);
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectChatScreen(
            repository: chats,
            chatId: id,
            userId: p.clientId,
            displayName: 'Coffee',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Attach image or document'));
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsNothing);
      expect(find.text('Take Photo'), findsNothing);
      expect(find.text('Files'), findsOneWidget);
      await tap(tester, 'Gallery');
      expect(find.text('Send attachment'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextField, 'Caption (optional)'),
        'Updated design',
      );
      await tap(tester, 'Send attachment');
      expect(files.sources, ['gallery']);
      expect(chats.findThread(id)!.messages.single.attachment!.id, file.id);
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
      expect(find.text('Updated design'), findsOneWidget);
      await tester.tap(find.byType(AttachmentTile));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      files.selected = document;
      files.viewer = false;
      await tester.tap(find.byTooltip('Attach image or document'));
      await tester.pumpAndSettle();
      await tap(tester, 'Files');
      await tap(tester, 'Send attachment');
      expect(chats.findThread(id)!.messages, hasLength(2));
      ScaffoldMessenger.of(tester.element(find.byType(ProjectChatScreen)))
          .clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AttachmentTile && w.attachment.id == document.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No compatible viewer is installed.'),
        findsOneWidget,
      );
      final snapshot = jsonDecode(
        jsonEncode(DemoSnapshot.encode([p], chats)),
      ) as Map<String, dynamic>;
      await tester.pumpWidget(const SizedBox());
      final restored = DemoChatRepository()
        ..attachments = files
        ..restore(snapshot, DemoSnapshot.projectsFrom(snapshot));
      addTearDown(restored.dispose);
      expect(restored.findThread(id)!.messages.map((m) => m.attachment!.id), [
        file.id,
        document.id,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectChatScreen(
            repository: restored,
            chatId: id,
            userId: 'student-daria',
            displayName: 'Daria',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated design'), findsOneWidget);
      expect(find.byType(AttachmentTile), findsNWidgets(2));
      for (final source in ['Gallery', 'Files']) {
        files.selected = source == 'Gallery' ? file : document;
        await tester.tap(find.byTooltip('Attach image or document'));
        await tester.pumpAndSettle();
        expect(find.text('Camera'), findsNothing);
        await tap(tester, source);
        expect(find.text('Send attachment'), findsWidgets);
        await tap(tester, 'Cancel');
        await tester.pumpAndSettle();
      }
      expect(files.sources, ['gallery', 'files', 'gallery', 'files']);
    },
  );
}
