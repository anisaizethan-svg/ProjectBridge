import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  test('profile ownership, normalized skills, optional education and portfolio survive restoration', () {
    final repository = ProfessionalRepository(projects: () => []);
    addTearDown(repository.dispose);
    expect(Skill.clean(['C++', 'c++', 'C#', 'Қазақша', ' қазақша ']), [
      'C++',
      'C#',
      'Қазақша',
    ]);
    final p = repository.profile('student-daria');
    repository.saveProfile(
      p.id,
      p.withChanges({
        'headline': 'Flutter developer',
        'skills': [
          'flutter',
          'Flutter',
          ' UX/UI ',
          'UI/UX Design',
          'Custom Skill',
        ],
        'education': null,
        'summary': 'My professional summary',
        'availability': 'available',
        'weeklyHours': 5,
      }),
    );
    final edited = repository.profile(p.id);
    expect(edited.skills, ['Flutter', 'UI/UX Design', 'Custom Skill']);
    expect(edited.education, isNull);
    expect(
      () => repository.saveProfile('student-dias', edited),
      throwsStateError,
    );
    final entry = PortfolioProject(
      id: 'personal-one',
      ownerId: p.id,
      title: 'Personal App',
      description: 'My own work',
      skills: ['Flutter'],
    );
    repository.savePortfolio(p.id, entry);
    expect(entry.verified, isFalse);
    expect(
      () => repository.removePortfolio('student-dias', entry.id),
      throwsStateError,
    );
    final snapshot =
        jsonDecode(jsonEncode(repository.toJson())) as Map<String, dynamic>;
    final restored = ProfessionalRepository(projects: () => [])
      ..restore(snapshot);
    addTearDown(restored.dispose);
    expect(restored.profile(p.id).headline, 'Flutter developer');
    expect(restored.profile(p.id).education, isNull);
    expect(restored.portfolioFor(p.id).single.title, 'Personal App');
    repository.saveProfile(
      p.id,
      edited.withChanges({
        'skills': ['Dart'],
      }),
    );
    expect(repository.profile(p.id).skills, ['Dart']);
  });

  test('typing an institution or editing a public profile cannot grant verification', () {
    final repository = ProfessionalRepository(projects: () => []);
    addTearDown(repository.dispose);
    final p = repository.profile('student-daria');
    final education = const InstitutionAffiliation(
      id: 'new',
      name: 'User-entered college',
      status: EducationStatus.demoVerified,
    );
    repository.saveProfile(
      p.id,
      p.withChanges({'education': education.toJson()}),
    );
    expect(
      repository.profile(p.id).education!.status,
      EducationStatus.notVerified,
    );
    expect(repository.profile(p.id).education!.label, 'Not verified');
    expect(repository.profiles, hasLength(5));
  });

  testWidgets(
    'professional profile and independent portfolio use the existing navigation',
    (tester) async {
      await tester.pumpWidget(const ProjectBridgeApp());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer | UI/UX Enthusiast'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      final headline = find.widgetWithText(
        TextFormField,
        'Professional headline',
      );
      await tester.enterText(headline, 'Flutter developer and designer');
      await tester.scrollUntilVisible(
        find.text('Save changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter developer and designer'), findsOneWidget);
      await tester.tap(find.text('Portfolio').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add personal project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'My independent app',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'A personal Flutter prototype',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('My independent app'), findsOneWidget);
      expect(find.textContaining('Self-reported'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'project details opened from Home show the saved profile skills',
    (tester) async {
      await tester.pumpWidget(const ProjectBridgeApp());
      await tester.tap(find.text('Coffee Shop Website'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Your skills: Flutter, Dart, Firebase'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(
        find.textContaining('Your skills: Flutter, Dart, Firebase'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
