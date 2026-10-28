# ProjectBridge Stage 1 demo

Stage 2 extends profiles, portfolio, trust and safe collaboration; see [STAGE2_DEMO.md](STAGE2_DEMO.md). The application/acceptance/chat workflow below remains supported.

## Architecture

This is an offline, single-device Android demo. Firebase Core/Auth and the Android Gradle configuration are preserved. Firebase initialization remains optional; this workflow does not require Firebase credentials or a network connection once the app is installed. It does not synchronize different phones.

`ProjectBridgeApp` owns one project repository and one `DemoChatRepository` for both roles. The supported demo identities are `client-demo-coffee` (Demo Coffee) and `student-daria` (Daria). Role switching changes the displayed screens, not the repositories.

Each project has a stable, locally generated ID. Daria's application is stored on that project with her ID, name, skills, introduction, availability, timestamp and status. Submitting twice cannot replace the application. Submission creates no conversation. Pending/Accepted/Rejected states are shared by the Student and Client screens. One applicant per project is supported in this MVP; the team-size field describes the brief, not a multi-student recruitment backend.

`BridgeProject.acceptApplication` updates the same membership state read by chat authorization, then creates or reconciles direct and team conversations. Repeated acceptance uses the existing threads. Direct identity includes project ID, client ID and student ID; team identity includes project ID. Editing a project title cannot change its conversation ID, and projects with the same title do not collide. Pending, rejected, removed and unrelated users cannot send; inbox and message readers also check membership. These are demo checks, not server-side security for a production service.

Messages contain conversation identity (through the thread), sender ID/name, content, kind and timestamp. Shared streams update previews and unread counts. Only actual sends create messages. Friendly greetings are UI placeholders. Each role sees its own sends on the right and the other participant's sends on the left.

On Android, `DemoStorage` serializes a versioned JSON snapshot through the `projectbridge/demo_storage` method channel. `MainActivity` commits it to private SharedPreferences before acknowledging a save. Writes are queued in order. The snapshot includes projects and their application/task state, conversation timestamps, messages, unread counts, reports and demo display names/skills. Startup restores project references and reconciles thread membership. Unreadable data is preserved and a retry screen is displayed. Save failures show a warning. Other platforms retain the in-memory demo. Additional profile fields and standalone portfolio work samples are still session-only.

## Jury walkthrough

1. From Student **Profile**, scroll down and select **Switch to Client demo**.
2. Open **Create → Start Manually**. Enter:
   - Title: **Coffee Shop Digital Menu**
   - Description: **We need a digital menu website for our coffee shop. Customers should scan a QR code to view drinks, photos, and prices.**
   - Category: **Web Development**
   - Detailed description/problem: describe the menu and why customers need it.
   - Expected deliverables: **A working responsive digital menu website.**
3. Continue to Requirements. Enter **Web Development, UI/UX Design** as required skills; select duration and student count. Keep or edit the student role.
4. Continue through Conditions, then Preview. Select **Publish as Demo Coffee**. The form closes and the published project appears under Projects.
5. Open **Profile → Switch to Student demo → Explore**. Search **Coffee Shop Digital Menu**, open it and select **Apply to project**. Enter an introduction and availability, then submit. Status is **Pending**; My Projects also shows this application. Messages remains empty until acceptance.
6. Switch back through **Profile → Switch to Client demo**, then open **Applicants**. Review Daria's profile and select **Accept**, then confirm. Status becomes **Accepted**.
7. Open **Dashboard → Messages** (top-right icon). Open the **Daria** direct conversation for this project. A separate **Project team** conversation is also available. The empty direct conversation says **👋 Say hi to Daria!**
8. Send **Hi Daria! Welcome to our coffee shop project.** Back out to Dashboard and switch to Student through Profile.
9. Open **Home → Messages**, open the matching Demo Coffee conversation and read the exact message. Send **Thank you! I'm excited to work on this project.**
10. Back out, switch to Client and open **Dashboard → Messages**. The preview and conversation show Daria's reply.
11. Close and reopen the Android app. The application, membership, both conversations and their messages remain. Startup opens Student mode. No source edits, app restart, or message insertion are needed between steps 1–10.

For a repeat presentation, create a new project; the prior demonstration remains saved. Distinct project IDs keep histories separate even with identical titles. Uninstalling the app or clearing Android app storage removes the local demo data.

## Verification

`flutter pub get`, `flutter analyze`, `flutter test`, and `flutter run -d emulator-5554 --no-resident` are the verification commands. The regression suite covers manual creation and Explore visibility, application submission, duplicate prevention, Applicants/profile navigation, acceptance and authorization, shared deterministic thread identities, two-way sends, unread counts, reopening/restoration, rejected/pending/removed accounts, same-title projects, role-specific greetings, and the complete jury UI scenario.

The two existing assistant UI tests remain intentionally skipped while those entry points are paused. Assistant service tests still run. No Gradle/Firebase version changes, new packages, cache deletion or `flutter clean` are required.

### Completed checks (October 22, 2026)

- Dependency resolution passed without changes to `pubspec.yaml` or `pubspec.lock`.
- Analysis passed with no issues; the complete suite passed 27 active tests. Two pre-existing assistant UI tests were deliberately skipped.
- The Android APK built, installed and launched on `emulator-5554`.
- Using Android UI controls, Demo Coffee published **Coffee Shop Digital Menu**; Daria discovered it and applied; Demo Coffee accepted the application; both role inboxes showed the automatically created direct/team chats.
- Demo Coffee sent the specified welcome message and Daria sent the specified reply. Switching back to Demo Coffee displayed that exact reply. Both messages were verified in Android private storage under one stable direct conversation ID.
- Firebase's existing Kotlin Gradle Plugin migration warning remains nonblocking. No dependency or Gradle version was changed.

The source checkpoint is `/private/tmp/pr_bridge-stage1-before-20261022.tgz`. Build and test logs are `/private/tmp/pr_bridge-stage1-final-run.log` and `/private/tmp/pr_bridge-stage1-tests.log`.
- Cold-restart verification passed: after force-stopping the app and installing/launching the final APK, Daria reopened the same conversation and both original messages were visible. The foreground activity was confirmed as `com.example.pr_bridge/.MainActivity` on `emulator-5554`.
