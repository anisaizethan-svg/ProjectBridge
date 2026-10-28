# ProjectBridge

ProjectBridge connects students with beginner friendly, real world projects. This repository currently contains an interactive Flutter demo shell and a locally persisted Android walkthrough. It is not yet a Firebase connected MVP.

## Settings and local attachments

Both demo roles now have editable Account Settings, event-driven in-app notifications, enforced privacy and blocking, Help / About, and private on-device support reports. Accepted project chats support Android Gallery and Files attachments stored privately across restarts. See [SETTINGS_ATTACHMENTS.md](SETTINGS_ATTACHMENTS.md) for verified behavior, implementation files and local-only limitations.

## Stage 2 professional workflow

Professional profiles, persistent self-reported portfolio entries, demo education review, evidence-backed demo passports, versioned agreements, milestones, private reports, local matching/team suggestions and professional connections are implemented. See [STAGE2_DEMO.md](STAGE2_DEMO.md) for architecture, the scoring formula, limitations, verification and the exact competition walkthrough. Stage 1 application/acceptance/chat behavior is preserved. No dependency or Android build configuration changes were required.

## Repository status

The starting repository was a stock Flutter counter app. It had no Firebase dependencies, Firebase platform configuration, database rules, storage rules, or server functions. The current implementation provides a Material 3 visual foundation, separate Student and Client modes with five working tabs each, Student Explore and application workflows, Client project filters and details, manual project creation (assistant entry points remain paused), demo publishing, applicant review, team management, task creation/review, project completion, profile editing, and demo Passports. The Smart Assistant uses a deterministic local rule engine for English, Russian, and Kazakh; project analysis makes no network request and is clearly identified as non-generative. It also has team/direct project chat screens, a Messages inbox, stream-based in-session message delivery, unread counts, link rendering, and message reporting. Accepting an actual in-session application enables team/direct chats for its listed participants, and access checks require accepted project membership.

Stage 1 uses one shared local repository. On Android, projects (including application and task state), conversations, messages, unread counts, and the demo display names/skills are stored in app-private preferences and restored at startup. Student and Client are demo identities on one device, not separate authenticated accounts. Other platforms retain in-memory demo behavior. Firebase Core/Auth and Android build versions are preserved; Firebase initialization is optional, and no Firestore synchronization is implemented.

See [STAGE1_DEMO.md](STAGE1_DEMO.md) for the exact jury scenario, storage design, verification, and limitations. AI Assistant and Smart Assistant entry points remain paused; their source and service tests are retained.

## Offline Smart Project Assistant

The Client **Create Project** tab currently offers **Create Manually**. The Smart Assistant UI is paused. The Smart Assistant runs locally in `lib/features/project_assistant/`; no internet connection, API key, AI provider, HTTP request, or Cloud Function is used for analysis. It is a deterministic rule engine, not generative AI. It detects overlapping categories, project features, confidence, risks, skills, optional technology choices, tasks, deliverables, questions, and a cautious difficulty/timeline estimate in English, Russian, and Kazakh. Results are editable and can be transferred into the existing project creation and publishing workflow. Unanswered questions may be skipped and are recorded as assumptions. Sensitive-data and payment projects receive a mentor-review warning.

Firebase Core and Auth dependencies remain in the app for its broader Firebase setup. They are not needed by the local assistant. The former `analyzeProjectBrief` Cloud Function and AI-only `firebase.json` deployment configuration have been removed because this repository had no other Cloud Functions.

## Run

Install Flutter matching the Dart constraint in `pubspec.yaml`, then run the local demo:

```sh
flutter pub get
flutter run
```

The repository's configured Flutter SDK is at `/Users/anisaizetkhan/develop/flutter`. Project analysis works without network access. The Firebase Auth/Core packages remain for the app's Firebase integration; Android builds may still need Google Maven access to resolve their Android artifacts. Student/Client demo data is persisted locally on Android and is not synchronized through Firebase.

## Demo walkthrough

1. Explore projects; search by title, client, description, or skill and combine category, difficulty, and status filters.
2. Save a project or open its details and apply with a motivation and availability.
3. Find the application under **My Projects → Applications**.
4. Switch to Client demo, accept or reject the application, then create a task.
5. After acceptance, use the chat icon or project card chat action. Send a message as Demo Coffee.
6. Switch back to Student and open **My Projects → Active → Open workspace → Chat**. Read and reply; the other account view updates in the same running app session.
7. Open **Messages** from the Student Home header to see team and direct conversations and unread counts.
8. Return to the workspace Tasks tab to submit work.
9. Switch to Client and review the submission, request a revision, or approve it; complete the project after approval.
10. Switch to Student and open **My Projects → Completed** or **Portfolio** for the demo Passport details.
11. Edit the student profile and work samples in **Profile** and **Portfolio**.

This walkthrough uses shared local objects and streams, with Android persistence across restart. It does not demonstrate Firebase synchronization, separate authenticated sessions, server timestamps, push notifications, or attachment upload.

## Firebase production setup still required

No Firebase credentials are included or should be committed. To enable the production path, create a Firebase project and configure FlutterFire for Android and iOS. Add Authentication (email/password), Cloud Firestore, Storage, and optionally Cloud Messaging, then provide generated platform configuration through the normal FlutterFire setup. Implement Firestore repositories for projects, memberships, chat threads/messages/reports, server timestamps, unread state, and notification records. Add matching least-privilege Firestore/Storage rules and server-controlled membership validation; do not trust participant IDs sent by the client. Add server-controlled role claims and privileged operations for application acceptance, task review, completion, passport issuance, and moderation.

Before public launch, define and review Firestore and Storage rules, indexes, data retention and deletion behavior, moderation/report workflows, and Kazakhstan specific requirements with the institution and qualified local counsel. No legal compliance assessment has been performed.

## Planned implementation phases

1. Foundation: Firebase configuration, authentication, role onboarding, profile repositories, routing, and security boundaries.
2. Marketplace: persisted projects, moderation lifecycle, search/filter, applications, and membership transactions.
3. Collaboration: authorized workspaces, tasks, file submissions, reviews, and activity records.
4. Completion: server validated project completion, individual contribution records, passport issuance, and notifications.
5. Quality: integration/security tests, responsive QA, accessibility, and two-account live demo verification.
