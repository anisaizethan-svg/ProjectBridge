part of '../../main.dart';

class SettingsLinks extends StatelessWidget {
  const SettingsLinks({
    super.key,
    required this.accountId,
    required this.client,
  });
  final String accountId;
  final bool client;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in {
        'Account Settings': Icons.manage_accounts_outlined,
        'Notification Settings': Icons.notifications_outlined,
        'Notifications': Icons.notifications_active_outlined,
        'Privacy Settings': Icons.lock_outline,
        'Help / About': Icons.help_outline,
      }.entries)
        ListTile(
          leading: Icon(item.value, color: violet),
          title: Text(item.key),
          onTap: () => openSettingsPage(context, accountId, client, item.key),
        ),
    ],
  );
}

void openSettingsPage(
  BuildContext context,
  String accountId,
  bool client,
  String page,
) {
  final root = context.findAncestorStateOfType<_ProjectBridgeAppState>();
  final settings = SettingsScope.maybeOf(context);
  if (root == null || settings == null) return;
  if (page == 'Notifications') root.persist();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => switch (page) {
        'Account Settings' => _AccountSettingsScreen(
          root: root,
          accountId: accountId,
          client: client,
        ),
        'Notification Settings' => NotificationSettingsScreen(
          repository: settings,
          accountId: accountId,
          client: client,
        ),
        'Notifications' => _NotificationCenter(
          root: root,
          accountId: accountId,
          client: client,
        ),
        'Privacy Settings' || 'Privacy & Safety' => PrivacySettingsScreen(
          repository: settings,
          professional: root.professional,
          accountId: accountId,
          client: client,
        ),
        'About ProjectBridge' => const AboutProjectBridgeScreen(),
        _ => HelpAboutScreen(repository: settings, accountId: accountId),
      },
    ),
  );
}

class _AccountSettingsScreen extends StatefulWidget {
  const _AccountSettingsScreen({
    required this.root,
    required this.accountId,
    required this.client,
  });
  final _ProjectBridgeAppState root;
  final String accountId;
  final bool client;
  @override
  State<_AccountSettingsScreen> createState() => __AccountSettingsScreenState();
}

