import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  testWidgets(
    'both accounts acknowledge, submit a milestone and explicitly complete its passport through UI',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = BridgeProject(
        'Digital Menu Delivery',
        'Demo Coffee',
        'Web Development',
        'A responsive menu.',
        ['HTML', 'CSS'],
      );
      final chats = DemoChatRepository();
      final repo = ProfessionalRepository(projects: () => [p]);
      addTearDown(chats.dispose);
      addTearDown(repo.dispose);
      p.submitApplication(
        studentId: 'student-daria',
        name: 'Daria',
        studentSkills: ['HTML'],
        introduction: 'Build the menu',
        hours: '5 hours',
      );
      p.acceptApplication(chats);
      Future<void> mount(String actor) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            home: ProjectSafetyScreen(
              repository: repo,
              projectId: p.id,
              actorId: actor,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            450,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .first,
          );
        } else {
          await tester.ensureVisible(finder.last);
        }
        await tester.pumpAndSettle();
        await tester.tap(finder.last);
        await tester.pumpAndSettle();
      }

      await mount(p.clientId);
      await tap('Create agreement');
      await tap('Save');
      await tap('Milestones');
      await tap('Create milestone');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Milestone title'),
        'Responsive menu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected deliverable'),
        'An accessible QR menu with prices.',
      );
      await tap('Save');
      await tap('Agreement');
      await tap('I acknowledge this scope');
      await mount('student-daria');
      await tap('I acknowledge this scope');
      expect(repo.agreementReady(p), isTrue);
      await tap('Milestones');
      await tap('Start milestone');
      await tap('Submit progress');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Deliverable or progress link'),
        'https://example.test/finished-menu',
      );
      await tap('Save');
      await mount(p.clientId);
      await tap('Milestones');
      await tap('Approve work');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Review feedback'),
        'The agreed menu is complete and accessible.',
      );
      await tap('Save');
      expect(repo.passportsFor('student-daria'), isEmpty);
      await tap('Approve project completion');
      await tap('Confirm completion');
      expect(repo.passportsFor('student-daria'), hasLength(1));
      expect(p.completed, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalPortfolioBody(
            repository: repo,
            profileId: 'student-daria',
            actorId: 'student-daria',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Digital Menu Delivery'), findsOneWidget);
      await tester.tap(find.text('Digital Menu Delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Project Passport'), findsOneWidget);
      expect(find.text('Verified · demo client confirmation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
