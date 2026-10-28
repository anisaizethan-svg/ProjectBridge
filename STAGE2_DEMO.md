# ProjectBridge Stage 2

## What is implemented

The existing Flutter app and white/lavender interface remain. No packages, Firebase versions, native plugins, Gradle settings, or wrapper distributions were changed. AI/Smart Assistant entry points remain paused. Matching uses local Dart calculations, with no AI service or network call.

- Professional profiles: name/avatar, headline, broad city, summary, specialization, skills, optional education/program/period/type/city, availability, weekly hours, preferred roles, experience level, completed-project and connection counts.
- Existing Edit Profile is extended, not replaced with a separate identity system. Skills support a catalog, multiple selection, custom Unicode names and normalized duplicate prevention.
- Independent portfolio projects have working create/edit/remove and link-copy controls. They are always **Self-reported**. They cannot become verified by editing a field.
- Education review supports Not verified, Verification pending, and a clearly marked **Verified Education · demo only** state. Only the demo administrator action can simulate confirmation. Changing affiliation details invalidates it. No real enrollment or institutional partnership is claimed.
- Authorized client review and explicit completion create immutable demo passports with project/student/client IDs, title, description, role, demonstrated skills, actual deliverables/tasks, start/completion dates and review. Public profile/portfolio views honor project portfolio permission; the student and authorized client retain their own records.
- Agreements are versioned. Both owner and accepted student acknowledge before new work. Scope/task/milestone changes invalidate acknowledgements. Agreements are understandable summaries, not legal advice or claims of enforceable contracts.
- Clients create/assign milestones; accepted assignees start and submit; only the owner reviews. States are Not started, In progress, Submitted, Approved and Needs changes. Explicit completion after approved work creates the passport.
- Legacy task controls use the same membership, scope acknowledgement and client-review checks. Editing an assigned task invalidates earlier approval evidence.
- Students request withdrawal and clients approve/decline it. Clients can close/cancel with a reason. Status events and messages are retained; approved withdrawal revokes project membership and chat access.
- Reports have categories, details, timestamps and status. Normal UI readers see only their own reports. Records are saved locally as **Awaiting demo review**; no real moderation service receives them. A restricted repository method can record a clearly simulated moderator review without claiming resolution.
- Team matching ranks five fictional profiles, explains scores, and finds a complementary team without duplicate people. It shows uncovered roles and missing skills. Candidates' full public profiles are accessible.
- Recommended Projects uses the same matcher and opens the normal project/apply flow.
- Professional connections support requests, recipient acceptance/decline, duplicate prevention, counts/lists, public-profile viewing and removal. Connections never create chat membership.

## Data and authorization

`ProjectBridgeApp` still owns the original project/chat repositories. One `ProfessionalRepository` extends the shared state for profiles, portfolio, education audit, review evidence, passports, agreements, milestones, reports, lifecycle events and connections. `ProfessionalScope` provides it to existing screens and pushed routes. Business logic is split into `lib/features/professional/`; `main.dart` integrates the existing navigation and legacy controls.

Project application, acceptance and message identities remain unchanged. Projects get an optional recorded acceptance date; old snapshots keep their IDs. Existing project, application and chat histories are neither reseeded nor deleted when loading Stage 1 data.

The existing Android method channel/private preferences snapshot remains version 1 with backward-compatible optional fields and a nested `professional` payload. Writes use the existing ordered save queue. Profile edits and Stage 2 actions save immediately. Old Stage 1 snapshots migrate on first save. No Firebase deployment or network connectivity is required after installing the APK. Other platforms retain the existing in-memory demo behavior.

Repository methods check actor ownership/accepted membership. Public profile views exclude reports and chat history. Reports are readable only by their reporter or the explicit demo moderator role. Education review has a separate demo administrator role. These are application-level demo checks; production requires authenticated identities, server-side authorization and trusted audit/storage enforcement. Local preferences are not a production trust authority.

## Matching calculation

Default, constructor-adjustable weights:

| Component | Weight | Calculation |
|---|---:|---|
| Required skills | 45 | Fraction of normalized required skills matched; optional skills add up to 0.1 within this component, capped at 1 |
| Role compatibility | 25 | Actual role skill overlap, boosted by relevant declared specialization/preferred roles; a preference without relevant skills cannot cover a role |
| Availability/workload | 20 | Average of declared availability factor and weekly-hours coverage, divided by `1 + active project count` |
| Relevant experience | 10 | Client-confirmed relevant completions / 3, capped at 1; no invented reviews or experience |