class __AccountSettingsScreenState extends State<_AccountSettingsScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.root.accountName(widget.accountId, ''),
  );
  late final description = TextEditingController(
    text: widget.client
        ? widget.root.clientDescription
        : widget.root.professional.profile(widget.accountId).headline,
  );
  late final contact = TextEditingController(
    text: widget.root.settings.account(widget.accountId).contact,
  );
  late LocalAttachment? photo = widget.root.settings
      .account(widget.accountId)
      .photo;
  final files = NativeAttachmentRepository();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    contact.dispose();
    super.dispose();
  }

  Future<void> choosePhoto() async {
    try {
      final selected = await files.pick('gallery');
      if (selected != null && mounted) {
        if (!selected.image) {
          await files.delete(selected);
          throw ArgumentError();
        }
        setState(() => photo = selected);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not select this photo. Choose a JPG, PNG or WEBP image up to 10 MB.',
        );
      }
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final root = widget.root;
    final preferences = root.settings.account(widget.accountId);
    final oldPhoto = preferences.photo, oldContact = preferences.contact;
    final oldName = root.accountName(widget.accountId, '');
    final oldDescription = root.clientDescription;
    final oldProfile = widget.client
        ? null
        : root.professional.profile(widget.accountId);
    final projectNames = {
      for (final p in root.projects)
        p.id: [p.client, p.applicantName, p.applicantHeadline],
    };
    try {
      preferences
        ..photo = photo
        ..contact = contact.text.trim();
      if (widget.client) {
        root.clientOrganization = name.text.trim();
        root.clientDescription = description.text.trim();
      } else {
        root.professional._profiles[widget.accountId] = oldProfile!.withChanges(
          {'name': name.text.trim(), 'headline': description.text.trim()},
        );
        root._syncProfessional();
      }
      for (final p in root.projects) {
        if (widget.client && p.clientId == widget.accountId) {
          p.client = name.text.trim();
        }
        if (!widget.client && p.applicantId == widget.accountId) {
          p.applicantName = name.text.trim();
          if (!widget.client && p.applicantId == widget.accountId) {
            p.applicantHeadline = description.text.trim();
          }
        }
      }
      await root.saveApplicationSnapshot();
      root._settingsChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account settings saved.')),
        );
      }
    } catch (_) {
      preferences
        ..photo = oldPhoto
        ..contact = oldContact;
      if (widget.client) {
        root.clientOrganization = oldName;
        root.clientDescription = oldDescription;
      } else {
        root.professional._profiles[widget.accountId] = oldProfile!;
        root._syncProfessional();
      }
      for (final p in root.projects) {
        p.client = projectNames[p.id]![0]!;
        p.applicantName = projectNames[p.id]![1];
        p.applicantHeadline = projectNames[p.id]![2];
      }
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Settings could not be saved. Your changes are here; please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (photo != null)
                AttachmentTile(attachment: photo!, repository: files),
              TextButton.icon(
                onPressed: busy ? null : choosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Choose profile photo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                enabled: !busy,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (v) => (v?.trim().length ?? 0) < 2
                    ? 'Enter a name of at least two characters.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                enabled: !busy,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.client
                      ? 'Organization description'
                      : 'Professional headline',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Add a short description.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contact,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Contact email (optional)',
                  helperText:
                      'Hidden by default. Sharing requires privacy permission.',
                ),
                validator: (v) =>
                    v == null ||
                        v.trim().isEmpty ||
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                    ? null
                    : 'Enter a valid email address.',
              ),
              DropdownButtonFormField<String>(
                initialValue: 'English',
                decoration: const InputDecoration(
                  labelText: 'App language',
                  helperText: 'Only supported UI languages are offered.',
                ),
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                ],
                onChanged: busy ? null : (_) {},
              ),
              const SizedBox(height: 16),
              InfoCard(
                icon: Icons.info_outline,
                title: 'Account information',
                body:
                    '${widget.client ? 'Client' : 'Student'} · Local demo account\nThere is no email/password sign-in in this demo. Contact email is optional profile data, not a login credential.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save changes'),
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.repository,
    required this.accountId,
    required this.client,
  });
  final SettingsRepository repository;
  final String accountId;
  final bool client;
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final values = Map<String, bool>.from(
    widget.repository.account(widget.accountId).notifications,
  );
  bool busy = false;
  String? error;
  Future<void> save() async {
    setState(() => busy = true);
    final target = widget.repository.account(widget.accountId).notifications;
    final before = Map<String, bool>.from(target);
    target
      ..clear()
      ..addAll(values);
    try {
      await widget.repository.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved.')),
        );
      }
    } catch (_) {
      target
        ..clear()
        ..addAll(before);
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'In-app notifications for real activity on this device. Background push notifications are not enabled.',
        ),
        for (final category in widget.repository.categories(widget.client))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(noticeLabels[category]!),
            value: values[category.name] ?? true,
            onChanged: busy
                ? null
                : (v) => setState(() => values[category.name] = v),
          ),
        if (error != null) Text(error!),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Save preferences'),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    super.key,
    required this.repository,
    required this.professional,
    required this.accountId,
    required this.client,
  });
  final SettingsRepository repository;
  final ProfessionalRepository professional;
  final String accountId;
  final bool client;
  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  late AccountPreferences draft = AccountPreferences.fromJson(
    widget.repository.account(widget.accountId).toJson(),
  );
  bool busy = false;
  String? error;
  Future<void> save() async {
    setState(() => busy = true);
    final before = widget.repository.account(widget.accountId);
    widget.repository.accounts[widget.accountId] = draft;
    try {
      await widget.repository.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings saved.')),
        );
      }
    } catch (_) {
      widget.repository.accounts[widget.accountId] = before;
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save privacy settings. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!widget.client) ...[
          SwitchListTile(
            title: const Text('Limited profile visibility'),
            subtitle: const Text(
              'Only you and clients of projects you have joined can view your full profile.',
            ),
            value: draft.limitedProfile,
            onChanged: busy
                ? null
                : (v) => setState(() => draft.limitedProfile = v),
          ),
          SwitchListTile(
            title: const Text('Private portfolio'),
            subtitle: const Text(
              'When off, your portfolio is visible to clients. When on, only you can view it. Entries attached to an application stay available to that client.',
            ),
            value: draft.privatePortfolio,
            onChanged: busy
                ? null
                : (v) => setState(() => draft.privatePortfolio = v),
          ),
          SwitchListTile(
            title: const Text('Availability visible to project clients'),
            subtitle: const Text(
              'Your application-specific weekly commitment is still shared when you apply.',
            ),
            value: draft.showAvailability,
            onChanged: busy
                ? null
                : (v) => setState(() => draft.showAvailability = v),
          ),
        ],
        SwitchListTile(
          title: const Text('Share contact with accepted project participants'),
          subtitle: const Text(
            'Hidden by default. Only the other accepted participant may view your optional contact email.',
          ),
          value: draft.shareContact,
          onChanged: busy
              ? null
              : (v) => setState(() => draft.shareContact = v),
        ),
        const SectionTitle('Blocked users'),
        const Text(
          'Blocking stops new messages and connection requests in either direction. Accepted chat history stays available.',
        ),
        for (final id in draft.blocked)
          ListTile(
            title: Text(widget.professional._profiles[id]?.name ?? id),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => draft.blocked.remove(id)),
              child: const Text('Unblock'),
            ),
          ),
        if (draft.blocked.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No blocked users.'),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey(draft.blocked.join(',')),
          decoration: const InputDecoration(
            labelText: 'Choose a user to block',
          ),
          items: [
            for (final id
                in {
                  ...widget.professional._profiles.keys,
                  'client-demo-coffee',
                }.where(
                  (id) => id != widget.accountId && !draft.blocked.contains(id),
                ))
              DropdownMenuItem(
                value: id,
                child: Text(
                  widget.professional._profiles[id]?.name ?? 'Demo Coffee',
                ),
              ),
          ],
          onChanged: busy
              ? null
              : (id) {
                  if (id != null) setState(() => draft.blocked.add(id));
                },
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Report a user, project or message'),
          subtitle: const Text('Private report saved on this device'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SupportReportScreen(
                repository: widget.repository,
                accountId: widget.accountId,
              ),
            ),
          ),
        ),
        const Text(
          'You can also report projects from their details and messages by long-pressing them. Project chat access still requires acceptance.',
        ),
        if (error != null) Text(error!),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Save privacy settings'),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _NotificationCenter extends StatefulWidget {
  const _NotificationCenter({
    required this.root,
    required this.accountId,
    required this.client,
  });
  final _ProjectBridgeAppState root;
  final String accountId;
  final bool client;
  @override
  State<_NotificationCenter> createState() => __NotificationCenterState();
}

