part of '../../main.dart';

Future<void> professionalAction(
  BuildContext context,
  VoidCallback action,
) async {
  try {
    action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Check the entered values and try again.',
          ),
        ),
      );
    }
  }
}

class ProfessionalProfileBody extends StatelessWidget {
  const ProfessionalProfileBody({
    super.key,
    required this.repository,
    required this.profileId,
    required this.actorId,
    this.onEdit,
    this.publicOnly = false,
  });
  final ProfessionalRepository repository;
  final String profileId, actorId;
  final Future<void> Function()? onEdit;
  final bool publicOnly;
  bool get editable => onEdit != null && actorId == profileId && !publicOnly;
  String get passportViewer => publicOnly ? 'public-viewer' : actorId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) {
      final p = repository.profile(profileId);
      final privacy = repository.settings;
      if (!(privacy?.canViewProfile(
            passportViewer,
            profileId,
            repository.projects(),
          ) ??
          true)) {
        return const EmptyState(
          title: 'Limited profile',
          body: 'This profile is visible only to its owner and accepted project clients.',
        );
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Brand(),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(
                        initials: p.name.isEmpty ? '?' : p.name[0],
                        accountId: profileId,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              p.headline.isEmpty
                                  ? p.specialization
                                  : p.headline,
                            ),
                            if (p.city.isNotEmpty)
                              Text(
                                p.city,
                                style: const TextStyle(color: muted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.education?.name ??
                        'Independent professional · No institution required',
                  ),
                  if (privacy?.canViewAvailability(
                        passportViewer,
                        profileId,
                        repository.projects(),
                      ) ??
                      true)
                    Text(
                      'Availability: ${p.availability.name}${p.weeklyHours == null ? '' : ' · ${p.weeklyHours} h/week'}',
                    ),
                  Text('${p.specialization} · ${p.level}'),
                  Text(
                    '${repository.visiblePassports(passportViewer, profileId).length} completed projects · ${repository.connectionsFor(profileId).length} connections',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fictional demo profile',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  if (editable)
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                    ),
                ],
              ),
            ),
          ),
          if (privacy != null &&
              privacy.canViewContact(
                passportViewer,
                profileId,
                repository.projects(),
              ) &&
              privacy.account(profileId).contact.isNotEmpty)
            Text('Contact: ${privacy.account(profileId).contact}'),
          ReviewsReputationSection(
            profileId: profileId,
            actorId: actorId,
            client: false,
          ),
          const SizedBox(height: 18),
          const SectionTitle('About'),
          Text(p.summary.isEmpty ? 'No summary added yet.' : p.summary),
          const SizedBox(height: 18),
          SectionTitle(
            'Skills',
            trailing: !editable
                ? null
                : TextButton(
                    onPressed: () async {
                      final skills = await chooseSkills(context, p.skills);
                      if (skills != null && context.mounted) {
                        professionalAction(
                          context,
                          () => repository.saveProfile(
                            actorId,
                            p.withChanges({'skills': skills}),
                          ),
                        );
                      }
                    },
                    child: const Text('Edit skills'),
                  ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.skills.map((s) => SkillChip(label: s)).toList(),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Education'),
          InfoCard(
            icon: Icons.school_outlined,
            title: p.education?.name ?? 'Independent professional',
            body: p.education == null
                ? 'Institutional affiliation is optional. Full access to projects and matching.'
                : '${p.education!.program} · ${p.education!.period}\n${p.education!.type} · ${p.education!.city}\n${p.education!.label}',
          ),
          const SizedBox(height: 18),
          if (editable && p.education != null)
            Wrap(
              spacing: 8,
              children: [
                if (p.education!.status == EducationStatus.notVerified)
                  TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repository.requestEducationReview(actorId),
                    ),
                    child: const Text('Request demo education review'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DemoEducationReviewScreen(repository: repository),
                    ),
                  ),
                  child: const Text('Enter demo administrator'),
                ),
              ],
            ),
          SectionTitle(
            'Experience',
            trailing: Text(
              '${repository.visiblePassports(passportViewer, profileId).length} completed',
            ),
          ),
          Text(
            '${repository.visiblePassports(passportViewer, profileId).length} client-confirmed demo projects',
          ),
          for (final passport in repository.visiblePassports(
            passportViewer,
            profileId,
          ))
            ListTile(
              title: Text(passport.title),
              subtitle: Text(
                '${passport.role} · ${passport.skills.join(', ')}\n${passport.verificationLabel}',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Project Passport')),
                    body: VerifiedPassportBody(passport: passport),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (editable) SettingsLinks(accountId: profileId, client: false),
          if (editable)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MySafetyReportsScreen(
                    repository: repository,
                    actorId: actorId,
                  ),
                ),
              ),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('My private reports'),
            ),
          const SectionTitle('Connections'),
          Text(
            '${repository.connectionsFor(profileId).length} professional connections',
          ),
          for (final connection in repository.connectionsFor(profileId))
            ListTile(
              title: Text(connection.name),
              subtitle: Text(connection.headline),
              onTap: () => openProfessionalProfile(
                context,
                repository,
                connection.id,
                actorId,
                publicOnly: publicOnly,
              ),
            ),
          if (editable)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfessionalConnectionsScreen(
                    repository: repository,
                    initialActor: actorId,
                  ),
                ),
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Manage connections'),
            ),
          if (actorId != profileId &&
              repository.profiles.any((p) => p.id == actorId)) ...[
            Text(repository.connectionState(actorId, profileId)),
            if (repository.connectionState(actorId, profileId) ==
                'Not connected')
              TextButton(
                onPressed: () => professionalAction(
                  context,
                  () => repository.sendConnectionRequest(actorId, profileId),
                ),
                child: const Text('Send connection request'),
              ),
            if (repository.connectionState(actorId, profileId) ==
                'Request received')
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repository.respondToConnection(
                        actorId,
                        repository.connectionId(actorId, profileId),
                        true,
                      ),
                    ),
                    child: const Text('Accept request'),
                  ),
                  TextButton(
                    onPressed: () => professionalAction(
                      context,
                      () => repository.respondToConnection(
                        actorId,
                        repository.connectionId(actorId, profileId),
                        false,
                      ),
                    ),
                    child: const Text('Decline request'),
                  ),
                ],
              ),
            if (repository.connectionState(actorId, profileId) == 'Connected')
              TextButton(
                onPressed: () => professionalAction(
                  context,
                  () => repository.removeConnection(actorId, profileId),
                ),
                child: const Text('Remove connection'),
              ),
          ],
          if (repository.settings?.canViewPortfolio(
                passportViewer,
                profileId,
              ) ??
              true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Portfolio'),
              subtitle: Text(
                '${repository.portfolioFor(profileId).length} independent projects · Self-reported',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('${p.name} · Portfolio')),
                    body: ProfessionalPortfolioBody(
                      repository: repository,
                      profileId: profileId,
                      actorId: passportViewer,
                      allowEditing: editable,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

void openProfessionalProfile(
  BuildContext context,
  ProfessionalRepository repository,
  String profileId,
  String actorId, {
  bool publicOnly = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Professional profile')),
        body: ProfessionalProfileBody(
          repository: repository,
          profileId: profileId,
          actorId: actorId,
          publicOnly: publicOnly,
        ),
      ),
    ),
  );
}

