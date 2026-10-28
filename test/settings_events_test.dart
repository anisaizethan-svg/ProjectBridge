import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

BridgeProject project() =>
    BridgeProject('Deadline menu', 'Demo Coffee', 'Web', 'Menu site', ['HTML']);
void main() {
  test('task, feedback, completion and deadline notices reflect real transitions once', () {
    final p = project(),
        chats = DemoChatRepository(),
        settings = SettingsRepository();
    addTearDown(chats.dispose);
    addTearDown(settings.dispose);
    p.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: [],
      introduction: 'I can build your accessible menu project.',
      hours: '5–10 hours/week',
    );
    p.acceptApplication(chats);
    settings.observe([p], chats);
    p
      ..taskCreated = true
      ..taskTitle = 'Menu layout';
    settings.observe([p], chats);
    expect(settings.notices.last.category, NoticeCategory.tasks);
    p.submitted = true;
    settings.observe([p], chats);
    expect(settings.notices.last.recipient, p.clientId);
    p.feedback = 'Please increase the text size.';
    settings.observe([p], chats);
    expect(settings.notices.last.recipient, p.applicantId);
    p.deadlineAt = DateTime(2026, 10, 23);
    settings.observe([p], chats, now: DateTime(2026, 10, 22));
    expect(
      settings.notices.where((n) => n.category == NoticeCategory.deadlines),
      hasLength(2),
    );
    settings.observe([p], chats, now: DateTime(2026, 10, 22));
    expect(
      settings.notices.where((n) => n.category == NoticeCategory.deadlines),
      hasLength(2),
    );
    p.completed = true;
    settings.observe([p], chats);
    expect(
      settings.notices.where((n) => n.category == NoticeCategory.completion),
      hasLength(2),
    );
  });
  Future<void> tap(WidgetTester tester, String label) async {
    final scroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    if (find.text(label).evaluate().isEmpty) {
      // Reset to the top before looking for lazily built controls.
      await tester.drag(scroll, const Offset(0, 3000));
      await tester.pumpAndSettle();
      if (find.text(label).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: scroll,
        );
      }
    }
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 10 && find.text(label).hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(scroll, const Offset(0, -150));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(label).hitTestable().last);
    await tester.pumpAndSettle();
  }

  testWidgets('notification opens its authorized shared project chat', (
    tester,
  ) async {
    final p = project(),
        chats = DemoChatRepository(),
        settings = SettingsRepository();
    p.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: ['HTML'],
      introduction: 'I can build your accessible menu project.',
      hours: '5–10 hours/week',
    );
    p.acceptApplication(chats);
    settings.observe([p], chats);
    await chats.sendMessage(
      chatId: chats.chatIdFor(p, ChatKind.direct),
      userId: p.clientId,
      displayName: 'Demo Coffee',
      content: 'Actual notification test message',
      kind: ChatMessageKind.text,
    );
    settings.observe([p], chats);
    final snapshot = DemoSnapshot.encode(
      [p],
      chats,
      settings: settings.toJson(),
    );
    await tester.pumpWidget(ProjectBridgeApp(snapshot: snapshot));
    await tap(tester, 'Profile');
    await tap(tester, 'Notifications');
    await tap(tester, 'New message from Demo Coffee in Deadline menu.');
    expect(find.text('Actual notification test message'), findsOneWidget);
    expect(find.byTooltip('Attach image or document'), findsOneWidget);
    chats.dispose();
    settings.dispose();
  });
  testWidgets(
    'privacy changes save, hide portfolio and survive serialized restart',
    (tester) async {
      final settings = SettingsRepository(),
          professional = ProfessionalRepository(projects: () => []);
      professional.settings = settings;
      addTearDown(settings.dispose);
      addTearDown(professional.dispose);
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
                    builder: (_) => PrivacySettingsScreen(
                      repository: settings,
                      professional: professional,
                      accountId: 'student-daria',
                      client: false,
                    ),
                  ),
                ),
                child: const Text('Open privacy'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Open privacy');
      await tap(tester, 'Private portfolio');
      await tap(tester, 'Limited profile visibility');
      await tap(tester, 'Choose a user to block');
      await tap(tester, 'Dias');
      expect(tester.takeException(), isNull);
      await tap(tester, 'Unblock');
      await tap(tester, 'Save privacy settings');
      final restored = SettingsRepository()..restore(saved);
      addTearDown(restored.dispose);
      expect(restored.account('student-daria').limitedProfile, isTrue);
      expect(
        restored.canViewPortfolio('client-demo-coffee', 'student-daria'),
        isFalse,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalPortfolioBody(
              repository: professional,
              profileId: 'student-daria',
              actorId: 'client-demo-coffee',
              allowEditing: false,
            ),
          ),
        ),
      );
      expect(find.text('Private portfolio'), findsOneWidget);
    },
  );
  testWidgets(
    'support save failure keeps draft and does not record a submitted report',
    (tester) async {
      final settings = SettingsRepository()
        ..save = () async => throw StateError('disk');
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SupportReportScreen(
            repository: settings,
            accountId: 'student-daria',
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Subject'),
        'Report a problem',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'The project attachment could not be opened.',
      );
      await tap(tester, 'Submit report');
      expect(settings.supportReports, isEmpty);
      expect(
        find.text('Report could not be saved. Please retry.'),
        findsOneWidget,
      );
      expect(
        find.text('The project attachment could not be opened.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('account cancel does not change display name', (tester) async {
    await tester.pumpWidget(const ProjectBridgeApp());
    await tap(tester, 'Profile');
    await tap(tester, 'Account Settings');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Unsaved name',
    );
    await tap(tester, 'Cancel');
    await tester.scrollUntilVisible(
      find.text('Daria'),
      -300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    expect(find.text('Daria'), findsWidgets);
    expect(find.text('Unsaved name'), findsNothing);
  });
}
