import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

class ReviewFixture {
  ReviewFixture({bool team = false}) {
    professional = ProfessionalRepository(projects: () => [project]);
    reviews = LocalReviewRepository(
      professional: professional,
      settings: settings,
      clock: () => now,
    );
    project.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: ['Flutter'],
      introduction: 'Build a real app',
      hours: '5 hours',
    );
    project.acceptApplication(chats);
    if (team) {
      project.teamSize = 2;
      professional.acceptTeamStudent(
        project.clientId,
        project.id,
        'student-dias',
        chats,
      );
    }
  }
  final project = BridgeProject(
    'Accessible menu',
    'Demo Coffee',
    'Mobile Development',
    'Build a menu.',
    ['Flutter'],
  );
  final chats = DemoChatRepository();
  final settings = SettingsRepository();
  late final ProfessionalRepository professional;
  late final LocalReviewRepository reviews;
  DateTime now = DateTime.now();
  void complete() {
    professional.saveAgreement(
      project.clientId,
      project.id,
      professional.agreementPreview(project).terms,
    );
    professional.saveLegacyTask(
      project.clientId,
      project.id,
      'Menu',
      'Responsive menu',
      'Medium',
      project.deadlineAt,
    );
    for (final actor in [project.clientId, ...project.acceptedParticipantIds]) {
      professional.acknowledgeAgreement(actor, project.id);
    }
    professional.submitWork(
      'student-daria',
      project.id,
      'Actual deliverable',
      'Ready',
    );
    professional.reviewWork(project.clientId, project.id, true, 'Approved');
    professional.completeProject(project.clientId, project.id);
    now = project.completedAt!;
    reviews.synchronize();
  }

  Future<void> student({
    int score = 5,
    String actor = 'student-daria',
    String comment = 'Clear requirements and respectful communication.',
  }) => reviews.submit(
    actorId: actor,
    projectId: project.id,
    targetId: project.clientId,
    overallRating: score,
    categoryRatings: {
      'clarity': score,
      'communication': score,
      'fairness': score,
    },
    comment: comment,
  );
  Future<void> client({String target = 'student-daria', int score = 4}) =>
      reviews.submit(
        actorId: project.clientId,
        projectId: project.id,
        targetId: target,
        overallRating: score,
        categoryRatings: {
          'quality': score,
          'communication': score,
          'reliability': score,
        },
        comment: 'Thoughtful work.',
      );
  void dispose() {
    reviews.dispose();
    professional.dispose();
    settings.dispose();
    chats.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReviewFixture f;
  setUp(() {
    f = ReviewFixture();
  });
  tearDown(() => f.dispose());

  test('incomplete, rejected, unrelated, self and flag-only completion cannot review', () async {
    expect(f.reviews.targets('student-daria', f.project.id), isEmpty);
    await expectLater(f.student(), throwsStateError);
    f.project.applicationStatus = 'Rejected';
    await expectLater(f.client(), throwsStateError);
    f.project.applicationStatus = 'Accepted';
    f.project.completed = true;
    f.project.approved = true;
    f.project.completedAt = f.now;
    expect(f.reviews.targets(f.project.clientId, f.project.id), isEmpty);
    f.project.completed = false;
    f.project.approved = false;
    f.complete();
    await expectLater(f.student(actor: 'student-amina'), throwsStateError);
    await expectLater(
      f.reviews.submit(
        actorId: f.project.clientId,
        projectId: f.project.id,
        targetId: f.project.clientId,
        overallRating: 5,
        categoryRatings: const {},
      ),
      throwsStateError,
    );
  });
  test('student and client submit independently, pending content stays hidden and both publish together', () async {
    f.complete();
    await f.student(comment: 'Hidden feedback');
    expect(f.reviews.publishedFor(f.project.clientId), isEmpty);
    expect(f.reviews.averageFor(f.project.clientId), isNull);
    expect(
      f.reviews.ownReview(f.project.clientId, f.project.id, 'student-daria'),
      isNull,
    );
    expect(
      f.reviews
          .ownReview('student-daria', f.project.id, f.project.clientId)!
          .publicationStatus,
      ReviewPublication.pending,
    );
    await f.client();
    expect(
      f.reviews.publishedFor(f.project.clientId).single.comment,
      'Hidden feedback',
    );
    expect(f.reviews.publishedFor('student-daria').single.overallRating, 4);
    expect(f.reviews.averageFor(f.project.clientId), 5);
    expect(
      f.professional.profile('student-daria').education!.status,
      EducationStatus.notVerified,
    );
  });
  test(
    'duplicates, invalid ratings and wrong category sets are rejected',
    () async {
      f.complete();
      await expectLater(f.student(score: 0), throwsArgumentError);
      await expectLater(f.student(score: 6), throwsArgumentError);
      await expectLater(
        f.reviews.submit(
          actorId: 'student-daria',
          projectId: f.project.id,
          targetId: f.project.clientId,
          overallRating: 5,
          categoryRatings: {'quality': 5, 'communication': 5, 'reliability': 5},
        ),
        throwsArgumentError,
      );
      await f.student();
      await expectLater(f.student(), throwsStateError);
      await f.client();
      await expectLater(f.client(), throwsStateError);
    },
  );
  test('one-sided review publishes exactly at 14 days; late counterpart publishes immediately', () async {
    f.complete();
    await f.student();
    f.now = f.project.completedAt!
        .add(const Duration(days: 14))
        .subtract(const Duration(microseconds: 1));
    await f.reviews.refresh();
    expect(f.reviews.publishedFor(f.project.clientId), isEmpty);
    f.now = f.now.add(const Duration(microseconds: 1));
    await f.reviews.refresh();
    expect(f.reviews.publishedFor(f.project.clientId), hasLength(1));
    final published = f.reviews
        .publishedFor(f.project.clientId)
        .single
        .publishedAt;
    f.now = f.now.add(const Duration(days: 1));
    await f.client();
    expect(f.reviews.publishedFor('student-daria'), hasLength(1));
    expect(
      f.reviews.publishedFor(f.project.clientId).single.publishedAt,
      published,
    );
    final late = ReviewFixture();
    addTearDown(late.dispose);
    late.complete();
    late.now = late.now.add(const Duration(days: 16));
    await late.client();
    expect(late.reviews.publishedFor('student-daria'), hasLength(1));
  });
  test('team eligibility and publication are isolated per accepted student-client pair', () async {
    final team = ReviewFixture(team: true);
    addTearDown(team.dispose);
    team.complete();
    expect(team.reviews.targets(team.project.clientId, team.project.id), [
      'student-daria',
      'student-dias',
    ]);
    expect(team.reviews.targets('student-amina', team.project.id), isEmpty);
    await team.student(score: 5);
    await team.client();
    await team.student(actor: 'student-dias', score: 3);
    expect(team.reviews.publishedFor(team.project.clientId), hasLength(1));
    await team.client(target: 'student-dias', score: 2);
    expect(team.reviews.publishedFor(team.project.clientId), hasLength(2));
    expect(team.reviews.averageFor(team.project.clientId), 4);
    expect(team.reviews.averageFor('student-dias'), 2);
  });
  test('save failure rolls back review, publication and notification changes; retries are possible', () async {
    f.complete();
    await f.student();
    final oldNotices = f.settings.notices.length;
    f.reviews.save = () async => throw StateError('disk full');
    await expectLater(f.client(), throwsStateError);
    expect(
      f.reviews.ownReview(f.project.clientId, f.project.id, 'student-daria'),
      isNull,
    );
    expect(f.reviews.publishedFor(f.project.clientId), isEmpty);
    expect(f.settings.notices, hasLength(oldNotices));
    f.reviews.save = () async {};
    await f.client();
    expect(f.reviews.publishedFor(f.project.clientId), hasLength(1));
  });
  test('concurrent duplicate submission is blocked while saving', () async {
    f.complete();
    final saving = Completer<void>();
    f.reviews.save = () => saving.future;
    final first = f.student();
    await expectLater(f.student(), throwsStateError);
    saving.complete();
    await first;
    expect(
      f.reviews.ownReview('student-daria', f.project.id, f.project.clientId),
      isNotNull,
    );
  });
  test(
    'reports preserve published ratings and pending reports stay private',
    () async {
      f.complete();
      await f.student();
      await f.client();
      final review = f.reviews.publishedFor(f.project.clientId).single;
      await expectLater(
        f.reviews.report(
          actorId: 'outsider',
          reviewId: review.id,
          reason: 'Private information',
        ),
        throwsStateError,
      );
      await expectLater(
        f.reviews.report(
          actorId: f.project.clientId,
          reviewId: review.id,
          reason: 'no',
        ),
        throwsArgumentError,
      );
      await f.reviews.report(
        actorId: f.project.clientId,
        reviewId: review.id,
        reason: 'Contains inappropriate content.',
      );
      expect(
        f.reviews.publishedFor(f.project.clientId).single.moderationStatus,
        ReviewModeration.reported,
      );
      expect(f.reviews.averageFor(f.project.clientId), 5);
      await expectLater(
        f.reviews.report(
          actorId: f.project.clientId,
          reviewId: review.id,
          reason: 'Again inappropriate',
        ),
        throwsStateError,
      );
    },
  );
  test('snapshots preserve IDs, team, chats, profiles, pending reviews and notifications across restart', () async {
    final team = ReviewFixture(team: true);
    addTearDown(team.dispose);
    team.complete();
    await team.chats.sendMessage(
      chatId: team.chats.chatIdFor(team.project, ChatKind.direct),
      userId: 'student-daria',
      displayName: 'Daria',
      content: 'Keep this message',
      kind: ChatMessageKind.text,
    );
    await team.student();
    team.project.client = 'Renamed organization';
    final snapshot = jsonDecode(
      jsonEncode(
        DemoSnapshot.encode(
          [team.project],
          team.chats,
          professional: team.professional.toJson(),
          settings: team.settings.toJson(),
          reviewSystem: team.reviews.toJson(),
        ),
      ),
    ) as Map<String, dynamic>;
    final projects = DemoSnapshot.projectsFrom(snapshot);
    final professional = ProfessionalRepository(projects: () => projects)
      ..restore(snapshot['professional'] as Map<String, dynamic>);
    final settings = SettingsRepository()
      ..restore(snapshot['settings'] as Map<String, dynamic>);
    final reviews = LocalReviewRepository(
      professional: professional,
      settings: settings,
      clock: () => team.now,
    )..restore(snapshot['reviewSystem'] as Map<String, dynamic>);
    final chats = DemoChatRepository()..restore(snapshot, projects);
    addTearDown(professional.dispose);
    addTearDown(settings.dispose);
    addTearDown(reviews.dispose);
    addTearDown(chats.dispose);
    expect(projects.single.clientId, team.project.clientId);
    expect(projects.single.acceptedParticipantIds, [
      'student-daria',
      'student-dias',
    ]);
    expect(
      chats
          .findThread(team.chats.chatIdFor(team.project, ChatKind.direct))!
          .messages
          .single
          .content,
      'Keep this message',
    );
    expect(reviews.publishedFor(team.project.clientId), isEmpty);
    expect(
      reviews
          .ownReview('student-daria', team.project.id, team.project.clientId)!
          .publicationStatus,
      ReviewPublication.pending,
    );
    final count = settings.notices.length;
    reviews.synchronize();
    reviews.synchronize();
    expect(settings.notices, hasLength(count));
    await reviews.submit(
      actorId: team.project.clientId,
      projectId: team.project.id,
      targetId: 'student-daria',
      overallRating: 4,
      categoryRatings: {'quality': 4, 'communication': 4, 'reliability': 4},
    );
    expect(
      settings.notices.where((n) => n.reviewProfileId != null),
      hasLength(2),
    );
    final notices = settings.notices.length;
    reviews.synchronize();
    expect(settings.notices, hasLength(notices));
  });
  test(
    'legacy snapshots keep education state and have no invented reputation',
    () {
      final reviews = LocalReviewRepository(
        professional: f.professional,
        settings: f.settings,
      )..restore(null);
      addTearDown(reviews.dispose);
      expect(reviews.publishedFor('student-daria'), isEmpty);
      expect(reviews.averageFor('student-daria'), isNull);
      expect(
        f.professional.profile('student-daria').education!.status,
        EducationStatus.notVerified,
      );
    },
  );

  Widget host(Widget body) => MaterialApp(
    builder: (context, child) => ProfessionalScope(
      repository: f.professional,
      child: ReviewScope(repository: f.reviews, child: child!),
    ),
    home: Scaffold(body: body),
  );
  Future<void> visibleTap(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (find.byType(ListView).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile empty states and only published reviews are displayed for both roles',
    (tester) async {
      f.complete();
      await tester.pumpWidget(
        host(
          const SingleChildScrollView(
            child: Column(
              children: [
                ReviewsReputationSection(
                  profileId: 'student-daria',
                  actorId: 'student-daria',
                  client: false,
                ),
                ReviewsReputationSection(
                  profileId: 'client-demo-coffee',
                  actorId: 'student-daria',
                  client: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.text(
          'No reviews yet. Complete your first project to start building your reputation.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No reviews yet. Reviews will appear after completed projects.',
        ),
        findsOneWidget,
      );
      await f.student(comment: 'Secret until both submit');
      await tester.pumpAndSettle();
      expect(find.text('Secret until both submit'), findsNothing);
      await f.client();
      await tester.pumpAndSettle();
      expect(find.text('Secret until both submit'), findsOneWidget);
      expect(find.text('Thoughtful work.'), findsOneWidget);
      expect(find.text('Demo Coffee'), findsOneWidget);
      expect(find.text('Daria'), findsOneWidget);
    },
  );
  testWidgets(
    'student and client forms validate, select stars, confirm and replace entry with submitted status',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      f.complete();
      for (final actor in ['student-daria', f.project.clientId]) {
        final client = actor == f.project.clientId;
        await tester.pumpWidget(
          host(
            ListView(
              children: [
                ProjectReviewActions(project: f.project, actorId: actor),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await visibleTap(tester, find.text('Leave a Review'));
        expect(
          find.text(client ? 'Review Student' : 'Review Client'),
          findsOneWidget,
        );
        await visibleTap(tester, find.text('Submit Review'));
        expect(
          find.text('Select a rating from 1 to 5 for every category.'),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView).last, const Offset(0, 1500));
        await tester.pumpAndSettle();
        for (final label in [
          'Overall rating',
          ...(client ? studentReviewCategories : clientReviewCategories).values,
        ]) {
          await visibleTap(tester, find.byTooltip('$label: 5 of 5'));
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        await visibleTap(tester, find.text('Submit Review'));
        expect(find.text('Submit your review?'), findsOneWidget);
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(find.textContaining('Review submitted ·'), findsOneWidget);
        expect(find.text('Leave a Review'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      expect(f.reviews.publishedFor('student-daria'), hasLength(1));
      expect(f.reviews.publishedFor(f.project.clientId), hasLength(1));
    },
  );
  testWidgets(
    'report screen saves moderation status without hiding a published review',
    (tester) async {
      f.complete();
      await f.student();
      await f.client();
      await tester.pumpWidget(
        host(
          const SingleChildScrollView(
            child: ReviewsReputationSection(
              profileId: 'student-daria',
              actorId: 'student-daria',
              client: false,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Report review'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Harassment in this review.',
      );
      await visibleTap(tester, find.text('Submit report'));
      expect(find.text('Reported · awaiting local moderation'), findsOneWidget);
      expect(f.reviews.averageFor('student-daria'), 4);
    },
  );
  testWidgets(
    'app restart retains hidden reviews, completion invite routes and publication notifications',
    (tester) async {
      f.complete();
      await f.student();
      const channel = MethodChannel('test/mutual-review-storage');
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
      final snapshot = DemoSnapshot.encode(
        [f.project],
        f.chats,
        professional: f.professional.toJson(),
        settings: f.settings.toJson(),
        reviewSystem: f.reviews.toJson(),
      );
      await tester.pumpWidget(
        ProjectBridgeApp(storage: storage, snapshot: snapshot),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Switch to Client Demo'));
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text("You can now review Daria's work."));
      expect(find.text('Review Student'), findsOneWidget);
      for (final label in [
        'Overall rating',
        ...studentReviewCategories.values,
      ]) {
        await visibleTap(tester, find.byTooltip('$label: 4 of 5'));
      }
      await visibleTap(tester, find.text('Submit Review'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(disk, isNotNull);
      final saved = await storage.load();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProjectBridgeApp(storage: storage, snapshot: saved),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      await visibleTap(
        tester,
        find.text('A new review is available on your profile.'),
      );
      expect(find.text('★ 4.0 / 5 · 1 published reviews'), findsOneWidget);
      expect(
        find.text('Thoughtful work.'),
        findsNothing,
      ); // Submitted via UI with optional feedback empty.
      expect(find.text('No written feedback.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
