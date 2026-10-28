part of '../../main.dart';

enum NoticeCategory {
  applications,
  decisions,
  messages,
  tasks,
  feedback,
  deadlines,
  completion,
  updates,
}

const noticeLabels = <NoticeCategory, String>{
  NoticeCategory.applications: 'New project applications',
  NoticeCategory.decisions: 'Application accepted or rejected',
  NoticeCategory.messages: 'New project messages',
  NoticeCategory.tasks: 'Task assignments',
  NoticeCategory.feedback: 'Submission feedback',
  NoticeCategory.deadlines: 'Project deadlines',
  NoticeCategory.completion: 'Project completion',
  NoticeCategory.updates: 'Project updates',
};

class AccountPreferences {
  bool limitedProfile = false,
      privatePortfolio = false,
      shareContact = false,
      showAvailability = true;
  String contact = '', language = 'English';
  LocalAttachment? photo;
  final Set<String> blocked = {};
  final Map<String, bool> notifications = {};
  Map<String, dynamic> toJson() => {
    'limited': limitedProfile,
    'privatePortfolio': privatePortfolio,
    'shareContact': shareContact,
    'availability': showAvailability,
    'contact': contact,
    'language': language,
    'photo': photo?.toJson(),
    'blocked': blocked.toList(),
    'notifications': notifications,
  };
  factory AccountPreferences.fromJson(Map<String, dynamic> j) =>
      AccountPreferences()
        ..limitedProfile = j['limited'] == true
        ..privatePortfolio = j['privatePortfolio'] == true
        ..shareContact = j['shareContact'] == true
        ..showAvailability = j['availability'] != false
        ..contact = j['contact'] as String? ?? ''
        ..language = 'English'
        ..photo = j['photo'] == null
            ? null
            : LocalAttachment.fromJson(
                Map<String, dynamic>.from(j['photo'] as Map),
              )
        ..blocked.addAll(List<String>.from(j['blocked'] as List? ?? []))
        ..notifications.addAll(
          Map<String, bool>.from(j['notifications'] as Map? ?? {}),
        );
  AccountPreferences();
}

class LocalNotice {
  LocalNotice({
    required this.id,
    required this.recipient,
    required this.projectId,
    required this.category,
    required this.text,
    required this.date,
    this.chatId,
    this.reviewTargetId,
    this.reviewProfileId,
    this.read = false,
  });
  final String id, recipient, projectId, text;
  final String? chatId, reviewTargetId, reviewProfileId;
  final NoticeCategory category;
  final DateTime date;
  bool read;
  Map<String, dynamic> toJson() => {
    'id': id,
    'recipient': recipient,
    'projectId': projectId,
    'category': category.name,
    'text': text,
    'date': date.toIso8601String(),
    'chatId': chatId,
    'reviewTargetId': reviewTargetId,
    'reviewProfileId': reviewProfileId,
    'read': read,
  };
  factory LocalNotice.fromJson(Map<String, dynamic> j) => LocalNotice(
    id: j['id'] as String,
    recipient: j['recipient'] as String,
    projectId: j['projectId'] as String,
    category: NoticeCategory.values.byName(j['category'] as String),
    text: j['text'] as String,
    date: DateTime.parse(j['date'] as String),
    chatId: j['chatId'] as String?,
    reviewTargetId: j['reviewTargetId'] as String?,
    reviewProfileId: j['reviewProfileId'] as String?,
    read: j['read'] == true,
  );
}

