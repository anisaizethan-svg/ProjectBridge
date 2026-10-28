part of '../../main.dart';

extension ProjectSafetyOperations on ProfessionalRepository {
  void requireParticipant(String actorId, BridgeProject p) {
    if (actorId != p.clientId) requireStudent(actorId, p);
  }

  void requireActive(BridgeProject p) {
    if (['Cancelled', 'Closed', 'Completed'].contains(p.lifecycleStatus) ||
        p.completed) {
      throw StateError(
        'This project is closed for new work. History is preserved.',
      );
    }
    if (_withdrawals[p.id] == 'Requested') {
      throw StateError('Resolve the withdrawal request before more work.');
    }
  }

  ProjectAgreement agreementPreview(BridgeProject p) =>
      _agreements[p.id] ??
      ProjectAgreement(
        projectId: p.id,
        version: 0,
        terms: {
          'Project goal': p.description,
          'Student role': p.role,
          'Client responsibilities':
              'Provide clear requirements, resources and timely feedback.',
          'Expected deliverables': p.expectedResult,
          'Milestones': _milestones.values.any((m) => m.projectId == p.id)
              ? _milestones.values
                    .where((m) => m.projectId == p.id)
                    .map((m) => '${m.title}: ${m.description}')
                    .join('\n')
              : p.taskTitle,
          'Deadline': p.deadlineAt.toLocal().toString().split(' ').first,
          'Revision expectations':
              'Agree on revisions in writing before expanding the scope.',
          'Compensation terms': p.compensation,
          'Communication expectations':
              'Use the authorized project chat for weekly updates.',
          'Weekly commitment': p.weeklyCommitment == null
              ? 'To be agreed'
              : '${p.weeklyCommitment} hours/week',
          'Withdrawal procedure':
              'Request withdrawal here; agree on a handover with the client.',
          'Dispute reporting': 'Use Report a problem. Reports are saved privately for demo review only.',
        },
      );
  ProjectAgreement? agreementFor(String actorId, String projectId) {
    final p = project(projectId);
    requireParticipant(actorId, p);
    return _agreements[projectId];
  }

  ProjectAgreement saveAgreement(
    String actorId,
    String projectId,
    Map<String, String> terms,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    if (terms.values.any((v) => v.trim().isEmpty) ||
        terms.length != agreementPreview(p).terms.length ||
        !terms.keys.toSet().containsAll(agreementPreview(p).terms.keys)) {
      throw StateError('Complete every agreement section.');
    }
    final agreement = ProjectAgreement(
      projectId: projectId,
      version: (_agreements[projectId]?.version ?? 0) + 1,
      terms: terms.map((key, value) => MapEntry(key, value.trim())),
    );
    _agreements[projectId] = agreement;
    _record(
      actorId,
      p,
      'Agreement updated to version ${agreement.version}; acknowledgements reset.',
    );
    changed();
    return agreement;
  }

  bool agreementReady(BridgeProject p) {
    final a = _agreements[p.id];
    return a != null &&
        p.acceptedParticipantIds.isNotEmpty &&
        [
          p.clientId,
          ...p.acceptedParticipantIds,
        ].every(a.acknowledgements.containsKey);
  }

  void acknowledgeAgreement(String actorId, String projectId) {
    final p = project(projectId);
    requireParticipant(actorId, p);
    requireActive(p);
    final agreement =
        _agreements[projectId] ??
        (throw StateError('The client must save an agreement first.'));
    _agreements[projectId] = ProjectAgreement(
      projectId: projectId,
      version: agreement.version,
      terms: agreement.terms,
      acknowledgements: {
        ...agreement.acknowledgements,
        actorId: DateTime.now().toIso8601String(),
      },
    );
    _record(actorId, p, 'Acknowledged agreement version ${agreement.version}.');
    changed();
  }

  void _invalidateMilestoneScope(BridgeProject p) {
    final agreement = _agreements[p.id];
    if (agreement == null) return;
    final summary = _milestones.values
        .where((m) => m.projectId == p.id)
        .map(
          (m) =>
              '${m.title}: ${m.description} · ${m.assigneeId ?? 'unassigned'} · ${m.dueAt.toIso8601String().split('T').first}',
        )
        .join('\n');
    _agreements[p.id] = ProjectAgreement(
      projectId: p.id,
      version: agreement.version + 1,
      terms: {...agreement.terms, 'Milestones': summary},
    );
  }

