import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  const service = TeamMatchingService();
  const project = MatchProjectRequirements(
    id: 'p',
    requiredSkills: ['Flutter', 'Dart', 'Firebase'],
    requiredRoles: ['Mobile Developer'],
    category: 'Mobile Development',
    weeklyHours: 6,
    duration: '4 weeks',
  );
  ProfessionalProfile mobile({
    Availability availability = Availability.available,
  }) => ProfessionalProfile(
    id: 'student',
    name: 'Any name',
    skills: ['Flutter', 'Dart', 'Firebase'],
    preferredRoles: ['Mobile Developer'],
    specialization: 'Mobile Development',
    availability: availability,
    weeklyHours: 8,
  );

  test('weights produce consistent actual-data scores with explainable missing data', () {
    final candidate = MatchCandidate(mobile(), relevantCompletedProjects: 3);
    final a = service.score(project, candidate);
    expect(a.score, 100);
    expect(a.reliable, isTrue);
    expect(service.score(project, candidate).score, a.score);
    expect(a.matchingSkills, ['Flutter', 'Dart', 'Firebase']);
    expect(a.explanations.join(' '), contains('3 relevant client-confirmed'));
    final missing = service.score(
      project,
      MatchCandidate(ProfessionalProfile(id: 'empty', name: 'Unknown')),
    );
    expect(missing.reliable, isFalse);
    expect(
      missing.label,
      'Not enough information to calculate a reliable match.',
    );
    expect(missing.explanations.join(' '), contains('unknown'));
    final renamed = mobile().withChanges({
      'name': 'Different person',
      'education': const InstitutionAffiliation(
        id: 'college',
        name: 'Unverified college',
      ).toJson(),
    });
    expect(
      service
          .score(project, MatchCandidate(renamed, relevantCompletedProjects: 3))
          .score,
      a.score,
    );
  });

  test('availability and actual workload reduce ranking and exclude unavailable team members', () {
    final fresh = service.score(project, MatchCandidate(mobile()));
    final busy = service.score(
      project,
      MatchCandidate(mobile(), activeProjects: 2),
    );
    expect(fresh.score!, greaterThan(busy.score!));
    expect(
      service
          .score(project, MatchCandidate(mobile(), activeProjects: 3))
          .eligible,
      isFalse,
    );
    final unavailable = MatchCandidate(
      mobile(availability: Availability.unavailable),
    );
    expect(service.score(project, unavailable).eligible, isFalse);
    expect(service.buildTeam(project, [unavailable]).members, isEmpty);
    final noHours = mobile().withChanges({'weeklyHours': 0});
    expect(service.score(project, MatchCandidate(noHours)).eligible, isFalse);
  });

  test('team builder covers complementary roles with unique students and reports gaps', () {
    final repository = ProfessionalRepository(projects: () => []);
    addTearDown(repository.dispose);
    const platform = MatchProjectRequirements(
      id: 'platform',
      requiredSkills: ['HTML', 'CSS', 'Figma', 'Graphic Design'],
      requiredRoles: ['Web Developer', 'UI/UX Designer', 'Graphic Designer'],
      teamSize: 3,
      weeklyHours: 4,
    );
    final team = service.buildTeam(
      platform,
      repository.profiles.map((p) => MatchCandidate(p)).toList(),
    );
    expect(team.members, hasLength(3));
    expect(
      team.members.map((m) => m.candidate.profile.id).toSet(),
      hasLength(3),
    );
    expect(
      team.members
          .firstWhere((m) => m.role == 'Web Developer')
          .candidate
          .profile
          .id,
      'student-dias',
    );
    expect(
      team.members
          .firstWhere((m) => m.role == 'UI/UX Designer')
          .candidate
          .profile
          .id,
      'student-aruzhan',
    );
    expect(
      team.members
          .firstWhere((m) => m.role == 'Graphic Designer')
          .candidate
          .profile
          .id,
      'student-amina',
    );
    expect(team.uncoveredRoles, isEmpty);
    expect(team.missingSkills, isEmpty);
    final incomplete = service.buildTeam(platform, [
      MatchCandidate(repository.profile('student-dias')),
    ]);
    expect(
      incomplete.uncoveredRoles,
      containsAll(['UI/UX Designer', 'Graphic Designer']),
    );
    expect(incomplete.members, hasLength(1));
  });

  test('ranking uses stored profile edits and never enrolls or creates conversations', () async {
    final p = BridgeProject(
      'Mobile demo',
      'Demo Coffee',
      'Mobile Development',
      'Build a mobile app.',
      ['Flutter'],
    );
    final repository = ProfessionalRepository(projects: () => [p]);
    final chats = DemoChatRepository();
    addTearDown(repository.dispose);
    addTearDown(chats.dispose);
    final before = repository.matchFor(p, 'student-daria');
    repository.saveProfile(
      'student-daria',
      repository.profile('student-daria').withChanges({
        'skills': ['Branding'],
      }),
    );
    final after = repository.matchFor(p, 'student-daria');
    expect(before.score!, greaterThan(after.score!));
    service.buildTeam(repository.requirements(p), repository.candidatesFor(p));
    expect(p.applied, isFalse);
    expect(p.accepted, isFalse);
    expect(await chats.watchChats('student-daria').first, isEmpty);
  });

  testWidgets(
    'client matching UI explains results and opens a public candidate profile',
    (tester) async {
      final p =
          BridgeProject(
              'Coffee platform',
              'Demo Coffee',
              'Web Development',
              'Build a platform',
              ['HTML', 'Figma'],
            )
            ..requiredRoles = ['Web Developer', 'UI/UX Designer']
            ..teamSize = 2;
      final repo = ProfessionalRepository(projects: () => [p]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TeamMatchingScreen(
            repository: repo,
            projectId: p.id,
            actorId: p.clientId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Suggested Team'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Dias — Web Developer'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Dias — Web Developer'));
      await tester.pumpAndSettle();
      expect(find.text('Professional profile'), findsOneWidget);
      expect(find.text('Dias'), findsOneWidget);
      expect(
        find.text('Independent professional · No institution required'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('broad development requirements recognize sufficient stored technical skills with an explanation', () {
    final profile = ProfessionalProfile(
      id: 'web',
      name: 'Web developer',
      skills: ['HTML', 'CSS', 'JavaScript'],
      availability: Availability.available,
      preferredRoles: ['Web Developer'],
    );
    const broad = MatchProjectRequirements(
      id: 'broad',
      requiredSkills: ['Web Development', 'UI/UX Design'],
      category: 'Web Development',
    );
    final result = service.score(broad, MatchCandidate(profile));
    expect(result.matchingSkills, ['Web Development']);
    expect(result.missingSkills, ['UI/UX Design']);
    expect(
      result.explanations.join(' '),
      contains('recognized from declared technical skills'),
    );
    expect(service.supportsSkills('Web Development', ['HTML']), isFalse);
    final unrelated = ProfessionalProfile(
      id: 'other',
      name: 'Unrelated',
      skills: ['Python'],
    );
    expect(
      service.score(broad, MatchCandidate(unrelated)).suggestedRole,
      isEmpty,
    );
  });
}
