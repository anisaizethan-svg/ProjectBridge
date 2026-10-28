import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

import 'features/professional/professional_models.dart';
import 'features/professional/matching_service.dart';
import 'features/professional/safety_models.dart';
import 'features/project_assistant/models/smart_project_analysis.dart';
import 'features/project_assistant/services/local_smart_project_assistant.dart';

export 'features/project_assistant/models/smart_project_analysis.dart';
export 'features/project_assistant/services/local_smart_project_assistant.dart';

export 'features/professional/professional_models.dart';
export 'features/professional/matching_service.dart';
export 'features/professional/safety_models.dart';

part 'features/demo/demo_storage.dart';
part 'features/reviews/review_models.dart';
part 'features/reviews/review_repository.dart';
part 'features/reviews/review_screens.dart';
part 'features/profile/profile_overview.dart';
part 'features/settings/settings_repository.dart';
part 'features/settings/settings_screens.dart';
part 'features/attachments/local_attachments.dart';
part 'features/applications/application_sheet.dart';
part 'features/professional/professional_repository.dart';
part 'features/professional/professional_screens.dart';
part 'features/professional/safety_repository.dart';
part 'features/professional/safety_screens.dart';
part 'features/professional/matching_screens.dart';
part 'features/professional/connections.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAppBootstrap.initializeIfConfigured();
  final storage = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? DemoStorage()
      : null;
  try {
    final snapshot = await storage?.load();
    runApp(ProjectBridgeApp(storage: storage, snapshot: snapshot));
  } catch (_) {
    // Keep an unreadable saved snapshot intact instead of replacing it with seeds.
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your saved demo could not be loaded.'),
                  const Text(
                    'Your data is preserved. Restart the app to try again.',
                  ),
                  TextButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const violet = Color(0xFF6C5CE7);
const ink = Color(0xFF202235);
const muted = Color(0xFF7B8094);
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
);
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

class FirebaseAppBootstrap {
  static bool initialized = false;
  static String? initializationError;

  static Future<void> initializeIfConfigured() async {
    if (firebaseApiKey.isEmpty ||
        firebaseAppId.isEmpty ||
        firebaseMessagingSenderId.isEmpty ||
        firebaseProjectId.isEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseMessagingSenderId,
          projectId: firebaseProjectId,
        ),
      );
      initialized = true;
    } catch (_) {
      initializationError = 'Firebase could not initialize. Check the Firebase app options and Android app registration.';
    }
  }
}

class ProjectBridgeApp extends StatefulWidget {
  const ProjectBridgeApp({super.key, this.storage, this.snapshot});
  final DemoStorage? storage;
  final Map<String, dynamic>? snapshot;
  @override
  State<ProjectBridgeApp> createState() => _ProjectBridgeAppState();
}

class _ProjectBridgeAppState extends State<ProjectBridgeApp>
    with WidgetsBindingObserver {
  Timer? _reviewTimer;
  late final reviews = LocalReviewRepository(
    professional: professional,
    settings: settings,
  );
  final settings = SettingsRepository();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool clientMode = false;
  int tab = 0;
  String studentName = 'Daria';
  String clientOrganization = 'Demo Coffee';
  String clientIndustry = 'Food & Beverage';
  String clientDescription =
      'A neighborhood coffee shop collaborating with emerging talent.';
  String clientWebsite = '';
  String college = 'Demo College';
  String specialization = 'Mobile Development';
  String course = 'Year 2';
  String biography =
      'Aspiring mobile developer building useful things with Flutter.';
  String experienceLevel = 'Beginner';
  List<String> studentSkills = ['Flutter', 'Dart', 'Firebase'];
  List<String> interests = ['Mobile apps', 'Education'];
  final samples = <WorkSample>[];
  final DemoChatRepository chatRepository = DemoChatRepository();
  late final ProjectBridgeRepository repository = DemoProjectBridgeRepository([
    BridgeProject(
      'Coffee Shop Website',
      'Demo Coffee',
      'Web Development',
      'Create a welcoming, mobile-friendly website for a neighborhood coffee shop.',
      ['HTML', 'CSS', 'JavaScript'],
    ),
    BridgeProject(
      'Lost & Found App',
      'Demo College',
      'Mobile Development',
      'Help students reconnect with belongings through a simple campus app.',
      ['Flutter', 'Dart', 'Firebase'],
    ),
    BridgeProject(
      'Event Poster Design',
      'Demo Events',
      'Graphic Design',
      'Design a clear and lively poster system for the campus spring fair.',
      ['Figma', 'Graphic Design'],
    ),
  ]);
  late final ProfessionalRepository professional = ProfessionalRepository(
    projects: () => projects,
  );
  List<BridgeProject> get projects => repository.projects;
  List<BridgeProject> get clientProjects => projects
      .where((project) => project.clientId == 'client-demo-coffee')
      .toList();

  @override
  void initState() {
    super.initState();
    final snapshot = widget.snapshot;
    if (snapshot != null) {
      projects
        ..clear()
        ..addAll(DemoSnapshot.projectsFrom(snapshot));
      chatRepository.restore(snapshot, projects);
      final profile = snapshot['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        studentName = profile['studentName'] as String? ?? studentName;
        studentSkills = List<String>.from(
          profile['studentSkills'] as List? ?? studentSkills,
        );
        clientOrganization =
            profile['clientOrganization'] as String? ?? clientOrganization;
        clientIndustry = profile['clientIndustry'] as String? ?? clientIndustry;
        clientDescription =
            profile['clientDescription'] as String? ?? clientDescription;
        clientWebsite = profile['clientWebsite'] as String? ?? clientWebsite;
      }
    }
    final professionalData = snapshot?['professional'] as Map<String, dynamic>?;
    if (professionalData != null) {
      professional.restore(professionalData);
    } else {
      final initial = professional.profile('student-daria');
      professional.saveProfile(
        'student-daria',
        initial.withChanges({
          'name': studentName,
          'skills': studentSkills,
          'summary': biography,
          'specialization': specialization,
          'education': college.trim().isEmpty
              ? null
              : InstitutionAffiliation(
                  id: 'daria-education',
                  name: college,
                  program: specialization,
                  period: course,
                ).toJson(),
        }),
      );
    }
    reviews.restore(snapshot?['reviewSystem'] as Map<String, dynamic>?);
    reviews.save = saveApplicationSnapshot;
    WidgetsBinding.instance.addObserver(this);
    reviews.addListener(_reviewsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshReviews();
    });
    settings.restore(snapshot?['settings'] as Map<String, dynamic>?);
    professional.settings = settings;
    chatRepository.settings = settings;
    chatRepository.saveConfirmed = saveApplicationSnapshot;
    chatRepository.nameFor = accountName;
    settings.observe(projects, chatRepository, professional: professional);
    settings.save = saveApplicationSnapshot;
    settings.addListener(_settingsChanged);
    _syncProfessional();
    professional.addListener(_professionalChanged);
    chatRepository.onChanged = persist;
  }

  void _reviewsChanged() {
    if (!mounted) return;
    setState(() {});
    _reviewTimer?.cancel();
    final deadlines =
        reviews._records.values
            .where((r) => r.publicationStatus == ReviewPublication.pending)
            .map((r) => reviews.publicationDeadline(r.projectId)!)
            .toList()
          ..sort();
    if (deadlines.isNotEmpty) {
      final delay = deadlines.first.difference(DateTime.now());
      _reviewTimer = Timer(
        delay.isNegative ? const Duration(seconds: 1) : delay,
        _refreshReviews,
      );
    }
  }

  Future<void> _refreshReviews() async {
    try {
      await reviews.refresh();
      if (mounted) _reviewsChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(navigatorKey.currentContext!)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Review updates could not be saved. Try again when you reopen Reviews.',
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshReviews();
  }

  String accountName(String id, String fallback) => id == 'client-demo-coffee'
      ? clientOrganization
      : professional._profiles[id]?.name ?? fallback;
  void _settingsChanged() {
    if (mounted) setState(() {});
    professional.changed();
  }

  void _syncProfessional() {
    final profile = professional.profile('student-daria');
    studentName = profile.name;
    studentSkills = List.of(profile.skills);
    biography = profile.summary;
    specialization = profile.specialization;
    college = profile.education?.name ?? '';
    course = profile.education?.period ?? '';
    experienceLevel = profile.level;
    interests = List.of(profile.interests);
  }

  void _professionalChanged() {
    if (!mounted) return;
    setState(_syncProfessional);
    persist();
  }

  Future<void> saveApplicationSnapshot() async {
    final reviewBefore =
        jsonDecode(jsonEncode(reviews.toJson())) as Map<String, dynamic>;
    final previous = settings._previous;
    final messages = settings._messageIds;
    final milestones = settings._milestones;
    final oldNotices = settings.notices.map((n) => n.id).toSet();
    final deadlines = Set<String>.from(settings._deadlineKeys);
    reviews.synchronize();
    settings.observe(projects, chatRepository, professional: professional);
    final observed = settings._previous;
    final newNotices = settings.notices
        .where((n) => !oldNotices.contains(n.id))
        .map((n) => n.id)
        .toSet();
    try {
      await widget.storage?.save(
        DemoSnapshot.encode(
          projects,
          chatRepository,
          profile: {
            'studentName': studentName,
            'studentSkills': studentSkills,
            'clientOrganization': clientOrganization,
            'clientIndustry': clientIndustry,
            'clientDescription': clientDescription,
            'clientWebsite': clientWebsite,
          },
          professional: professional.toJson(),
          settings: settings.toJson(),
          reviewSystem: reviews.toJson(),
        ),
      );
    } catch (_) {
      reviews.restore(reviewBefore);
      settings.notices.removeWhere((n) => newNotices.contains(n.id));
      if (identical(settings._previous, observed)) {
        settings._previous = previous;
        settings._messageIds = messages;
        settings._milestones = milestones;
        settings._deadlineKeys
          ..clear()
          ..addAll(deadlines);
      }
      rethrow;
    }
  }

  void persist() {
    unawaited(
      saveApplicationSnapshot().catchError((Object error) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save demo data. Keep the app open and try again.',
              ),
            ),
          );
        }
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reviewTimer?.cancel();
    reviews.removeListener(_reviewsChanged);
    reviews.dispose();
    settings.removeListener(_settingsChanged);
    settings.dispose();
    chatRepository.dispose();
    professional.removeListener(_professionalChanged);
    professional.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'ProjectBridge',
    builder: (context, child) => SettingsScope(
      repository: settings,
      child: ProfessionalScope(
        repository: professional,
        child: ReviewScope(repository: reviews, child: child!),
      ),
    ),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8F9FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: violet,
        primary: violet,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F9FC),
        foregroundColor: ink,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9EAF1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9EAF1)),
        ),
      ),
    ),
    home: Scaffold(
      body: SafeArea(
        child: clientMode
            ? switch (tab) {
                0 => ClientHome(
                  projects: clientProjects,
                  organizationName: clientOrganization,
                  industry: clientIndustry,
                  onChanged: refresh,
                  onStudent: switchMode,
                  chatRepository: chatRepository,
                  onMessages: () =>
                      openMessages('client-demo-coffee', clientOrganization),
                  onCreate: () => setState(() => tab = 2),
                  onProjects: () => setState(() => tab = 1),
                  onApplicants: () => setState(() => tab = 3),
                  onProfile: () => setState(() => tab = 4),
                  onOpenProject: openClientProject,
                  onReviewProject: (project) =>
                      openClientProject(project, initialPage: 3),
                ),
                1 => ClientProjectsScreen(
                  projects: clientProjects,
                  onChanged: refresh,
                  onCreate: () => setState(() => tab = 2),
                  onOpenProject: openClientProject,
                  chatRepository: chatRepository,
                ),
                2 => ClientCreateProjectEntryScreen(
                  onCreated: (project) {
                    project.client = clientOrganization;
                    setState(() {
                      projects.insert(0, project);
                      tab = 1;
                    });
                    persist();
                  },
                ),
                3 => ClientApplicantsScreen(
                  projects: clientProjects,
                  onChanged: refresh,
                  onOpenProject: openClientProject,
                  chatRepository: chatRepository,
                ),
                _ => ClientProfileScreen(
                  projects: clientProjects,
                  name: clientOrganization,
                  industry: clientIndustry,
                  description: clientDescription,
                  website: clientWebsite,
                  onSave: (data) {
                    setState(() {
                      clientOrganization = data['name']!;
                      clientIndustry = data['industry']!;
                      clientDescription = data['description']!;
                      clientWebsite = data['website']!;
                      for (final p in projects.where(
                        (p) => p.clientId == 'client-demo-coffee',
                      )) {
                        p.client = clientOrganization;
                      }
                    });
                    persist();
                  },
                  onStudent: switchMode,
                  onMessages: () =>
                      openMessages('client-demo-coffee', clientOrganization),
                ),
              }
            : IndexedStack(
                index: tab,
                children: [
                  StudentHome(
                    projects: projects,
                    onChanged: refresh,
                    onClient: switchMode,
                    onExplore: () => setState(() => tab = 1),
                    name: studentName,
                    onMessages: () => openMessages(
                      'student-daria',
                      studentName,
                      onExplore: () {
                        navigatorKey.currentState?.pop();
                        setState(() => tab = 1);
                      },
                    ),
                    chatRepository: chatRepository,
                  ),
                  ExploreScreen(
                    projects: projects,
                    onChanged: refresh,
                    skills: studentSkills,
                    chatRepository: chatRepository,
                    studentName: studentName,
                  ),
                  MyProjectsScreen(
                    projects: projects,
                    onChanged: refresh,
                    onExplore: () => setState(() => tab = 1),
                    chatRepository: chatRepository,
                    studentName: studentName,
                  ),
                  PortfolioScreen(
                    projects: projects,
                    samples: samples,
                    name: studentName,
                    college: college,
                    specialization: specialization,
                    skills: studentSkills,
                    onChanged: refresh,
                    onExplore: () => setState(() => tab = 1),
                    onEditSkills: editSkills,
                  ),
                  ProfileScreen(
                    name: studentName,
                    college: college,
                    specialization: specialization,
                    course: course,
                    biography: biography,
                    level: experienceLevel,
                    skills: studentSkills,
                    interests: interests,
                    projects: projects,
                    onEdit: editProfile,
                    onLogout: () => setState(() {
                      tab = 0;
                      clientMode = true;
                    }),
                    onClient: switchMode,
                  ),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: clientMode
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_box_outlined),
                  label: 'Create',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Applicants',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.work_outline),
                  label: 'My Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.workspace_premium_outlined),
                  label: 'Portfolio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
      ),
    ),
  );

  void refresh() {
    setState(() {});
    persist();
  }

  Future<void> openClientProject(
    BridgeProject project, {
    int initialPage = 0,
  }) async {
    await navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ClientProjectDetailsScreen(
          project: project,
          onChanged: refresh,
          chatRepository: chatRepository,
          initialPage: initialPage,
          onAccept: (project) {
            project.acceptApplication(chatRepository);
            refresh();
          },
        ),
      ),
    );
  }

  Future<void> editProfile() async {
    final form = await navigatorKey.currentState!.push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          professionalProfile: professional.profile('student-daria'),
          name: studentName,
          college: college,
          specialization: specialization,
          course: course,
          biography: biography,
          level: experienceLevel,
          skills: studentSkills,
          interests: interests,
        ),
      ),
    );
    if (form == null || !mounted) return;
    final previous = professional.profile('student-daria');
    professional.saveProfile(
      'student-daria',
      previous.withChanges({
        'name': form['name'],
        'summary': form['biography'],
        'specialization': form['specialization'],
        'skills': form['skills'],
        'level': form['level'],
        'interests': form['interests'],
        'headline': form['headline'],
        'city': form['city'],
        'availability': form['availability'],
        'weeklyHours': form['weeklyHours'],
        'preferredRoles': form['preferredRoles'],
        'education': (form['college'] as String).isEmpty
            ? null
            : InstitutionAffiliation(
                id: previous.education?.id ?? 'education-student-daria',
                name: form['college'] as String,
                program: form['studyProgram'] as String,
                period: form['studyPeriod'] as String,
                type: form['institutionType'] as String,
                city: form['institutionCity'] as String,
              ).toJson(),
      }),
    );
  }

  Future<void> editSkills() async {
    final updated = await chooseSkills(context, studentSkills);
    if (updated != null) {
      professional.saveProfile(
        'student-daria',
        professional.profile('student-daria').withChanges({'skills': updated}),
      );
    }
  }

  Future<void> openMessages(
    String userId,
    String displayName, {
    VoidCallback? onExplore,
  }) => navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => MessageCenterScreen(
        repository: chatRepository,
        userId: userId,
        displayName: displayName,
        onExplore: onExplore,
      ),
    ),
  );

  void switchMode() => setState(() {
    clientMode = !clientMode;
    tab = 0;
  });
}

