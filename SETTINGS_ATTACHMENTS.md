# Settings, notifications, privacy, help and attachments

This extends the existing local demo; it does not add a new authentication or
Firebase Storage backend. Both roles open the new screens from Profile.

## What works locally

- Account Settings edits name, professional headline or organization description,
  profile photo and optional contact email. Cancel discards the draft. English is
  the only offered/saved UI language because the app has no other localization.
  IDs stay stable. Name changes update existing applicant/project displays and chat
  identity; photos appear in profiles, account avatars and chat participant views.
- Notification Settings saves independent per-account category preferences. The
  notification center records real application decisions, applications, messages,
  tasks/milestones, submission/feedback, completion, deadlines and project updates.
  Opening a notice routes to its project, applicants or authorized conversation.
  Existing historical data is a baseline, not invented notification history.
  Disabling a category suppresses future notices, without deleting existing ones.
  Deadline checks happen on startup and local persistence/events, including opening
  the notification center; there is no background scheduler or push delivery.
- Limited student profiles hide full details from unrelated viewers. Accepted
  project clients retain full-profile access. Portfolio entries/passports can be
  client-visible or owner-only. Contact is hidden by default; explicit sharing
  makes an optional email visible to the other accepted project participant.
  Availability can be hidden; matching screens use unknown availability for
  viewers without permission. A student's application-specific commitment and
  explicitly attached portfolio entries remain available to the application client.
- Blocking is symmetric for new messages/attachments and connection requests;
  blocked clients cannot receive a new application through the form. Unblocking
  restores those interactions. Existing accepted project history is retained;
  blocking never grants access to a chat. These are local demo policy checks,
  not server-enforced multi-device authorization.
- Help / About has expandable FAQs, current app version, rules and a validated
  support/report form with optional screenshot. Reports are saved privately for
  the current demo account with “Saved on this device”; they are not delivered to
  a support team. Existing contextual project/message reports remain available.
- Chat paperclip opens Gallery or Files using Android system activities.
  Images: JPG/JPEG/PNG/WEBP. Documents: PDF/DOC/DOCX/TXT. Nonempty files must be at
  most 10 MB; native content checks reject mismatched/corrupt formats and images
  over 40 megapixels. The limit is defined in the Dart/native attachment repository.
  Images have a thumbnail and zoomable full-screen viewer. Documents show name and
  size, and open with an installed application or a clear missing-viewer message.
  Captions are optional; sender and timestamp accompany attachment messages.

## Storage and security

Android `AttachmentBridge` copies selected content streams into
`files/attachments/<UUID>.<extension>` before returning a preview. It bounds the
actual copied byte count, rather than trusting provider metadata. Canceled imports
and unsuccessful validation are cleaned up. Canceling the attachment preview
removes that unsent copy. Saved profile/support photo replacements can leave unused
private copies; automatic orphan-file cleanup is not implemented.

Snapshots contain relative IDs, names, MIME types and sizes, never image binaries
or external picker paths. Existing version-1 snapshots accept optional `settings`
and message `attachment` fields. Old text messages gain a null attachment field;
their original fields and IDs remain unchanged.

Sending checks accepted membership and blocking, resolves/validates the private
file again, prevents concurrent duplicate sends, and awaits the native snapshot
commit before publishing the new message to chat streams. Persistence errors roll
back the message/unread change and preserve the preview for retry. Text and
attachment messages share accepted-participant authorization. Unauthorized chat
streams expose no messages. Each message stays in its original project thread.

Opening documents grants temporary read access to one FileProvider URI. The
provider is not exported and exposes only the app's attachment directory. Native
resolution accepts only UUID filenames and checks canonical containment, file
existence, type and size. System pickers do not require broad storage permissions.
The native approach follows Android's [system document picker guidance](https://developer.android.com/training/data-storage/shared/documents-files)
and [common intent guidance](https://developer.android.com/guide/components/intents-common).

## Verification

- `flutter pub get --offline`: succeeded using unchanged dependencies.
- `flutter analyze`: no issues.
- `flutter test`: 69 active tests passed; two existing assistant UI tests skipped.
  New tests cover event preferences/navigation, privacy and blocking, account
  name/headline/photo persistence and cancel, support validation/failure, native
  picker doubles (gallery/files/cancel), file validation, duplicate/failing
  sends, membership restrictions, role switching, snapshot restore and viewers.
- `flutter run --no-pub -d emulator-5554`: final debug APK built and launched.
- Real emulator checks: Gallery selected a PNG; Student sent it; Client saw it;
  full-screen image viewing worked. Files selected a TXT; Client sent it; after
  cold launch Student opened the persisted message notification into the correct
  chat and opened the TXT in Android HTML Viewer. Both private files matched the
  original input bytes after restart. Camera capture is not required and is hidden from chat attachments.
- Native data audit: all four original project records and both conversation IDs
  retained; all fields of the three original messages preserved. Two clearly named
  attachment verification messages were appended in the existing accepted direct
  chat, yielding five messages. No original project/chat data was removed.
- Pubspec, lockfile, Gradle wrapper, AGP/Kotlin configuration and Firebase versions
  are unchanged. Existing Kotlin plugin compatibility warning remains nonblocking.

Pre-edit backup: `/private/tmp/pr_bridge-settings-attachments-before-20261022.tgz`.
Final logs: `/private/tmp/pr_bridge-settings-final-analyze.log`,
`/private/tmp/pr_bridge-settings-final-tests.log`,
`/private/tmp/pr_bridge-settings-final-run.log`.

## Files

New: `lib/features/settings/settings_repository.dart`, `settings_screens.dart`;
`lib/features/attachments/local_attachments.dart`;
`test/settings_attachments_test.dart`, `test/settings_events_test.dart`;
Android `AttachmentBridge.kt` and `res/xml/attachment_paths.xml`.

Updated: `lib/main.dart`, `features/demo/demo_storage.dart`,
`features/applications/application_sheet.dart`, professional repository/screens,
matching screens and connections; Android `MainActivity.kt` and `AndroidManifest.xml`.

## Future backend / platform limits

Preferences, events, reports and files are local to this installation. Cross-device
sync, remote attachment storage, real authentication/authorization, moderation
intake and background push need a backend. Native picker/viewer integration is
implemented for Android; other platform adapters are future work. PDF/Word
viewing needs a compatible installed viewer. The
external viewer controls its own layout. Picker activity process-death recovery
and automatic cleanup of abandoned private photo/support drafts are not implemented.
