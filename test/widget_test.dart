import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  testWidgets('all five Student navigation destinations open', (tester) async {
    await tester.pumpWidget(const ProjectBridgeApp());
    expect(find.text('ProjectBridge'), findsOneWidget);
    expect(find.text('Hi, Daria!'), findsOneWidget);
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Coffee Shop Website'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Explore Projects'), findsOneWidget);

    await tester.tap(find.text('My Projects'));
    await tester.pumpAndSettle();
    expect(
      find.text('Track your applications and active work.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your skills. Your work. Your real experience.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Hi, Daria!'), findsOneWidget);
  });

  testWidgets(
    'Student Messages icon opens an empty state with Explore action',
    (tester) async {
      await tester.pumpWidget(const ProjectBridgeApp());
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('No conversations yet'), findsOneWidget);
      expect(
        find.text('Join a project to start collaborating with your team.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Explore Projects'));
      await tester.pumpAndSettle();
      expect(find.text('Explore Projects'), findsOneWidget);
    },
  );

  testWidgets(
    'all five Client navigation destinations show their own screens',
    (tester) async {
      await tester.pumpWidget(const ProjectBridgeApp());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Switch to Client Demo'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Switch to Client Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch to Client Demo'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Coffee'), findsOneWidget);

      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Manage your published and in-progress work.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(find.text('Smart Assistant'), findsNothing);
      expect(find.text('Create Manually'), findsOneWidget);
      expect(find.text('Start Manually'), findsOneWidget);

      await tester.tap(find.text('Applicants').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Applications grouped by your projects.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Your organization'), findsOneWidget);
      expect(find.text('Demo account · Not verified'), findsOneWidget);
    },
  );

  testWidgets(
    'accepting Daria creates direct and team chats visible to both inboxes',
    (tester) async {
      final repository = DemoChatRepository();
      final project =
          BridgeProject(
              'Coffee Shop Website',
              'Demo Coffee',
              'Web Development',
              'Create the coffee shop website.',
              ['HTML', 'CSS'],
            )
            ..applied = true
            ..applicantId = 'student-daria'
            ..applicantName = 'Daria';
      repository.ensureProjectChats(project);
      expect(await repository.watchChats(project.clientId).first, isEmpty);
      expect(await repository.watchChats('student-daria').first, isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientProjectTile(
              project: project,
              onChanged: () {},
              chatRepository: repository,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();
      expect(await repository.watchChats(project.clientId).first, hasLength(2));
      expect(await repository.watchChats('student-daria').first, hasLength(2));
      expect(project.applicationStatus, 'Accepted');

      await tester.pumpWidget(
        MaterialApp(
          home: MessageCenterScreen(
            repository: repository,
            userId: project.clientId,
            displayName: 'Demo Coffee',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coffee Shop Website'), findsNWidgets(2));
      expect(find.textContaining('Project team'), findsOneWidget);
      await tester.tap(find.text('Daria\nNo messages yet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Client hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('Client hello'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: MessageCenterScreen(
            repository: repository,
            userId: 'student-daria',
            displayName: 'Daria',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Client hello'), findsOneWidget);
      await tester.tap(find.textContaining('Client hello'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Student reply');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('Client hello'), findsOneWidget);
      expect(find.text('Student reply'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: MessageCenterScreen(
            repository: repository,
            userId: project.clientId,
            displayName: 'Demo Coffee',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Student reply'));
      await tester.pumpAndSettle();
      expect(find.text('Client hello'), findsOneWidget);
      expect(find.text('Student reply'), findsOneWidget);
    },
  );

  testWidgets('student can search, apply, and see application in My Projects', (
    tester,
  ) async {
    await tester.pumpWidget(const ProjectBridgeApp());
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lost & Found');
    await tester.pumpAndSettle();
    expect(find.text('Lost & Found App'), findsOneWidget);

    await tester.tap(find.text('Lost & Found App'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Apply to project'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Apply to project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'I would love to build a useful campus app.',
    );
    await tester.ensureVisible(find.text('Weekly availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5–10 hours/week').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit application'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit application'));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Lost & Found App'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets(
    'Client creates and publishes a demo project from the four-step flow',
    (tester) async {
      BridgeProject? created;
      final chatRepository = DemoChatRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientCreateProjectScreen(
              onCreated: (project) => created = project,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Coffee Shop Website',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A new website for our shop.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'The current site is hard to use.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Customers need clear menus.',
      );
      await tester.scrollUntilVisible(
        find.text('Expected deliverables'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Responsive website and menu.',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 2 of 4'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Student role'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'HTML, CSS, Flutter',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Web developer');
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 3 of 4'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Compensation information (no payments processed)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Weekly progress updates.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Unpaid learning opportunity',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 4 of 4'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Publish as Demo Coffee'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Publish as Demo Coffee'), findsOneWidget);
      await tester.tap(find.text('Publish as Demo Coffee'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.title, 'Coffee Shop Website');
      expect(created!.clientId, 'client-demo-coffee');
      expect(created!.lifecycleStatus, 'Published');
      expect(created!.isPublished, isTrue);
      expect(created!.requiredSkills, ['HTML', 'CSS', 'Flutter']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreScreen(
              projects: [created!],
              onChanged: () {},
              skills: ['HTML', 'CSS'],
              chatRepository: chatRepository,
              studentName: 'Daria',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Coffee Shop Website'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Coffee Shop Website'), findsOneWidget);
      await tester.tap(find.text('Coffee Shop Website'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Apply to project'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'I am excited to build the coffee shop site.',
      );
      await tester.ensureVisible(find.text('Weekly availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5–10 hours/week').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(created!.applicantId, 'student-daria');
      expect(created!.applicantName, 'Daria');
      expect(created!.applied, isTrue);
      expect(created!.applicationStatus, 'Pending');
    },
  );

  testWidgets(
    'Create Project opens the manual form while assistants are paused',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientCreateProjectEntryScreen(onCreated: (_) {}),
          ),
        ),
      );
      expect(find.text('Smart Assistant'), findsNothing);
      expect(find.text('Describe Your Idea'), findsNothing);
      await tester.tap(find.text('Start Manually'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 1 of 4'), findsOneWidget);
    },
  );

  testWidgets(
    'offline recommendations are editable and prefill the project form',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BridgeProject? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientCreateProjectEntryScreen(
              onCreated: (project) => created = project,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Describe Your Idea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project_idea_input')),
        'I run a coffee shop and need a QR menu with photos and prices that I can edit.',
      );
      await tester.tap(find.text('Analyze Project'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Project Plan'), findsOneWidget);
      expect(find.textContaining('Rule-based recommendations'), findsOneWidget);
      final suggestedTitle = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((field) => field.controller?.text == 'Cafe QR Menu');
      await tester.enterText(
        find.byWidget(suggestedTitle),
        'My Edited Cafe Menu',
      );
      await tester.scrollUntilVisible(
        find.text('Difficulty estimate'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .any(
              (field) => [
                'Beginner',
                'Intermediate',
                'Advanced',
                'Difficulty requires clarification',
              ].contains(field.controller?.text),
            ),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Use This Plan'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Use This Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 1 of 4'), findsOneWidget);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .any((field) => field.controller?.text == 'My Edited Cafe Menu'),
        isTrue,
      );
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(created, isNotNull);
      expect(created!.smartAssistantAssisted, isTrue);
      expect(created!.originalDescription, contains('I run a coffee shop'));
      expect(created!.requiredSkills, contains('HTML'));
      expect(created!.acceptanceCriteria, isNotEmpty);
      expect(created!.smartAnalysisVersion, 'smart-rules-v1');
    },
    // Assistant UI is temporarily paused; preserve the source and service tests.
    skip: true,
  );

  testWidgets(
    'Create Manually remains available from a smart plan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientCreateProjectEntryScreen(onCreated: (_) {}),
          ),
        ),
      );
      await tester.tap(find.text('Describe Your Idea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('project_idea_input')),
        'I need a simple website for my small business.',
      );
      await tester.scrollUntilVisible(
        find.text('Analyze Project'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Analyze Project'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Project Plan'), findsOneWidget);
      await tester.tap(find.text('Create Manually'));
      await tester.pumpAndSettle();
      expect(find.text('Create Project · Step 1 of 4'), findsOneWidget);
    },
    // Assistant UI is temporarily paused; preserve the source and service tests.
    skip: true,
  );

  test('demo chat streams both directions and updates unread counts', () async {
    final repo = DemoChatRepository();
    final project =
        BridgeProject(
            'Demo App',
            'Demo Coffee',
            'Mobile Development',
            'Build a demo.',
            ['Flutter'],
          )
          ..applied = true
          ..accepted = true
          ..applicationStatus = 'Accepted'
          ..applicantId = 'student-daria'
          ..applicantName = 'Daria';
    repo.ensureProjectChats(project);
    final id = repo.chatIdFor(project, ChatKind.direct);
    final received = <List<ChatMessage>>[];
    final subscription = repo
        .watchMessages(id, userId: 'student-daria')
        .listen(received.add);

    await repo.sendMessage(
      chatId: id,
      userId: 'client-demo-coffee',
      displayName: 'Demo Coffee',
      content: 'Здравствуйте! Когда сможете отправить первый вариант?',
      kind: ChatMessageKind.text,
    );
    await Future<void>.delayed(Duration.zero);
    expect(received.last.single.senderId, 'client-demo-coffee');
    expect(repo.findThread(id)!.unread['student-daria'], 1);
    await repo.markRead(id, 'student-daria');

    await repo.sendMessage(
      chatId: id,
      userId: 'student-daria',
      displayName: 'Daria',
      content: 'Здравствуйте! Сегодня вечером отправлю.',
      kind: ChatMessageKind.text,
    );
    await Future<void>.delayed(Duration.zero);
    expect(received.last.length, 2);
    expect(received.last.last.senderId, 'student-daria');
    expect(repo.findThread(id)!.unread['client-demo-coffee'], 1);
    await subscription.cancel();
  });

  testWidgets('Messages chat row opens the matching conversation', (
    tester,
  ) async {
    final repo = DemoChatRepository();
    final project =
        BridgeProject(
            'Coffee Shop Website',
            'Demo Coffee',
            'Web Development',
            'Demo.',
            ['HTML'],
          )
          ..applied = true
          ..accepted = true
          ..applicationStatus = 'Accepted'
          ..applicantId = 'student-daria'
          ..applicantName = 'Daria';
    repo.ensureProjectChats(project);
    final id = repo.chatIdFor(project, ChatKind.direct);
    await repo.sendMessage(
      chatId: id,
      userId: 'client-demo-coffee',
      displayName: 'Demo Coffee',
      content: 'Hello Daria',
      kind: ChatMessageKind.text,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MessageCenterScreen(
          repository: repo,
          userId: 'student-daria',
          displayName: 'Daria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coffee Shop Website'), findsNWidgets(2));
    expect(find.textContaining('Hello Daria'), findsOneWidget);
    await tester.tap(find.text('Coffee Shop Website').first);
    await tester.pumpAndSettle();
    expect(find.text('Hello Daria'), findsOneWidget);
    expect(find.text('Coffee Shop Website'), findsOneWidget);
  });

  test('chat repository denies messages before acceptance', () async {
    final repo = DemoChatRepository();
    final project = BridgeProject(
      'Private Project',
      'Demo Coffee',
      'Other',
      'Demo.',
      ['Flutter'],
    );
    repo.ensureProjectChats(project);
    final id = repo.chatIdFor(project, ChatKind.direct);
    await expectLater(
      repo.sendMessage(
        chatId: id,
        userId: 'student-daria',
        displayName: 'Daria',
        content: 'Hello',
        kind: ChatMessageKind.text,
      ),
      throwsStateError,
    );
  });

  test('accepted project conversations still reject nonmembers', () async {
    final repo = DemoChatRepository();
    final project =
        BridgeProject('Restricted', 'Demo Coffee', 'Other', 'Demo.', [
            'Flutter',
          ])
          ..applied = true
          ..accepted = true
          ..applicationStatus = 'Accepted'
          ..applicantId = 'student-daria'
          ..applicantName = 'Daria';
    repo.ensureProjectChats(project);
    final id = repo.chatIdFor(project, ChatKind.direct);
    expect(await repo.watchChats('unrelated-user').first, isEmpty);
    await expectLater(
      repo.sendMessage(
        chatId: id,
        userId: 'unrelated-user',
        displayName: 'Intruder',
        content: 'Hello',
        kind: ChatMessageKind.text,
      ),
      throwsStateError,
    );
  });

  testWidgets('project chat sends text and receives a streamed reply', (
    tester,
  ) async {
    final repo = DemoChatRepository();
    final project =
        BridgeProject(
            'Chat Demo',
            'Demo Coffee',
            'Web Development',
            'Demo project.',
            ['HTML'],
          )
          ..applied = true
          ..accepted = true
          ..applicationStatus = 'Accepted'
          ..applicantId = 'student-daria'
          ..applicantName = 'Daria';
    repo.ensureProjectChats(project);
    final id = repo.chatIdFor(project, ChatKind.direct);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectChatScreen(
          repository: repo,
          chatId: id,
          userId: 'student-daria',
          displayName: 'Daria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('👋 Say hi to Demo Coffee!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repo.findThread(id)!.messages, isEmpty);

    await tester.enterText(
      find.byType(TextField).last,
      'My first project update',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('My first project update'), findsOneWidget);

    await repo.sendMessage(
      chatId: id,
      userId: 'client-demo-coffee',
      displayName: 'Demo Coffee',
      content: 'Thanks, Daria!',
      kind: ChatMessageKind.text,
    );
    await tester.pumpAndSettle();
    expect(find.text('Thanks, Daria!'), findsOneWidget);
    expect(repo.findThread(id)!.unread['student-daria'], 0);
  });
}
