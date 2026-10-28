import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  test('education review requires demo admin and is invalidated by affiliation edits', () {
    final repository = ProfessionalRepository(projects: () => []);
    addTearDown(repository.dispose);
    repository.requestEducationReview('student-daria');
    expect(
      repository.profile('student-daria').education!.status,
      EducationStatus.pending,
    );
    expect(
      () => repository.demoVerifyEducation('student-daria', 'student-daria'),
      throwsStateError,
    );
    repository.demoVerifyEducation('demo-administrator', 'student-daria');
    var profile = repository.profile('student-daria');
    expect(profile.education!.label, 'Verified Education · demo only');
    repository.saveProfile(
      profile.id,
      profile.withChanges({'headline': 'Updated headline'}),
    );
    expect(
      repository.profile(profile.id).education!.status,
      EducationStatus.demoVerified,
    );
    profile = repository.profile(profile.id);
    repository.saveProfile(
      profile.id,
      profile.withChanges({
        'education': {
          ...profile.education!.toJson(),
          'name': 'Different college',
        },
      }),
    );
    expect(
      repository.profile(profile.id).education!.status,
      EducationStatus.notVerified,
    );
  });

  test('verified passport requires accepted work, authorized review and explicit completion', () {
    final p = BridgeProject(
      'Real contribution',
      'Demo Coffee',
      'Mobile Development',
      'Build an app.',
      ['Flutter'],
    );
    final repository = ProfessionalRepository(projects: () => [p]);
    final chats = DemoChatRepository();
    addTearDown(repository.dispose);
    addTearDown(chats.dispose);
    expect(
      () => repository.completeProject(p.clientId, p.id),
      throwsStateError,
    );
    p.submitApplication(
      studentId: 'student-daria',
      name: 'Daria',
      studentSkills: ['Flutter'],
      introduction: 'I can build the app',
      hours: '5 hours',
    );
    expect(
      () => repository.submitWork('student-daria', p.id, 'work', ''),
      throwsStateError,
    );
    p.acceptApplication(chats);
    p.taskCreated = true;
    repository.saveAgreement(
      p.clientId,
      p.id,
      repository.agreementPreview(p).terms,
    );
    repository.acknowledgeAgreement(p.clientId, p.id);
    repository.acknowledgeAgreement('student-daria', p.id);
    // A local flag edit does not manufacture a review record.
    p.submitted = true;
    p.approved = true;
    p.submissionText = 'work';
    expect(
      () => repository.completeProject(p.clientId, p.id),
      throwsStateError,
    );
    repository.submitWork('student-daria', p.id, 'Actual deliverable', 'Done');
    expect(
      () => repository.reviewWork('student-daria', p.id, true, 'Approved'),
      throwsStateError,
    );
    repository.reviewWork(
      p.clientId,
      p.id,
      false,
      'Please improve accessibility',
    );
    expect(repository.passportStatus(p), 'Changes requested');
    repository.submitWork(
      'student-daria',
      p.id,
      'Accessible deliverable',
      'Fixed',
    );
    expect(repository.passportStatus(p), 'Submitted for review');
    repository.reviewWork(p.clientId, p.id, true, 'Clear and usable work.');
    expect(repository.passportsFor('student-daria'), isEmpty);
    expect(
      () => repository.completeProject('student-daria', p.id),
      throwsStateError,
    );
    final passport = repository.completeProject(p.clientId, p.id);
    expect(passport.studentId, 'student-daria');
    expect(passport.deliverables, 'Accessible deliverable');
    expect(passport.review, 'Clear and usable work.');
    expect(passport.verificationLabel, contains('demo'));
    p.portfolioPermission = false;
    expect(
      repository.visiblePassports('student-dias', 'student-daria'),
      isEmpty,
    );
    expect(
      repository.visiblePassports('student-daria', 'student-daria'),
      hasLength(1),
    );
    expect(
      repository.visiblePassports(p.clientId, 'student-daria'),
      hasLength(1),
    );

    expect(repository.completeProject(p.clientId, p.id).id, passport.id);
    final restored = ProfessionalRepository(projects: () => [p])
      ..restore(
        jsonDecode(jsonEncode(repository.toJson())) as Map<String, dynamic>,
      );
    addTearDown(restored.dispose);
    expect(restored.passportsFor('student-daria').single.id, passport.id);
  });
}
