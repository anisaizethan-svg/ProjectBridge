part of '../../main.dart';

/// Offline adapter; UI consumes ReviewRepository so storage can be replaced later.
/// Actor IDs are existing demo identities, not authenticated server credentials.
class LocalReviewRepository extends ChangeNotifier implements ReviewRepository {
  LocalReviewRepository({
    required this.professional,
    required this.settings,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ProfessionalRepository professional;
  final SettingsRepository settings;
  final DateTime Function() clock;
  Future<void> Function()? save;
  final Map<String, ProjectReview> _records = {};
  final Map<String, Map<String, dynamic>> _completions = {};
  final List<Map<String, dynamic>> _reports = [];
  bool _busy = false;
  static const reviewWindow = Duration(days: 14);

  BridgeProject? _project(String id) =>
      professional.projects().where((p) => p.id == id).firstOrNull;
  bool _approved(BridgeProject p) {
    final evidence = professional.passportForProject(p.id);
    return p.completed &&
        p.approved &&
        p.completedAt != null &&
        evidence != null &&
        evidence.clientId == p.clientId &&
        evidence.completedAt.isAtSameMomentAs(p.completedAt!);
  }

  String _key(String project, String reviewer, String target) =>
      jsonEncode([project, reviewer, target]);
  @override
  String nameFor(String id, BridgeProject p) => id == p.clientId
      ? p.client
      : professional.profiles.where((s) => s.id == id).firstOrNull?.name ??
            p.acceptedTeamStudents[id] ??
            p.applicantName ??
            'Student';

  /// Called while saving the existing app snapshot; keys make restart idempotent.
  void synchronize() {
    for (final p in professional.projects().where(_approved)) {
      _completions.putIfAbsent(
        p.id,
        () => {
          'clientId': p.clientId,
          'students': List<String>.from(p.acceptedParticipantIds),
          'completedAt': p.completedAt!.toIso8601String(),
        },
      );
      final members = List<String>.from(
        _completions[p.id]!['students'] as List,
      );
      for (final student in members) {
        settings.emit(
          'review-invite:${p.id}:$student:client',
          p.clientId,
          p,
          NoticeCategory.completion,
          'You can now review ${nameFor(student, p)}\'s work.',
          reviewTargetId: student,
        );
        settings.emit(
          'review-invite:${p.id}:$student:student',
          student,
          p,
          NoticeCategory.completion,
          'Your project is complete. You can now review ${p.client}.',
          reviewTargetId: p.clientId,
        );
      }
    }
    final now = clock();
    for (final entry in _records.entries.toList()) {
      final r = entry.value;
      if (r.publicationStatus == ReviewPublication.published) continue;
      final deadline = publicationDeadline(r.projectId);
      if (deadline == null) continue;
      final counterpart =
          _records[_key(r.projectId, r.revieweeId, r.reviewerId)];
      if (counterpart == null && now.isBefore(deadline)) continue;
      final published = r.withStatus(publishedAt: now);
      _records[entry.key] = published;
      final p = _project(r.projectId);
      if (p != null) {
        settings.emit(
          'review-published:${r.id}',
          r.revieweeId,
          p,
          NoticeCategory.feedback,
          'A new review is available on your profile.',
          reviewProfileId: r.revieweeId,
        );
      }
    }
  }

  @override
  DateTime? publicationDeadline(String projectId) {
    final completion = _completions[projectId];
    final p = _project(projectId);
    final date = completion == null
        ? (p != null && _approved(p) ? p.completedAt : null)
        : DateTime.parse(completion['completedAt'] as String);
    return date?.add(reviewWindow);
  }

  @override
  List<String> targets(String actorId, String projectId) {
    final p = _project(projectId);
    if (p == null || !_approved(p)) return const [];
    final completion = _completions[projectId];
    final students = completion == null
        ? p.acceptedParticipantIds
        : List<String>.from(completion['students'] as List);
    if (actorId == p.clientId) {
      return List.unmodifiable(students.where((id) => id != actorId));
    }
    if (students.contains(actorId)) return [p.clientId];
    return const [];
  }

  @override
  ProjectReview? ownReview(String actorId, String projectId, String targetId) =>
      _records[_key(projectId, actorId, targetId)];
  @override
  List<ProjectReview> publishedFor(String profileId) => List.unmodifiable(
    _records.values
        .where(
          (r) =>
              r.revieweeId == profileId &&
              r.publicationStatus == ReviewPublication.published,
        )
        .toList()
      ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!)),
  );
  @override
  double? averageFor(String profileId) {
    final reviews = publishedFor(profileId);
    return reviews.isEmpty
        ? null
        : reviews.fold<int>(0, (sum, r) => sum + r.overallRating) /
              reviews.length;
  }

  Future<void> _commit(void Function() action) async {
    if (_busy) throw StateError('A review change is being saved. Please wait.');
    _busy = true;
    final oldRecords = Map<String, ProjectReview>.of(_records);
    final oldCompletions = Map<String, Map<String, dynamic>>.of(_completions);
    final oldReports = List<Map<String, dynamic>>.of(_reports);
    final noticeIds = settings.notices.map((n) => n.id).toSet();
    try {
      action();
      synchronize();
      await save?.call();
    } catch (_) {
      _records
        ..clear()
        ..addAll(oldRecords);
      _completions
        ..clear()
        ..addAll(oldCompletions);
      _reports
        ..clear()
        ..addAll(oldReports);
      settings.notices.removeWhere(
        (n) => !noticeIds.contains(n.id) && n.id.startsWith('review-'),
      );
      rethrow;
    } finally {
      _busy = false;
    }
    notifyListeners();
  }