Broad Web/Mobile/Backend Development requirements also recognize at least two stored technical skills covering at least half of the associated role catalog. This mapping is explicit, tested and explained in each result; it does not create experience or credentials. Candidates with no compatible role skills are not assigned a suggested role.

Unknown components are omitted from both the weighted numerator and denominator, and the missing information is explained. A reliable score needs skill/role evidence and at least 70% known weight. Unavailable profiles, profiles declaring zero hours, and profiles with three or more active projects are excluded from suggested teams. Institution, age, gender, religion, ethnicity, name and connections are not scoring factors.

Team selection uses a memoized assignment search, maximizing role coverage first and then role fit/score, subject to team size and one slot per student. Required roles default to an explainable category role if none are provided. Unknown or uncovered roles remain visible. Duration is displayed for discussion; the algorithm cannot infer availability across an entire date range from a weekly-hours field.

Recommendations are suggestions. They do not create applications, accept candidates, assign private chat access, or fabricate received messages.

## Competition walkthrough

### Profiles and independent work

1. Open Student **Profile**. Daria's professional header, summary and skills are shown. **Switch to Client demo** stays accessible above the profile list.
2. Select **Edit Profile**. Edit the headline, city, summary, specialization, availability/hours, preferred roles and skills. Education is optional; clear Institution to demonstrate independent participation. Scroll to **Save changes**.
3. Open **Portfolio → Add personal project**. Enter a title, description, technologies and project URL; save. Show the **Self-reported** label and the separate **Verified Projects** section. The overflow menu edits/removes an entry; opening it allows link copying.
4. Under Profile → Education, select **Request demo education review**, then **Enter demo administrator → Simulate confirmation**. Explain the demo-only badge and that it proves no real enrollment/partnership. Editing the institution removes the simulated verification.

### Recommended projects, candidates and complementary teams

5. Return to Student **Home → Recommended Projects For You**. Expand a matching project to show its actual skill matches, missing information and explanation. **Open project and apply** uses the existing application flow.
6. Switch to Demo Coffee through Student Profile. Open **Projects → Open Project → Find Team Members**.
7. Select **Edit team requirements**. For a three-person coffee platform use:
   - Required skills: `HTML, CSS, Figma, Graphic Design`
   - Required roles: `Web Developer, UI/UX Designer, Graphic Designer`
   - Team size: `3`
   - Optional skills: `React, Branding`
   - Hours per week: `4`
   - Estimated duration: `4 weeks`
8. Show the computed complementary suggestions: Dias for web, Aruzhan for UI/UX and Amina for graphics, assuming their editable demo profiles are unchanged. Expand a ranked candidate for the score explanation. Open a candidate to inspect the public résumé and portfolio. Nothing has been enrolled automatically.

### Stage 1 and safe collaboration

9. Create/publish a fresh project normally, switch to Daria, find it in Explore and apply. Switch back, view Daria's full professional profile through Applicants, then accept. The shared direct/team conversations still appear immediately. Exchange messages from both roles as in [STAGE1_DEMO.md](STAGE1_DEMO.md).
10. On the accepted project's client detail screen open **Agreement & Milestones**. In Agreement choose **Create agreement**, review/edit every term and save.
11. Open the sticky **Milestones** tab, create a milestone with expected deliverable and due date. It is assigned to the accepted student. Creating/changing scope resets acknowledgement, so define the work before final acknowledgement.
12. Return to Agreement, scroll to **I acknowledge this scope** as the client. Switch to Daria → **My Projects → Active → Open workspace → Agreement & Milestones** and acknowledge the same version.
13. In Milestones, select **Start milestone → Submit progress**, enter the deliverable/result and save.
14. Switch to Demo Coffee and return to Milestones. Select **Approve work** with an honest demo review. Then separately select **Approve project completion → Confirm completion**. This explicit action creates the demo passport.
15. Return to Daria. The passport appears in Profile Experience, Portfolio Verified Projects, and **My Projects → Completed → View Project Passport**. Show the complete details and **Verified · demo client confirmation** label, clearly explaining its local/demo scope.
16. For a separate active project, demonstrate **Request withdrawal** and client approval, or **Close project/Cancel project** with a reason. History remains. For a problem, use **Report a problem**; the reporter can track it under Safety → Reports or Student Profile → **My private reports**.

### Connections and restart