class BridgeProject {
  BridgeProject(
    this.title,
    this.client,
    this.category,
    this.description,
    this.skills, {
    String? clientId,
  }) : id = 'project-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
       clientId =
           clientId ??
           'client-${client.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
       requiredSkills = List<String>.from(skills);
  static int _nextId = 0;
  String id;
  String title, client, category, description;
  final String clientId;
  final List<String> skills;
  DateTime createdAt = DateTime.now();
  String difficulty = 'Beginner';
  String deadline = 'May 30';
  String expectedResult = 'A reviewed, portfolio-ready deliverable.';
  String? originalDescription;
  bool smartAssistantAssisted = false;
  String? assistantSuggestedCategory, difficultyReason, estimatedTimeline;
  List<String> suggestedTechnologies = [],
      suggestedRoles = [],
      deliverables = [],
      acceptanceCriteria = [],
      suggestedTasks = [],
      assumptions = [];
  String smartAnalysisVersion = '';
  String conditions = 'Remote collaboration; weekly progress updates.';
  String role = 'Student contributor';
  List<String> requiredSkills;
  String detailedDescription = '';
  String problemToSolve = '';
  String projectType = 'Real-world project';
  String workMode = 'Remote';
  String mentorInvolvement = 'Optional';
  String compensation = 'Compensation to be discussed';
  double? weeklyCommitment;
  List<String> optionalSkills = [], requiredRoles = [];
  String taskTitle = 'First milestone';
  String taskDescription = 'Prepare and share the first project milestone.';
  String taskPriority = 'Medium';
  String taskStatus = 'To Do';
  DateTime taskDueDate = DateTime.now().add(const Duration(days: 7));
  String applicationStatus = 'Pending';
  String lifecycleStatus = 'Published';
  int teamSize = 1;
  DateTime deadlineAt = DateTime.now().add(const Duration(days: 30));
  DateTime applicationDeadline = DateTime.now().add(const Duration(days: 14));
  DateTime appliedAt = DateTime.now();
  bool isPublished = true, isArchived = false, portfolioPermission = true;
  bool saved = false;
  String? motivation;
  String? availability;
  String? portfolioLink;
  String? applicationAvailabilityCode, applicantHeadline;
  List<PortfolioProject> applicationPortfolio = [];
  String? progressNote;
  String? submissionText;
  String? feedback;
  String? applicantId;
  String? applicantName;
  String applicantSpecialization = 'Mobile Development';
  List<String> applicantSkills = [];
  DateTime? completedAt, acceptedAt;
  int get progress => completed
      ? 100
      : approved
      ? 70
      : submitted
      ? 45
      : taskCreated
      ? 20
      : accepted
      ? 10
      : 0;
  bool applied = false,
      accepted = false,
      taskCreated = false,
      submitted = false,
      approved = false,
      completed = false;

  bool get isPending =>
      applied &&
      !accepted &&
      ['Pending', 'Submitted', 'Under Review'].contains(applicationStatus);
  final Map<String, String> acceptedTeamStudents = {};
  List<String> get acceptedParticipantIds =>
      accepted &&
          applied &&
          applicantId != null &&
          applicationStatus == 'Accepted'
      ? {applicantId!, ...acceptedTeamStudents.keys}.toList()
      : [];

  bool submitApplication({
    required String studentId,
    required String name,
    required List<String> studentSkills,
    required String introduction,
    required String hours,
    String? portfolio,
    String? availabilityCode,
    String? headline,
    List<PortfolioProject> portfolioProjects = const [],
  }) {
    if (applied ||
        !isPublished ||
        isArchived ||
        lifecycleStatus != 'Published' ||
        applicationDeadline.isBefore(DateTime.now())) {
      return false;
    }
    if (availabilityCode != null &&
        (ApplicationValidation.motivation(introduction) != null ||
            ApplicationValidation.portfolio(portfolio) != null ||
            !WeeklyAvailability.values.any(
              (a) => a.name == availabilityCode && a.label == hours,
            ))) {
      return false;
    }
    applicationAvailabilityCode = availabilityCode;
    applicantHeadline = headline;
    applicationPortfolio = List.of(portfolioProjects);
    applied = true;
    applicantId = studentId;
    applicantName = name;
    applicantSkills = List.of(studentSkills);
    applicationStatus = 'Pending';
    appliedAt = DateTime.now();
    motivation = introduction;
    availability = hours;
    portfolioLink = portfolio;
    return true;
  }

  bool acceptApplication(ChatRepository chats) {
    if (acceptedParticipantIds.isNotEmpty) {
      chats.ensureProjectChats(this);
      return true;
    }
    if (!isPending || applicantId == null || teamSize < 1) return false;
    accepted = true;
    acceptedAt = DateTime.now();
    applicationStatus = 'Accepted';
    lifecycleStatus = 'In Progress';
    chats.ensureProjectChats(this);
    return true;
  }

  void rejectApplication() {
    if (!isPending) return;
    accepted = false;
    applicationStatus = 'Rejected';
  }
}

abstract interface class ProjectBridgeRepository {
  List<BridgeProject> get projects;
}

/// Shared demo source of truth, snapshotted to private Android storage.
/// Replace this adapter with Firestore after
/// Firebase project configuration and access rules are supplied.
class DemoProjectBridgeRepository implements ProjectBridgeRepository {
  DemoProjectBridgeRepository(this.projects);
  @override
  final List<BridgeProject> projects;
}

enum ChatKind { team, direct }

enum ChatMessageKind { text, link, image, pdf }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.kind,
    required this.sentAt,
    this.attachment,
  });
  final String id, senderId, senderName, content;
  final ChatMessageKind kind;
  final DateTime sentAt;
  final LocalAttachment? attachment;
}

class ProjectChatThread {
  ProjectChatThread({
    required this.id,
    required this.project,
    required this.kind,
    required this.participants,
  });
  final String id;
  final BridgeProject project;
  final ChatKind kind;
  final List<String> participants;
  final List<ChatMessage> messages = [];
  final Map<String, int> unread = {};
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  String get preview => messages.isEmpty
      ? 'No messages yet'
      : messages.last.content.isEmpty
      ? messages.last.attachment?.name ?? 'Attachment'
      : messages.last.content;
}

abstract interface class ChatRepository {
  void ensureProjectChats(BridgeProject project);
  Stream<List<ProjectChatThread>> watchChats(String userId);
  Stream<List<ChatMessage>> watchMessages(
    String chatId, {
    required String userId,
  });
  Future<void> sendMessage({
    required String chatId,
    required String userId,
    required String displayName,
    required String content,
    required ChatMessageKind kind,
  });
  Future<void> markRead(String chatId, String userId);
  Future<void> reportMessage(
    String chatId,
    String messageId,
    String reporterId,
    String reason,
  );
  ProjectChatThread? findThread(String chatId);
  String chatIdFor(BridgeProject project, ChatKind kind);
}

/// Demo adapter uses broadcast streams to exercise the same repository
/// boundary that a Firestore implementation can later satisfy.
class DemoChatRepository implements ChatRepository {
  final Map<String, ProjectChatThread> _threads = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageStreams = {};
  final StreamController<void> _chatChanges =
      StreamController<void>.broadcast();
  final List<String> reports = [];
  AttachmentRepository attachments = NativeAttachmentRepository();
  SettingsRepository? settings;
  Future<void> Function()? saveConfirmed;
  String Function(String id, String fallback)? nameFor;
  final Set<String> _attachmentSends = {};
  bool canInteract(ProjectChatThread thread, String userId) =>
      canAccess(thread, userId) &&
      !thread.participants.any(
        (id) => id != userId && (settings?.blocked(userId, id) ?? false),
      );

  Future<void> sendAttachment({
    required String chatId,
    required String userId,
    required String displayName,
    required LocalAttachment attachment,
    String caption = '',
  }) async {
    final thread = _threads[chatId];
    if (thread == null || !canInteract(thread, userId)) {
      throw StateError(
        'Only unblocked accepted participants can send attachments.',
      );
    }
    if (!_attachmentSends.add(chatId)) {
      throw StateError('An attachment is already being sent.');
    }
    try {
      NativeAttachmentRepository.validate(attachment);
      await attachments.resolve(attachment);
      if (!canInteract(thread, userId)) {
        throw StateError('Project access changed.');
      }
      final oldDate = thread.updatedAt;
      final oldUnread = Map<String, int>.from(thread.unread);
      final message = ChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        senderId: userId,
        senderName: nameFor?.call(userId, displayName) ?? displayName,
        content: caption.trim(),
        kind: attachment.image ? ChatMessageKind.image : ChatMessageKind.pdf,
        sentAt: DateTime.now(),
        attachment: attachment,
      );
      thread.messages.add(message);
      thread.updatedAt = message.sentAt;
      for (final id in thread.participants.where((id) => id != userId)) {
        thread.unread[id] = (thread.unread[id] ?? 0) + 1;
      }
      try {
        await saveConfirmed?.call();
      } catch (_) {
        thread.messages.remove(message);
        thread.updatedAt = oldDate;
        thread.unread
          ..clear()
          ..addAll(oldUnread);
        rethrow;
      }
      _messageStreams[chatId]!.add(List.unmodifiable(thread.messages));
      _notify();
    } finally {
      _attachmentSends.remove(chatId);
    }
  }

  VoidCallback? onChanged;

  void _notify() {
    _chatChanges.add(null);
    onChanged?.call();
  }

  void dispose() {
    _chatChanges.close();
    for (final stream in _messageStreams.values) {
      stream.close();
    }
  }

  bool canAccess(ProjectChatThread thread, String userId) =>
      thread.project.acceptedParticipantIds.isNotEmpty &&
      thread.participants.contains(userId) &&
      (userId == thread.project.clientId ||
          thread.project.acceptedParticipantIds.contains(userId));

  String _key(BridgeProject project, ChatKind kind) =>
      '${project.id}:${kind.name}:${project.clientId}:${kind == ChatKind.direct ? project.applicantId ?? 'unassigned' : 'team'}';
  @override
  String chatIdFor(BridgeProject project, ChatKind kind) => _key(project, kind);

  @override
  void ensureProjectChats(BridgeProject project) {
    final applicantId = project.applicantId;
    if (project.acceptedParticipantIds.isEmpty ||
        applicantId == null ||
        applicantId.isEmpty) {
      return;
    }
    final participants = [project.clientId, ...project.acceptedParticipantIds];
    for (final kind in ChatKind.values) {
      final key = _key(project, kind);
      _threads.putIfAbsent(
        key,
        () => ProjectChatThread(
          id: key,
          project: project,
          kind: kind,
          participants: List.of(participants),
        ),
      );
      _threads[key]!.participants
        ..clear()
        ..addAll(participants);
      _messageStreams.putIfAbsent(
        key,
        () => StreamController<List<ChatMessage>>.broadcast(),
      );
    }
    _notify();
  }

  @override
  Stream<List<ProjectChatThread>> watchChats(String userId) async* {
    List<ProjectChatThread> snapshot() =>
        _threads.values.where((c) => canAccess(c, userId)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    yield snapshot();
    yield* _chatChanges.stream.map((_) => snapshot());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(
    String chatId, {
    required String userId,
  }) async* {
    final thread = _threads[chatId];
    if (thread == null || !canAccess(thread, userId)) {
      yield const [];
      return;
    }
    yield List.unmodifiable(thread.messages);
    yield* _messageStreams[chatId]!.stream.map(
      (messages) => canAccess(thread, userId) ? messages : <ChatMessage>[],
    );
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String userId,
    required String displayName,
    required String content,
    required ChatMessageKind kind,
  }) async {
    final thread = _threads[chatId];
    if (thread == null || !canInteract(thread, userId)) {
      throw StateError('This account is not an accepted project participant.');
    }
    if (content.trim().isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    final message = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      senderId: userId,
      senderName: nameFor?.call(userId, displayName) ?? displayName,
      content: content.trim(),
      kind: kind,
      sentAt: DateTime.now(),
    );
    thread.messages.add(message);
    thread.updatedAt = message.sentAt;
    for (final participant in thread.participants.where((id) => id != userId)) {
      thread.unread[participant] = (thread.unread[participant] ?? 0) + 1;
    }
    _messageStreams[chatId]!.add(List.unmodifiable(thread.messages));
    _notify();
  }

  @override
  Future<void> markRead(String chatId, String userId) async {
    final thread = _threads[chatId];
    if (thread != null && canAccess(thread, userId)) {
      thread.unread[userId] = 0;
      _notify();
    }
  }

  @override
  Future<void> reportMessage(
    String chatId,
    String messageId,
    String reporterId,
    String reason,
  ) async {
    final thread = _threads[chatId];
    if (thread == null || !canAccess(thread, reporterId)) {
      throw StateError('Only project participants can report this message.');
    }
    reports.add('$chatId|$messageId|$reporterId|${reason.trim()}');
    onChanged?.call();
  }

  @override
  ProjectChatThread? findThread(String chatId) => _threads[chatId];

  void revokeProjectMember(BridgeProject project, String userId) {
    for (final thread in _threads.values.where(
      (t) => identical(t.project, project),
    )) {
      thread.participants.remove(userId);
      thread.unread.remove(userId);
    }
    _notify();
  }
}

class StudentHome extends StatelessWidget {
  const StudentHome({
    super.key,
    required this.projects,
    required this.onChanged,
    required this.onClient,
    required this.onExplore,
    required this.name,
    required this.onMessages,
    required this.chatRepository,
  });
  final List<BridgeProject> projects;
  final VoidCallback onChanged, onClient;
  final VoidCallback onExplore;
  final String name;
  final VoidCallback onMessages;
  final ChatRepository chatRepository;
  @override
  Widget build(BuildContext context) {
    final joined = projects.where((p) => p.accepted).toList();
    final pending = projects.where((p) => p.applied && !p.accepted).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(child: Brand()),
            IconButton(
              onPressed: onMessages,
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Messages',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $name!',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Build experience through real projects.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            Avatar(
              initials: name.isEmpty ? '?' : name[0],
              accountId: 'student-daria',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Metric(value: '${joined.length}', label: 'Active'),
            Metric(value: '$pending', label: 'Pending'),
            Metric(
              value: '${projects.where((p) => p.completed).length}',
              label: 'Completed',
            ),
          ],
        ),
        if (ProfessionalScope.maybeOf(context) != null)
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecommendedProjectsScreen(
                  repository: ProfessionalScope.maybeOf(context)!,
                  chatRepository: chatRepository,
                  onChanged: onChanged,
                ),
              ),
            ),
            icon: const Icon(Icons.recommend_outlined),
            label: const Text('Recommended Projects For You'),
          ),
        const SizedBox(height: 28),
        SectionTitle(
          'Recommended for you',
          trailing: TextButton(
            onPressed: onExplore,
            child: const Text('See all'),
          ),
        ),
        ...projects
            .where((p) => !p.completed)
            .map(
              (p) => ProjectTile(
                project: p,
                onTap: () => openProject(
                  context,
                  p,
                  onChanged,
                  chatRepository: chatRepository,
                  displayName: name,
                ),
                onSaved: onChanged,
              ),
            ),
        if (joined.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('Continue working'),
          ...joined.map(
            (p) => WorkspaceTile(
              project: p,
              onChanged: onChanged,
              chatRepository: chatRepository,
              studentName: name,
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onClient,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Switch to Client demo'),
        ),
      ],
    );
  }
}