  @override
  Future<void> submit({
    required String actorId,
    required String projectId,
    required String targetId,
    required int overallRating,
    required Map<String, int> categoryRatings,
    String comment = '',
  }) => _commit(() {
    if (!targets(actorId, projectId).contains(targetId) ||
        actorId == targetId) {
      throw StateError(
        'Only accepted participants of an approved completed project can review the other side.',
      );
    }
    if (ownReview(actorId, projectId, targetId) != null) {
      throw StateError(
        'You already submitted a review for this participant on this project.',
      );
    }
    final p = _project(projectId)!;
    final client = actorId == p.clientId;
    final required = client ? studentReviewCategories : clientReviewCategories;
    if (overallRating < 1 ||
        overallRating > 5 ||
        categoryRatings.length != required.length ||
        !categoryRatings.keys.toSet().containsAll(required.keys) ||
        categoryRatings.values.any((v) => v < 1 || v > 5)) {
      throw ArgumentError('Select a rating from 1 to 5 for every category.');
    }
    if (comment.trim().length > 2000) {
      throw ArgumentError('Use no more than 2000 characters.');
    }
    final key = _key(projectId, actorId, targetId);
    _records[key] = ProjectReview(
      id: 'review:$key',
      projectId: projectId,
      reviewerId: actorId,
      revieweeId: targetId,
      reviewerRole: client ? ReviewRole.client : ReviewRole.student,
      revieweeRole: client ? ReviewRole.student : ReviewRole.client,
      overallRating: overallRating,
      categoryRatings: categoryRatings,
      comment: comment.trim(),
      createdAt: clock(),
      reviewerName: nameFor(actorId, p),
      revieweeName: nameFor(targetId, p),
      projectTitle: p.title,
    );
  });
  @override
  Future<void> refresh() async {
    if (_busy) return;
    // Avoid a disk write and UI rebuild if there is no new completion or deadline.
    final due = _records.values.any(
      (r) =>
          r.publicationStatus == ReviewPublication.pending &&
          !(clock().isBefore(publicationDeadline(r.projectId)!)),
    );
    final missing = professional.projects().any(
      (p) => _approved(p) && !_completions.containsKey(p.id),
    );
    if (due || missing) await _commit(() {});
  }

  @override
  Future<void> report({
    required String actorId,
    required String reviewId,
    required String reason,
  }) => _commit(() {
    final entry = _records.entries
        .where(
          (e) =>
              e.value.id == reviewId &&
              e.value.publicationStatus == ReviewPublication.published,
        )
        .firstOrNull;
    if (entry == null) {
      throw StateError('Only published reviews can be reported.');
    }
    if (!professional.profiles.any((p) => p.id == actorId) &&
        !professional.projects().any((p) => p.clientId == actorId)) {
      throw StateError('Use an existing demo account.');
    }
    if (reason.trim().length < 5 || reason.trim().length > 1000) {
      throw ArgumentError('Add a reason of 5–1000 characters.');
    }
    if (_reports.any(
      (r) => r['reviewId'] == reviewId && r['reporterId'] == actorId,
    )) {
      throw StateError('You already reported this review.');
    }
    _reports.add({
      'reviewId': reviewId,
      'reporterId': actorId,
      'reason': reason.trim(),
      'createdAt': clock().toIso8601String(),
      'status': 'Awaiting local moderation',
    });
    _records[entry.key] = entry.value.withStatus(
      moderation: ReviewModeration.reported,
    );
  });
  Map<String, dynamic> toJson() => {
    'records': _records.values.map((r) => r.toJson()).toList(),
    'completions': _completions,
    'reports': _reports,
  };
  void restore(Map<String, dynamic>? j) {
    if (j == null) return;
    _records.clear();
    _completions.clear();
    _reports.clear();
    for (final raw in j['records'] as List? ?? []) {
      final r = ProjectReview.fromJson(Map<String, dynamic>.from(raw as Map));
      _records[_key(r.projectId, r.reviewerId, r.revieweeId)] = r;
    }
    (j['completions'] as Map? ?? {}).forEach(
      (key, value) =>
          _completions[key as String] = Map<String, dynamic>.from(value as Map),
    );
    _reports.addAll(
      (j['reports'] as List? ?? []).map(
        (v) => Map<String, dynamic>.from(v as Map),
      ),
    );
  }
}

class ReviewScope extends InheritedNotifier<ReviewRepository> {
  const ReviewScope({
    super.key,
    required ReviewRepository repository,
    required super.child,
  }) : super(notifier: repository);
  static ReviewRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReviewScope>()?.notifier;
}

extension AcceptedReviewTeam on ProfessionalRepository {
  /// Explicit owner acceptance; recommendations alone never become participants.
  void acceptTeamStudent(
    String actorId,
    String projectId,
    String studentId,
    ChatRepository chats,
  ) {
    final p = project(projectId);
    requireClient(actorId, p);
    requireActive(p);
    if (p.acceptedParticipantIds.isEmpty ||
        p.submitted ||
        p.approved ||
        p.acceptedParticipantIds.contains(studentId) ||
        p.acceptedParticipantIds.length >= p.teamSize ||
        studentId == p.clientId ||
        !profiles.any((s) => s.id == studentId) ||
        (settings?.blocked(actorId, studentId) ?? false)) {
      throw StateError(
        'Only a new student can be accepted into an available team slot before final review.',
      );
    }
    p.acceptedTeamStudents[studentId] = profile(studentId).name;
    chats.ensureProjectChats(p);
    changed();
  }
}
