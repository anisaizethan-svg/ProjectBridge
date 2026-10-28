part of '../../main.dart';

/// Shared Stage 2 repository. Identity checks model demo roles, not server auth.
class ProfessionalRepository extends ChangeNotifier {
  SettingsRepository? settings;
  ProfessionalRepository({required this.projects}) {
    final demos = [
      ProfessionalProfile(
        id: 'student-daria',
        name: 'Daria',
        headline: 'Flutter Developer | UI/UX Enthusiast',
        specialization: 'Mobile Development',
        summary: 'Mobile development student passionate about useful digital products and real project experience.',
        skills: ['Flutter', 'Dart', 'Firebase'],
        preferredRoles: ['Mobile Developer'],
        education: const InstitutionAffiliation(
          id: 'demo-college',
          name: 'Demo College',
          program: 'Mobile Development',
          period: 'Year 2',
        ),
      ),
      ProfessionalProfile(
        id: 'student-aruzhan',
        name: 'Aruzhan',
        headline: 'UI/UX Designer',
        specialization: 'UI/UX Design',
        skills: ['Figma', 'UI/UX Design', 'Prototyping', 'User Research'],
        preferredRoles: ['UI/UX Designer'],
        availability: Availability.available,
        weeklyHours: 8,
      ),
      ProfessionalProfile(
        id: 'student-dias',
        name: 'Dias',
        headline: 'Web Developer',
        specialization: 'Web Development',
        skills: ['HTML', 'CSS', 'JavaScript', 'React'],
        preferredRoles: ['Web Developer'],
        availability: Availability.available,
        weeklyHours: 8,
      ),
      ProfessionalProfile(
        id: 'student-amina',
        name: 'Amina',
        headline: 'Graphic Designer',
        specialization: 'Graphic Design',
        skills: ['Graphic Design', 'Branding', 'Illustrator'],
        preferredRoles: ['Graphic Designer'],
        availability: Availability.limited,
        weeklyHours: 4,
      ),
      ProfessionalProfile(
        id: 'student-alikhan',
        name: 'Alikhan',
        headline: 'Backend Developer',
        specialization: 'Backend Development',
        skills: ['Python', 'Backend Development', 'Database Design'],
        preferredRoles: ['Backend Developer'],
        availability: Availability.available,
        weeklyHours: 6,
      ),
    ];
    _profiles.addAll({for (final profile in demos) profile.id: profile});
  }
  final List<BridgeProject> Function() projects;
  final Map<String, ProfessionalProfile> _profiles = {};
  final Map<String, ConnectionRequest> _connections = {};
  final Map<String, PortfolioProject> _portfolio = {};
  List<ProfessionalProfile> get profiles => List.unmodifiable(_profiles.values);
  ProfessionalProfile profile(String id) =>
      _profiles[id] ?? (throw StateError('Profile not found.'));
  static int _sequence = 0;
  String newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  void owner(String actorId, String ownerId) {
    if (actorId != ownerId) {
      throw StateError('Only the owner can change this record.');
    }
  }

  void saveProfile(String actorId, ProfessionalProfile value) {
    owner(actorId, value.id);
    if (value.name.trim().isEmpty ||
        (value.weeklyHours != null &&
            (!value.weeklyHours!.isFinite ||
                value.weeklyHours! < 0 ||
                value.weeklyHours! > 80))) {
      throw ArgumentError('Enter a name and weekly hours between 0 and 80.');
    }
    final previous = _profiles[value.id];
    var education = value.education;
    // Public editing cannot create a verification credential or retain one after an education change.
    if (education != null) {
      final unchanged =
          previous?.education?.name == education.name &&
          previous?.education?.program == education.program &&
          previous?.education?.period == education.period &&
          previous?.education?.id == education.id &&
          previous?.education?.type == education.type &&
          previous?.education?.city == education.city;
      education = InstitutionAffiliation(
        id: education.id,
        name: education.name,
        type: education.type,
        city: education.city,
        program: education.program,
        period: education.period,
        status: unchanged
            ? previous!.education!.status
            : EducationStatus.notVerified,
      );
    }
    _profiles[value.id] = value.withChanges({'education': education?.toJson()});
    notifyListeners();
  }