class ClientHome extends StatelessWidget {
  const ClientHome({
    super.key,
    required this.projects,
    required this.organizationName,
    required this.industry,
    required this.onChanged,
    required this.onStudent,
    required this.chatRepository,
    required this.onMessages,
    required this.onCreate,
    required this.onProjects,
    required this.onApplicants,
    required this.onProfile,
    required this.onOpenProject,
    required this.onReviewProject,
  });
  final List<BridgeProject> projects;
  final String organizationName, industry;
  final VoidCallback onChanged, onStudent;
  final VoidCallback onCreate, onProjects, onApplicants, onProfile;
  final ValueChanged<BridgeProject> onOpenProject;
  final ValueChanged<BridgeProject> onReviewProject;
  final ChatRepository chatRepository;
  final VoidCallback onMessages;
  @override
  Widget build(BuildContext context) {
    final pending = projects
        .where(
          (p) => p.applied && !p.accepted && p.applicationStatus != 'Rejected',
        )
        .length;
    final active = projects.where((p) => p.accepted && !p.completed).length;
    final review = projects.where((p) => p.submitted && !p.approved).length;
    final completed = projects.where((p) => p.completed).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(child: Brand()),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => openSettingsPage(
                context,
                'client-demo-coffee',
                true,
                'Notifications',
              ),
              icon: const Icon(Icons.notifications_none),
            ),
            IconButton(
              onPressed: onMessages,
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Messages',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationName,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Small Business · $industry',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Client Profile',
              onPressed: onProfile,
              icon: const Avatar(
                initials: 'DC',
                accountId: 'client-demo-coffee',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Column(
          children: [
            Row(
              children: [
                Metric(value: '${projects.length}', label: 'Projects'),
                Metric(value: '$active', label: 'Active'),
                Metric(value: '$pending', label: 'Pending'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Metric(value: '$review', label: 'To review'),
                Metric(value: '$completed', label: 'Completed'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),
        const SectionTitle('Quick actions'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Project'),
            ),
            OutlinedButton.icon(
              onPressed: onApplicants,
              icon: const Icon(Icons.people_outline),
              label: const Text('Applicants'),
            ),
            OutlinedButton.icon(
              onPressed: () => review > 0
                  ? onReviewProject(
                      projects.firstWhere((p) => p.submitted && !p.approved),
                    )
                  : onProjects(),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review Submissions'),
            ),
            OutlinedButton.icon(
              onPressed: onMessages,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Open Messages'),
            ),
          ],
        ),
        const SizedBox(height: 25),
        SectionTitle(
          'My Projects',
          trailing: TextButton(
            onPressed: onProjects,
            child: const Text('See all'),
          ),
        ),
        ...projects
            .take(3)
            .map(
              (p) => ClientProjectTile(
                project: p,
                onChanged: onChanged,
                chatRepository: chatRepository,
                onOpen: () => onOpenProject(p),
              ),
            ),
        const SizedBox(height: 14),
        const SectionTitle('Recent Activity'),
        ...projects
            .where((p) => p.applied || p.accepted || p.submitted || p.completed)
            .take(5)
            .map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt_outlined, color: violet),
                title: Text(
                  p.completed
                      ? '${p.title} completed'
                      : p.submitted
                      ? '${p.applicantName ?? 'Student'} submitted work'
                      : p.accepted
                      ? '${p.applicantName ?? 'Student'} joined ${p.title}'
                      : 'New application for ${p.title}',
                ),
                subtitle: Text(_activityTime(p.completedAt ?? p.appliedAt)),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onStudent,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Switch to Student demo'),
        ),
      ],
    );
  }
}

String _activityTime(DateTime date) =>
    '${date.month}/${date.day} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class ClientProjectsScreen extends StatefulWidget {
  const ClientProjectsScreen({
    super.key,
    required this.projects,
    required this.onChanged,
    required this.onCreate,
    required this.onOpenProject,
    required this.chatRepository,
  });
  final List<BridgeProject> projects;
  final VoidCallback onChanged, onCreate;
  final ValueChanged<BridgeProject> onOpenProject;
  final ChatRepository chatRepository;

  @override
  State<ClientProjectsScreen> createState() => _ClientProjectsScreenState();
}

class _ClientProjectsScreenState extends State<ClientProjectsScreen> {
  String filter = 'All';
  static const filters = [
    'All',
    'Drafts',
    'Pending Review',
    'Published',
    'In Progress',
    'Completed',
    'Archived',
  ];

  bool matches(BridgeProject project) => switch (filter) {
    'Drafts' => project.lifecycleStatus == 'Draft',
    'Pending Review' => project.lifecycleStatus == 'Pending Review',
    'Published' => project.lifecycleStatus == 'Published',
    'In Progress' => project.lifecycleStatus == 'In Progress',
    'Completed' => project.lifecycleStatus == 'Completed' || project.completed,
    'Archived' => project.isArchived,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final visible = widget.projects.where(matches).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Projects',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your published and in-progress work.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          EmptyState(
            title: 'No ${filter.toLowerCase()} projects',
            body: filter == 'All'
                ? 'Create a project to begin working with students.'
                : 'Projects in this stage will appear here.',
            action: filter == 'All' ? 'Create Project' : null,
            onAction: filter == 'All' ? widget.onCreate : null,
          )
        else
          ...visible.map(
            (project) => ClientProjectTile(
              project: project,
              onChanged: widget.onChanged,
              chatRepository: widget.chatRepository,
              onOpen: () => widget.onOpenProject(project),
            ),
          ),
      ],
    );
  }
}

class ClientCreateProjectEntryScreen extends StatelessWidget {
  const ClientCreateProjectEntryScreen({super.key, required this.onCreated});

  final ValueChanged<BridgeProject> onCreated;

  void startManual(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          body: ClientCreateProjectScreen(
            onCreated: (project) {
              onCreated(project);
              Navigator.of(pageContext).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
    children: [
      Text('Create Project', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text(
        'Create your project brief with the standard project form.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 22),
      _CreateModeCard(
        icon: Icons.edit_note,
        title: 'Create Manually',
        description: 'Fill in the existing four-step project form yourself.',
        action: 'Start Manually',
        onPressed: () => startManual(context),
      ),
    ],
  );
}

class _CreateModeCard extends StatelessWidget {
  const _CreateModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String title, description, action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: violet, size: 30),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: muted)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );
}

class ProjectAssistantScreen extends StatefulWidget {
  const ProjectAssistantScreen({
    super.key,
    required this.service,
    required this.onContinue,
    required this.onCreateManually,
  });
  final ProjectAssistantService service;
  final ValueChanged<SmartProjectAnalysis> onContinue;
  final VoidCallback onCreateManually;

  @override
  State<ProjectAssistantScreen> createState() => _ProjectAssistantScreenState();
}

class _ProjectAssistantScreenState extends State<ProjectAssistantScreen> {
  final description = TextEditingController();
  bool loading = false;
  String? error;
  SmartProjectAnalysis? result;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> analyze([Map<String, String> answers = const {}]) async {
    if (description.text.trim().length < 20) {
      setState(
        () =>
            error = 'Please add a little more detail (at least 20 characters).',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final analysis = await widget.service.analyze(
        description.text,
        clarificationAnswers: answers,
      );
      if (!mounted) return;
      setState(() => result = analysis);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => result != null
      ? SmartProjectAnalysisScreen(
          key: ObjectKey(result),
          analysis: result!,
          loading: loading,
          error: error,
          onRegenerate: analyze,
          onContinue: widget.onContinue,
          onCreateManually: widget.onCreateManually,
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Describe Your Idea')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Describe Your Idea',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us what you need in your own words.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('project_idea_input'),
                controller: description,
                minLines: 6,
                maxLines: 10,
                maxLength: 5000,
                decoration: const InputDecoration(
                  hintText: 'For example: I own a coffee shop. I want customers to scan a QR code, view our menu with photos and prices, and I want to edit the menu myself.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Examples',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final example in [
                'I need a website where customers can view my services and request an appointment.',
                'I want a simple mobile app to help our community find local events.',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb_outline, color: violet),
                  title: Text(example),
                  onTap: () => setState(() => description.text = example),
                ),
              const InfoCard(
                icon: Icons.auto_awesome,
                title: 'Smart Project Assistant — Ready',
                body: 'This on-device, rule-based assistant works offline. Its suggestions are estimates, not generative AI or a substitute for mentor review.',
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.error_outline,
                  title: 'Could not analyze idea',
                  body: error!,
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: loading ? null : analyze,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(loading ? 'Analyzing locally…' : 'Analyze Project'),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: Text('Analyzing locally without a network request…'),
                  ),
                ),
            ],
          ),
        );
}

class SmartProjectAnalysisScreen extends StatefulWidget {
  const SmartProjectAnalysisScreen({
    super.key,
    required this.analysis,
    required this.onRegenerate,
    required this.onContinue,
    required this.onCreateManually,
    required this.loading,
    required this.error,
  });
  final SmartProjectAnalysis analysis;
  final Future<void> Function([Map<String, String> answers]) onRegenerate;
  final ValueChanged<SmartProjectAnalysis> onContinue;
  final VoidCallback onCreateManually;
  final bool loading;
  final String? error;

  @override
  State<SmartProjectAnalysisScreen> createState() =>
      _SmartProjectAnalysisScreenState();
}

class _SmartProjectAnalysisScreenState
    extends State<SmartProjectAnalysisScreen> {
  late final title = TextEditingController(text: widget.analysis.title);
  late final category = TextEditingController(text: widget.analysis.category);
  late final additionalCategories = TextEditingController(
    text: widget.analysis.additionalCategories.join(', '),
  );
  late final conflictNotes = TextEditingController(
    text: widget.analysis.conflictNotes.join('\n'),
  );
  late final description = TextEditingController(
    text: widget.analysis.description,
  );
  late final problem = TextEditingController(
    text: widget.analysis.problemToSolve,
  );
  late final skills = TextEditingController(
    text: widget.analysis.requiredSkills.join(', '),
  );
  late final technologies = TextEditingController(
    text: widget.analysis.suggestedTechnologies.join(', '),
  );
  late final difficulty = TextEditingController(
    text: widget.analysis.difficulty,
  );
  late final difficultyReason = TextEditingController(
    text: widget.analysis.difficultyReason,
  );
  late final roles = TextEditingController(
    text: widget.analysis.suggestedRoles.join(', '),
  );
  late final teamSize = TextEditingController(
    text: '${widget.analysis.estimatedTeamSize}',
  );
  late final deliverables = TextEditingController(
    text: widget.analysis.deliverables.join('\n'),
  );
  late final tasks = TextEditingController(
    text: widget.analysis.suggestedTasks.join('\n'),
  );
  late final criteria = TextEditingController(
    text: widget.analysis.acceptanceCriteria.join('\n'),
  );
  late final timeline = TextEditingController(
    text: widget.analysis.estimatedTimeline,
  );
  late final assumptions = TextEditingController(
    text: widget.analysis.risksAndAssumptions.join('\n'),
  );
  late final detectedFeatures = TextEditingController(
    text: widget.analysis.detectedFeatures.join(', '),
  );
  final questionSectionKey = GlobalKey();
  late final answerControllers = widget.analysis.clarifyingQuestions
      .map((_) => TextEditingController())
      .toList();

  @override
  void dispose() {
    for (final controller in [
      title,
      category,
      additionalCategories,
      conflictNotes,
      description,
      problem,
      skills,
      technologies,
      difficulty,
      difficultyReason,
      roles,
      teamSize,
      deliverables,
      tasks,
      criteria,
      timeline,
      assumptions,
      detectedFeatures,
      ...answerControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> lines(String value) => value
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  List<String> commaList(String value) =>
      value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  SmartProjectAnalysis current() {
    final result = widget.analysis;
    result
      ..title = title.text.trim()
      ..category = category.text.trim()
      ..additionalCategories = commaList(additionalCategories.text)
      ..conflictNotes = lines(conflictNotes.text)
      ..description = description.text.trim()
      ..problemToSolve = problem.text.trim()
      ..requiredSkills = commaList(skills.text)
      ..suggestedTechnologies = commaList(technologies.text)
      ..difficulty = difficulty.text.trim()
      ..difficultyReason = difficultyReason.text.trim()
      ..suggestedRoles = commaList(roles.text)
      ..estimatedTeamSize =
          int.tryParse(teamSize.text.trim()) ?? result.estimatedTeamSize
      ..deliverables = lines(deliverables.text)
      ..suggestedTasks = lines(tasks.text)
      ..acceptanceCriteria = lines(criteria.text)
      ..estimatedTimeline = timeline.text.trim()
      ..risksAndAssumptions = lines(assumptions.text);
    result.detectedFeatures = commaList(detectedFeatures.text);
    if (answerControllers.any((controller) => controller.text.trim().isEmpty) &&
        result.clarifyingQuestions.isNotEmpty) {
      final note =
          'Unanswered questions remain assumptions; confirm them with the client before implementation.';
      if (!result.risksAndAssumptions.contains(note)) {
        result.risksAndAssumptions = [...result.risksAndAssumptions, note];
      }
    }
    return result;
  }

  Widget editField(
    TextEditingController controller,
    String label, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final unresolved =
        widget.analysis.clarifyingQuestions.isNotEmpty &&
        answerControllers.any((controller) => controller.text.trim().isEmpty);
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Project Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoCard(
            icon: Icons.info_outline,
            title:
                'Rule-based recommendations · ${widget.analysis.confidencePercent}% confidence',
            body:
                '${widget.analysis.confidenceLabel}. This is a local heuristic, not generative AI. Review and edit the suggestions; complex or sensitive work needs mentor review.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onCreateManually,
              icon: const Icon(Icons.edit_note),
              label: const Text('Create Manually'),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.analysis.clarifyingQuestions.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                final target = questionSectionKey.currentContext;
                if (target != null) {
                  Scrollable.ensureVisible(
                    target,
                    duration: const Duration(milliseconds: 250),
                  );
                }
              },
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text('Answer Questions'),
            ),
          _analysisSection('Edit Recommendations', [
            editField(title, 'Suggested project title'),
            editField(category, 'Primary category'),
            editField(
              additionalCategories,
              'Additional matching categories (comma separated)',
              lines: 2,
            ),
            if (widget.analysis.conflictNotes.isNotEmpty)
              editField(
                conflictNotes,
                'Conflicting requirements to confirm',
                lines: 3,
              ),
            editField(description, 'Project description', lines: 4),
            editField(problem, 'Problem to solve', lines: 3),
            editField(
              detectedFeatures,
              'Detected features (editable)',
              lines: 2,
            ),
          ]),
          _analysisSection('Skills and approach', [
            editField(skills, 'Required skills (comma separated)', lines: 2),
            editField(
              technologies,
              'Suggested technologies and notes (comma separated)',
              lines: 2,
            ),
            editField(difficulty, 'Difficulty estimate'),
            editField(difficultyReason, 'Difficulty reasoning', lines: 3),
          ]),
          _analysisSection('Team and scope', [
            editField(roles, 'Suggested roles (comma separated)', lines: 2),
            editField(teamSize, 'Estimated team size'),
            editField(deliverables, 'Deliverables (one per line)', lines: 4),
            editField(tasks, 'Suggested tasks (one per line)', lines: 4),
            editField(criteria, 'Acceptance criteria (one per line)', lines: 4),
            editField(timeline, 'Estimated timeline and assumptions', lines: 2),
            editField(
              assumptions,
              'Risks and assumptions (one per line)',
              lines: 4,
            ),
          ]),
          if (widget.analysis.clarifyingQuestions.isNotEmpty)
            Container(
              key: questionSectionKey,
              child: _analysisSection('Clarifying questions', [
                const Text(
                  'You can answer now or skip and continue with the listed assumptions.',
                ),
                for (
                  var i = 0;
                  i < widget.analysis.clarifyingQuestions.length;
                  i++
                )
                  editField(
                    answerControllers[i],
                    widget.analysis.clarifyingQuestions[i],
                    lines: 2,
                  ),
                FilledButton.tonal(
                  onPressed: widget.loading
                      ? null
                      : () => widget.onRegenerate({
                          for (var i = 0; i < answerControllers.length; i++)
                            widget.analysis.clarifyingQuestions[i]:
                                answerControllers[i].text.trim(),
                        }),
                  child: const Text('Answer Questions · Analyze Again'),
                ),
              ]),
            ),
          if (widget.error != null)
            InfoCard(
              icon: Icons.error_outline,
              title: 'Could not analyze idea',
              body: widget.error!,
            ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Start Over'),
          ),
          OutlinedButton.icon(
            onPressed: widget.loading ? null : () => widget.onRegenerate(),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze Again'),
          ),
          FilledButton(
            onPressed: () => widget.onContinue(current()),
            child: Text(
              unresolved ? 'Use This Plan with Assumptions' : 'Use This Plan',
            ),
          ),
        ],
      ),
    );
  }
}

Widget _analysisSection(String title, List<Widget> children) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);