class __NotificationCenterState extends State<_NotificationCenter> {
  Future<void> open(LocalNotice notice) async {
    notice.read = true;
    try {
      await widget.root.settings.commit();
    } catch (_) {
      notice.read = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark as read. Please retry.'),
          ),
        );
      }
    }
    if (!mounted) return;
    final projects = widget.root.projects.where(
      (p) => p.id == notice.projectId,
    );
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This project is no longer available.')),
      );
      return;
    }
    final p = projects.first;
    if (notice.reviewTargetId != null) {
      final reviews = widget.root.reviews;
      if (reviews.ownReview(widget.accountId, p.id, notice.reviewTargetId!) !=
          null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review submitted.')));
      } else if (reviews
          .targets(widget.accountId, p.id)
          .contains(notice.reviewTargetId)) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ReviewFormScreen(
              repository: reviews,
              project: p,
              actorId: widget.accountId,
              targetId: notice.reviewTargetId!,
            ),
          ),
        );
      }
    } else if (notice.reviewProfileId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReviewProfileScreen(
            repository: widget.root.reviews,
            profileId: notice.reviewProfileId!,
            actorId: widget.accountId,
            client: notice.reviewProfileId == p.clientId,
          ),
        ),
      );
    } else if (notice.chatId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProjectChatScreen(
            repository: widget.root.chatRepository,
            chatId: notice.chatId!,
            userId: widget.accountId,
            displayName: widget.root.accountName(
              widget.accountId,
              'Participant',
            ),
          ),
        ),
      );
    } else if (widget.client &&
        notice.category == NoticeCategory.applications) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Applicants')),
            body: ClientApplicantsScreen(
              projects: [p],
              onChanged: widget.root.refresh,
              onOpenProject: widget.root.openClientProject,
              chatRepository: widget.root.chatRepository,
            ),
          ),
        ),
      );
    } else if (widget.client) {
      await widget.root.openClientProject(p);
    } else {
      openProject(
        context,
        p,
        widget.root.refresh,
        chatRepository: widget.root.chatRepository,
        displayName: widget.root.studentName,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notices = widget.root.settings.notices
        .where((n) => n.recipient == widget.accountId)
        .toList()
        .reversed
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notices.isEmpty
          ? const EmptyState(
              title: 'You are all caught up.',
              body: 'Real project activity will appear here.',
            )
          : ListView(
              children: [
                for (final notice in notices)
                  ListTile(
                    leading: Icon(
                      notice.read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: violet,
                    ),
                    title: Text(notice.text),
                    subtitle: Text(
                      notice.date.toLocal().toString().split('.').first,
                    ),
                    onTap: () => open(notice),
                  ),
              ],
            ),
    );
  }
}

