part of '../../main.dart';

extension ProfessionalConnections on ProfessionalRepository {
  String connectionId(String first, String second) =>
      'connection:${([first, second]..sort()).join(':')}';
  List<ProfessionalProfile> connectionsFor(String profileId) =>
      List.unmodifiable(
        _connections.values
            .where(
              (c) =>
                  c.includes(profileId) &&
                  c.status == ConnectionStatus.accepted,
            )
            .map((c) => profile(c.other(profileId))),
      );
  List<ConnectionRequest> requestsFor(String actorId) => List.unmodifiable(
    _connections.values.where(
      (c) => c.includes(actorId) && c.status == ConnectionStatus.pending,
    ),
  );
  String connectionState(String actorId, String targetId) {
    final value = _connections[connectionId(actorId, targetId)];
    if (value == null ||
        [
          ConnectionStatus.declined,
          ConnectionStatus.removed,
        ].contains(value.status)) {
      return 'Not connected';
    }
    if (value.status == ConnectionStatus.accepted) return 'Connected';
    return value.senderId == actorId ? 'Request sent' : 'Request received';
  }

  ConnectionRequest sendConnectionRequest(String actorId, String targetId) {
    profile(actorId);
    profile(targetId);
    if (settings?.blocked(actorId, targetId) ?? false) {
      throw StateError(
        'Connection requests are unavailable between blocked accounts.',
      );
    }
    if (actorId == targetId) {
      throw StateError('Choose another professional to connect with.');
    }
    final id = connectionId(actorId, targetId);
    final previous = _connections[id];
    if (previous != null &&
        [
          ConnectionStatus.pending,
          ConnectionStatus.accepted,
        ].contains(previous.status)) {
      return previous;
    }
    final now = DateTime.now();
    final value = ConnectionRequest(
      id: id,
      senderId: actorId,
      recipientId: targetId,
      createdAt: now,
      updatedAt: now,
    );
    _connections[id] = value;
    changed();
    return value;
  }

  void respondToConnection(String actorId, String id, bool accept) {
    final value =
        _connections[id] ?? (throw StateError('Connection request not found.'));
    owner(actorId, value.recipientId);
    if (settings?.blocked(value.senderId, value.recipientId) ?? false) {
      throw StateError('Unblock this account before responding.');
    }
    if (value.status == ConnectionStatus.accepted && accept) return;
    if (value.status != ConnectionStatus.pending) {
      throw StateError('This request is no longer pending.');
    }
    _connections[id] = ConnectionRequest(
      id: id,
      senderId: value.senderId,
      recipientId: value.recipientId,
      createdAt: value.createdAt,
      updatedAt: DateTime.now(),
      status: accept ? ConnectionStatus.accepted : ConnectionStatus.declined,
    );
    changed();
  }

  void removeConnection(String actorId, String targetId) {
    final id = connectionId(actorId, targetId);
    final value =
        _connections[id] ?? (throw StateError('Connection not found.'));
    if (!value.includes(actorId) || value.status != ConnectionStatus.accepted) {
      throw StateError(
        'Only a connected participant can remove this connection.',
      );
    }
    _connections[id] = ConnectionRequest(
      id: id,
      senderId: value.senderId,
      recipientId: value.recipientId,
      createdAt: value.createdAt,
      updatedAt: DateTime.now(),
      status: ConnectionStatus.removed,
    );
    changed();
  }
}

class ProfessionalConnectionsScreen extends StatefulWidget {
  const ProfessionalConnectionsScreen({
    super.key,
    required this.repository,
    this.initialActor = 'student-daria',
  });
  final ProfessionalRepository repository;
  final String initialActor;
  @override
  State<ProfessionalConnectionsScreen> createState() =>
      _ProfessionalConnectionsScreenState();
}

class _ProfessionalConnectionsScreenState
    extends State<ProfessionalConnectionsScreen> {
  late String actorId = widget.initialActor;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Professional connections')),
    body: AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final repo = widget.repository;
        final connections = repo.connectionsFor(actorId);
        final requests = repo.requestsFor(actorId);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Fictional demo inboxes. Switching here changes only the local networking identity; your project account stays unchanged. Connections never grant chat access.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: actorId,
              decoration: const InputDecoration(
                labelText: 'Demo networking account',
              ),
              items: repo.profiles
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => actorId = value!),
            ),
            const SizedBox(height: 18),
            SectionTitle(
              'Connections',
              trailing: Text('${connections.length}'),
            ),
            if (connections.isEmpty) const Text('No connections yet.'),
            for (final profile in connections)
              Card(
                child: ListTile(
                  title: Text(profile.name),
                  subtitle: Text(profile.headline),
                  onTap: () => openProfessionalProfile(
                    context,
                    repo,
                    profile.id,
                    actorId,
                    publicOnly: true,
                  ),
                  trailing: TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repo.removeConnection(actorId, profile.id),
                    ),
                    child: const Text('Remove connection'),
                  ),
                ),
              ),
            const SectionTitle('Connection requests'),
            if (requests.isEmpty) const Text('No pending requests.'),
            for (final request in requests)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(repo.profile(request.other(actorId)).name),
                      Text(
                        request.senderId == actorId
                            ? 'Request sent'
                            : 'Request received',
                      ),
                      if (request.recipientId == actorId)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => professionalAction(
                                context,
                                () => repo.respondToConnection(
                                  actorId,
                                  request.id,
                                  true,
                                ),
                              ),
                              child: const Text('Accept request'),
                            ),
                            TextButton(
                              onPressed: () => professionalAction(
                                context,
                                () => repo.respondToConnection(
                                  actorId,
                                  request.id,
                                  false,
                                ),
                              ),
                              child: const Text('Decline request'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Discover professionals'),
            for (final profile in repo.profiles.where((p) => p.id != actorId))
              Card(
                child: ListTile(
                  leading: Avatar(initials: profile.name[0]),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.headline}\n${repo.connectionState(actorId, profile.id)}',
                  ),
                  onTap: () => openProfessionalProfile(
                    context,
                    repo,
                    profile.id,
                    actorId,
                    publicOnly: true,
                  ),
                  trailing:
                      repo.connectionState(actorId, profile.id) ==
                          'Not connected'
                      ? TextButton(
                          onPressed: () => professionalAction(
                            context,
                            () =>
                                repo.sendConnectionRequest(actorId, profile.id),
                          ),
                          child: const Text('Connect'),
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );
}