class ClientCreateProjectScreen extends StatefulWidget {
  const ClientCreateProjectScreen({
    super.key,
    required this.onCreated,
    this.initialAnalysis,
  });
  final ValueChanged<BridgeProject> onCreated;
  final SmartProjectAnalysis? initialAnalysis;

  @override
  State<ClientCreateProjectScreen> createState() =>
      _ClientCreateProjectScreenState();
}

class _ClientCreateProjectScreenState extends State<ClientCreateProjectScreen> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.initialAnalysis?.title);
  late final shortDescription = TextEditingController(
    text: widget.initialAnalysis?.description,
  );
  late final detailed = TextEditingController(
    text: widget.initialAnalysis?.description,
  );
  late final problem = TextEditingController(
    text: widget.initialAnalysis?.problemToSolve,
  );
  late final deliverables = TextEditingController(
    text: widget.initialAnalysis?.deliverables.join('\n'),
  );
  late final skills = TextEditingController(
    text: widget.initialAnalysis?.requiredSkills.join(', '),
  );
  late final estimatedTimeline = TextEditingController(
    text: widget.initialAnalysis?.estimatedTimeline,
  );
  late final suggestedTechnologies = TextEditingController(
    text: widget.initialAnalysis?.suggestedTechnologies.join(', '),
  );
  late final suggestedTasks = TextEditingController(
    text: widget.initialAnalysis?.suggestedTasks.join('\n'),
  );
  late final acceptanceCriteria = TextEditingController(
    text: widget.initialAnalysis?.acceptanceCriteria.join('\n'),
  );
  late final difficultyReason = TextEditingController(
    text: widget.initialAnalysis?.difficultyReason,
  );
  late final risksAndAssumptions = TextEditingController(
    text: widget.initialAnalysis?.risksAndAssumptions.join('\n'),
  );
  final conditions = TextEditingController(
    text: 'Remote collaboration with weekly updates.',
  );
  final compensation = TextEditingController(
    text: 'Compensation to be discussed',
  );
  final weeklyCommitment = TextEditingController();
  final optionalSkills = TextEditingController();
  final requiredRoles = TextEditingController();
  late final roleController = TextEditingController(
    text:
        widget.initialAnalysis?.suggestedRoles.join(', ') ??
        'Student contributor',
  );
  int step = 0, durationWeeks = 4;
  late int participants = (widget.initialAnalysis?.estimatedTeamSize ?? 1)
      .clamp(1, 5)
      .toInt();
  DateTime applicationDueDate = DateTime.now().add(const Duration(days: 14));
  late String category = widget.initialAnalysis?.category ?? 'Web Development';
  late String difficulty = widget.initialAnalysis?.difficulty ?? 'Beginner';
  String role = 'Student contributor', projectType = 'Real-world project';
  String workMode = 'Remote', mentor = 'Optional';
  bool portfolio = true;

  @override
  void dispose() {
    for (final controller in [
      title,
      shortDescription,
      detailed,
      problem,
      deliverables,
      skills,
      estimatedTimeline,
      suggestedTechnologies,
      suggestedTasks,
      acceptanceCriteria,
      difficultyReason,
      risksAndAssumptions,
      conditions,
      compensation,
      weeklyCommitment,
      optionalSkills,
      requiredRoles,
      roleController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  BridgeProject buildProject(String status) {
    final project =
        BridgeProject(
            title.text.trim(),
            'Demo Coffee',
            category,
            shortDescription.text.trim(),
            skills.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          )
          ..detailedDescription = detailed.text.trim()
          ..problemToSolve = problem.text.trim()
          ..expectedResult = deliverables.text.trim()
          ..requiredSkills = skills.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..difficulty = difficulty
          ..originalDescription = widget.initialAnalysis?.originalDescription
          ..smartAssistantAssisted = widget.initialAnalysis != null
          ..assistantSuggestedCategory = widget.initialAnalysis?.category
          ..estimatedTimeline = estimatedTimeline.text.trim().isEmpty
              ? '$durationWeeks weeks'
              : estimatedTimeline.text.trim()
          ..difficultyReason = difficultyReason.text.trim()
          ..suggestedTechnologies = suggestedTechnologies.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..suggestedRoles = roleController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..deliverables = deliverables.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..acceptanceCriteria = acceptanceCriteria.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..suggestedTasks = suggestedTasks.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          ..assumptions = risksAndAssumptions.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .followedBy(
                widget.initialAnalysis?.conflictNotes ?? const <String>[],
              )
              .toList()
          ..smartAnalysisVersion = widget.initialAnalysis?.rulesVersion ?? ''
          ..role = roleController.text.trim()
          ..teamSize = participants
          ..deadlineAt = DateTime.now().add(Duration(days: durationWeeks * 7))
          ..applicationDeadline = applicationDueDate
          ..projectType = projectType
          ..workMode = workMode
          ..mentorInvolvement = mentor
          ..conditions = conditions.text.trim()
          ..compensation = compensation.text.trim()
          ..weeklyCommitment = double.tryParse(weeklyCommitment.text)
          ..optionalSkills = Skill.clean(optionalSkills.text.split(','))
          ..requiredRoles = Skill.clean(requiredRoles.text.split(','))
          ..portfolioPermission = portfolio
          ..lifecycleStatus = status
          ..isPublished = status == 'Published';
    return project;
  }

  Future<void> chooseApplicationDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: applicationDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => applicationDueDate = date);
  }

  void save(String status) {
    if (step < 3 || !formKey.currentState!.validate()) return;
    widget.onCreated(buildProject(status));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'Published'
              ? 'Demo project published to Student Explore.'
              : status == 'Draft'
              ? 'Draft saved on this device.'
              : 'Submitted for demo review.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'Web Development',
      'Mobile Development',
      'UX/UI Design',
      'Graphic Design',
      'Testing',
      'Marketing',
      'Research',
    ];
    if (!categories.contains(category)) categories.add(category);
    final difficulties = <String>['Beginner', 'Intermediate', 'Advanced'];
    if (!difficulties.contains(difficulty)) difficulties.add(difficulty);
    final titles = [
      'Basic Information',
      'Requirements',
      'Conditions',
      'Preview',
    ];
    return Form(
      key: formKey,
      child: ListView(
        key: ValueKey('create-step-$step'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Create Project · Step ${step + 1} of 4',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            titles[step],
            style: const TextStyle(color: violet, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Offline demo projects are shared between Student and Client modes on this device.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 18),
          if (step == 0) ...[
            field(title, 'Project title'),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => setState(() => category = x ?? category),
            ),
            const SizedBox(height: 12),
            field(shortDescription, 'Short description', lines: 2),
            field(detailed, 'Detailed description', lines: 4),
            field(problem, 'Problem to solve', lines: 3),
            field(deliverables, 'Expected deliverables', lines: 3),
          ] else if (step == 1) ...[
            field(skills, 'Required skills (comma separated)'),
            DropdownButtonFormField<String>(
              initialValue: difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: difficulties
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => setState(() => difficulty = x ?? difficulty),
            ),
            if (widget.initialAnalysis != null) ...[
              const SizedBox(height: 12),
              field(
                difficultyReason,
                'Why this difficulty was suggested',
                lines: 3,
                required: false,
              ),
              field(
                suggestedTechnologies,
                'Suggested technologies (editable)',
                lines: 2,
                required: false,
              ),
              field(
                suggestedTasks,
                'Suggested tasks (one per line)',
                lines: 4,
                required: false,
              ),
              field(
                acceptanceCriteria,
                'Acceptance criteria (one per line)',
                lines: 4,
                required: false,
              ),
              field(
                risksAndAssumptions,
                'Risks and assumptions (one per line)',
                lines: 4,
                required: false,
              ),
            ],
            const SizedBox(height: 12),
            field(roleController, 'Student role'),
            field(
              optionalSkills,
              'Optional skills (comma separated)',
              required: false,
            ),
            field(
              requiredRoles,
              'Required team roles (comma separated)',
              required: false,
            ),
            DropdownButtonFormField<int>(
              initialValue: participants,
              decoration: const InputDecoration(
                labelText: 'Number of participants',
              ),
              items: [1, 2, 3, 4, 5]
                  .map((x) => DropdownMenuItem(value: x, child: Text('$x')))
                  .toList(),
              onChanged: (x) => setState(() => participants = x ?? 1),
            ),
            DropdownButtonFormField<int>(
              initialValue: durationWeeks,
              decoration: const InputDecoration(labelText: 'Timeline'),
              items: [2, 4, 6, 8, 12]
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text('$x weeks')),
                  )
                  .toList(),
              onChanged: (x) => setState(() => durationWeeks = x ?? 4),
            ),
            if (widget.initialAnalysis != null) ...[
              const SizedBox(height: 12),
              field(
                estimatedTimeline,
                'Estimated timeline (review and edit)',
                required: false,
              ),
            ],
            ListTile(
              leading: const Icon(Icons.event_outlined, color: violet),
              title: const Text('Application deadline'),
              subtitle: Text(_activityTime(applicationDueDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: chooseApplicationDeadline,
            ),
          ] else if (step == 2) ...[
            DropdownButtonFormField<String>(
              initialValue: projectType,
              decoration: const InputDecoration(labelText: 'Project type'),
              items: [
                'Real-world project',
                'Learning project',
                'Research',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (x) => setState(() => projectType = x ?? projectType),
            ),
            DropdownButtonFormField<String>(
              initialValue: workMode,
              decoration: const InputDecoration(labelText: 'Work mode'),
              items: [
                'Remote',
                'Hybrid',
                'On-site',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (x) => setState(() => workMode = x ?? workMode),
            ),
            DropdownButtonFormField<String>(
              initialValue: mentor,
              decoration: const InputDecoration(
                labelText: 'Mentor involvement',
              ),
              items: [
                'Optional',
                'Weekly',
                'Not provided',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (x) => setState(() => mentor = x ?? mentor),
            ),
            field(conditions, 'Participation conditions', lines: 3),
            SwitchListTile(
              value: portfolio,
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow portfolio use after approval'),
              onChanged: (x) => setState(() => portfolio = x),
            ),
            field(
              compensation,
              'Compensation information (no payments processed)',
              required: false,
            ),
          ] else ...[
            InfoCard(
              icon: Icons.work_outline,
              title: title.text,
              body: '$category · $difficulty · $workMode',
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.flag_outlined,
              title: 'Problem and deliverables',
              body: '${problem.text}\n\n${deliverables.text}',
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.people_outline,
              title: 'Requirements',
              body:
                  '${skills.text}\n$role · $participants participant(s) · $durationWeeks weeks',
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.rule_outlined,
              title: 'Conditions',
              body:
                  '${conditions.text}\n$mentor mentor · Portfolio permission: ${portfolio ? 'Yes' : 'No'}\n${compensation.text}',
            ),
            if (widget.initialAnalysis != null) ...[
              const SizedBox(height: 10),
              InfoCard(
                icon: Icons.devices_outlined,
                title: 'Suggested technologies',
                body: suggestedTechnologies.text,
              ),
              const SizedBox(height: 10),
              InfoCard(
                icon: Icons.checklist_outlined,
                title: 'Suggested tasks and acceptance criteria',
                body:
                    '${suggestedTasks.text}\n\nAcceptance criteria:\n${acceptanceCriteria.text}\n\nDifficulty: ${difficultyReason.text}\n\nRisks and assumptions:\n${risksAndAssumptions.text}',
              ),
              const SizedBox(height: 10),
              InfoCard(
                icon: Icons.schedule_outlined,
                title: 'Estimated timeline',
                body: estimatedTimeline.text,
              ),
            ],
          ],
          if (step == 2) ...[
            DropdownButtonFormField<String>(
              initialValue: 'Compensation to be discussed',
              decoration: const InputDecoration(
                labelText: 'Compensation status',
              ),
              items: const [
                'Paid',
                'Unpaid / portfolio experience',
                'Compensation to be discussed',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => compensation.text = v!,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                controller: weeklyCommitment,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Expected hours per week (optional)',
                ),
                validator: (v) =>
                    v == null ||
                        v.isEmpty ||
                        (double.tryParse(v) != null &&
                            double.parse(v) > 0 &&
                            double.parse(v) <= 80)
                    ? null
                    : 'Use 1–80 hours',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (step > 0)
                OutlinedButton(
                  onPressed: () => setState(() => step--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (step < 3)
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    setState(() => step++);
                  },
                  child: const Text('Continue'),
                ),
            ],
          ),
          if (step == 3) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => save('Draft'),
              child: const Text('Save Draft'),
            ),
            OutlinedButton(
              onPressed: () => save('Pending Review'),
              child: const Text('Submit for Review'),
            ),
            FilledButton.icon(
              onPressed: () => save('Published'),
              icon: const Icon(Icons.publish),
              label: Text(
                'Publish as ${context.findAncestorStateOfType<_ProjectBridgeAppState>()?.clientOrganization ?? 'Demo Coffee'}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ClientApplicantsScreen extends StatelessWidget {
  const ClientApplicantsScreen({
    super.key,
    required this.projects,
    required this.onChanged,
    required this.onOpenProject,
    required this.chatRepository,
  });
  final List<BridgeProject> projects;
  final VoidCallback onChanged;
  final ValueChanged<BridgeProject> onOpenProject;
  final ChatRepository chatRepository;

  Future<void> _decide(
    BuildContext context,
    BridgeProject project,
    bool accept,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Accept applicant?' : 'Reject application?'),
        content: Text(
          accept
              ? 'Accept ${project.applicantName ?? 'this student'} to ${project.title}? This enables their workspace and project chats.'
              : 'Reject this application? It will not receive project access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (accept) {
      if (!project.acceptApplication(chatRepository)) return;
    } else {
      project.rejectApplication();
    }
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Student accepted. Your conversation is ready in Messages.'
                : 'Application rejected.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final applications = projects.where((p) => p.applied).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Applicants',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Applications grouped by your projects.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        if (applications.isEmpty)
          const EmptyState(
            title: 'No applicants yet',
            body: 'Applications to your published projects will appear here.',
          ),
        ...applications.map(
          (p) => Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(
                      initials: (p.applicantName?.isNotEmpty ?? false)
                          ? p.applicantName![0]
                          : '?',
                      accountId: p.applicantId,
                    ),
                    title: Text(p.applicantName ?? 'Student'),
                    subtitle: Text(
                      '${p.applicantSpecialization} · ${p.applicantSkills.join(', ')}',
                    ),
                    trailing: StatusPill(
                      text: p.applicationStatus,
                      color: p.accepted ? const Color(0xFF20A67A) : violet,
                    ),
                    onTap: () => _showApplicant(context, p),
                  ),
                  Text(
                    'Motivation: ${p.motivation ?? 'No motivation provided.'}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied ${_activityTime(p.appliedAt)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _showApplicant(context, p),
                        child: const Text('View Student Profile'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showApplicant(context, p, portfolioOnly: true),
                        child: const Text('View Portfolio'),
                      ),
                      if (p.isPending) ...[
                        FilledButton(
                          onPressed: () => _decide(context, p, true),
                          child: const Text('Accept'),
                        ),
                        TextButton(
                          onPressed: () => _decide(context, p, false),
                          child: const Text('Reject'),
                        ),
                      ],
                      if (p.accepted)
                        TextButton(
                          onPressed: () => onOpenProject(p),
                          child: const Text('Open Workspace'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showApplicant(
    BuildContext context,
    BridgeProject project, {
    bool portfolioOnly = false,
  }) {
    final professional = ProfessionalScope.maybeOf(context);
    final publicProfile = professional != null && project.applicantId != null
        ? professional.profile(project.applicantId!)
        : null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          portfolioOnly
              ? '${project.applicantName ?? 'Student'} · Portfolio'
              : '${project.applicantName ?? 'Student'} · Profile',
        ),
        content: SingleChildScrollView(
          child: Text(
            portfolioOnly
                ? '${project.portfolioLink ?? "No external link supplied."}\n${project.applicationPortfolio.map((p) => '${p.title} — ${p.description}\n${p.url}').join('\n\n')}'
                : '${project.applicantHeadline ?? publicProfile?.headline ?? project.applicantSpecialization}\nRelevant skills: ${project.applicantSkills.join(', ')}\nWeekly availability: ${project.availability ?? "Not supplied"}\nStatus: ${project.applicationStatus}\nApplied: ${project.appliedAt.toLocal().toString().split('.').first}\nMotivation: ${project.motivation ?? "Not provided"}\nPortfolio: ${project.portfolioLink ?? "Not supplied"}\n${project.applicationPortfolio.map((p) => '${p.title} — ${p.description}').join('\n')}',
          ),
        ),
        actions: [
          if (professional != null &&
              project.applicantId != null &&
              !portfolioOnly)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openProfessionalProfile(
                  context,
                  professional,
                  project.applicantId!,
                  project.clientId,
                );
              },
              child: const Text('View full professional profile'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({
    super.key,
    required this.projects,
    required this.name,
    required this.industry,
    required this.description,
    required this.website,
    required this.onSave,
    required this.onStudent,
    required this.onMessages,
  });
  final List<BridgeProject> projects;
  final String name, industry, description, website;
  final ValueChanged<Map<String, String>> onSave;
  final VoidCallback onStudent, onMessages;
  @override
  Widget build(BuildContext context) => ProfileOverview(
    client: true,
    name: name,
    subtitle: 'Small Business · $industry',
    description: description,
    projects: projects,
    onEdit: () => _edit(context),
    onSwitch: onStudent,
  );

  Future<void> _edit(BuildContext context) async {
    final values = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationEditorScreen(
          name: name,
          industry: industry,
          description: description,
          website: website,
        ),
      ),
    );
    if (values != null) onSave(values);
  }
}

class ClientProjectDetailsScreen extends StatefulWidget {
  const ClientProjectDetailsScreen({
    super.key,
    required this.project,
    required this.onChanged,
    required this.chatRepository,
    required this.onAccept,
    this.initialPage = 0,
  });
  final BridgeProject project;
  final VoidCallback onChanged;
  final ChatRepository chatRepository;
  final ValueChanged<BridgeProject> onAccept;
  final int initialPage;

  @override
  State<ClientProjectDetailsScreen> createState() =>
      _ClientProjectDetailsScreenState();
}

class _ClientProjectDetailsScreenState
    extends State<ClientProjectDetailsScreen> {
  late int page = widget.initialPage;
  BridgeProject get project => widget.project;

  Future<void> accept() async {
    if (project.accepted || project.applicantId == null || !project.applied) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept student?'),
        content: Text(
          'Accept ${project.applicantName ?? 'this student'} to ${project.title}? This enables project workspace and chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onAccept(project);
  }

  Future<void> editCoreFields() async {
    if (project.accepted) return;
    final title = TextEditingController(text: project.title);
    final description = TextEditingController(text: project.description);
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              title.text.trim(),
              description.text.trim(),
            ]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    if (values == null || values.first.isEmpty || values.last.isEmpty) return;
    if (project.accepted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Project requirements are locked after a student is accepted.',
          ),
        ),
      );
      return;
    }
    setState(() {
      project.title = values.first;
      project.description = values.last;
    });
    widget.onChanged();
  }

  Future<void> createTask() async {
    final title = TextEditingController(text: project.taskTitle);
    final description = TextEditingController(text: project.taskDescription);
    var dueDate = project.taskDueDate;
    var priority = project.taskPriority;
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(project.taskCreated ? 'Edit task' : 'Create task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / expected deliverable',
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Assigned student'),
                  subtitle: Text('Daria'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['Low', 'Medium', 'High']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? priority),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Due date'),
                  subtitle: Text(_activityTime(dueDate)),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selected != null) {
                      setDialogState(() => dueDate = selected);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, [
                title.text.trim(),
                description.text.trim(),
                priority,
                dueDate.toIso8601String(),
              ]),
              child: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (values == null || values[0].isEmpty || values[1].isEmpty) return;
    if (!mounted) return;
    final professional = ProfessionalScope.maybeOf(context);
    if (professional != null) {
      try {
        professional.saveLegacyTask(
          project.clientId,
          project.id,
          values[0],
          values[1],
          values[2],
          DateTime.parse(values[3]),
        );
      } catch (error) {
        professionalAction(context, () => throw error);
        return;
      }
      setState(() {});
      widget.onChanged();
      return;
    }
    setState(() {
      project.taskTitle = values[0];
      project.taskDescription = values[1];
      project.taskPriority = values[2];
      project.taskDueDate = DateTime.parse(values[3]);
      project.taskCreated = true;
      project.taskStatus = 'To Do';
    });
    widget.onChanged();
  }

  Future<void> archive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          project.isArchived ? 'Restore project?' : 'Archive project?',
        ),
        content: Text(
          project.isArchived
              ? 'Restore this project to your active management list?'
              : project.accepted
              ? 'Archiving hides the project from new applications. Current accepted members keep their project access.'
              : 'This project will no longer appear in student discovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(project.isArchived ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      project.isArchived = !project.isArchived;
      project.lifecycleStatus = project.isArchived
          ? 'Archived'
          : (project.accepted ? 'In Progress' : 'Published');
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Overview',
      'Applicants',
      'Team',
      'Tasks',
      'Chat',
      'Activity',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          IconButton(
            tooltip: project.accepted
                ? 'Locked after acceptance'
                : 'Edit Project',
            onPressed: project.accepted ? null : editCoreFields,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: project.isArchived ? 'Restore Project' : 'Archive Project',
            onPressed: archive,
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                tabs.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tabs[i]),
                    selected: page == i,
                    onSelected: (_) => setState(() => page = i),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (ProfessionalScope.maybeOf(context) != null)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TeamMatchingScreen(
                        repository: ProfessionalScope.maybeOf(context)!,
                        projectId: project.id,
                        actorId: project.clientId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Find Team Members'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openProjectSafety(
                    context,
                    ProfessionalScope.maybeOf(context)!,
                    project.id,
                    project.clientId,
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Agreement & Milestones'),
                ),
              ],
            ),
          ProjectReviewActions(project: project, actorId: project.clientId),
          if (page == 0) ...[
            StatusPill(
              text: project.lifecycleStatus,
              color: project.completed ? const Color(0xFF20A67A) : violet,
            ),
            const SizedBox(height: 12),
            InfoCard(
              icon: Icons.description_outlined,
              title: 'Project overview',
              body: project.detailedDescription.isEmpty
                  ? project.description
                  : project.detailedDescription,
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.lightbulb_outline,
              title: 'Problem to solve',
              body: project.problemToSolve.isEmpty
                  ? project.description
                  : project.problemToSolve,
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.flag_outlined,
              title: 'Expected deliverables',
              body: project.expectedResult,
            ),
            const SizedBox(height: 10),
            InfoCard(
              icon: Icons.rule_outlined,
              title: 'Requirements & timeline',
              body:
                  '${project.category} · ${project.difficulty}\nSkills: ${project.requiredSkills.join(', ')}\n${project.workMode} · ${project.teamSize} participant(s)\nDue ${_activityTime(project.deadlineAt)}',
            ),
            if (project.isPending)
              FilledButton.icon(
                onPressed: accept,
                icon: const Icon(Icons.check),
                label: Text('Accept ${project.applicantName ?? 'Applicant'}'),
              ),
          ],
          if (page == 1) ...[
            if (!project.applied)
              const EmptyState(
                title: 'No applicants yet',
                body: 'Student applications will appear here.',
              ),
            if (project.applied)
              ListTile(
                leading: Avatar(initials: 'S', accountId: project.applicantId),
                title: Text(project.applicantName ?? 'Student'),
                subtitle: Text(
                  '${project.applicantSpecialization} · ${project.applicantSkills.join(', ')}\n${project.applicationStatus}',
                ),
                isThreeLine: true,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      '${project.applicantName ?? 'Student'} profile',
                    ),
                    content: Text(
                      '${project.applicantSpecialization}\nSkills: ${project.applicantSkills.join(', ')}\nMotivation: ${project.motivation ?? 'Not provided'}\nPortfolio: ${project.portfolioLink ?? 'Not supplied'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            if (project.isPending) ...[
              FilledButton(
                onPressed: accept,
                child: const Text('Accept Application'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reject application?'),
                      content: const Text(
                        'The student will not receive workspace or chat access.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(project.rejectApplication);
                    widget.onChanged();
                  }
                },
                child: const Text('Reject'),
              ),
            ],
          ],
          if (page == 2) ...[
            if (!project.accepted)
              const EmptyState(
                title: 'Team not formed yet',
                body: 'Accept an applicant to add them to this project team.',
              ),
            if (project.accepted)
              Card(
                child: ListTile(
                  leading: Avatar(
                    initials: 'S',
                    accountId: project.applicantId,
                  ),
                  title: Text(project.applicantName ?? 'Student'),
                  subtitle: Text(
                    '${project.applicantSpecialization} · ${project.role}\nTask: ${project.taskCreated ? project.taskTitle : 'No task assigned'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'role') _editRole();
                      if (value == 'remove') _removeMember();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'role', child: Text('Edit Role')),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove Member'),
                      ),
                    ],
                  ),
                  onTap: () => openProjectChat(
                    context,
                    widget.chatRepository,
                    project,
                    ChatKind.direct,
                    project.clientId,
                    project.client,
                  ),
                ),
              ),
            if (project.accepted)
              OutlinedButton.icon(
                onPressed: () => openProjectChat(
                  context,
                  widget.chatRepository,
                  project,
                  ChatKind.direct,
                  project.clientId,
                  project.client,
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Message team member'),
              ),
          ],
          if (page == 3) ...[
            if (!project.accepted)
              const EmptyState(
                title: 'Tasks are unavailable',
                body: 'Accept a student before assigning project work.',
              ),
            if (project.accepted && !project.taskCreated)
              FilledButton.icon(
                onPressed: createTask,
                icon: const Icon(Icons.add_task),
                label: const Text('Create Task'),
              ),
            if (project.taskCreated)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined, color: violet),
                  title: Text(project.taskTitle),
                  subtitle: Text(
                    '${project.taskStatus} · ${project.taskPriority}\n${project.taskDescription}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') createTask();
                      if (value == 'review' && project.submitted) {
                        reviewSubmission(context, project, () {
                          setState(() {});
                          widget.onChanged();
                        });
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Task'),
                      ),
                      if (project.submitted)
                        const PopupMenuItem(
                          value: 'review',
                          child: Text('Review Submission'),
                        ),
                    ],
                  ),
                ),
              ),
            if (project.submitted)
              FilledButton(
                onPressed: () => reviewSubmission(context, project, () {
                  setState(() {});
                  widget.onChanged();
                }),
                child: const Text('Review Submission'),
              ),
          ],
          if (page == 4) ...[
            if (!project.accepted)
              const EmptyState(
                title: 'Chat unavailable',
                body: 'Only accepted members can access project conversations.',
              ),
            if (project.accepted) ...[
              FilledButton.icon(
                onPressed: () => openProjectChat(
                  context,
                  widget.chatRepository,
                  project,
                  ChatKind.team,
                  project.clientId,
                  project.client,
                ),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Open Team Chat'),
              ),
              OutlinedButton.icon(
                onPressed: () => openProjectChat(
                  context,
                  widget.chatRepository,
                  project,
                  ChatKind.direct,
                  project.clientId,
                  project.client,
                ),
                icon: const Icon(Icons.person_outline),
                label: Text(
                  'Direct Chat · ${project.applicantName ?? 'Student'}',
                ),
              ),
            ],
          ],
          if (page == 5) ...[
            ActivityLine(
              text: 'Project ${project.lifecycleStatus.toLowerCase()}',
            ),
            if (project.applied)
              ActivityLine(
                text:
                    '${project.applicantName ?? 'Student'} applied · ${_activityTime(project.appliedAt)}',
              ),
            if (project.accepted)
              ActivityLine(
                text: 'Application accepted · membership and project chats enabled',
              ),
            if (project.taskCreated)
              ActivityLine(text: 'Task assigned: ${project.taskTitle}'),
            if (project.submitted)
              ActivityLine(text: 'Work submitted for review'),
            if (project.approved) ActivityLine(text: 'Submission approved'),
            if (project.completed) ActivityLine(text: 'Project completed'),
          ],
        ],
      ),
    );
  }

  Future<void> _editRole() async {
    final controller = TextEditingController(text: project.role);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign project role'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Role'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => project.role = result);
      widget.onChanged();
    }
  }

  Future<void> _removeMember() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove project member?'),
        content: const Text(
          'This revokes this demo member’s access to project workspaces and chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (project.applicantId != null &&
        widget.chatRepository is DemoChatRepository) {
      (widget.chatRepository as DemoChatRepository).revokeProjectMember(
        project,
        project.applicantId!,
      );
    }
    setState(() {
      project.accepted = false;
      project.applicationStatus = 'Removed';
      project.lifecycleStatus = 'Published';
      project.taskCreated = false;
    });
    widget.onChanged();
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: violet,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.hub_outlined, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      const Flexible(
        child: Text(
          'ProjectBridge',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
    ],
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.accountId});
  final String initials;
  final String? accountId;
  @override
  Widget build(BuildContext context) {
    final photo = accountId == null
        ? null
        : SettingsScope.maybeOf(context)?.account(accountId!).photo;
    if (photo != null) {
      return ClipOval(
        child: SizedBox(
          width: 46,
          height: 46,
          child: FutureBuilder<String>(
            future: NativeAttachmentRepository().resolve(photo),
            builder: (_, snapshot) => snapshot.hasData
                ? Image.file(
                    File(snapshot.data!),
                    fit: BoxFit.cover,
                    cacheWidth: 138,
                    errorBuilder: (_, _, _) => const Icon(Icons.person),
                  )
                : const Icon(Icons.person),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFFEDE9FF),
      child: Text(
        initials,
        style: const TextStyle(color: violet, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.onTap,
    required this.onSaved,
  });
  final BridgeProject project;
  final VoidCallback onTap;
  final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE9EAF1)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: project.saved
                      ? 'Remove saved project'
                      : 'Save project',
                  onPressed: () {
                    project.saved = !project.saved;
                    onSaved();
                  },
                  icon: Icon(
                    project.saved ? Icons.bookmark : Icons.bookmark_border,
                    color: violet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${project.client}  ·  ${project.category}',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: project.skills
                  .take(3)
                  .map((s) => SkillChip(label: s))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFF0A23B), size: 17),
                const Text(
                  ' Beginner',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.applied
                        ? (project.accepted ? 'Accepted' : 'Applied')
                        : actualMatchLabel(context, project),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: violet,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1EEFF),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF5143C5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class ClientProjectTile extends StatelessWidget {
  const ClientProjectTile({
    super.key,
    required this.project,
    required this.onChanged,
    required this.chatRepository,
    this.onOpen,
  });
  final BridgeProject project;
  final VoidCallback onChanged;
  final ChatRepository chatRepository;
  final VoidCallback? onOpen;

  Future<void> _acceptApplicant(BuildContext context) async {
    if (!project.applied || project.applicantId == null || project.accepted) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept applicant?'),
        content: Text(
          'Accept ${project.applicantName ?? 'this student'} to ${project.title}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    if (!context.mounted) return;
    if (project.teamSize < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This project has no open positions.')),
      );
      return;
    }
    project.acceptApplication(chatRepository);
    onChanged();
  }

  Future<void> _completeProject(BuildContext context) async {
    if (!project.approved || !project.taskCreated) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete project?'),
        content: const Text(
          'The required task has been approved. Completing creates a demo Passport record for the student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Project'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    if (!context.mounted) return;
    final professional = ProfessionalScope.maybeOf(context);
    if (professional != null) {
      try {
        professional.completeProject(project.clientId, project.id);
      } catch (error) {
        professionalAction(context, () => throw error);
        return;
      }
    } else {
      project.completed = true;
      project.completedAt = DateTime.now();
      project.lifecycleStatus = 'Completed';
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: Color(0xFFE9EAF1)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${project.category} · ${project.lifecycleStatus}',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 9),
          Text(
            project.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children:
                [
                      'Team ${project.accepted ? 1 : 0}/${project.teamSize}',
                      '${project.applied ? 1 : 0} applicants',
                      '${project.progress}% complete',
                      'Due ${_activityTime(project.deadlineAt)}',
                    ]
                    .map(
                      (text) => Text(
                        text,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    )
                    .toList(),
          ),
          if (project.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: project.requiredSkills
                  .map((skill) => SkillChip(label: skill))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 6,
              color: violet,
              backgroundColor: const Color(0xFFE9EAF1),
            ),
          ),
          if (onOpen != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Project'),
              ),
            ),
          if (project.applied) ...[
            const Divider(height: 23),
            Row(
              children: [
                Avatar(
                  initials: (project.applicantName ?? 'S')
                      .substring(0, 1)
                      .toUpperCase(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${project.applicantName ?? 'Student'} · Applicant',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (project.isPending)
                  FilledButton(
                    onPressed: () => _acceptApplicant(context),
                    child: const Text('Accept'),
                  )
                else if (project.accepted)
                  const Text(
                    'Accepted',
                    style: TextStyle(
                      color: Color(0xFF20A67A),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (project.applicationStatus == 'Rejected')
                  const Text(
                    'Rejected',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                if (project.isPending)
                  TextButton(
                    onPressed: () {
                      showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reject application?'),
                          content: const Text(
                            'Rejected students will not receive project or chat access.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ).then((confirm) {
                        if (confirm == true) {
                          project.rejectApplication();
                          onChanged();
                        }
                      });
                    },
                    child: const Text('Reject'),
                  ),
              ],
            ),
            if (project.motivation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Motivation: ${project.motivation}',
                style: const TextStyle(color: muted),
              ),
              if (project.availability != null)
                Text(
                  'Availability: ${project.availability}',
                  style: const TextStyle(color: muted),
                ),
            ],
          ],
          if (project.submitted) ...[
            const Divider(height: 23),
            Row(
              children: [
                const Icon(Icons.task_alt, color: violet),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.approved
                        ? 'Task approved'
                        : 'Daria submitted a task',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!project.approved)
                  TextButton(
                    onPressed: () =>
                        reviewSubmission(context, project, onChanged),
                    child: const Text('Review'),
                  ),
              ],
            ),
          ],
          if (project.accepted && !project.taskCreated)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final professional = ProfessionalScope.maybeOf(context);
                  if (professional != null) {
                    professionalAction(
                      context,
                      () => professional.saveLegacyTask(
                        project.clientId,
                        project.id,
                        project.taskTitle,
                        project.taskDescription,
                        project.taskPriority,
                        project.taskDueDate,
                      ),
                    );
                  } else {
                    project.taskCreated = true;
                    project.taskStatus = 'To Do';
                  }
                  onChanged();
                },
                icon: const Icon(Icons.add_task),
                label: const Text('Create task'),
              ),
            ),
          if (project.accepted)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => openProjectChat(
                    context,
                    chatRepository,
                    project,
                    ChatKind.team,
                    project.clientId,
                    'Demo Coffee',
                  ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Team chat'),
                ),
                TextButton.icon(
                  onPressed: () => openProjectChat(
                    context,
                    chatRepository,
                    project,
                    ChatKind.direct,
                    project.clientId,
                    'Demo Coffee',
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Student chat'),
                ),
              ],
            ),
          if (project.approved && project.taskCreated && !project.completed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _completeProject(context),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Complete project'),
              ),
            ),
          ProjectReviewActions(project: project, actorId: project.clientId),
          if (project.completed)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Label(text: 'Passport ready', color: Color(0xFF20A67A)),
            ),
        ],
      ),
    ),
  );
}

