import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr_bridge/main.dart';

void main() {
  test('connections enforce recipient actions, prevent duplicates and never grant chat access', () async {
    final repo = ProfessionalRepository(projects: () => []);
    final chats = DemoChatRepository();
    addTearDown(repo.dispose);
    addTearDown(chats.dispose);
    final request = repo.sendConnectionRequest(
      'student-daria',
      'student-aruzhan',
    );
    expect(
      repo.connectionState('student-daria', 'student-aruzhan'),
      'Request sent',
    );
    expect(
      repo.connectionState('student-aruzhan', 'student-daria'),
      'Request received',
    );
    expect(
      repo.sendConnectionRequest('student-aruzhan', 'student-daria').id,
      request.id,
    );
    expect(repo.requestsFor('student-daria'), hasLength(1));
    expect(
      () => repo.respondToConnection('student-daria', request.id, true),
      throwsStateError,
    );
    expect(
      () => repo.respondToConnection('student-dias', request.id, true),
      throwsStateError,
    );
    repo.respondToConnection('student-aruzhan', request.id, true);
    repo.respondToConnection('student-aruzhan', request.id, true);
    expect(repo.connectionsFor('student-daria').single.id, 'student-aruzhan');
    expect(repo.connectionsFor('student-aruzhan').single.id, 'student-daria');
    expect(await chats.watchChats('student-daria').first, isEmpty);
    final restored = ProfessionalRepository(projects: () => [])
      ..restore(jsonDecode(jsonEncode(repo.toJson())) as Map<String, dynamic>);
    addTearDown(restored.dispose);
    expect(
      restored.connectionState('student-daria', 'student-aruzhan'),
      'Connected',
    );
    repo.removeConnection('student-daria', 'student-aruzhan');
    expect(repo.connectionsFor('student-daria'), isEmpty);
    expect(
      repo.connectionState('student-daria', 'student-aruzhan'),
      'Not connected',
    );
    final again = repo.sendConnectionRequest(
      'student-daria',
      'student-aruzhan',
    );
    repo.respondToConnection('student-aruzhan', again.id, false);
    expect(repo.requestsFor('student-daria'), isEmpty);
    expect(repo.connectionsFor('student-daria'), isEmpty);
  });

  testWidgets(
    'fictional networking inbox can send, accept and remove a connection',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ProfessionalRepository(projects: () => []);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ProfessionalConnectionsScreen(repository: repo)),
      );
      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();
      expect(repo.requestsFor('student-daria'), hasLength(1));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aruzhan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept request'));
      await tester.pumpAndSettle();
      expect(repo.connectionsFor('student-aruzhan'), hasLength(1));
      await tester.tap(find.text('Remove connection'));
      await tester.pumpAndSettle();
      expect(repo.connectionsFor('student-aruzhan'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'networking public views expose no owner editing or private-report controls',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ProfessionalRepository(projects: () => []);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfessionalProfileBody(
            repository: repo,
            profileId: 'student-aruzhan',
            actorId: 'student-aruzhan',
            publicOnly: true,
          )),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Edit skills'), findsNothing);
      expect(find.text('My private reports'), findsNothing);
      expect(find.text('Enter demo administrator'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Portfolio'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      expect(find.text('Add personal project'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
