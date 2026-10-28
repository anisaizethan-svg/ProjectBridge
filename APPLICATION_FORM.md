# Student application form

The existing `applyToProject` entry point opens `ApplicationSheet` in a scrollable,
keyboard-aware bottom sheet. Implementation lives in
`lib/features/applications/application_sheet.dart`.

The sheet reads the profile using the applicant ID supplied by the existing
navigation. Weekly hours preselect an application-specific enum option when
known. Matching uses `Skill.key` normalization and the project's required skills;
only skills actually present in the profile can be highlighted. Missing skills
are informational. Profile editing preserves the draft. Existing independent
portfolio entries can be attached as self-reported snapshots; the first valid
portfolio entry URL can prefill the optional external link.

Motivation is trimmed, 30–1000 characters, and must contain several words.
Validation appears after field interaction or submission. Availability is required;
nonempty external links must use HTTP or HTTPS. Controllers belong to the sheet
and are disposed when it closes.

Submission calls the existing `BridgeProject.submitApplication`, records the
structured availability code alongside its readable label, captures headline,
highlighted skills and selected portfolio entries, and awaits the existing Android
private-storage save acknowledgement. Save failures restore application fields
and keep the draft open for retry. In-memory widget/demo sessions have no native
storage to await. Pending applications create no chats. Existing acceptance,
participant authorization and messaging logic are unchanged.

New snapshot fields are optional when loading older data. IDs and legacy
application statuses are retained. Client applicant details display submitted
information, status and date in a scrollable dialog; Accept/Reject remain intact.
This remains the application's existing local demo repository, not a new Firebase
application backend. Firebase dependencies and configuration are unchanged.

Verification: `flutter analyze` clean; `flutter test` 56 passed, two existing paused
assistant tests skipped. `flutter run -d emulator-5554` built and launched the debug
APK. Four existing project records and two conversations were unchanged in a
before/after native-storage comparison. Backup before editing:
`/private/tmp/pr_bridge-application-form-before-20261022.tgz`.