class WorkspaceTile extends StatelessWidget {
  const WorkspaceTile({
    super.key,
    required this.project,
    required this.onChanged,
    required this.chatRepository,
    required this.studentName,
  });
  final BridgeProject project;
  final VoidCallback onChanged;
  final ChatRepository chatRepository;
  final String studentName;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFF1EEFF),
        child: Icon(Icons.assignment_outlined, color: violet),
      ),
      title: Text(project.title),
      subtitle: Text(
        project.completed
            ? 'Project complete · View passport status'
            : project.taskCreated
            ? (project.submitted
                  ? (project.approved
                        ? 'Task approved'
                        : 'Submitted · Awaiting review')
                  : 'Task assigned · Due in 5 days')
            : 'Workspace · Waiting for client task',
      ),
      trailing: project.taskCreated && !project.submitted
          ? IconButton(
              onPressed: () => submitTask(context, project, onChanged),
              icon: const Icon(Icons.upload_outlined, color: violet),
            )
          : project.completed
          ? const Icon(Icons.workspace_premium, color: violet)
          : null,
      onTap: project.completed
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PassportDetailsScreen(
                  project: project,
                  studentName: studentName,
                  specialization: 'Mobile Development',
                ),
              ),
            )
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProjectWorkspace(
                  project: project,
                  onChanged: onChanged,
                  chatRepository: chatRepository,
                  userId: 'student-daria',
                  displayName: studentName,
                ),
              ),
            ),
    ),
  );
}