  List<PortfolioProject> portfolioFor(String id) =>
      List.unmodifiable(_portfolio.values.where((p) => p.ownerId == id));
  void savePortfolio(String actorId, PortfolioProject value) {
    owner(actorId, value.ownerId);
    final previous = _portfolio[value.id];
    if (previous != null) owner(actorId, previous.ownerId);
    if (value.title.trim().isEmpty) {
      throw ArgumentError('A project title is required.');
    }
    _portfolio[value.id] = value;
    notifyListeners();
  }

  void removePortfolio(String actorId, String id) {
    final value = _portfolio[id] ?? (throw StateError('Project not found.'));
    owner(actorId, value.ownerId);
    _portfolio.remove(id);
    notifyListeners();
  }

  final Map<String, ProjectAgreement> _agreements = {};
  final Map<String, ProjectMilestone> _milestones = {};
  final Map<String, SafetyReport> _reports = {};
  final Map<String, String> _withdrawals = {};
  final List<Map<String, String>> _history = [];
  void changed() => notifyListeners();

  final Map<String, ProjectPassport> _passports = {};
  final Map<String, ClientWorkReview> _reviews = {};
  final List<Map<String, String>> _trustAudit = [];
  List<ProjectPassport> passportsFor(String id) =>
      List.unmodifiable(_passports.values.where((p) => p.studentId == id));
  List<ProjectPassport> visiblePassports(String viewerId, String studentId) =>
      List.unmodifiable(
        passportsFor(studentId).where(
          (passport) =>
              viewerId == studentId ||
              ((settings?.canViewPortfolio(viewerId, studentId) ?? true) &&
                  (viewerId == passport.clientId ||
                      projects().any(
                        (p) =>
                            p.id == passport.projectId && p.portfolioPermission,
                      ))),
        ),
      );
  ProjectPassport? passportForProject(String id) => _passports[id];

  void requestEducationReview(String actorId) {
    final p = profile(actorId);
    final education =
        p.education ?? (throw StateError('Add an optional institution first.'));
    if (education.status == EducationStatus.demoVerified) return;
    _profiles[actorId] = p.withChanges({
      'education': {
        ...education.toJson(),
        'status': EducationStatus.pending.name,
      },
    });
    notifyListeners();
  }

  void demoVerifyEducation(String actorId, String studentId) {
    if (actorId != 'demo-administrator') {
      throw StateError('Demo administrator access is required.');
    }
    final p = profile(studentId);
    final education =
        p.education ?? (throw StateError('No institution supplied.'));
    if (education.status != EducationStatus.pending) {
      throw StateError('Request a demo review first.');
    }
    _profiles[studentId] = p.withChanges({
      'education': {
        ...education.toJson(),
        'status': EducationStatus.demoVerified.name,
      },
    });
    _trustAudit.add({
      'studentId': studentId,
      'actorId': actorId,
      'time': DateTime.now().toIso8601String(),
      'action': 'Simulated education confirmation',
    });
    notifyListeners();
  }