17. Open Student Profile → **Manage connections**. Connect to Aruzhan. Use the labelled **Demo networking account** selector to open Aruzhan's fictional inbox, accept the request, and show the connection. It does not change the main project account or open any chat. Remove the connection or demonstrate decline using another request.
18. Close/reopen the Android app. Profile, portfolio, connections, agreements, milestones and Stage 1 messages restore from the same local snapshot.

## Limits

- Single-device offline MVP, not Firebase Authentication/Firestore multi-device synchronization, production verification, moderation, legal contracting or secure multi-tenant storage.
- Main project-mode switching retains the existing Demo Coffee/Daria workflow and its one-applicant-per-project model. Other fictional profiles support discovery, networking and team suggestions. Complementary team selection is not multi-student enrollment or an invitation system; applications and acceptance remain explicit in Stage 1.
- No verified experience is seeded. A verified demo passport must be earned through the actual accepted/submitted/reviewed/completed demo workflow. Old local completion flags alone remain unverified.
- No real institution partnership, enrollment check, payment processing, document credential, public passport sharing, outside-project messaging or external AI is implemented.
- Clearing Android app storage/uninstalling removes the local data. The new professional fields are persisted on Android; other targets retain the existing in-memory behavior.
- Firebase's existing KGP migration warning remains; versions were preserved because it does not block this build.

## Files and checks

New models/services/screens are in `lib/features/professional/`: `professional_models.dart`, `professional_repository.dart`, `professional_screens.dart`, `safety_models.dart`, `safety_repository.dart`, `safety_screens.dart`, `matching_service.dart`, `matching_screens.dart`, and `connections.dart`. Integration/persistence changes are in `lib/main.dart` and `lib/features/demo/demo_storage.dart`.

Tests: `stage2_profiles_test.dart`, `stage2_trust_test.dart`, `stage2_safety_test.dart`, `stage2_safety_ui_test.dart`, `stage2_matching_test.dart`, `stage2_connections_test.dart`, `stage2_persistence_test.dart`, plus all Stage 1 regressions. The creation regression now scrolls to Continue because the form has additional structured requirements; its workflow assertions remain.

Baseline: analysis clean, 27 active tests passed. Phase A: 30. Phase B: 32. Phase C: 36. Phase D: 41. Phase E: 43. Final expanded suite: 49 active tests passed; two pre-existing assistant UI tests remain deliberately skipped. The full safety UI test and Stage 1 jury scenario both ran.

Source backup: `/private/tmp/pr_bridge-stage2-before-20261022.tgz`. Emulator data backup before install: `/private/tmp/pr_bridge-stage2-device-before.xml`. Test log: `/private/tmp/pr_bridge-stage2-final-tests.log`. Android final run log: `/private/tmp/pr_bridge-stage2-final-run.log`.

### Exact source file inventory

- `lib/main.dart`
- `lib/features/demo/demo_storage.dart`
- `lib/features/professional/connections.dart`
- `lib/features/professional/matching_screens.dart`
- `lib/features/professional/matching_service.dart`
- `lib/features/professional/professional_models.dart`
- `lib/features/professional/professional_repository.dart`
- `lib/features/professional/professional_screens.dart`
- `lib/features/professional/safety_models.dart`
- `lib/features/professional/safety_repository.dart`
- `lib/features/professional/safety_screens.dart`
- `test/stage2_connections_test.dart`
- `test/stage2_matching_test.dart`
- `test/stage2_persistence_test.dart`
- `test/stage2_profiles_test.dart`
- `test/stage2_safety_test.dart`
- `test/stage2_safety_ui_test.dart`
- `test/stage2_trust_test.dart`
- `test/widget_test.dart`
- `README.md`
- `STAGE1_DEMO.md`
- `STAGE2_DEMO.md`

### Android verification completed

The final APK built, installed and launched successfully with `flutter run -d emulator-5554 --no-resident`. Native UI checks covered profile editing (city/availability), adding a self-reported portfolio entry, cold-start restoration, client team recommendations, a candidate's public professional profile, the versioned agreement preview, and the final category-aware score explanation. The final public-networking privacy refinement was verified by an additional widget regression and another successful Android build/launch.

The pre-install/final Android data audit confirmed all four original project records, both conversation IDs and all three original messages unchanged. Five professional profiles and an independent portfolio entry are persisted on the device. No verified passport or institutional partnership was fabricated for native demo data; the actual review/completion workflow was exercised in the safety UI test.

Final analysis: clean. Final suite: **49 active tests passed, 2 pre-existing assistant UI tests intentionally skipped, no failing tests**. The emulator remains on the final running app. No package or Android configuration changes were required.