class Label extends StatelessWidget {
  const Label({super.key, required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: color, fontWeight: FontWeight.w700),
  );
}

Future<void> openProject(
  BuildContext context,
  BridgeProject p,
  VoidCallback onChanged, {
  List<String> skills = const [],
  required ChatRepository chatRepository,
  required String displayName,
}) async {
  final resolvedSkills = skills.isEmpty
      ? ProfessionalScope.maybeOf(context)?.profile('student-daria').skills ??
            skills
      : skills;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProjectDetails(
        project: p,
        onChanged: onChanged,
        skills: resolvedSkills,
        chatRepository: chatRepository,
        displayName: displayName,
      ),
    ),
  );
}

class ProjectDetails extends StatelessWidget {
  const ProjectDetails({
    super.key,
    required this.project,
    required this.onChanged,
    required this.chatRepository,
    required this.displayName,
    this.skills = const [],
  });
  final BridgeProject project;
  final VoidCallback onChanged;
  final List<String> skills;
  final ChatRepository chatRepository;
  final String displayName;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          project.title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${project.client} · ${project.category}',
          style: const TextStyle(color: muted),
        ),
        ProjectReviewActions(project: project, actorId: 'student-daria'),
        if (ReviewScope.maybeOf(context) case final reviews?)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ReviewProfileScreen(
                  repository: reviews,
                  profileId: project.clientId,
                  actorId: 'student-daria',
                  client: true,
                ),
              ),
            ),
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('View Client Reviews'),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.verified_outlined, color: muted, size: 18),
            const SizedBox(width: 6),
            Text(
              '${project.client} · demo partner, not independently verified',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Label(text: 'About this project', color: ink),
        const SizedBox(height: 8),
        Text(project.description, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 20),
        const Label(text: 'Skills you will use', color: ink),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          children: project.skills.map((s) => SkillChip(label: s)).toList(),
        ),
        const SizedBox(height: 22),
        InfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Expected deliverable',
          body: project.expectedResult,
        ),
        const SizedBox(height: 15),
        InfoCard(
          icon: Icons.event_outlined,
          title: 'Timeline and deadline',
          body:
              '${project.difficulty} · ${project.estimatedTimeline ?? 'Deadline ${project.deadlineAt.toLocal().toString().split(' ').first}'} · ${project.accepted ? 'Team member' : '${project.teamSize} positions available'}',
        ),
        const SizedBox(height: 15),
        InfoCard(
          icon: Icons.rule_outlined,
          title: 'Participation conditions',
          body: project.conditions,
        ),
        const SizedBox(height: 15),
        InfoCard(
          icon: Icons.auto_awesome_outlined,
          title:
              'Skill match · ${project.skills.where(skills.contains).length}/${project.skills.length}',
          body:
              'A skill-based indicator, not a prediction of success. Your skills: ${skills.join(', ')}.',
        ),
        const SizedBox(height: 15),
        InfoCard(
          icon: Icons.handshake_outlined,
          title: 'Scope and compensation',
          body:
              '${project.expectedResult}\n${project.compensation}\nWeekly commitment: ${project.weeklyCommitment == null ? 'To be agreed' : '${project.weeklyCommitment} hours'}\nTeam: ${project.teamSize} · Deadline: ${project.deadlineAt.toLocal().toString().split(' ').first}\nClient expectations: ${project.conditions}',
        ),
        if (ProfessionalScope.maybeOf(context) != null)
          TextButton.icon(
            onPressed: () => openSafetyReport(
              context,
              ProfessionalScope.maybeOf(context)!,
              'student-daria',
              project.id,
            ),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report a problem'),
          ),
        const SizedBox(height: 25),
        if (project.accepted)
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProjectWorkspace(
                  project: project,
                  onChanged: onChanged,
                  chatRepository: chatRepository,
                  userId: 'student-daria',
                  displayName: displayName,
                ),
              ),
            ),
            child: const Text('Open workspace'),
          )
        else if (project.applied)
          StatusPill(text: project.applicationStatus, color: violet)
        else
          FilledButton(
            onPressed: () => applyToProject(
              context,
              project,
              onChanged,
              skills,
              applicantId: 'student-daria',
              applicantName: displayName,
            ),
            child: const Text('Apply to project'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            project.saved = !project.saved;
            onChanged();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  project.saved
                      ? 'Project saved'
                      : 'Project removed from saved',
                ),
              ),
            );
          },
          icon: Icon(project.saved ? Icons.bookmark : Icons.bookmark_border),
          label: Text(project.saved ? 'Saved project' : 'Save project'),
        ),
      ],
    ),
  );
}

Future<void> reviewSubmission(
  BuildContext context,
  BridgeProject project,
  VoidCallback changed,
) async {
  final feedback = TextEditingController(text: project.feedback);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Review student work'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.submissionText ?? 'Student submitted a deliverable.'),
            const SizedBox(height: 14),
            TextField(
              controller: feedback,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (feedback.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add feedback before requesting a revision.'),
                ),
              );
              return;
            }
            final professional = ProfessionalScope.maybeOf(context);
            if (professional != null) {
              try {
                professional.reviewWork(
                  project.clientId,
                  project.id,
                  false,
                  feedback.text,
                );
              } catch (error) {
                professionalAction(context, () => throw error);
                return;
              }
            } else {
              project.feedback = feedback.text.trim();
              project.submitted = false;
              project.taskStatus = 'Revision Requested';
            }
            changed();
            Navigator.pop(context);
          },
          child: const Text('Request revision'),
        ),
        FilledButton(
          onPressed: () {
            final professional = ProfessionalScope.maybeOf(context);
            if (professional != null) {
              try {
                professional.reviewWork(
                  project.clientId,
                  project.id,
                  true,
                  feedback.text,
                );
              } catch (error) {
                professionalAction(context, () => throw error);
                return;
              }
            } else {
              project.approved = true;
              project.taskStatus = 'Approved';
              project.feedback = feedback.text.trim().isEmpty
                  ? 'Approved by the client.'
                  : feedback.text.trim();
            }
            changed();
            Navigator.pop(context);
          },
          child: const Text('Approve'),
        ),
      ],
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE9EAF1)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: violet),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(body, style: const TextStyle(color: muted, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> createProject(
  BuildContext context,
  List<BridgeProject> projects,
  VoidCallback changed,
) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final created = await showModalBottomSheet<BridgeProject>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a project',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Project title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What will students work on?',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty ||
                    description.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  BridgeProject(
                    title.text.trim(),
                    'Demo Coffee',
                    'Web Development',
                    description.text.trim(),
                    ['HTML', 'CSS'],
                  ),
                );
              },
              child: const Text('Publish demo project'),
            ),
          ),
        ],
      ),
    ),
  );
  if (created != null) {
    projects.insert(0, created);
    changed();
  }
}

Future<void> submitTask(
  BuildContext context,
  BridgeProject project,
  VoidCallback changed,
) async {
  final note = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Submit your work'),
      content: TextField(
        controller: note,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Describe your result or add a link',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (note.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add a description or link before submitting.'),
                ),
              );
              return;
            }
            final professional = ProfessionalScope.maybeOf(context);
            if (professional != null) {
              try {
                professional.submitWork(
                  'student-daria',
                  project.id,
                  note.text,
                  project.progressNote ?? '',
                );
              } catch (error) {
                professionalAction(context, () => throw error);
                return;
              }
            } else {
              project.submitted = true;
              project.submissionText = note.text.trim();
              project.taskStatus = 'Submitted';
            }
            changed();
            Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

void showPassport(BuildContext context, BridgeProject p) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.workspace_premium, color: violet, size: 42),
    title: const Text('Project Passport'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('Completed by Daria · Mobile Development'),
        const SizedBox(height: 8),
        Text(
          'Unverified legacy completion record · ${p.client}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 8),
        const Text('Flutter · Dart · Firebase'),
        const SizedBox(height: 14),
        const Label(
          text: 'DEMO PASSPORT · NOT A REAL CREDENTIAL',
          color: violet,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

void notice(BuildContext context) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('You’re all caught up.')));

Future<void> openProjectChat(
  BuildContext context,
  ChatRepository repository,
  BridgeProject project,
  ChatKind kind,
  String userId,
  String displayName,
) async {
  if (project.acceptedParticipantIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Chat is available after the client accepts your application.',
        ),
      ),
    );
    return;
  }
  repository.ensureProjectChats(project);
  final id = repository.chatIdFor(project, kind);
  final thread = repository.findThread(id);
  if (thread == null || !thread.participants.contains(userId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This account is not a project participant.'),
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).clearSnackBars();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProjectChatScreen(
        repository: repository,
        chatId: id,
        userId: userId,
        displayName: displayName,
      ),
    ),
  );
}

class WorkSample {
  WorkSample({
    required this.title,
    required this.description,
    required this.technologies,
    required this.url,
    required this.type,
  });
  String title, description, technologies, url, type;
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.projects,
    required this.onChanged,
    required this.skills,
    required this.chatRepository,
    required this.studentName,
  });
  final List<BridgeProject> projects;
  final VoidCallback onChanged;
  final List<String> skills;
  final ChatRepository chatRepository;
  final String studentName;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final search = TextEditingController();
  String category = 'All categories', difficulty = 'All levels';
  String status = 'All projects';
  bool newest = true, savedOnly = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<BridgeProject> get results {
    final q = search.text.trim().toLowerCase();
    final list = widget.projects.where((p) {
      final text =
          '${p.title} ${p.description} ${p.client} ${p.skills.join(' ')}'
              .toLowerCase();
      return p.isPublished &&
          !p.isArchived &&
          p.lifecycleStatus != 'Draft' &&
          p.lifecycleStatus != 'Pending Review' &&
          p.lifecycleStatus != 'Completed' &&
          (q.isEmpty || text.contains(q)) &&
          (category == 'All categories' || p.category == category) &&
          (difficulty == 'All levels' || p.difficulty == difficulty) &&
          (status == 'All projects' ||
              (status == 'Saved'
                  ? p.saved
                  : status == 'Open'
                  ? !p.completed && !p.accepted
                  : p.completed)) &&
          (!savedOnly || p.saved);
    }).toList();
    if (newest) list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
    children: [
      const Brand(),
      const SizedBox(height: 22),
      Text(
        'Explore Projects',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      const Text(
        'Find your next real-world opportunity.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search projects, skills, clients',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: openFilters,
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: !savedOnly,
            onSelected: (_) => setState(() => savedOnly = false),
          ),
          ChoiceChip(
            label: const Text('Saved'),
            selected: savedOnly,
            onSelected: (_) => setState(() => savedOnly = !savedOnly),
          ),
        ],
      ),
      const SizedBox(height: 17),
      SectionTitle(
        '${results.length} opportunities',
        trailing: TextButton.icon(
          onPressed: () => setState(() => newest = !newest),
          icon: const Icon(Icons.sort, size: 18),
          label: Text(newest ? 'Newest' : 'Relevance'),
        ),
      ),
      if (results.isEmpty)
        EmptyState(
          title: 'No matching projects',
          body: 'Try another search or reset your filters.',
          action: 'Reset search',
          onAction: () {
            search.clear();
            category = 'All categories';
            difficulty = 'All levels';
            status = 'All projects';
            savedOnly = false;
            setState(() {});
          },
        )
      else
        ...results.map(
          (p) => ProjectTile(
            project: p,
            onSaved: widget.onChanged,
            onTap: () => openProject(
              context,
              p,
              widget.onChanged,
              skills: widget.skills,
              chatRepository: widget.chatRepository,
              displayName: widget.studentName,
            ),
          ),
        ),
    ],
  );
  Future<void> openFilters() async {
    var c = category, d = difficulty, s = status;
    final values = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const Text('Category'),
              DropdownButton<String>(
                isExpanded: true,
                value: c,
                items:
                    [
                          'All categories',
                          'Mobile Development',
                          'Web Development',
                          'UX/UI Design',
                          'Graphic Design',
                          'Testing',
                          'Other',
                        ]
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                onChanged: (x) => update(() => c = x!),
              ),
              const Text('Difficulty'),
              DropdownButton<String>(
                isExpanded: true,
                value: d,
                items: ['All levels', 'Beginner', 'Intermediate', 'Advanced']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (x) => update(() => d = x!),
              ),
              const Text('Project status'),
              DropdownButton<String>(
                isExpanded: true,
                value: s,
                items: ['All projects', 'Open', 'Completed', 'Saved']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (x) => update(() => s = x!),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, [
                      'All categories',
                      'All levels',
                      'All projects',
                    ]),
                    child: const Text('Reset filters'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, [c, d, s]),
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (values != null && mounted) {
      setState(() {
        category = values[0];
        difficulty = values[1];
        status = values[2];
      });
    }
  }
}

