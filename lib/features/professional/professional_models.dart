/// Public professional data only. No birthdays, private contacts or demographics.
enum Availability { available, limited, unavailable, unknown }

enum EducationStatus { notVerified, pending, demoVerified }

class Skill {
  static const catalog = [
    'Flutter',
    'Dart',
    'Firebase',
    'HTML',
    'CSS',
    'JavaScript',
    'React',
    'Python',
    'UI/UX Design',
    'Figma',
    'Graphic Design',
    'Branding',
    'Video Editing',
    'Content Creation',
    'Project Management',
    'Prototyping',
    'User Research',
    'Backend Development',
    'Database Design',
  ];
  static String key(String value) {
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value)) return '';
    final key = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}+#]', unicode: true),
      '',
    );
    return ['uxui', 'uiux', 'uxuidesign', 'uiuxdesign'].contains(key)
        ? 'uiuxdesign'
        : key;
  }

  static List<String> clean(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (key(value).isNotEmpty && seen.add(key(value)))
          catalog.firstWhere(
            (s) => key(s) == key(value),
            orElse: () => value.trim().replaceAll(RegExp(r'\s+'), ' '),
          ),
    ];
  }
}

class InstitutionAffiliation {
  const InstitutionAffiliation({
    required this.id,
    required this.name,
    this.type = 'College',
    this.city = '',
    this.program = '',
    this.period = '',
    this.status = EducationStatus.notVerified,
  });
  final String id, name, type, city, program, period;
  final EducationStatus status;
  String get label => switch (status) {
    EducationStatus.notVerified => 'Not verified',
    EducationStatus.pending => 'Verification pending · demo review',
    EducationStatus.demoVerified => 'Verified Education · demo only',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'city': city,
    'program': program,
    'period': period,
    'status': status.name,
  };
  factory InstitutionAffiliation.fromJson(Map<String, dynamic> j) =>
      InstitutionAffiliation(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        city: j['city'] as String,
        program: j['program'] as String,
        period: j['period'] as String,
        status: EducationStatus.values.byName(j['status'] as String),
      );
}

class ProfessionalProfile {
  ProfessionalProfile({
    required this.id,
    required this.name,
    this.headline = '',
    this.city = '',
    this.summary = '',
    this.specialization = '',
    List<String> skills = const [],
    this.education,
    this.availability = Availability.unknown,
    this.weeklyHours,
    List<String> preferredRoles = const [],
    this.level = 'Beginner',
    List<String> interests = const [],
    this.isDemo = true,
  }) : skills = List.unmodifiable(Skill.clean(skills)),
       preferredRoles = List.unmodifiable(Skill.clean(preferredRoles)),
       interests = List.unmodifiable(interests);
  final String id, name, headline, city, summary, specialization, level;
  final List<String> skills, preferredRoles, interests;
  final InstitutionAffiliation? education;
  final Availability availability;
  final double? weeklyHours;
  final bool isDemo;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'headline': headline,
    'city': city,
    'summary': summary,
    'specialization': specialization,
    'skills': skills,
    'education': education?.toJson(),
    'availability': availability.name,
    'weeklyHours': weeklyHours,
    'preferredRoles': preferredRoles,
    'level': level,
    'interests': interests,
    'isDemo': isDemo,
  };
  factory ProfessionalProfile.fromJson(Map<String, dynamic> j) =>
      ProfessionalProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        headline: j['headline'] as String? ?? '',
        city: j['city'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        specialization: j['specialization'] as String? ?? '',
        skills: List<String>.from(j['skills'] as List? ?? []),
        education: j['education'] == null
            ? null
            : InstitutionAffiliation.fromJson(
                Map<String, dynamic>.from(j['education'] as Map),
              ),
        availability: Availability.values.byName(
          j['availability'] as String? ?? 'unknown',
        ),
        weeklyHours: (j['weeklyHours'] as num?)?.toDouble(),
        preferredRoles: List<String>.from(j['preferredRoles'] as List? ?? []),
        level: j['level'] as String? ?? 'Beginner',
        interests: List<String>.from(j['interests'] as List? ?? []),
        isDemo: j['isDemo'] as bool? ?? true,
      );
  ProfessionalProfile withChanges(Map<String, dynamic> changes) =>
      ProfessionalProfile.fromJson({...toJson(), ...changes, 'id': id});
}