  void requireAgreement(BridgeProject p) {
    requireActive(p);
    if (!agreementReady(p)) {
      throw StateError(
        'Both parties must acknowledge the current agreement before work begins.',
      );
    }
  }

  List<ProjectMilestone> milestonesFor(String actorId, String projectId) {
    final p = project(projectId);
    requireParticipant(actorId, p);
    return List.unmodifiable(
      _milestones.values.where((m) => m.projectId == projectId),
    );
  }

  ProjectMilestone createMilestone(
    String actorId,
    String projectId,
    String title,
    String description,
    DateTime dueAt, {
    String? assigneeId,
  }) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    if (title.trim().isEmpty || description.trim().isEmpty) {
      throw StateError('Add a title and expected deliverable.');
    }
    if (assigneeId != null) requireStudent(assigneeId, p);
    final value = ProjectMilestone(
      id: newId('milestone'),
      projectId: projectId,
      title: title.trim(),
      description: description.trim(),
      dueAt: dueAt,
      assigneeId: assigneeId,
    );
    _milestones[value.id] = value;
    _invalidateMilestoneScope(p);
    _record(actorId, p, 'Created milestone: ${value.title}.');
    changed();
    return value;
  }

  void assignMilestone(String actorId, String milestoneId, String studentId) {
    final value =
        _milestones[milestoneId] ?? (throw StateError('Milestone not found.'));
    final p = project(value.projectId);
    requireClient(actorId, p);
    requireStudent(studentId, p);
    requireActive(p);
    if (value.status != MilestoneStatus.notStarted) {
      throw StateError('Only unstarted work can be reassigned.');
    }
    _milestones[value.id] = value.withChanges({'assigneeId': studentId});
    _invalidateMilestoneScope(p);
    changed();
  }

  void startMilestone(String actorId, String milestoneId) {
    final value =
        _milestones[milestoneId] ?? (throw StateError('Milestone not found.'));
    final p = project(value.projectId);
    requireStudent(actorId, p);
    owner(actorId, value.assigneeId ?? 'unassigned');
    requireAgreement(p);
    if (value.status != MilestoneStatus.notStarted &&
        value.status != MilestoneStatus.needsChanges) {
      throw StateError('This milestone cannot be started.');
    }
    _milestones[value.id] = value.withChanges({
      'status': MilestoneStatus.inProgress.name,
    });
    changed();
  }

  void submitMilestone(String actorId, String milestoneId, String text) {
    final value =
        _milestones[milestoneId] ?? (throw StateError('Milestone not found.'));
    final p = project(value.projectId);
    requireStudent(actorId, p);
    owner(actorId, value.assigneeId ?? 'unassigned');
    requireAgreement(p);
    if (text.trim().isEmpty ||
        ![
          MilestoneStatus.inProgress,
          MilestoneStatus.needsChanges,
        ].contains(value.status)) {
      throw StateError('Start your milestone and add a deliverable first.');
    }
    _milestones[value.id] = value.withChanges({
      'status': MilestoneStatus.submitted.name,
      'submission': text.trim(),
      'reviewedBy': null,
      'reviewedAt': null,
      'feedback': '',
    });
    _record(actorId, p, 'Submitted milestone: ${value.title}.');
    changed();
  }

  void reviewMilestone(
    String actorId,
    String milestoneId,
    bool approve,
    String feedback,
  ) {
    final value =
        _milestones[milestoneId] ?? (throw StateError('Milestone not found.'));
    final p = project(value.projectId);
    requireClient(actorId, p);
    requireAgreement(p);
    if (value.status != MilestoneStatus.submitted ||
        (!approve && feedback.trim().isEmpty)) {
      throw StateError(
        'Review submitted work and explain requested revisions.',
      );
    }
    _milestones[value.id] = value.withChanges({
      'status':
          (approve ? MilestoneStatus.approved : MilestoneStatus.needsChanges)
              .name,
      'feedback': feedback.trim().isEmpty
          ? 'Approved by the demo client.'
          : feedback.trim(),
      'reviewedBy': actorId,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
    _record(
      actorId,
      p,
      '${approve ? 'Approved' : 'Requested changes to'} milestone: ${value.title}.',
    );
    changed();
  }

  void _record(String actorId, BridgeProject p, String detail) {
    _history.add({
      'projectId': p.id,
      'actorId': actorId,
      'detail': detail,
      'time': DateTime.now().toIso8601String(),
      'status': p.lifecycleStatus,
    });
  }

  List<Map<String, String>> historyFor(String actorId, String projectId) {
    final p = project(projectId);
    // A withdrawn participant retains their own collaboration history.
    if (actorId != p.clientId && actorId != p.applicantId) {
      throw StateError('Project history is private.');
    }
    return _history
        .where((e) => e['projectId'] == projectId)
        .map((e) => Map<String, String>.unmodifiable(e))
        .toList();
  }

  String? withdrawalFor(String actorId, String projectId) {
    final p = project(projectId);
    if (actorId != p.clientId && actorId != p.applicantId) {
      throw StateError('Withdrawal information is private.');
    }
    return _withdrawals[projectId];
  }

  void requestWithdrawal(String actorId, String projectId, String reason) {
    final p = project(projectId);
    requireStudent(actorId, p);
    requireActive(p);
    if (reason.trim().isEmpty) {
      throw StateError('Describe the withdrawal and proposed handover.');
    }
    _withdrawals[projectId] = 'Requested';
    _record(actorId, p, 'Withdrawal requested: ${reason.trim()}');
    changed();
  }

  void reviewWithdrawal(String actorId, String projectId, bool approve) {
    final p = project(projectId);
    requireClient(actorId, p);
    if (_withdrawals[projectId] != 'Requested') {
      throw StateError('No pending withdrawal request.');
    }
    _withdrawals[projectId] = approve ? 'Approved' : 'Declined';
    if (approve) {
      p.accepted = false;
      p.applicationStatus = 'Withdrawn';
      p.lifecycleStatus = 'Published';
    }
    _record(
      actorId,
      p,
      'Withdrawal ${approve ? 'approved' : 'declined'}. History retained.',
    );
    changed();
  }

  void closeProject(
    String actorId,
    String projectId,
    bool cancel,
    String reason,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    if (reason.trim().isEmpty) {
      throw StateError('Record why the project is closing.');
    }
    p.lifecycleStatus = cancel ? 'Cancelled' : 'Closed';
    p.isPublished = false;
    _record(actorId, p, '${p.lifecycleStatus}: ${reason.trim()}');
    changed();
  }

  SafetyReport createReport(
    String actorId,
    String projectId,
    String category,
    String details,
  ) {
    final p = project(projectId);
    final known = _profiles.containsKey(actorId) || actorId == p.clientId;
    if (!known ||
        (!p.isPublished && actorId != p.clientId && actorId != p.applicantId)) {
      throw StateError('This account cannot report this project.');
    }
    if (!SafetyReport.categories.contains(category) ||
        details.trim().length < 10) {
      throw StateError(
        'Choose a category and describe the problem (at least 10 characters).',
      );
    }
    final report = SafetyReport(
      id: newId('report'),
      projectId: projectId,
      reporterId: actorId,
      category: category,
      details: details.trim(),
      createdAt: DateTime.now(),
    );
    _reports[report.id] = report;
    changed();
    return report;
  }

  List<SafetyReport> reportsFor(String actorId) => List.unmodifiable(
    _reports.values.where(
      (r) => r.reporterId == actorId || actorId == 'demo-moderator',
    ),
  );
  void noteDemoReview(String actorId, String reportId, String note) {
    if (actorId != 'demo-moderator') {
      throw StateError('Demo moderator access is required.');
    }
    final report =
        _reports[reportId] ?? (throw StateError('Report not found.'));
    if (note.trim().isEmpty) throw StateError('Add a demo review note.');
    _reports[reportId] = SafetyReport(
      id: report.id,
      projectId: report.projectId,
      reporterId: report.reporterId,
      category: report.category,
      details: report.details,
      createdAt: report.createdAt,
      status: 'Demo review noted · no real moderation',
      reviewNote: note.trim(),
    );
    changed();
  }
}