class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({
    super.key,
    required this.projects,
    required this.onChanged,
    required this.onExplore,
    required this.chatRepository,
    required this.studentName,
  });
  final List<BridgeProject> projects;
  final VoidCallback onChanged;
  final VoidCallback onExplore;
  final ChatRepository chatRepository;
  final String studentName;
  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  int segment = 0;
  @override
  Widget build(BuildContext context) {
    final list = widget.projects
        .where(
          (p) => segment == 0
              ? p.applied
              : segment == 1
              ? p.accepted && !p.completed
              : p.completed,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Brand(),
        const SizedBox(height: 22),
        Text(
          'My Projects',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Track your applications and active work.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Applications')),
            ButtonSegment(value: 1, label: Text('Active')),
            ButtonSegment(value: 2, label: Text('Completed')),
          ],
          selected: {segment},
          onSelectionChanged: (x) => setState(() => segment = x.first),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            title: segment == 0
                ? 'No applications yet'
                : segment == 1
                ? 'No active projects'
                : 'No completed projects',
            body: 'Explore opportunities and start building real experience.',
            action: 'Explore projects',
            onAction: widget.onExplore,
          ),
        ...list.map(
          (p) => ApplicationCard(
            project: p,
            onChanged: widget.onChanged,
            onWorkspace: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProjectWorkspace(
                  project: p,
                  onChanged: widget.onChanged,
                  chatRepository: widget.chatRepository,
                  userId: 'student-daria',
                  displayName: widget.studentName,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ApplicationCard extends StatelessWidget {
  const ApplicationCard({
    super.key,
    required this.project,
    required this.onChanged,
    required this.onWorkspace,
  });
  final BridgeProject project;
  final VoidCallback onChanged, onWorkspace;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE9EAF1)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${project.client} · applied ${project.appliedAt.month}/${project.appliedAt.day}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusPill(
                text: project.completed
                    ? 'Completed'
                    : project.accepted
                    ? 'Accepted'
                    : project.applicationStatus,
                color: project.accepted ? const Color(0xFF20A67A) : violet,
              ),
              const Spacer(),
              if (project.applicationStatus == 'Withdrawn' &&
                  ProfessionalScope.maybeOf(context) != null)
                TextButton(
                  onPressed: () => openProjectSafety(
                    context,
                    ProfessionalScope.maybeOf(context)!,
                    project.id,
                    'student-daria',
                  ),
                  child: const Text('View collaboration history'),
                ),
              if (project.completed)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PassportDetailsScreen(
                        project: project,
                        studentName: project.applicantName ?? 'Student',
                        specialization: project.applicantSpecialization,
                      ),
                    ),
                  ),
                  child: const Text('View Project Passport'),
                ),
              if (project.accepted && !project.completed)
                TextButton(
                  onPressed: onWorkspace,
                  child: const Text('Open workspace'),
                ),
              if (project.applied &&
                  !project.accepted &&
                  !project.completed &&
                  project.isPending)
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Withdraw application?'),
                      content: const Text('You can apply again later.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          onPressed: () {
                            project.applicationStatus = 'Withdrawn';
                            onChanged();
                            Navigator.pop(context);
                          },
                          child: const Text('Withdraw'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Withdraw'),
                ),
            ],
          ),
          ProjectReviewActions(project: project, actorId: 'student-daria'),
        ],
      ),
    ),
  );
}

class ProjectWorkspace extends StatefulWidget {
  const ProjectWorkspace({
    super.key,
    required this.project,
    required this.onChanged,
    required this.chatRepository,
    required this.userId,
    required this.displayName,
  });
  final BridgeProject project;
  final VoidCallback onChanged;
  final ChatRepository chatRepository;
  final String userId, displayName;
  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${p.client} · ${p.role}', style: const TextStyle(color: muted)),
          const SizedBox(height: 15),
          if (ProfessionalScope.maybeOf(context) != null)
            OutlinedButton.icon(
              onPressed: () => openProjectSafety(
                context,
                ProfessionalScope.maybeOf(context)!,
                p.id,
                widget.userId,
              ),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Agreement & Milestones'),
            ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Overview')),
              ButtonSegment(value: 1, label: Text('Tasks')),
              ButtonSegment(value: 2, label: Text('Team')),
              ButtonSegment(value: 3, label: Text('Activity')),
              ButtonSegment(value: 4, label: Text('Chat')),
            ],
            selected: {page},
            onSelectionChanged: (s) => setState(() => page = s.first),
          ),
          const SizedBox(height: 18),
          if (page == 0) ...[
            InfoCard(
              icon: Icons.info_outline,
              title: 'Project overview',
              body: p.description,
            ),
            const SizedBox(height: 12),
            SectionTitle('Progress · ${p.progress}%'),
            LinearProgressIndicator(
              value: p.progress / 100,
              color: violet,
              backgroundColor: const Color(0xFFE9EAF1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 20),
            InfoCard(
              icon: Icons.flag_outlined,
              title: 'Expected result',
              body: p.expectedResult,
            ),
            const SizedBox(height: 12),
            InfoCard(
              icon: Icons.event_outlined,
              title: 'Milestone',
              body:
                  'Deliver first reviewed task by ${p.deadlineAt.toLocal().toString().split(' ').first}.',
            ),
          ],
          if (page == 1) TaskPanel(project: p, onChanged: widget.onChanged),
          if (page == 2) ...[
            const SectionTitle('Project team'),
            ListTile(
              leading: Avatar(initials: 'S', accountId: p.applicantId),
              title: Text(
                context
                        .findAncestorStateOfType<_ProjectBridgeAppState>()
                        ?.accountName(
                          p.applicantId ?? '',
                          p.applicantName ?? 'Student',
                        ) ??
                    p.applicantName ??
                    'Student',
              ),
              subtitle: const Text('Student contributor'),
            ),
            ListTile(
              leading: const Avatar(
                initials: 'DC',
                accountId: 'client-demo-coffee',
              ),
              title: Text(p.client),
              subtitle: const Text('Client and project lead'),
            ),
            const ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('Mentor'),
              subtitle: Text('No mentor assigned'),
            ),
          ],
          if (page == 3) ...[
            const SectionTitle('Activity'),
            ActivityLine(
              text: 'Application ${p.accepted ? 'accepted' : 'submitted'}',
            ),
            if (p.taskCreated) const ActivityLine(text: 'Task assigned'),
            if (p.submitted)
              const ActivityLine(text: 'Work submitted for review'),
            if (p.approved)
              const ActivityLine(text: 'Client approved the task'),
            if (p.completed) const ActivityLine(text: 'Project completed'),
            ProjectReviewActions(project: p, actorId: widget.userId),
          ],
          if (page == 4) ...[
            const SectionTitle('Project conversations'),
            const Text(
              'Only accepted project members can open these chats.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openProjectChat(
                context,
                widget.chatRepository,
                p,
                ChatKind.team,
                widget.userId,
                widget.displayName,
              ),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Open team chat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openProjectChat(
                context,
                widget.chatRepository,
                p,
                ChatKind.direct,
                widget.userId,
                widget.displayName,
              ),
              icon: const Icon(Icons.person_outline),
              label: const Text('Open client direct chat'),
            ),
          ],
        ],
      ),
    );
  }
}

class TaskPanel extends StatelessWidget {
  const TaskPanel({super.key, required this.project, required this.onChanged});
  final BridgeProject project;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final p = project;
    if (!p.taskCreated) {
      return const EmptyState(
        title: 'No tasks assigned yet',
        body: 'The client will add tasks to your workspace.',
        action: null,
        onAction: null,
      );
    }
    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: violet),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.taskTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusPill(
                  text: p.taskStatus,
                  color: p.approved ? const Color(0xFF20A67A) : violet,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.taskDescription,
              style: const TextStyle(color: muted, height: 1.4),
            ),
            if (p.feedback != null) ...[
              const SizedBox(height: 12),
              InfoCard(
                icon: Icons.feedback_outlined,
                title: 'Client feedback',
                body: p.feedback!,
              ),
            ],
            if (p.progressNote != null) ...[
              const SizedBox(height: 10),
              Text('Progress note: ${p.progressNote}'),
            ],
            Text(
              'Due ${_activityTime(p.taskDueDate)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (!p.submitted || p.feedback != null)
              FilledButton(
                onPressed: () => taskSubmission(context, p, onChanged),
                child: Text(
                  p.feedback != null
                      ? 'Resubmit work'
                      : p.submitted
                      ? 'Submitted'
                      : 'Start and submit task',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> taskSubmission(
  BuildContext context,
  BridgeProject p,
  VoidCallback changed,
) async {
  final note = TextEditingController(text: p.submissionText ?? '');
  final progress = TextEditingController(text: p.progressNote ?? '');
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Task submission'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: progress,
              decoration: const InputDecoration(labelText: 'Progress note'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Result, GitHub or Figma link',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (note.text.trim().isEmpty) return;
            final professional = ProfessionalScope.maybeOf(context);
            if (professional != null) {
              try {
                professional.submitWork(
                  'student-daria',
                  p.id,
                  note.text,
                  progress.text,
                );
              } catch (error) {
                professionalAction(context, () => throw error);
                return;
              }
            } else {
              p.progressNote = progress.text.trim();
              p.submissionText = note.text.trim();
              p.submitted = true;
              p.feedback = null;
              p.taskStatus = 'Submitted';
            }
            changed();
            Navigator.pop(context);
          },
          child: const Text('Submit for review'),
        ),
      ],
    ),
  );
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({
    super.key,
    required this.projects,
    required this.samples,
    required this.name,
    required this.college,
    required this.specialization,
    required this.skills,
    required this.onChanged,
    required this.onExplore,
    required this.onEditSkills,
  });
  final List<BridgeProject> projects;
  final List<WorkSample> samples;
  final String name, college, specialization;
  final List<String> skills;
  final VoidCallback onChanged, onExplore, onEditSkills;
  @override
  Widget build(BuildContext context) {
    final repository = ProfessionalScope.maybeOf(context);
    if (repository != null) {
      return ProfessionalPortfolioBody(
        repository: repository,
        profileId: 'student-daria',
        actorId: 'student-daria',
      );
    }
    final done = projects
        .where((p) => p.completed && p.approved && p.portfolioPermission)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Brand(),
        const SizedBox(height: 22),
        Text(
          'My Portfolio',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your skills. Your work. Your real experience.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EAF1)),
          ),
          child: Row(
            children: [
              const Avatar(initials: 'D'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$specialization · $college',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${done.length} completed',
                style: const TextStyle(
                  color: violet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle('Verified Projects'),
        if (done.isEmpty)
          EmptyState(
            title: 'Your first real project starts here.',
            body: 'Complete a project and receive client approval to build your verified portfolio.',
            action: 'Explore Projects',
            onAction: onExplore,
          )
        else
          ...done.map(
            (p) => PassportCard(
              project: p,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PassportDetailsScreen(
                    project: p,
                    studentName: name,
                    specialization: specialization,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SectionTitle(
          'Work Samples',
          trailing: TextButton.icon(
            onPressed: () => editSample(context, null, samples, onChanged),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        if (samples.isEmpty)
          const Text(
            'Add independent work samples to complement your verified experience.',
            style: TextStyle(color: muted),
          ),
        ...samples.map(
          (s) =>
              WorkSampleCard(sample: s, samples: samples, onChanged: onChanged),
        ),
        const SizedBox(height: 20),
        SectionTitle(
          'Skills',
          trailing: TextButton(
            onPressed: onEditSkills,
            child: const Text('Edit skills'),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skills.map((x) => SkillChip(label: x)).toList(),
        ),
      ],
    );
  }
}

class PassportCard extends StatelessWidget {
  const PassportCard({super.key, required this.project, required this.onTap});
  final BridgeProject project;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const Icon(Icons.workspace_premium, color: violet, size: 30),
      title: Text(project.title),
      subtitle: Text(
        '${project.client} · ${project.role}\nCompletion record · Passport PB-${project.id}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class PassportDetailsScreen extends StatelessWidget {
  const PassportDetailsScreen({
    super.key,
    required this.project,
    required this.studentName,
    required this.specialization,
  });
  final BridgeProject project;
  final String studentName, specialization;
  @override
  Widget build(BuildContext context) {
    final record = ProfessionalScope.maybeOf(context)
        ?.passportForProject(project.id);
    if (record != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Passport')),
        body: VerifiedPassportBody(passport: record),
      );
    }
    final id = 'PB-${project.id}';
    return Scaffold(
      appBar: AppBar(title: const Text('Project Passport')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE9EAF1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.workspace_premium, color: violet, size: 40),
                const SizedBox(height: 14),
                Text(
                  project.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('Completed by $studentName · $specialization'),
                const SizedBox(height: 10),
                StatusPill(
                  text: 'Unverified legacy demo record',
                  color: violet,
                ),
                const Divider(height: 28),
                InfoCard(
                  icon: Icons.business_outlined,
                  title: 'Client',
                  body: project.client,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.task_alt,
                  title: 'Approved contribution',
                  body: project.submissionText ?? project.expectedResult,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.code,
                  title: 'Technologies',
                  body: project.skills.join(' · '),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.verified_outlined,
                  title: 'Verification source',
                  body:
                      'No authorized Stage 2 completion evidence is recorded.',
                ),
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.event_outlined,
                  title: 'Completion date',
                  body:
                      project.completedAt
                          ?.toLocal()
                          .toString()
                          .split(' ')
                          .first ??
                      'Not recorded',
                ),
                const SizedBox(height: 12),
                Text('Passport ID  $id', style: const TextStyle(color: muted)),
                const SizedBox(height: 20),
                const Label(
                  text: 'DEMO PASSPORT · NOT A REAL CREDENTIAL',
                  color: violet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const InfoCard(
            icon: Icons.lock_outline,
            title: 'Public sharing unavailable',
            body: 'This project has no configured public sharing permission or verified server record. Sharing is disabled in this demo.',
          ),
        ],
      ),
    );
  }
}

class WorkSampleCard extends StatelessWidget {
  const WorkSampleCard({
    super.key,
    required this.sample,
    required this.samples,
    required this.onChanged,
  });
  final WorkSample sample;
  final List<WorkSample> samples;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    child: ListTile(
      leading: const Icon(Icons.link, color: violet),
      title: Text(sample.title),
      subtitle: Text(
        '${sample.type} · ${sample.technologies}\nSelf-added sample',
      ),
      isThreeLine: true,
      onTap: () => editSample(context, sample, samples, onChanged),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          samples.remove(sample);
          onChanged();
        },
      ),
    ),
  );
}

Future<void> editSample(
  BuildContext context,
  WorkSample? current,
  List<WorkSample> samples,
  VoidCallback changed,
) async {
  final title = TextEditingController(text: current?.title),
      description = TextEditingController(text: current?.description),
      tech = TextEditingController(text: current?.technologies),
      url = TextEditingController(text: current?.url);
  final result = await showDialog<WorkSample>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(current == null ? 'Add work sample' : 'Edit work sample'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: tech,
              decoration: const InputDecoration(labelText: 'Technologies'),
            ),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'Image or project URL',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              WorkSample(
                title: title.text.trim(),
                description: description.text.trim(),
                technologies: tech.text.trim(),
                url: url.text.trim(),
                type: 'Self-directed',
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result != null) {
    if (current == null) {
      samples.add(result);
    } else {
      current.title = result.title;
      current.description = result.description;
      current.technologies = result.technologies;
      current.url = result.url;
    }
    changed();
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.college,
    required this.specialization,
    required this.course,
    required this.biography,
    required this.level,
    required this.skills,
    required this.interests,
    required this.projects,
    required this.onEdit,
    required this.onLogout,
    required this.onClient,
  });
  final String name, college, specialization, course, biography, level;
  final List<String> skills, interests;
  final List<BridgeProject> projects;
  final VoidCallback onLogout, onClient;
  final Future<void> Function() onEdit;
  @override
  Widget build(BuildContext context) => ProfileOverview(
    client: false,
    name: name,
    subtitle: 'Student · $specialization',
    description: biography,
    projects: projects,
    onEdit: onEdit,
    onSwitch: onClient,
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.professionalProfile,
    required this.name,
    required this.college,
    required this.specialization,
    required this.course,
    required this.biography,
    required this.level,
    required this.skills,
    required this.interests,
  });
  final ProfessionalProfile? professionalProfile;
  final String name, college, specialization, course, biography, level;
  final List<String> skills, interests;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final name = TextEditingController(text: widget.name),
      college = TextEditingController(text: widget.college),
      specialization = TextEditingController(text: widget.specialization),
      course = TextEditingController(text: widget.course),
      bio = TextEditingController(text: widget.biography),
      skills = TextEditingController(text: widget.skills.join(', ')),
      interests = TextEditingController(text: widget.interests.join(', '));
  late final headline = TextEditingController(
        text: widget.professionalProfile?.headline ?? '',
      ),
      city = TextEditingController(
        text: widget.professionalProfile?.city ?? '',
      ),
      hours = TextEditingController(
        text: widget.professionalProfile?.weeklyHours?.toString() ?? '',
      ),
      preferredRoles = TextEditingController(
        text: widget.professionalProfile?.preferredRoles.join(', ') ?? '',
      ),
      studyProgram = TextEditingController(
        text:
            widget.professionalProfile?.education?.program ??
            widget.specialization,
      ),
      studyPeriod = TextEditingController(
        text: widget.professionalProfile?.education?.period ?? widget.course,
      ),
      institutionType = TextEditingController(
        text: widget.professionalProfile?.education?.type ?? 'College',
      ),
      institutionCity = TextEditingController(
        text: widget.professionalProfile?.education?.city ?? '',
      );
  late Availability availability =
      widget.professionalProfile?.availability ?? Availability.unknown;
  String level = '';
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    level = widget.level;
  }

  @override
  void dispose() {
    for (final c in [
      name,
      college,
      specialization,
      course,
      bio,
      skills,
      interests,
      headline,
      city,
      hours,
      preferredRoles,
      studyProgram,
      studyPeriod,
      institutionType,
      institutionCity,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          TextFormField(
            controller: headline,
            decoration: const InputDecoration(
              labelText: 'Professional headline',
            ),
          ),
          TextFormField(
            controller: city,
            decoration: const InputDecoration(labelText: 'City (optional)'),
          ),
          DropdownButtonFormField<Availability>(
            initialValue: availability,
            decoration: const InputDecoration(labelText: 'Availability'),
            items: Availability.values
                .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                .toList(),
            onChanged: (value) => setState(() => availability = value!),
          ),
          TextFormField(
            controller: hours,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Hours per week (optional)',
            ),
            validator: (v) =>
                v == null ||
                    v.trim().isEmpty ||
                    (double.tryParse(v) != null &&
                        double.parse(v) >= 0 &&
                        double.parse(v) <= 80)
                ? null
                : 'Use a number from 0 to 80',
          ),
          TextFormField(
            controller: preferredRoles,
            decoration: const InputDecoration(
              labelText: 'Preferred roles (comma separated)',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Education is optional. Entering a name does not verify it.',
            ),
          ),
          TextFormField(
            controller: college,
            decoration: const InputDecoration(
              labelText: 'Institution (optional)',
            ),
          ),
          TextFormField(
            controller: specialization,
            decoration: const InputDecoration(labelText: 'Specialization'),
          ),
          TextFormField(
            controller: course,
            decoration: const InputDecoration(labelText: 'Course / year'),
          ),
          TextFormField(
            controller: studyProgram,
            decoration: const InputDecoration(labelText: 'Study program'),
          ),
          TextFormField(
            controller: studyPeriod,
            decoration: const InputDecoration(labelText: 'Study period'),
          ),
          TextFormField(
            controller: institutionType,
            decoration: const InputDecoration(labelText: 'Institution type'),
          ),
          TextFormField(
            controller: institutionCity,
            decoration: const InputDecoration(labelText: 'Institution city'),
          ),
          TextFormField(
            controller: bio,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Biography'),
          ),
          TextFormField(
            controller: skills,
            decoration: const InputDecoration(
              labelText: 'Skills (comma separated)',
            ),
          ),
          TextFormField(
            controller: interests,
            decoration: const InputDecoration(
              labelText: 'Interests (comma separated)',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: level,
            decoration: const InputDecoration(labelText: 'Experience level'),
            items: [
              'Beginner',
              'Intermediate',
              'Advanced',
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (x) => setState(() => level = x ?? level),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, {
                'headline': headline.text.trim(),
                'city': city.text.trim(),
                'availability': availability.name,
                'weeklyHours': double.tryParse(hours.text),
                'preferredRoles': Skill.clean(preferredRoles.text.split(',')),
                'studyProgram': studyProgram.text.trim(),
                'studyPeriod': studyPeriod.text.trim(),
                'institutionType': institutionType.text.trim(),
                'institutionCity': institutionCity.text.trim(),
                'name': name.text.trim(),
                'college': college.text.trim(),
                'specialization': specialization.text.trim(),
                'course': course.text.trim(),
                'biography': bio.text.trim(),
                'level': level,
                'skills': skills.text
                    .split(',')
                    .map((x) => x.trim())
                    .where((x) => x.isNotEmpty)
                    .toList(),
                'interests': interests.text
                    .split(',')
                    .map((x) => x.trim())
                    .where((x) => x.isNotEmpty)
                    .toList(),
              });
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
}

Future<List<String>?> chooseSkills(
  BuildContext context,
  List<String> current,
) async {
  final available = Skill.clean([...Skill.catalog, ...current]);
  final selected = Skill.clean(current).toSet();
  var custom = '';
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Edit skills'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final skill in available)
                    FilterChip(
                      label: Text(skill),
                      selected: selected.contains(skill),
                      onSelected: (value) => update(
                        () => value
                            ? selected.add(skill)
                            : selected.remove(skill),
                      ),
                    ),
                ],
              ),
              TextField(
                onChanged: (value) => custom = value,
                decoration: const InputDecoration(labelText: 'Custom skill'),
              ),
              TextButton(
                onPressed: () => update(() {
                  final clean = Skill.clean([custom]);
                  if (clean.isEmpty) return;
                  final existing = available.where(
                    (s) => Skill.key(s) == Skill.key(clean.single),
                  );
                  final skill = existing.isEmpty
                      ? clean.single
                      : existing.first;
                  if (existing.isEmpty) available.add(skill);
                  selected.add(skill);
                }),
                child: const Text('Add skill'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, Skill.clean(selected)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE9EAF1)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.explore_outlined, color: violet, size: 34),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.4),
        ),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

