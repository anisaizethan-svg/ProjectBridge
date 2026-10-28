part of '../../main.dart';

class LocalAttachment {
  const LocalAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
  });
  final String id, name, mime;
  final int size;
  bool get image => mime.startsWith('image/');
  String get sizeLabel => size < 1024 * 1024
      ? '${(size / 1024).ceil()} KB'
      : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'mime': mime,
  };
  factory LocalAttachment.fromJson(Map<String, dynamic> j) => LocalAttachment(
    id: j['id'] as String,
    name: j['name'] as String,
    size: j['size'] as int,
    mime: j['mime'] as String,
  );
}

abstract interface class AttachmentRepository {
  Future<LocalAttachment?> pick(String source);
  Future<String> resolve(LocalAttachment attachment);
  Future<bool> open(LocalAttachment attachment);
  Future<void> delete(LocalAttachment attachment);
}

class NativeAttachmentRepository implements AttachmentRepository {
  NativeAttachmentRepository({
    this.channel = const MethodChannel('projectbridge/attachments'),
  });
  final MethodChannel channel;
  static const maxBytes = 10 * 1024 * 1024;
  static const extensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
    'txt',
  };
  static void validate(LocalAttachment a) {
    if (!RegExp(r'^[a-f0-9-]{36}\.[a-z]+$').hasMatch(a.id) ||
        !extensions.contains(a.id.split('.').last) ||
        a.size <= 0 ||
        a.size > maxBytes ||
        a.name.trim().isEmpty) {
      throw ArgumentError(
        'Choose a supported, nonempty file of 10 MB or less.',
      );
    }
    const mimeByExtension = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
    };
    if (mimeByExtension[a.id.split('.').last] != a.mime) {
      throw ArgumentError('File type does not match its extension.');
    }
  }

  @override
  Future<LocalAttachment?> pick(String source) async {
    final raw = await channel.invokeMapMethod<String, dynamic>('pick', {
      'source': source,
    });
    if (raw == null) return null;
    final a = LocalAttachment.fromJson(raw);
    validate(a);
    return a;
  }

  @override
  Future<String> resolve(LocalAttachment a) async {
    validate(a);
    return (await channel.invokeMethod<String>('resolve', {'id': a.id}))!;
  }

  @override
  Future<bool> open(LocalAttachment a) async {
    validate(a);
    return await channel.invokeMethod<bool>('open', {'id': a.id}) ?? false;
  }

  @override
  Future<void> delete(LocalAttachment a) async {
    validate(a);
    await channel.invokeMethod<void>('delete', {'id': a.id});
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.attachment,
    required this.repository,
    this.onTap,
    this.thumbnail = true,
  });
  final LocalAttachment attachment;
  final AttachmentRepository repository;
  final VoidCallback? onTap;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment.image && thumbnail)
          FutureBuilder<String>(
            future: repository.resolve(attachment),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Image unavailable on this device.');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(snapshot.data!),
                  width: 220,
                  height: 150,
                  fit: BoxFit.cover,
                  cacheWidth: 660,
                  errorBuilder: (_, _, _) =>
                      const Text('Image could not be decoded.'),
                ),
              );
            },
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attachment.image
                  ? Icons.image_outlined
                  : Icons.description_outlined,
              color: violet,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${attachment.name}\n${attachment.sizeLabel}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> viewAttachment(
  BuildContext context,
  AttachmentRepository repository,
  LocalAttachment attachment,
) async {
  try {
    final path = await repository.resolve(attachment);
    if (!context.mounted) return;
    if (attachment.image) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(attachment.name)),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Image.file(
                  File(path),
                  errorBuilder: (_, _, _) => const Text(
                    'Image unavailable.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (!await repository.open(attachment) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No compatible viewer is installed. Install a viewer for this document type.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This attachment is missing or cannot be opened on this device.',
          ),
        ),
      );
    }
  }
}

Future<void> composeAttachment(
  BuildContext context,
  ChatRepository repository,
  String chatId,
  String userId,
  String displayName, {
  AttachmentRepository? attachments,
}) async {
  if (repository is! DemoChatRepository) return;
  final thread = repository.findThread(chatId);
  if (thread == null || !repository.canAccess(thread, userId)) return;
  final files = attachments ?? repository.attachments;
  final source = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in {
            'gallery': Icons.photo_library_outlined,
            'files': Icons.folder_open_outlined,
          }.entries)
            ListTile(
              leading: Icon(item.value, color: violet),
              title: Text(item.key[0].toUpperCase() + item.key.substring(1)),
              onTap: () => Navigator.pop(c, item.key),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Images and documents · Up to 10 MB each'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  LocalAttachment? file;
  try {
    file = await files.pick(source);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is PlatformException
                ? e.message ?? 'Could not select this file.'
                : 'Choose a supported file of 10 MB or less.',
          ),
        ),
      );
    }
    return;
  }
  if (file == null) return;
  if (!context.mounted) {
    await files.delete(file);
    return;
  }
  final selected = file;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AttachmentComposer(
      attachment: selected,
      attachments: files,
      send: (caption) => repository.sendAttachment(
        chatId: chatId,
        userId: userId,
        displayName: displayName,
        attachment: selected,
        caption: caption,
      ),
    ),
  );
  if (sent != true) await files.delete(selected);
}

class AttachmentComposer extends StatefulWidget {
  const AttachmentComposer({
    super.key,
    required this.attachment,
    required this.attachments,
    required this.send,
  });
  final LocalAttachment attachment;
  final AttachmentRepository attachments;
  final Future<void> Function(String caption) send;
  @override
  State<AttachmentComposer> createState() => _AttachmentComposerState();
}

class _AttachmentComposerState extends State<AttachmentComposer> {
  final caption = TextEditingController();
  bool sending = false;
  String? error;
  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.send(caption.text.trim());
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Attachment sent.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          sending = false;
          error = 'Attachment was not sent. Your preview is preserved; check access and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send attachment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AttachmentTile(
                attachment: widget.attachment,
                repository: widget.attachments,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: caption,
                enabled: !sending,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: sending ? null : send,
                child: sending
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Send attachment'),
              ),
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