/// Local events only. Observing an initial snapshot establishes a baseline, not history.
class SettingsRepository extends ChangeNotifier {
  final Map<String, AccountPreferences> accounts = {};
  final List<LocalNotice> notices = [];
  final List<Map<String, dynamic>> supportReports = [];
  Map<String, Map<String, dynamic>>? _previous;
  Set<String> _messageIds = {};
  Map<String, Map<String, dynamic>>? _milestones;
  final Set<String> _deadlineKeys = {};
  Future<void> Function()? save;
  AccountPreferences account(String id) =>
      accounts.putIfAbsent(id, AccountPreferences.new);
  bool blocked(String first, String second) =>
      account(first).blocked.contains(second) ||
      account(second).blocked.contains(first);
  bool acceptedClient(
    String viewer,
    String owner,
    List<BridgeProject> projects,
  ) => projects.any(
    (p) => p.clientId == viewer && p.acceptedParticipantIds.contains(owner),
  );
  bool canViewProfile(
    String viewer,
    String owner,
    List<BridgeProject> projects,
  ) =>
      viewer == owner ||
      (!blocked(viewer, owner) &&
          (!account(owner).limitedProfile ||
              acceptedClient(viewer, owner, projects)));
  bool canViewPortfolio(String viewer, String owner) =>
      viewer == owner ||
      (viewer.startsWith('client-') &&
          !blocked(viewer, owner) &&
          !account(owner).privatePortfolio);
  bool canViewAvailability(
    String viewer,
    String owner,
    List<BridgeProject> projects,
  ) =>
      viewer == owner ||
      (account(owner).showAvailability &&
          acceptedClient(viewer, owner, projects) &&
          !blocked(viewer, owner));
  bool canViewContact(
    String viewer,
    String owner,
    List<BridgeProject> projects,
  ) =>
      viewer == owner ||
      (account(owner).shareContact &&
          (acceptedClient(viewer, owner, projects) ||
              projects.any(
                (p) =>
                    p.clientId == owner &&
                    p.acceptedParticipantIds.contains(viewer),
              )) &&
          !blocked(viewer, owner));
  Future<void> commit() async {
    await save?.call();
    notifyListeners();
  }

  List<NoticeCategory> categories(bool client) => NoticeCategory.values
      .where(
        (c) => client
            ? ![NoticeCategory.decisions, NoticeCategory.tasks].contains(c)
            : c != NoticeCategory.applications,
      )
      .toList();
  bool enabled(String id, NoticeCategory category) =>
      account(id).notifications[category.name] ?? true;
  void emit(
    String key,
    String recipient,
    BridgeProject p,
    NoticeCategory category,
    String text, {
    String? chatId,
    String? reviewTargetId,
    String? reviewProfileId,
  }) {
    if (!enabled(recipient, category) || notices.any((n) => n.id == key)) {
      return;
    }
    notices.add(
      LocalNotice(
        id: key,
        recipient: recipient,
        projectId: p.id,
        category: category,
        text: text,
        date: DateTime.now(),
        chatId: chatId,
        reviewTargetId: reviewTargetId,
        reviewProfileId: reviewProfileId,
      ),
    );
  }