class ActivityLine extends StatelessWidget {
  const ActivityLine({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.check_circle_outline, color: violet),
    title: Text(text),
    subtitle: const Text('Project activity'),
  );
}

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({
    super.key,
    required this.repository,
    required this.userId,
    required this.displayName,
    this.onExplore,
  });
  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
  final VoidCallback? onExplore;
  final ChatRepository repository;
  final String userId, displayName;
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    final userId = widget.userId;
    final displayName = widget.displayName;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<ProjectChatThread>>(
        stream: repository.watchChats(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load messages. Try again.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allChats = snapshot.data!;
          final query = search.text.trim().toLowerCase();
          final chats = allChats
              .where(
                (chat) =>
                    '${chat.project.title} ${chat.project.client} ${chat.kind.name} ${chat.preview}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search conversations',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: allChats.isEmpty
                    ? Center(
                        child: EmptyState(
                          title: 'No conversations yet',
                          body: widget.onExplore == null
                              ? 'A project chat opens after the client accepts a student.'
                              : 'Join a project to start collaborating with your team.',
                          action: widget.onExplore == null
                              ? null
                              : 'Explore Projects',
                          onAction: widget.onExplore,
                        ),
                      )
                    : chats.isEmpty
                    ? const Center(
                        child: Text(
                          'No conversations match your search.',
                          style: TextStyle(color: muted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final threadName = chat.kind == ChatKind.team
                              ? '${chat.project.client} · Project team'
                              : (userId == chat.project.applicantId
                                    ? chat.project.client
                                    : (chat.project.applicantName ??
                                          'Student'));
                          final unread = chat.unread[userId] ?? 0;
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE9EAF1)),
                            ),
                            child: ListTile(
                              leading: chat.kind == ChatKind.direct
                                  ? Avatar(
                                      initials: 'P',
                                      accountId: userId == chat.project.clientId
                                          ? chat.project.applicantId
                                          : chat.project.clientId,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: const Color(0xFFF1EEFF),
                                      child: Icon(
                                        chat.kind == ChatKind.team
                                            ? Icons.groups_outlined
                                            : Icons.person_outline,
                                        color: violet,
                                      ),
                                    ),
                              title: Text(
                                chat.project.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '$threadName\n${chat.preview}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _chatTime(chat.updatedAt),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (unread > 0) ...[
                                    const SizedBox(height: 5),
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: violet,
                                      child: Text(
                                        '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProjectChatScreen(
                                      repository: repository,
                                      chatId: chat.id,
                                      userId: userId,
                                      displayName: displayName,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _chatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class ProjectChatScreen extends StatefulWidget {
  const ProjectChatScreen({
    super.key,
    required this.repository,
    required this.chatId,
    required this.userId,
    required this.displayName,
  });
  final ChatRepository repository;
  final String chatId, userId, displayName;
  @override
  State<ProjectChatScreen> createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  final composer = TextEditingController();
  bool sending = false;
  String currentName(String id, String fallback) =>
      widget.repository is DemoChatRepository
      ? (widget.repository as DemoChatRepository).nameFor?.call(id, fallback) ??
            fallback
      : fallback;
  ProjectChatThread? get thread => widget.repository.findThread(widget.chatId);

  @override
  void initState() {
    super.initState();
    widget.repository.markRead(widget.chatId, widget.userId);
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = composer.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final kind =
          Uri.tryParse(text)?.hasScheme == true &&
              (text.startsWith('https://') || text.startsWith('http://'))
          ? ChatMessageKind.link
          : ChatMessageKind.text;
      await widget.repository.sendMessage(
        chatId: widget.chatId,
        userId: widget.userId,
        displayName: widget.displayName,
        content: text,
        kind: kind,
      );
      composer.clear();
      await widget.repository.markRead(widget.chatId, widget.userId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Message was not sent. Check that you are still an accepted project participant and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = thread;
    if (active == null ||
        active.project.acceptedParticipantIds.isEmpty ||
        !active.participants.contains(widget.userId) ||
        (widget.userId != active.project.clientId &&
            !active.project.acceptedParticipantIds.contains(widget.userId))) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const EmptyState(
          title: 'Chat unavailable',
          body: 'Only accepted project participants can access this conversation.',
        ),
      );
    }
    final policy = SettingsScope.maybeOf(context);
    final blocked = active.participants.any(
      (id) =>
          id != widget.userId && (policy?.blocked(widget.userId, id) ?? false),
    );
    final title = active.kind == ChatKind.team
        ? 'Project team'
        : (widget.userId == active.project.applicantId
              ? currentName(active.project.clientId, active.project.client)
              : currentName(
                  active.project.applicantId ?? '',
                  active.project.applicantName ?? 'Student',
                ));
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(
              active.project.title,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Participant information',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              final other = active.participants.firstWhere(
                (id) => id != widget.userId,
                orElse: () => widget.userId,
              );
              final settings = SettingsScope.maybeOf(context);
              final root = context
                  .findAncestorStateOfType<_ProjectBridgeAppState>();
              final contact = settings?.account(other);
              final shared =
                  contact != null &&
                  contact.shareContact &&
                  !(settings?.blocked(widget.userId, other) ?? false);
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(
                    root?.accountName(other, 'Participant') ?? 'Participant',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Avatar(initials: 'P', accountId: other),
                      Text(
                        shared && contact.contact.isNotEmpty
                            ? contact.contact
                            : 'Contact information is hidden.',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'report'
                ? reportConversation(
                    context,
                    widget.repository,
                    widget.chatId,
                    widget.userId,
                  )
                : showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Participants'),
                      content: Text(
                        active.kind == ChatKind.team
                            ? '${active.project.client}\n${currentName(active.project.applicantId ?? '', active.project.applicantName ?? 'Student')}\nNo mentor assigned'
                            : '${active.project.client}\n${currentName(active.project.applicantId ?? '', active.project.applicantName ?? 'Student')}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'participants', child: Text('Participants')),
              PopupMenuItem(
                value: 'report',
                child: Text('Report conversation'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (blocked)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'New messages are blocked between these accounts. You can still view your project history.',
              ),
            ),
          Container(
            width: double.infinity,
            color: const Color(0xFFF1EEFF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Offline demo · Shared on this device only.',
              style: TextStyle(fontSize: 11, color: Color(0xFF5143C5)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.repository.watchMessages(
                widget.chatId,
                userId: widget.userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load conversation.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if ((active.unread[widget.userId] ?? 0) > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      widget.repository.markRead(widget.chatId, widget.userId);
                    }
                  });
                }
                if (messages.isEmpty) {
                  return Center(
                    child: EmptyState(
                      title:
                          '👋 Say hi to ${widget.userId == active.project.clientId ? active.project.applicantName ?? 'your team' : active.project.client}!',
                      body: widget.userId == active.project.clientId
                          ? 'Your project collaboration starts here. Send the first message.'
                          : "You've been accepted! Introduce yourself and get started.",
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final mine = message.senderId == widget.userId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: mine
                            ? null
                            : () => reportSingleMessage(
                                context,
                                widget.repository,
                                widget.chatId,
                                widget.userId,
                                message,
                              ),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 310),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFFEDE9FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: mine
                                ? null
                                : Border.all(color: const Color(0xFFE9EAF1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Avatar(
                                  initials: message.senderName.isEmpty
                                      ? '?'
                                      : message.senderName[0],
                                  accountId: message.senderId,
                                ),
                              if (!mine)
                                Text(
                                  (widget.repository is DemoChatRepository
                                          ? (widget.repository
                                                    as DemoChatRepository)
                                                .nameFor
                                                ?.call(
                                                  message.senderId,
                                                  message.senderName,
                                                )
                                          : null) ??
                                      message.senderName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: violet,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (message.attachment != null)
                                AttachmentTile(
                                  attachment: message.attachment!,
                                  repository:
                                      (widget.repository as DemoChatRepository)
                                          .attachments,
                                  onTap: () {
                                    final repo =
                                        widget.repository as DemoChatRepository;
                                    if (repo.canAccess(active, widget.userId)) {
                                      viewAttachment(
                                        context,
                                        repo.attachments,
                                        message.attachment!,
                                      );
                                    }
                                  },
                                ),
                              if (message.kind == ChatMessageKind.link)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      color: violet,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: SelectableText(
                                        message.content,
                                        style: const TextStyle(
                                          color: Color(0xFF5143C5),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  message.content,
                                  style: const TextStyle(
                                    color: ink,
                                    height: 1.35,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _chatTime(message.sentAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach image or document',
                    onPressed: sending || blocked
                        ? null
                        : () => composeAttachment(
                            context,
                            widget.repository,
                            widget.chatId,
                            widget.userId,
                            widget.displayName,
                          ),
                    icon: const Icon(Icons.attach_file, color: violet),
                  ),
                  Expanded(
                    child: TextField(
                      enabled: !blocked,
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending || blocked ? null : send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> reportConversation(
  BuildContext context,
  ChatRepository repository,
  String chatId,
  String userId,
) async => reportSingleMessage(context, repository, chatId, userId, null);

Future<void> reportSingleMessage(
  BuildContext context,
  ChatRepository repository,
  String chatId,
  String userId,
  ChatMessage? message,
) async {
  final reason = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report conversation'),
      content: TextField(
        controller: reason,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'What should moderators review?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (reason.text.trim().isEmpty) return;
            await repository.reportMessage(
              chatId,
              message?.id ?? 'conversation',
              userId,
              reason.text,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Report saved for moderator review in this demo.',
                  ),
                ),
              );
            }
          },
          child: const Text('Send report'),
        ),
      ],
    ),
  );
}
