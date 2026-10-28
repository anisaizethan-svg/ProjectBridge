import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  late BridgeProject p;
  late ProfessionalRepository repo;
  late DemoChatRepository chats;
  setUp(() {
    p = BridgeProject(
      'Safe demo project',
      'Demo Coffee',
      'Mobile Development',
      'Build an app.',
      ['Flutter'],
    );
    repo = ProfessionalRepository(projects: () => [p]);
    chats = DemoChatRepository();
    p.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: ['Flutter'],
      introduction: 'Build the app',
      hours: '5 hours',
    );
    p.acceptApplication(chats);
  });
  tearDown(() {
    repo.dispose();
    chats.dispose();
  });
  void acknowledge() {
    repo.acknowledgeAgreement(p.clientId, p.id);
    repo.acknowledgeAgreement('student-daria', p.id);
  }

  test('agreement and milestones enforce owners, acknowledgements and explicit client completion', () {
    expect(
      () => repo.saveAgreement(
        'student-daria',
        p.id,
        repo.agreementPreview(p).terms,
      ),
      throwsStateError,
    );
    repo.saveAgreement(p.clientId, p.id, repo.agreementPreview(p).terms);
    final milestone = repo.createMilestone(
      p.clientId,
      p.id,
      'Accessible menu',
      'Responsive menu with prices',
      p.deadlineAt,
      assigneeId: 'student-daria',
    );
    expect(
      () => repo.startMilestone('student-daria', milestone.id),
      throwsStateError,
    );
    expect(
      () => repo.acknowledgeAgreement('student-dias', p.id),
      throwsStateError,
    );
    acknowledge();
    expect(repo.agreementReady(p), isTrue);
    repo.startMilestone('student-daria', milestone.id);
    expect(
      () => repo.submitMilestone('student-dias', milestone.id, 'work'),
      throwsStateError,
    );
    repo.submitMilestone(
      'student-daria',
      milestone.id,
      'https://example.test/menu',
    );
    expect(
      () =>
          repo.reviewMilestone('student-daria', milestone.id, true, 'approved'),
      throwsStateError,
    );
    repo.reviewMilestone(p.clientId, milestone.id, false, 'Improve contrast');
    expect(
      repo.milestonesFor(p.clientId, p.id).single.status,
      MilestoneStatus.needsChanges,
    );
    repo.startMilestone('student-daria', milestone.id);
    repo.submitMilestone(
      'student-daria',
      milestone.id,
      'Accessible final menu',
    );
    repo.reviewMilestone(
      p.clientId,
      milestone.id,
      true,
      'Accessible and usable.',
    );
    expect(repo.passportsFor('student-daria'), isEmpty);
    final passport = repo.completeProject(p.clientId, p.id);
    expect(passport.tasks, 'Accessible menu');
    expect(passport.deliverables, 'Accessible final menu');
    expect(p.completed, isTrue);
    expect(repo.historyFor(p.clientId, p.id), isNotEmpty);
  });

  test('scope edits and new milestones reset acknowledgements without granting chat access', () async {
    repo.saveAgreement(p.clientId, p.id, repo.agreementPreview(p).terms);
    acknowledge();
    final terms = {
      ...repo.agreementPreview(p).terms,
      'Expected deliverables': 'An expanded menu',
    };
    repo.saveAgreement(p.clientId, p.id, terms);
    expect(repo.agreementReady(p), isFalse);
    acknowledge();
    repo.createMilestone(
      p.clientId,
      p.id,
      'New scope',
      'New approved deliverable',
      p.deadlineAt,
      assigneeId: 'student-daria',
    );
    expect(repo.agreementReady(p), isFalse);
    expect(await chats.watchChats('student-dias').first, isEmpty);
    expect(await chats.watchChats('student-daria').first, hasLength(2));
  });

  test(
    'reports are private, retained and honestly labeled across restoration',
    () {
      final report = repo.createReport(
        'student-daria',
        p.id,
        'Unclear requirements',
        'The scope needs more detail.',
      );
      expect(repo.reportsFor(p.clientId), isEmpty);
      expect(repo.reportsFor('student-dias'), isEmpty);
      expect(
        repo.reportsFor('student-daria').single.status,
        'Awaiting demo review',
      );
      expect(
        () => repo.noteDemoReview(p.clientId, report.id, 'Reviewed'),
        throwsStateError,
      );
      repo.noteDemoReview(
        'demo-moderator',
        report.id,
        'Local simulation only.',
      );
      final restored = ProfessionalRepository(
        projects: () => [p],
      )..restore(jsonDecode(jsonEncode(repo.toJson())) as Map<String, dynamic>);
      addTearDown(restored.dispose);
      expect(
        restored.reportsFor('student-daria').single.status,
        contains('no real moderation'),
      );
      expect(restored.reportsFor(p.clientId), isEmpty);
    },
  );

  test('withdrawal revokes membership and preserves messages and lifecycle history', () async {
    final id = chats.chatIdFor(p, ChatKind.direct);
    await chats.sendMessage(
      chatId: id,
      userId: 'student-daria',
      displayName: 'Daria',
      content: 'A real update',
      kind: ChatMessageKind.text,
    );
    repo.requestWithdrawal(
      'student-daria',
      p.id,
      'Need to arrange a handover.',
    );
    expect(
      () => repo.reviewWithdrawal('student-daria', p.id, true),
      throwsStateError,
    );
    repo.reviewWithdrawal(p.clientId, p.id, true);
    expect(p.applicationStatus, 'Withdrawn');
    expect(await chats.watchChats('student-daria').first, isEmpty);
    expect(chats.findThread(id)!.messages.single.content, 'A real update');
    expect(repo.historyFor('student-daria', p.id), hasLength(2));
    expect(
      () => repo.closeProject('student-dias', p.id, true, 'Cancel'),
      throwsStateError,
    );
    repo.closeProject(p.clientId, p.id, true, 'Closed after handover.');
    expect(p.lifecycleStatus, 'Cancelled');
    expect(p.isPublished, isFalse);
  });
  test('updating legacy assigned work invalidates approval and scope acknowledgements', () {
    repo.saveLegacyTask(
      p.clientId,
      p.id,
      'First task',
      'Deliver a responsive page',
      'Medium',
      p.deadlineAt,
    );
    repo.saveAgreement(p.clientId, p.id, repo.agreementPreview(p).terms);
    acknowledge();
    repo.submitWork('student-daria', p.id, 'First deliverable', 'Done');
    repo.reviewWork(p.clientId, p.id, true, 'Approved first task.');
    expect(
      () => repo.saveLegacyTask(
        'student-daria',
        p.id,
        'Forged task',
        'Description',
        'High',
        p.deadlineAt,
      ),
      throwsStateError,
    );
    repo.saveLegacyTask(
      p.clientId,
      p.id,
      'Changed task',
      'An expanded deliverable',
      'High',
      p.deadlineAt,
    );
    expect(p.approved, isFalse);
    expect(repo.agreementReady(p), isFalse);
    acknowledge();
    expect(() => repo.completeProject(p.clientId, p.id), throwsStateError);
  });
}
