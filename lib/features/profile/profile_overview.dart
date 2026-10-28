part of '../../main.dart';

class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 12,
        leading: Icon(icon, color: ink, size: 22),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right, size: 20, color: muted),
        onTap: onTap,
      ),
      const Divider(height: 1, color: Color(0xFFE9EAF1)),
    ],
  );
}

class ProfileOverview extends StatelessWidget {
  const ProfileOverview({
    super.key,
    required this.client,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.projects,
    required this.onEdit,
    required this.onSwitch,
  });
  final bool client;
  final String name, subtitle, description;
  final List<BridgeProject> projects;
  final Future<void> Function() onEdit;
  final VoidCallback onSwitch;
  String get accountId => client ? 'client-demo-coffee' : 'student-daria';

  void openDetails(BuildContext context) {
    final repository = ProfessionalScope.maybeOf(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              client ? 'Organization Profile' : 'Professional Profile',
            ),
          ),
          body: SafeArea(
            child: client
                ? OrganizationProfileDetails(projects: projects, onEdit: onEdit)
                : repository == null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(name),
                      Text(description),
                      TextButton(
                        onPressed: onEdit,
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  )
                : ProfessionalProfileBody(
                    repository: repository,
                    profileId: accountId,
                    actorId: accountId,
                    onEdit: onEdit,
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ProfessionalScope.maybeOf(context);
    final profile = client ? null : repository?.profile(accountId);
    final displayName = profile?.name ?? name;
    final completed = client
        ? projects.where((p) => p.completed).length
        : repository?.passportsFor(accountId).length ?? 0;
    final isDemo = client || (profile?.isDemo ?? true);
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Profile',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => openSettingsPage(
                  context,
                  accountId,
                  client,
                  'Notifications',
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar(
              initials: displayName.isEmpty ? '?' : displayName[0],
              accountId: accountId,
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              profile == null
                  ? subtitle
                  : 'Student · ${profile.specialization}',
            ),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => openDetails(context),
          ),
          const SizedBox(height: 22),
          Text(
            client ? 'Your organization' : 'Your professional profile',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (client)
            Text(
              description.isEmpty
                  ? 'Add a description to introduce your organization.'
                  : description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, height: 1.5),
            ),
          if (profile != null) ...[
            if (profile.headline.isNotEmpty)
              Text(profile.headline, style: const TextStyle(color: muted)),
            const SizedBox(height: 8),
            if (profile.skills.isEmpty)
              const Text('Add skills to help clients discover your work.'),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: profile.skills
                  .take(4)
                  .map((s) => SkillChip(label: s))
                  .toList(),
            ),
            if (profile.education != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  profile.education!.name,
                  style: const TextStyle(color: muted),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text(
                client
                    ? '${projects.where((p) => p.isPublished && !p.isArchived).length} published projects'
                    : '${repository?.portfolioFor(accountId).length ?? 0} portfolio projects',
              ),
              Text('$completed completed projects'),
            ],
          ),
          if (client)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Demo account · Not verified',
                style: TextStyle(color: muted),
              ),
            ),
          if (!client && completed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '$completed client-confirmed demo experiences',
                style: const TextStyle(color: muted),
              ),
            ),
          ProfileSettingsTile(
            title: client
                ? 'View Organization Profile'
                : 'View Professional Profile',
            icon: client ? Icons.business_outlined : Icons.badge_outlined,
            onTap: () => openDetails(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 18),
          if (ReviewScope.maybeOf(context) case final reviewRepository?)
            ProfileSettingsTile(
              title: 'Reviews & Reputation',
              subtitle: reviewRepository.averageFor(accountId) == null
                  ? 'No published reviews yet'
                  : '★ ${reviewRepository.averageFor(accountId)!.toStringAsFixed(1)} · ${reviewRepository.publishedFor(accountId).length} reviews',
              icon: Icons.star_outline_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ReviewProfileScreen(
                    repository: reviewRepository,
                    profileId: accountId,
                    actorId: accountId,
                    client: client,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ProfileSettingsTile(
            title: client ? 'Organization Information' : 'Personal Information',
            icon: client ? Icons.business_outlined : Icons.person_outline,
            onTap: onEdit,
          ),
          for (final entry in {
            'Account Settings': Icons.manage_accounts_outlined,
            'Notifications': Icons.notifications_outlined,
            'Notification Settings': Icons.tune_outlined,
            'Privacy & Safety': Icons.shield_outlined,
            'Help & Support': Icons.help_outline,
            'About ProjectBridge': Icons.info_outline,
          }.entries)
            ProfileSettingsTile(
              title: entry.key,
              icon: entry.value,
              onTap: () =>
                  openSettingsPage(context, accountId, client, entry.key),
            ),
          if (isDemo)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TextButton.icon(
                onPressed: onSwitch,
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  client ? 'Switch to Student Demo' : 'Switch to Client Demo',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OrganizationProfileDetails extends StatefulWidget {
  const OrganizationProfileDetails({
    super.key,
    required this.projects,
    required this.onEdit,
  });
  final List<BridgeProject> projects;
  final Future<void> Function() onEdit;
  @override
  State<OrganizationProfileDetails> createState() =>
      _OrganizationProfileDetailsState();
}

class _OrganizationProfileDetailsState
    extends State<OrganizationProfileDetails> {
  @override
  Widget build(BuildContext context) {
    final root = context.findAncestorStateOfType<_ProjectBridgeAppState>()!;
    final account = root.settings.account('client-demo-coffee');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Avatar(
          initials: root.clientOrganization.isEmpty
              ? '?'
              : root.clientOrganization[0],
          accountId: 'client-demo-coffee',
        ),
        const SizedBox(height: 16),
        Text(
          root.clientOrganization,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        Text(
          'Small Business · ${root.clientIndustry}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        const SectionTitle('About'),
        Text(
          root.clientDescription.isEmpty
              ? 'No organization description added yet.'
              : root.clientDescription,
        ),
        if (root.clientWebsite.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(root.clientWebsite),
          ),
        if (account.shareContact && account.contact.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText('Contact: ${account.contact}'),
          ),
        const SizedBox(height: 24),
        const SectionTitle('Published projects'),
        Text(
          '${widget.projects.where((p) => p.isPublished && !p.isArchived).length} published projects',
        ),
        for (final p in widget.projects.where(
          (p) => p.isPublished && !p.isArchived,
        ))
          ProfileSettingsTile(
            title: p.title,
            subtitle: p.completed ? 'Completed' : 'Published',
            icon: Icons.work_outline,
            onTap: () => root.openClientProject(p),
          ),
        const SizedBox(height: 20),
        const SectionTitle('Completed projects'),
        Text(
          '${widget.projects.where((p) => p.completed).length} completed projects',
        ),
        const SizedBox(height: 20),
        const ReviewsReputationSection(
          profileId: 'client-demo-coffee',
          actorId: 'client-demo-coffee',
          client: true,
        ),
        const SizedBox(height: 20),
        const SectionTitle('Verification status'),
        const Text('Demo account · Not verified'),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await widget.onEdit();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Profile'),
        ),
      ],
    );
  }
}

class AboutProjectBridgeScreen extends StatelessWidget {
  const AboutProjectBridgeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About ProjectBridge')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'ProjectBridge',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text('Version 1.0.0+1'),
          SizedBox(height: 20),
          Text(
            'Connect students with real projects, build a professional portfolio, and help organizations collaborate with emerging talent.',
          ),
          SizedBox(height: 16),
          Text(
            'This offline demo stores projects, profiles, messages and preferences on this device. Support reports are saved locally. Authentication, cross-device sync and push delivery are not configured.',
          ),
        ],
      ),
    ),
  );
}

class OrganizationEditorScreen extends StatefulWidget {
  const OrganizationEditorScreen({
    super.key,
    required this.name,
    required this.industry,
    required this.description,
    required this.website,
  });
  final String name, industry, description, website;
  @override
  State<OrganizationEditorScreen> createState() =>
      _OrganizationEditorScreenState();
}

class _OrganizationEditorScreenState extends State<OrganizationEditorScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.name);
  late final industry = TextEditingController(text: widget.industry);
  late final description = TextEditingController(text: widget.description);
  late final website = TextEditingController(text: widget.website);
  @override
  void dispose() {
    name.dispose();
    industry.dispose();
    description.dispose();
    website.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Organization Information')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Organization name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter an organization name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: industry,
              decoration: const InputDecoration(labelText: 'Industry'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a business category.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: website,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Website'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final uri = Uri.tryParse(v.trim());
                return uri != null &&
                        ['http', 'https'].contains(uri.scheme) &&
                        uri.host.isNotEmpty
                    ? null
                    : 'Enter a full http or https website address.';
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Changes are saved on this device.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'industry': industry.text.trim(),
                  'description': description.text.trim(),
                  'website': website.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
