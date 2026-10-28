import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

BridgeProject project() => BridgeProject(
  'Menu',
  'Coffee',
  'Web',
  'Build a menu',
  ['HTML', 'CSS', 'Figma'],
);
const intro = 'I build accessible HTML menus and can help your customers.';
void main() {
  test('validation, normalized honest skill matching and structured hours', () {
    for (final value in ['', '   ', 'Hello', 'a' * 40, 'a ' * 501]) {
      expect(ApplicationValidation.motivation(value), isNotNull);
    }
    expect(ApplicationValidation.motivation('  $intro  '), isNull);
    expect(ApplicationValidation.portfolio(''), isNull);
    expect(ApplicationValidation.portfolio('https://github.com/user'), isNull);
    expect(ApplicationValidation.portfolio('http://example.com'), isNull);
    for (final value in [
      'abcd',
      'ftp://example.com',
      'https://',
      'https://hello world.com',
    ]) {
      expect(ApplicationValidation.portfolio(value), isNotNull);
    }
    expect(
      ApplicationValidation.matching(
        ['html', 'UI UX'],
        ['HTML', 'Flutter', 'UI/UX Design'],
      ),
      ['HTML', 'UI/UX Design'],
    );
    expect(WeeklyAvailability.fromHours(8), WeeklyAvailability.fiveTo10);
    expect(WeeklyAvailability.fromHours(null), isNull);
  });

  test('application snapshots retain structured availability and selected portfolio without changing IDs', () {
    final p = project();
    final entry = PortfolioProject(
      id: 'portfolio-1',
      ownerId: 'student-test',
      title: 'Accessible menu',
      description: 'Independent HTML work',
      skills: ['HTML'],
    );
    expect(
      p.submitApplication(
        studentId: 'student-test',
        name: 'Test Student',
        studentSkills: ['HTML'],
        introduction: intro,
        hours: WeeklyAvailability.fiveTo10.label,
        availabilityCode: 'fiveTo10',
        headline: 'Web student',
        portfolioProjects: [entry],
      ),
      isTrue,
    );
    final restored = DemoSnapshot.projectFromJson(
      DemoSnapshot.projectToJson(p),
    );
    expect(restored.id, p.id);
    expect(restored.applicantId, 'student-test');
    expect(restored.applicationAvailabilityCode, 'fiveTo10');
    expect(restored.applicantHeadline, 'Web student');
    expect(restored.applicationPortfolio.single.id, entry.id);
    expect(restored.applicationStatus, 'Pending');
    expect(restored.acceptedParticipantIds, isEmpty);
  });

  Future<void> open(
    WidgetTester tester,
    BridgeProject p,
    Future<void> Function() save, {
    List<String> skills = const ['HTML', 'Flutter'],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplicationSheet(
            project: p,
            applicantId: 'student-test',
            applicantName: 'Test Student',
            fallbackSkills: skills,
            save: save,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('application-motivation')),
      intro,
    );
    await tap(tester, 'Weekly availability');
    await tap(tester, '5–10 hours/week');
  }

  testWidgets('reads the supplied student profile and preselects its hours', (
    tester,
  ) async {
    final repository = ProfessionalRepository(projects: () => []);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplicationSheet(
            project: project(),
            applicantId: 'student-dias',
            applicantName: 'Fallback',
            fallbackSkills: const ['Flutter'],
            repository: repository,
            save: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HTML'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);
    expect(find.text('5–10 hours/week'), findsOneWidget);
  });

  testWidgets('cancel leaves no application and reopening starts a new draft', (
    tester,
  ) async {
    final p = project();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => applyToProject(
                context,
                p,
                () {},
                [],
                applicantId: 'student-test',
                applicantName: 'Student',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'Open');
    await tester.enterText(
      find.byKey(const Key('application-motivation')),
      intro,
    );
    await tap(tester, 'Cancel');
    expect(p.applied, isFalse);
    await tap(tester, 'Open');
    expect(find.text(intro), findsNothing);
    expect(p.applied, isFalse);
  });

  testWidgets(
    'quiet initial validation, required fields, invalid URL and no matches',
    (tester) async {
      await open(tester, project(), () async {}, skills: []);
      expect(
        find.text('Write at least 30 characters about your fit.'),
        findsNothing,
      );
      expect(
        find.text(
          'No matching skills found in your profile. You can still apply and explain your experience.',
        ),
        findsOneWidget,
      );
      await tap(tester, 'Submit application');
      expect(
        find.text('Write at least 30 characters about your fit.'),
        findsOneWidget,
      );
      expect(find.text('Select your weekly availability.'), findsOneWidget);
      await fill(tester);
      await tester.ensureVisible(
        find.byKey(const Key('application-portfolio')),
      );
      await tester.enterText(
        find.byKey(const Key('application-portfolio')),
        'abcd',
      );
      await tap(tester, 'Submit application');
      expect(
        find.text('Enter a valid http:// or https:// portfolio link.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'save failure rolls back and preserves draft; rapid retry saves once, acceptance opens chat',
    (tester) async {
      final p = project();
      var calls = 0;
      final pending = Completer<void>();
      await open(tester, p, () {
        calls++;
        return calls == 1 ? Future.error(Exception('disk')) : pending.future;
      });
      await fill(tester);
      await tap(tester, 'Submit application');
      expect(p.applied, isFalse);
      expect(
        find.textContaining('Your application could not be saved.'),
        findsOneWidget,
      );
      expect(find.text(intro), findsOneWidget);
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 2);
      expect(p.applicationStatus, 'Pending');
      expect(p.applicationAvailabilityCode, 'fiveTo10');
      expect(p.applicantSkills, ['HTML']);
      final chats = DemoChatRepository();
      expect(p.acceptedParticipantIds, isEmpty);
      expect(
        p.submitApplication(
          studentId: 'other',
          name: 'Other',
          studentSkills: [],
          introduction: intro,
          hours: '5',
        ),
        isFalse,
      );
      expect(p.acceptApplication(chats), isTrue);
      expect(p.acceptedParticipantIds, ['student-test']);
      pending.complete();
      await tester.pumpAndSettle();
      chats.dispose();
    },
  );

  testWidgets('small viewport and open keyboard scroll without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await open(tester, project(), () async {});
    await tester.tap(find.byKey(const Key('application-motivation')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