class ProfessionalPortfolioBody extends StatelessWidget {
  const ProfessionalPortfolioBody({
    super.key,
    required this.repository,
    required this.profileId,
    required this.actorId,
    this.allowEditing = true,
  });
  final ProfessionalRepository repository;
  final String profileId, actorId;
  final bool allowEditing;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) {
      if (!(repository.settings?.canViewPortfolio(actorId, profileId) ??
              true) ||
          !(repository.settings?.canViewProfile(
                actorId,
                profileId,
                repository.projects(),
              ) ??
              true)) {
        return const EmptyState(
          title: 'Private portfolio',
          body: 'This portfolio is not shared with this account.',
        );
      }
      final entries = repository.portfolioFor(profileId);
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My Portfolio',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const Text('Your skills. Your work. Your real experience.'),
          const SizedBox(height: 18),
          const SectionTitle('Verified Projects'),
          const Text(
            'Local demo confirmations only. Independent projects remain self-reported.',
          ),
          if (repository.visiblePassports(actorId, profileId).isEmpty)
            const Text(
              'No verified demo passports yet. Client review and explicit completion approval are required.',
            ),
          for (final passport in repository.visiblePassports(
            actorId,
            profileId,
          ))
            Card(
              child: ListTile(
                title: Text(passport.title),
                subtitle: Text(
                  '${passport.verificationLabel}\n${passport.role}',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Project Passport')),
                      body: VerifiedPassportBody(passport: passport),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          SectionTitle(
            'Independent Projects',
            trailing: allowEditing && actorId == profileId
                ? TextButton.icon(
                    onPressed: () => editProfessionalPortfolio(
                      context,
                      repository,
                      actorId,
                      null,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add personal project'),
                  )
                : null,
          ),
          if (entries.isEmpty)
            const Text(
              'Add personal websites, apps, assignments or design work. These are self-reported.',
            ),
          for (final entry in entries)
            Card(
              child: ListTile(
                title: Text(entry.title),
                subtitle: Text(
                  'Self-reported\n${entry.description}\n${entry.skills.join(', ')}',
                ),
                isThreeLine: false,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(entry.title),
                    content: SingleChildScrollView(
                      child: Text(
                        'Self-reported\n${entry.description}\n${entry.url}',
                      ),
                    ),
                    actions: [
                      if (entry.url.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: entry.url),
                            );
                            if (c.mounted) Navigator.pop(c);
                          },
                          child: const Text('Copy project link'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                trailing: allowEditing && actorId == profileId
                    ? PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            editProfessionalPortfolio(
                              context,
                              repository,
                              actorId,
                              entry,
                            );
                          }
                          if (action == 'delete') {
                            professionalAction(
                              context,
                              () =>
                                  repository.removePortfolio(actorId, entry.id),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Remove')),
                        ],
                      )
                    : null,
              ),
            ),
        ],
      );
    },
  );
}