const projectBridgeFaq = <String, String>{
  'What is ProjectBridge?': 'ProjectBridge connects students and clients through practical projects. This MVP stores demo data privately on this Android device.',
  'How do students apply?': 'Explore a published project, choose Apply to project, describe your fit and weekly availability, and submit. The client reviews your Pending application.',
  'How do clients create projects?': 'Switch to Client demo, open Create, describe the scope, required skills and conditions, then review and publish.',
  'How do clients review applications?': 'Open Applicants to review the submitted motivation, availability, selected skills and portfolio. Accept or reject the application.',
  'How do project chats work?': 'Acceptance unlocks the shared project chat. Only accepted participants may read or send messages and attachments. Blocking stops new messages.',
  'How do I submit work?': 'Open your accepted project workspace, review and acknowledge the agreement, and submit work against the relevant milestone. The client can request changes or approve it.',
  'What is a Verified Project Passport?': 'A passport records client-confirmed completion evidence. This local demo does not provide independent institutional verification. Self-reported portfolio entries are separate.',
  'How do I report a problem?': 'Use the support form below, Report a problem on a project, or long-press an inappropriate message. Local reports stay on this device and are not sent to a support team.',
  'Platform rules': 'Respect others, agree on scope and compensation, share only files you are allowed to share, and avoid sharing sensitive personal information. Do not harass, impersonate or misrepresent work. Use blocking and reporting when needed.',
};

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({
    super.key,
    required this.repository,
    required this.accountId,
  });
  final SettingsRepository repository;
  final String accountId;
  @override
  Widget build(BuildContext context) {
    SettingsScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help / About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'ProjectBridge',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text('Version 1.0.0+1 · Offline MVP'),
          for (final faq in projectBridgeFaq.entries)
            ExpansionTile(
              title: Text(faq.key),
              childrenPadding: const EdgeInsets.all(16),
              children: [Text(faq.value)],
            ),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SupportReportScreen(
                  repository: repository,
                  accountId: accountId,
                ),
              ),
            ),
            icon: const Icon(Icons.support_agent),
            label: const Text('Report a problem'),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Your saved support reports'),
          ...repository.supportReports
              .where((r) => r['accountId'] == accountId)
              .map(
                (r) => ListTile(
                  title: Text(r['subject'] as String),
                  subtitle: Text(
                    '${r['category']} · Saved on this device\n${r['description']}',
                  ),
                  onTap: r['attachment'] == null
                      ? null
                      : () => viewAttachment(
                          context,
                          NativeAttachmentRepository(),
                          LocalAttachment.fromJson(
                            Map<String, dynamic>.from(r['attachment'] as Map),
                          ),
                        ),
                ),
              ),
          if (!repository.supportReports.any(
            (r) => r['accountId'] == accountId,
          ))
            const Text('No support reports saved.'),
        ],
      ),
    );
  }
}

class SupportReportScreen extends StatefulWidget {
  const SupportReportScreen({
    super.key,
    required this.repository,
    required this.accountId,
  });
  final SettingsRepository repository;
  final String accountId;
  @override
  State<SupportReportScreen> createState() => _SupportReportScreenState();
}

class _SupportReportScreenState extends State<SupportReportScreen> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(),
      description = TextEditingController();
  String category = 'Technical problem';
  LocalAttachment? screenshot;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    final report = <String, dynamic>{
      'id': 'support-${DateTime.now().microsecondsSinceEpoch}',
      'accountId': widget.accountId,
      'category': category,
      'subject': subject.text.trim(),
      'description': description.text.trim(),
      'attachment': screenshot?.toJson(),
      'date': DateTime.now().toIso8601String(),
      'status': 'Saved on this device',
    };
    widget.repository.supportReports.add(report);
    try {
      await widget.repository.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved on this device. This report has not been sent to a support team.',
            ),
          ),
        );
      }
    } catch (_) {
      widget.repository.supportReports.remove(report);
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Report could not be saved. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report a problem')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Reports are private to your demo account and saved on this device.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              'Technical problem',
              'User report',
              'Project report',
              'Inappropriate message',
              'Other',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: busy ? null : (v) => setState(() => category = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: subject,
            enabled: !busy,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Subject'),
            validator: (v) => (v?.trim().length ?? 0) < 3
                ? 'Add a subject of at least three characters.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: description,
            enabled: !busy,
            maxLength: 3000,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'Include the project, user or message and what happened.',
            ),
            validator: (v) => (v?.trim().length ?? 0) < 10
                ? 'Describe the problem in at least 10 characters.'
                : null,
          ),
          if (screenshot != null)
            AttachmentTile(
              attachment: screenshot!,
              repository: NativeAttachmentRepository(),
            ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    try {
                      final file = await NativeAttachmentRepository().pick(
                        'gallery',
                      );
                      if (mounted && file != null) {
                        setState(() => screenshot = file);
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() => error = 'Could not attach screenshot.');
                      }
                    }
                  },
            icon: const Icon(Icons.image_outlined),
            label: const Text('Add screenshot (optional)'),
          ),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Saving…' : 'Submit report'),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
