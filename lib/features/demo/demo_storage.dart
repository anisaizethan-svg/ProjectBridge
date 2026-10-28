part of '../../main.dart';

/// Android private preferences hold one versioned, application-wide snapshot.
/// Tests may inject a channel backed by memory, without touching device data.
class DemoStorage {
  DemoStorage({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('projectbridge/demo_storage');
  final MethodChannel channel;
  Future<void> _writes = Future.value();

  Future<Map<String, dynamic>?> load() async {
    final value = await channel.invokeMethod<String>('load');
    if (value == null) return null;
    final snapshot = jsonDecode(value) as Map<String, dynamic>;
    if (snapshot['version'] != 1) {
      throw const FormatException(
        'Unsupported ProjectBridge demo data version',
      );
    }
    return snapshot;
  }

  Future<void> save(Map<String, dynamic> snapshot) {
    // Encode immediately, then serialize writes so older saves cannot win.
    final value = jsonEncode(snapshot);
    final write = _writes.then(
      (_) => channel.invokeMethod<void>('save', value),
    );
    _writes = write.catchError((Object _) {});
    return write;
  }
}

class DemoSnapshot {
  static Map<String, dynamic> encode(
    List<BridgeProject> projects,
    DemoChatRepository chats, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? professional,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? reviewSystem,
  }) => {
    'version': 1,
    'profile': profile,
    'professional': professional,
    'settings': settings,
    'reviewSystem': reviewSystem,
    'projects': projects.map(projectToJson).toList(),
    'conversations': chats._threads.values
        .map(
          (thread) => {
            'id': thread.id,
            'projectId': thread.project.id,
            'kind': thread.kind.name,
            'createdAt': thread.createdAt.toIso8601String(),
            'updatedAt': thread.updatedAt.toIso8601String(),
            'unread': thread.unread,
            'messages': thread.messages
                .map(
                  (message) => {
                    'id': message.id,
                    'senderId': message.senderId,
                    'senderName': message.senderName,
                    'content': message.content,
                    'kind': message.kind.name,
                    'attachment': message.attachment?.toJson(),
                    'sentAt': message.sentAt.toIso8601String(),
                  },
                )
                .toList(),
          },
        )
        .toList(),
    'reports': chats.reports,
  };

  static List<BridgeProject> projectsFrom(Map<String, dynamic> snapshot) =>
      (snapshot['projects'] as List)
          .map(
            (value) => projectFromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();

  static Map<String, dynamic> projectToJson(BridgeProject p) => {
    'id': p.id,
    'title': p.title,
    'client': p.client,
    'clientId': p.clientId,
    'category': p.category,
    'description': p.description,
    'difficulty': p.difficulty,
    'deadline': p.deadline,
    'expectedResult': p.expectedResult,
    'smartAnalysisVersion': p.smartAnalysisVersion,
    'conditions': p.conditions,
    'role': p.role,
    'detailedDescription': p.detailedDescription,
    'problemToSolve': p.problemToSolve,
    'projectType': p.projectType,
    'workMode': p.workMode,
    'mentorInvolvement': p.mentorInvolvement,
    'compensation': p.compensation,
    'weeklyCommitment': p.weeklyCommitment,
    'optionalSkills': p.optionalSkills,
    'requiredRoles': p.requiredRoles,
    'taskTitle': p.taskTitle,
    'taskDescription': p.taskDescription,
    'taskPriority': p.taskPriority,
    'taskStatus': p.taskStatus,
    'applicationStatus': p.applicationStatus,
    'lifecycleStatus': p.lifecycleStatus,
    'applicantSpecialization': p.applicantSpecialization,
    'originalDescription': p.originalDescription,
    'assistantSuggestedCategory': p.assistantSuggestedCategory,
    'difficultyReason': p.difficultyReason,
    'estimatedTimeline': p.estimatedTimeline,
    'motivation': p.motivation,
    'availability': p.availability,
    'portfolioLink': p.portfolioLink,
    'applicationAvailabilityCode': p.applicationAvailabilityCode,
    'applicantHeadline': p.applicantHeadline,
    'applicationPortfolio': p.applicationPortfolio
        .map((e) => e.toJson())
        .toList(),
    'progressNote': p.progressNote,
    'submissionText': p.submissionText,
    'feedback': p.feedback,
    'applicantId': p.applicantId,
    'acceptedTeamStudents': p.acceptedTeamStudents,
    'applicantName': p.applicantName,
    'skills': p.skills,
    'requiredSkills': p.requiredSkills,
    'suggestedTechnologies': p.suggestedTechnologies,
    'suggestedRoles': p.suggestedRoles,
    'deliverables': p.deliverables,
    'acceptanceCriteria': p.acceptanceCriteria,
    'suggestedTasks': p.suggestedTasks,
    'assumptions': p.assumptions,
    'applicantSkills': p.applicantSkills,
    'smartAssistantAssisted': p.smartAssistantAssisted,
    'isPublished': p.isPublished,
    'isArchived': p.isArchived,
    'portfolioPermission': p.portfolioPermission,
    'saved': p.saved,
    'applied': p.applied,
    'accepted': p.accepted,
    'taskCreated': p.taskCreated,
    'submitted': p.submitted,
    'approved': p.approved,
    'completed': p.completed,
    'teamSize': p.teamSize,
    'createdAt': p.createdAt.toIso8601String(),
    'taskDueDate': p.taskDueDate.toIso8601String(),
    'deadlineAt': p.deadlineAt.toIso8601String(),
    'applicationDeadline': p.applicationDeadline.toIso8601String(),
    'appliedAt': p.appliedAt.toIso8601String(),
    'completedAt': p.completedAt?.toIso8601String(),
    'acceptedAt': p.acceptedAt?.toIso8601String(),
  };

  static BridgeProject projectFromJson(Map<String, dynamic> data) {
    final p = BridgeProject(
      data['title'] as String,
      data['client'] as String,
      data['category'] as String,
      data['description'] as String,
      List<String>.from(data['skills'] as List),
      clientId: data['clientId'] as String?,
    );
    p.id = data['id'] as String;
    p.difficulty = data['difficulty'] as String;
    p.deadline = data['deadline'] as String;
    p.expectedResult = data['expectedResult'] as String;
    p.smartAnalysisVersion = data['smartAnalysisVersion'] as String;
    p.conditions = data['conditions'] as String;
    p.role = data['role'] as String;
    p.detailedDescription = data['detailedDescription'] as String;
    p.problemToSolve = data['problemToSolve'] as String;
    p.projectType = data['projectType'] as String;
    p.workMode = data['workMode'] as String;
    p.mentorInvolvement = data['mentorInvolvement'] as String;
    p.compensation = data['compensation'] as String;
    p.weeklyCommitment = (data['weeklyCommitment'] as num?)?.toDouble();
    p.optionalSkills = List<String>.from(data['optionalSkills'] as List? ?? []);
    p.requiredRoles = List<String>.from(data['requiredRoles'] as List? ?? []);
    p.taskTitle = data['taskTitle'] as String;
    p.taskDescription = data['taskDescription'] as String;
    p.taskPriority = data['taskPriority'] as String;
    p.taskStatus = data['taskStatus'] as String;
    p.applicationStatus = data['applicationStatus'] as String;
    p.lifecycleStatus = data['lifecycleStatus'] as String;
    p.applicantSpecialization = data['applicantSpecialization'] as String;
    p.originalDescription = data['originalDescription'] as String?;
    p.assistantSuggestedCategory =
        data['assistantSuggestedCategory'] as String?;
    p.difficultyReason = data['difficultyReason'] as String?;
    p.estimatedTimeline = data['estimatedTimeline'] as String?;
    p.motivation = data['motivation'] as String?;
    p.availability = data['availability'] as String?;
    p.portfolioLink = data['portfolioLink'] as String?;
    p.applicationAvailabilityCode =
        data['applicationAvailabilityCode'] as String?;
    p.applicantHeadline = data['applicantHeadline'] as String?;
    p.applicationPortfolio = (data['applicationPortfolio'] as List? ?? [])
        .map(
          (e) => PortfolioProject.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    p.progressNote = data['progressNote'] as String?;
    p.submissionText = data['submissionText'] as String?;
    p.feedback = data['feedback'] as String?;
    p.applicantId = data['applicantId'] as String?;
    p.acceptedTeamStudents.addAll(
      Map<String, String>.from(data['acceptedTeamStudents'] as Map? ?? {}),
    );
    p.applicantName = data['applicantName'] as String?;
    p.requiredSkills = List<String>.from(data['requiredSkills'] as List);
    p.suggestedTechnologies = List<String>.from(
      data['suggestedTechnologies'] as List,
    );
    p.suggestedRoles = List<String>.from(data['suggestedRoles'] as List);
    p.deliverables = List<String>.from(data['deliverables'] as List);
    p.acceptanceCriteria = List<String>.from(
      data['acceptanceCriteria'] as List,
    );
    p.suggestedTasks = List<String>.from(data['suggestedTasks'] as List);
    p.assumptions = List<String>.from(data['assumptions'] as List);
    p.applicantSkills = List<String>.from(data['applicantSkills'] as List);
    p.smartAssistantAssisted = data['smartAssistantAssisted'] as bool;
    p.isPublished = data['isPublished'] as bool;
    p.isArchived = data['isArchived'] as bool;
    p.portfolioPermission = data['portfolioPermission'] as bool;
    p.saved = data['saved'] as bool;
    p.applied = data['applied'] as bool;
    p.accepted = data['accepted'] as bool;
    p.taskCreated = data['taskCreated'] as bool;
    p.submitted = data['submitted'] as bool;
    p.approved = data['approved'] as bool;
    p.completed = data['completed'] as bool;
    p.teamSize = data['teamSize'] as int;
    p.createdAt = DateTime.parse(data['createdAt'] as String);
    p.taskDueDate = DateTime.parse(data['taskDueDate'] as String);
    p.deadlineAt = DateTime.parse(data['deadlineAt'] as String);
    p.applicationDeadline = DateTime.parse(
      data['applicationDeadline'] as String,
    );
    p.appliedAt = DateTime.parse(data['appliedAt'] as String);
    p.acceptedAt = data['acceptedAt'] == null
        ? null
        : DateTime.parse(data['acceptedAt'] as String);
    p.completedAt = data['completedAt'] == null
        ? null
        : DateTime.parse(data['completedAt'] as String);
    return p;
  }
}

extension DemoChatRestoration on DemoChatRepository {
  void restore(Map<String, dynamic> snapshot, List<BridgeProject> projects) {
    final byId = {for (final project in projects) project.id: project};
    for (final raw in snapshot['conversations'] as List? ?? []) {
      final data = Map<String, dynamic>.from(raw as Map);
      final project = byId[data['projectId']];
      if (project == null) continue;
      final thread = ProjectChatThread(
        id: data['id'] as String,
        project: project,
        kind: ChatKind.values.byName(data['kind'] as String),
        participants: [project.clientId, ...project.acceptedParticipantIds],
      );
      thread.createdAt = DateTime.parse(data['createdAt'] as String);
      thread.updatedAt = DateTime.parse(data['updatedAt'] as String);
      thread.unread.addAll(Map<String, int>.from(data['unread'] as Map));
      for (final rawMessage in data['messages'] as List) {
        final message = Map<String, dynamic>.from(rawMessage as Map);
        thread.messages.add(
          ChatMessage(
            id: message['id'] as String,
            senderId: message['senderId'] as String,
            senderName: message['senderName'] as String,
            content: message['content'] as String,
            kind: ChatMessageKind.values.byName(message['kind'] as String),
            sentAt: DateTime.parse(message['sentAt'] as String),
            attachment: message['attachment'] == null
                ? null
                : LocalAttachment.fromJson(
                    Map<String, dynamic>.from(message['attachment'] as Map),
                  ),
          ),
        );
      }
      _threads[thread.id] = thread;
      _messageStreams[thread.id] =
          StreamController<List<ChatMessage>>.broadcast();
    }
    reports.addAll(List<String>.from(snapshot['reports'] as List? ?? []));
    // Reconcile authorization and repair missing conversations after restoration.
    for (final project in projects) {
      ensureProjectChats(project);
    }
  }
}