  void observe(
    List<BridgeProject> projects,
    DemoChatRepository chats, {
    DateTime? now,
    ProfessionalRepository? professional,
  }) {
    final current = {
      for (final p in projects) p.id: DemoSnapshot.projectToJson(p),
    };
    final previous = _previous;
    if (previous != null) {
      for (final p in projects) {
        final old = previous[p.id];
        if (old == null) continue;
        final student = p.applicantId;
        void both(String key, NoticeCategory c, String text) {
          emit('$key:client', p.clientId, p, c, text);
          if (student != null) emit('$key:student', student, p, c, text);
        }

        if (old['applied'] != true && p.applied) {
          emit(
            'apply:${p.id}:${p.appliedAt.toIso8601String()}',
            p.clientId,
            p,
            NoticeCategory.applications,
            '${p.applicantName ?? 'A student'} applied to ${p.title}.',
          );
        }
        if (old['applicationStatus'] != p.applicationStatus &&
            student != null &&
            ['Accepted', 'Rejected'].contains(p.applicationStatus)) {
          emit(
            'decision:${p.id}:${p.applicationStatus}',
            student,
            p,
            NoticeCategory.decisions,
            'Your application to ${p.title} was ${p.applicationStatus.toLowerCase()}.',
          );
        }
        if (old['taskCreated'] != true && p.taskCreated && student != null) {
          emit(
            'task:${p.id}:${p.taskTitle}',
            student,
            p,
            NoticeCategory.tasks,
            'New task: ${p.taskTitle} · ${p.title}.',
          );
        }
        if (old['submitted'] != true && p.submitted) {
          emit(
            'submit:${p.id}:${p.submissionText}',
            p.clientId,
            p,
            NoticeCategory.feedback,
            'A student submitted a project deliverable for ${p.title}.',
          );
        }
        if (old['feedback'] != p.feedback &&
            p.feedback != null &&
            student != null) {
          emit(
            'feedback:${p.id}:${p.feedback}',
            student,
            p,
            NoticeCategory.feedback,
            'New submission feedback for ${p.title}.',
          );
        }
        if (old['completed'] != true && p.completed) {
          both(
            'complete:${p.id}',
            NoticeCategory.completion,
            '${p.title} is complete.',
          );
        }
        if (old['taskStatus'] != p.taskStatus ||
            old['lifecycleStatus'] != p.lifecycleStatus ||
            old['description'] != p.description) {
          both(
            'update:${p.id}:${DateTime.now().microsecondsSinceEpoch}',
            NoticeCategory.updates,
            '${p.title} has a project update.',
          );
        }
      }
      for (final thread in chats._threads.values) {
        for (final m in thread.messages.where(
          (m) => !_messageIds.contains(m.id),
        )) {
          for (final recipient in thread.participants.where(
            (id) => id != m.senderId,
          )) {
            if (!blocked(m.senderId, recipient)) {
              emit(
                'message:${thread.id}:${m.id}:$recipient',
                recipient,
                thread.project,
                NoticeCategory.messages,
                'New message from ${m.senderName} in ${thread.project.title}.',
                chatId: thread.id,
              );
            }
          }
        }
      }
    }
    if (professional != null) {
      final beforeMilestones = _milestones;
      final milestones = {
        for (final m in professional._milestones.values) m.id: m.toJson(),
      };
      if (beforeMilestones != null) {
        for (final m in professional._milestones.values) {
          final p = projects.where((p) => p.id == m.projectId).firstOrNull;
          if (p == null) continue;
          final old = beforeMilestones[m.id];
          if ((old == null || old['assigneeId'] != m.assigneeId) &&
              m.assigneeId != null) {
            emit(
              'milestone:${m.id}:assigned:${m.assigneeId}',
              m.assigneeId!,
              p,
              NoticeCategory.tasks,
              'Assigned milestone: ${m.title} · ${p.title}.',
            );
          }
          if (old != null &&
              old['status'] != m.status.name &&
              m.status == MilestoneStatus.submitted) {
            emit(
              'milestone:${m.id}:submitted:${m.submission}',
              p.clientId,
              p,
              NoticeCategory.feedback,
              'A student submitted ${m.title} for ${p.title}.',
            );
          }
          if (old != null &&
              old['feedback'] != m.feedback &&
              m.feedback.isNotEmpty &&
              m.assigneeId != null) {
            emit(
              'milestone:${m.id}:feedback:${m.reviewedAt}',
              m.assigneeId!,
              p,
              NoticeCategory.feedback,
              'Feedback on ${m.title} · ${p.title}.',
            );
          }
        }
      }
      _milestones = milestones;
    }
    _previous = current;
    _messageIds = chats._threads.values
        .expand((t) => t.messages.map((m) => m.id))
        .toSet();
    // Due-date reminders are computed from actual active assignments while the app runs.
    final today = now ?? DateTime.now();
    for (final p in projects.where(
      (p) =>
          p.accepted &&
          !p.completed &&
          !['Cancelled', 'Closed'].contains(p.lifecycleStatus),
    )) {
      final remaining = p.deadlineAt.difference(today);
      final key = 'deadline:${p.id}:${p.deadlineAt.toIso8601String()}';
      if (remaining <= const Duration(days: 2) &&
          !_deadlineKeys.contains(key)) {
        _deadlineKeys.add(key);
        emit(
          '$key:client',
          p.clientId,
          p,
          NoticeCategory.deadlines,
          '${p.title} is due ${p.deadlineAt.toLocal().toString().split(' ').first}.',
        );
        if (p.applicantId != null) {
          emit(
            '$key:student',
            p.applicantId!,
            p,
            NoticeCategory.deadlines,
            '${p.title} is due ${p.deadlineAt.toLocal().toString().split(' ').first}.',
          );
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'accounts': accounts.map((k, v) => MapEntry(k, v.toJson())),
    'notices': notices.map((n) => n.toJson()).toList(),
    'reports': supportReports,
    'deadlines': _deadlineKeys.toList(),
  };
  void restore(Map<String, dynamic>? j) {
    if (j == null) return;
    (j['accounts'] as Map? ?? {}).forEach(
      (k, v) => accounts[k as String] = AccountPreferences.fromJson(
        Map<String, dynamic>.from(v as Map),
      ),
    );
    notices.addAll(
      (j['notices'] as List? ?? []).map(
        (v) => LocalNotice.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    supportReports.addAll(
      (j['reports'] as List? ?? []).map(
        (v) => Map<String, dynamic>.from(v as Map),
      ),
    );
    _deadlineKeys.addAll(List<String>.from(j['deadlines'] as List? ?? []));
  }
}

class SettingsScope extends InheritedNotifier<SettingsRepository> {
  const SettingsScope({
    super.key,
    required SettingsRepository repository,
    required super.child,
  }) : super(notifier: repository);
  static SettingsRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