  BridgeProject project(String id) => projects().firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('Project not found.'),
  );
  void requireClient(String actorId, BridgeProject p) {
    owner(actorId, p.clientId);
  }

  void requireStudent(String actorId, BridgeProject p) {
    if (!p.acceptedParticipantIds.contains(actorId)) {
      throw StateError('Accepted project membership is required.');
    }
  }

  void saveLegacyTask(
    String actorId,
    String projectId,
    String title,
    String description,
    String priority,
    DateTime dueAt,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    if (p.acceptedParticipantIds.isEmpty ||
        title.trim().isEmpty ||
        description.trim().isEmpty) {
      throw StateError(
        'Accept a student and provide a clear task and deliverable.',
      );
    }
    p.taskTitle = title.trim();
    p.taskDescription = description.trim();
    p.taskPriority = priority;
    p.taskDueDate = dueAt;
    p.taskCreated = true;
    p.taskStatus = 'To Do';
    p.submitted = false;
    p.approved = false;
    p.submissionText = null;
    p.feedback = null;
    _reviews.remove(projectId);
    final agreement = _agreements[projectId];
    if (agreement != null) {
      _agreements[projectId] = ProjectAgreement(
        projectId: projectId,
        version: agreement.version + 1,
        terms: {
          ...agreement.terms,
          'Milestones':
              '${p.taskTitle}: ${p.taskDescription} · ${dueAt.toIso8601String().split('T').first}',
        },
      );
    }
    _record(
      actorId,
      p,
      'Assigned or updated task: ${p.taskTitle}. Scope acknowledgement is required.',
    );
    notifyListeners();
  }

  void submitWork(
    String actorId,
    String projectId,
    String text,
    String progress,
  ) {
    final p = project(projectId);
    requireStudent(actorId, p);
    requireAgreement(p);
    if (!p.taskCreated || p.completed || text.trim().isEmpty) {
      throw StateError(
        'Submit an assigned, unfinished task with a deliverable.',
      );
    }
    p.submissionText = text.trim();
    p.progressNote = progress.trim();
    p.submitted = true;
    p.approved = false;
    p.feedback = null;
    p.taskStatus = 'Submitted';
    _reviews.remove(projectId);
    notifyListeners();
  }

  void reviewWork(
    String actorId,
    String projectId,
    bool approve,
    String feedback,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireAgreement(p);
    if (!p.submitted ||
        !p.taskCreated ||
        p.submissionText == null ||
        p.acceptedParticipantIds.isEmpty ||
        p.completed) {
      throw StateError('An accepted student must submit assigned work first.');
    }
    if (!approve && feedback.trim().isEmpty) {
      throw StateError('Explain the requested changes.');
    }
    final note = feedback.trim().isEmpty
        ? 'Approved by the demo client.'
        : feedback.trim();
    _reviews[projectId] = ClientWorkReview(
      clientId: actorId,
      submission: p.submissionText!,
      feedback: note,
      approved: approve,
      reviewedAt: DateTime.now(),
    );
    p.approved = approve;
    p.submitted = approve;
    p.feedback = note;
    p.taskStatus = approve ? 'Approved' : 'Revision Requested';
    notifyListeners();
  }

  ProjectPassport completeProject(String actorId, String projectId) {
    final p = project(projectId);
    requireClient(actorId, p);
    final existing = _passports[projectId];
    if (existing != null) return existing;
    requireAgreement(p);
    final review = _reviews[projectId];
    final milestones = milestonesFor(actorId, projectId);
    final milestonesApproved =
        milestones.isNotEmpty &&
        milestones.every(
          (m) =>
              m.status == MilestoneStatus.approved &&
              m.reviewedBy == actorId &&
              m.reviewedAt != null &&
              p.acceptedParticipantIds.contains(m.assigneeId) &&
              m.submission.isNotEmpty,
        );
    final legacyApproved =
        p.taskCreated &&
        p.submitted &&
        p.approved &&
        review != null &&
        review.approved &&
        review.clientId == actorId &&
        review.submission == p.submissionText;
    if (p.acceptedParticipantIds.isEmpty ||
        (milestones.isEmpty ? !legacyApproved : !milestonesApproved)) {
      throw StateError(
        'Client review and explicit approval of every submitted milestone are required.',
      );
    }
    final completed = DateTime.now();
    final passport = ProjectPassport(
      id: 'passport-${p.id}-${p.applicantId}',
      projectId: p.id,
      studentId: p.applicantId!,
      studentName: p.applicantName ?? profile(p.applicantId!).name,
      title: p.title,
      description: p.description,
      client: p.client,
      clientId: p.clientId,
      role: p.role,
      skills: List.unmodifiable(p.skills),
      tasks: milestones.isEmpty
          ? p.taskTitle
          : milestones.map((m) => m.title).join('\n'),
      deliverables: milestones.isEmpty
          ? p.submissionText!
          : milestones.map((m) => m.submission).join('\n'),
      startedAt:
          p.acceptedAt ??
          DateTime.parse(_agreements[p.id]!.acknowledgements[p.applicantId!]!),
      completedAt: completed,
      review: milestones.isEmpty
          ? review!.feedback
          : milestones.map((m) => m.feedback).join('\n'),
    );
    _passports[projectId] = passport;
    p.completed = true;
    p.approved = true;
    p.completedAt = completed;
    p.lifecycleStatus = 'Completed';
    _record(
      actorId,
      p,
      'Client explicitly approved completion and issued a demo passport.',
    );
    notifyListeners();
    return passport;
  }

  String passportStatus(BridgeProject p) {
    if (_passports.containsKey(p.id)) {
      return 'Verified · demo client confirmation';
    }
    if (p.completed) return 'Completed · no verification evidence';
    final milestones = _milestones.values
        .where((m) => m.projectId == p.id)
        .toList();
    if (milestones.any((m) => m.status == MilestoneStatus.needsChanges)) {
      return 'Changes requested';
    }
    if (milestones.any((m) => m.status == MilestoneStatus.submitted)) {
      return 'Submitted for review';
    }
    if (milestones.isNotEmpty &&
        milestones.every((m) => m.status == MilestoneStatus.approved)) {
      return 'Work approved · awaiting client completion';
    }
    if (p.taskStatus == 'Revision Requested') return 'Changes requested';
    if (p.submitted) return 'Submitted for review';
    return 'In progress';
  }

  Map<String, dynamic> toJson() => {
    'connections': _connections.values.map((c) => c.toJson()).toList(),
    'agreements': _agreements.values.map((a) => a.toJson()).toList(),
    'milestones': _milestones.values.map((m) => m.toJson()).toList(),
    'safetyReports': _reports.values.map((r) => r.toJson()).toList(),
    'withdrawals': _withdrawals,
    'history': _history,
    'passports': _passports.values.map((p) => p.toJson()).toList(),
    'reviews': _reviews.map((key, value) => MapEntry(key, value.toJson())),
    'trustAudit': _trustAudit,
    'profiles': _profiles.values.map((p) => p.toJson()).toList(),
    'portfolio': _portfolio.values.map((p) => p.toJson()).toList(),
  };
  void restore(Map<String, dynamic> data) {
    for (final raw in data['connections'] as List? ?? []) {
      final c = ConnectionRequest.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _connections[c.id] = c;
    }
    for (final raw in data['agreements'] as List? ?? []) {
      final a = ProjectAgreement.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _agreements[a.projectId] = a;
    }
    for (final raw in data['milestones'] as List? ?? []) {
      final m = ProjectMilestone.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _milestones[m.id] = m;
    }
    for (final raw in data['safetyReports'] as List? ?? []) {
      final r = SafetyReport.fromJson(Map<String, dynamic>.from(raw as Map));
      _reports[r.id] = r;
    }
    _withdrawals.addAll(
      Map<String, String>.from(data['withdrawals'] as Map? ?? {}),
    );
    _history.addAll(
      (data['history'] as List? ?? []).map(
        (v) => Map<String, String>.from(v as Map),
      ),
    );
    for (final raw in data['passports'] as List? ?? []) {
      final p = ProjectPassport.fromJson(Map<String, dynamic>.from(raw as Map));
      _passports[p.projectId] = p;
    }
    (data['reviews'] as Map? ?? {}).forEach(
      (key, value) => _reviews[key as String] = ClientWorkReview.fromJson(
        Map<String, dynamic>.from(value as Map),
      ),
    );
    _trustAudit.addAll(
      (data['trustAudit'] as List? ?? []).map(
        (v) => Map<String, String>.from(v as Map),
      ),
    );
    for (final raw in data['profiles'] as List? ?? []) {
      final p = ProfessionalProfile.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _profiles[p.id] = p;
    }
    for (final raw in data['portfolio'] as List? ?? []) {
      final p = PortfolioProject.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _portfolio[p.id] = p;
    }
  }
}

class ProfessionalScope extends InheritedNotifier<ProfessionalRepository> {
  const ProfessionalScope({
    super.key,
    required ProfessionalRepository repository,
    required super.child,
  }) : super(notifier: repository);
  static ProfessionalRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfessionalScope>()?.notifier;
}