Future<void> editProfessionalPortfolio(
  BuildContext context,
  ProfessionalRepository repository,
  String actorId,
  PortfolioProject? entry,
) async {
  final samples = <WorkSample>[
    if (entry != null)
      WorkSample(
        title: entry.title,
        description: entry.description,
        technologies: entry.skills.join(', '),
        url: entry.url,
        type: entry.type,
      ),
  ];
  await editSample(
    context,
    samples.isEmpty ? null : samples.single,
    samples,
    () {
      final sample = samples.single;
      professionalAction(
        context,
        () => repository.savePortfolio(
          actorId,
          PortfolioProject(
            id: entry?.id ?? repository.newId('portfolio'),
            ownerId: actorId,
            title: sample.title,
            description: sample.description,
            skills: Skill.clean(sample.technologies.split(',')),
            url: sample.url,
            type: sample.type,
          ),
        ),
      );
    },
  );
}

class DemoEducationReviewScreen extends StatelessWidget {
  const DemoEducationReviewScreen({super.key, required this.repository});
  final ProfessionalRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demo institution review')),
    body: AnimatedBuilder(
      animation: repository,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InfoCard(
            icon: Icons.science_outlined,
            title: 'Acting as demo administrator',
            body: 'This is a local simulation. It does not confirm enrollment, establish a partnership, or verify a real institution.',
          ),
          for (final profile in repository.profiles.where(
            (p) => p.education != null,
          ))
            Card(
              child: ListTile(
                title: Text('${profile.name} · ${profile.education!.name}'),
                subtitle: Text(profile.education!.label),
                trailing: profile.education!.status == EducationStatus.pending
                    ? TextButton(
                        onPressed: () => professionalAction(
                          context,
                          () => repository.demoVerifyEducation(
                            'demo-administrator',
                            profile.id,
                          ),
                        ),
                        child: const Text('Simulate confirmation'),
                      )
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}

class VerifiedPassportBody extends StatelessWidget {
  const VerifiedPassportBody({super.key, required this.passport});
  final ProjectPassport passport;
  @override
  Widget build(BuildContext context) {
    final p = passport;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(p.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        StatusPill(text: p.verificationLabel, color: violet),
        const SizedBox(height: 12),
        Text(p.description),
        InfoCard(
          icon: Icons.person_outline,
          title: p.studentName,
          body: '${p.role}\nClient: ${p.client}',
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.code,
          title: 'Skills demonstrated',
          body: p.skills.join(', '),
        ),
        const SizedBox(height: 12),
        InfoCard(icon: Icons.task_alt, title: 'Tasks completed', body: p.tasks),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.inventory_2_outlined,
          title: 'Deliverables',
          body: p.deliverables,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.rate_review_outlined,
          title: 'Client review',
          body: p.review,
        ),
        const SizedBox(height: 12),
        Text(
          'Started ${p.startedAt.toLocal().toString().split(' ').first}\nCompleted ${p.completedAt.toLocal().toString().split(' ').first}\nPassport ${p.id}',
        ),
        const SizedBox(height: 16),
        const Text(
          'Local demo client approval, not an independently verified credential. No public sharing is enabled.',
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