/// Independent portfolio work is always self-reported; no editable verified flag.
class PortfolioProject {
  const PortfolioProject({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.skills,
    this.url = '',
    this.type = 'Independent',
  });
  final String id, ownerId, title, description, url, type;
  final List<String> skills;
  bool get verified => false;
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'description': description,
    'skills': skills,
    'url': url,
    'type': type,
  };
  factory PortfolioProject.fromJson(Map<String, dynamic> j) => PortfolioProject(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    skills: List<String>.from(j['skills'] as List),
    url: j['url'] as String? ?? '',
    type: j['type'] as String? ?? 'Independent',
  );
}

class ProjectPassport {
  const ProjectPassport({
    required this.id,
    required this.projectId,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.description,
    required this.client,
    required this.clientId,
    required this.role,
    required this.skills,
    required this.tasks,
    required this.deliverables,
    required this.startedAt,
    required this.completedAt,
    required this.review,
  });
  final String id,
      projectId,
      studentId,
      studentName,
      title,
      description,
      client,
      clientId,
      role,
      tasks,
      deliverables,
      review;
  final List<String> skills;
  final DateTime startedAt, completedAt;
  String get verificationLabel => 'Verified · demo client confirmation';
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'studentId': studentId,
    'studentName': studentName,
    'title': title,
    'description': description,
    'client': client,
    'clientId': clientId,
    'role': role,
    'skills': skills,
    'tasks': tasks,
    'deliverables': deliverables,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'review': review,
  };
  factory ProjectPassport.fromJson(Map<String, dynamic> j) => ProjectPassport(
    id: j['id'] as String,
    projectId: j['projectId'] as String,
    studentId: j['studentId'] as String,
    studentName: j['studentName'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    client: j['client'] as String,
    clientId: j['clientId'] as String,
    role: j['role'] as String,
    skills: List<String>.from(j['skills'] as List),
    tasks: j['tasks'] as String,
    deliverables: j['deliverables'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    completedAt: DateTime.parse(j['completedAt'] as String),
    review: j['review'] as String,
  );
}

class ClientWorkReview {
  const ClientWorkReview({
    required this.clientId,
    required this.submission,
    required this.feedback,
    required this.approved,
    required this.reviewedAt,
  });
  final String clientId, submission, feedback;
  final bool approved;
  final DateTime reviewedAt;
  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'submission': submission,
    'feedback': feedback,
    'approved': approved,
    'reviewedAt': reviewedAt.toIso8601String(),
  };
  factory ClientWorkReview.fromJson(Map<String, dynamic> j) => ClientWorkReview(
    clientId: j['clientId'] as String,
    submission: j['submission'] as String,
    feedback: j['feedback'] as String,
    approved: j['approved'] as bool,
    reviewedAt: DateTime.parse(j['reviewedAt'] as String),
  );
}

enum ConnectionStatus { pending, accepted, declined, removed }

class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.updatedAt,
    this.status = ConnectionStatus.pending,
  });
  final String id, senderId, recipientId;
  final DateTime createdAt, updatedAt;
  final ConnectionStatus status;
  bool includes(String id) => senderId == id || recipientId == id;
  String other(String id) => senderId == id ? recipientId : senderId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'recipientId': recipientId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
  };
  factory ConnectionRequest.fromJson(Map<String, dynamic> j) =>
      ConnectionRequest(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        recipientId: j['recipientId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        status: ConnectionStatus.values.byName(j['status'] as String),
      );
}
