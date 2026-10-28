enum MilestoneStatus {
  notStarted,
  inProgress,
  submitted,
  approved,
  needsChanges,
}

extension MilestoneStatusLabels on MilestoneStatus {
  String get label => switch (this) {
    MilestoneStatus.notStarted => 'Not started',
    MilestoneStatus.inProgress => 'In progress',
    MilestoneStatus.submitted => 'Submitted',
    MilestoneStatus.approved => 'Approved',
    MilestoneStatus.needsChanges => 'Needs changes',
  };
}

class ProjectAgreement {
  ProjectAgreement({
    required this.projectId,
    required this.version,
    required Map<String, String> terms,
    Map<String, String> acknowledgements = const {},
  }) : terms = Map.unmodifiable(terms),
       acknowledgements = Map.unmodifiable(acknowledgements);
  final String projectId;
  final int version;
  final Map<String, String> terms, acknowledgements;
  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'version': version,
    'terms': terms,
    'acknowledgements': acknowledgements,
  };
  factory ProjectAgreement.fromJson(Map<String, dynamic> j) => ProjectAgreement(
    projectId: j['projectId'] as String,
    version: j['version'] as int,
    terms: Map<String, String>.from(j['terms'] as Map),
    acknowledgements: Map<String, String>.from(j['acknowledgements'] as Map),
  );
}

class ProjectMilestone {
  const ProjectMilestone({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.dueAt,
    this.assigneeId,
    this.status = MilestoneStatus.notStarted,
    this.submission = '',
    this.feedback = '',
    this.reviewedBy,
    this.reviewedAt,
  });
  final String id, projectId, title, description, submission, feedback;
  final String? assigneeId, reviewedBy;
  final DateTime dueAt;
  final DateTime? reviewedAt;
  final MilestoneStatus status;
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'description': description,
    'dueAt': dueAt.toIso8601String(),
    'assigneeId': assigneeId,
    'status': status.name,
    'submission': submission,
    'feedback': feedback,
    'reviewedBy': reviewedBy,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
  factory ProjectMilestone.fromJson(Map<String, dynamic> j) => ProjectMilestone(
    id: j['id'] as String,
    projectId: j['projectId'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    dueAt: DateTime.parse(j['dueAt'] as String),
    assigneeId: j['assigneeId'] as String?,
    status: MilestoneStatus.values.byName(j['status'] as String),
    submission: j['submission'] as String,
    feedback: j['feedback'] as String,
    reviewedBy: j['reviewedBy'] as String?,
    reviewedAt: j['reviewedAt'] == null
        ? null
        : DateTime.parse(j['reviewedAt'] as String),
  );
  ProjectMilestone withChanges(Map<String, dynamic> changes) =>
      ProjectMilestone.fromJson({...toJson(), ...changes});
}

class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.projectId,
    required this.reporterId,
    required this.category,
    required this.details,
    required this.createdAt,
    this.status = 'Awaiting demo review',
    this.reviewNote = '',
  });
  static const categories = [
    'Unclear requirements',
    'Unreasonable workload',
    'Payment issue',
    'Inappropriate communication',
    'Project abandonment',
    'Other',
  ];
  final String id, projectId, reporterId, category, details, status, reviewNote;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'reporterId': reporterId,
    'category': category,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'reviewNote': reviewNote,
  };
  factory SafetyReport.fromJson(Map<String, dynamic> j) => SafetyReport(
    id: j['id'] as String,
    projectId: j['projectId'] as String,
    reporterId: j['reporterId'] as String,
    category: j['category'] as String,
    details: j['details'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    status: j['status'] as String,
    reviewNote: j['reviewNote'] as String,
  );
}
