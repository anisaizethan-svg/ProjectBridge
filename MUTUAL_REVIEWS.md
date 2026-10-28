# Mutual reviews and reputation

Reviews are an offline feature backed by the existing application snapshot. No new
packages, cloud services, Firebase configuration or Gradle versions were added.

## Eligibility and publication

The existing ProfessionalRepository must have issued a project passport through
explicit client completion after approved work. A completed flag alone does not
grant review eligibility. Each accepted student and the client can review the
other side once per project; self-reviews, rejected applicants, outsiders,
incomplete projects and duplicate submissions are rejected by the repository.
Completed participant IDs are frozen in the review completion record. Existing
education/verification records are unchanged; ratings never certify skills or
institutional enrollment.

Each review records overall and three role-specific category ratings (1–5),
optional feedback, stable IDs, names/project title at submission, timestamps,
publication status and moderation status. Team publication is independent for
each student–client pair. Only published reviews enter profile lists and averages.

Reviews publish when both participants in the pair submit, or after 14 × 24 hours
from the recorded project completion time. Late reviews publish immediately.
Pending reviews are not returned by profile queries or previewed in the other
side's form. The rules and deadline are shown before submission. Submitted
reviews cannot be edited. Save failures retain the draft and roll back repository
changes and review notifications; concurrent submissions are guarded.

Publication is checked on startup, app resume, review refresh and snapshot saves.
While the app is open, a timer targets the next pending publication deadline.
There is no background service while the app is closed: overdue reviews publish
when the application next runs. Time comes from the local device clock.

## Navigation

- Student: My Projects → Completed → Leave a Review; completed project details
  and Agreement & Milestones also expose the action.
- Client: Projects → Completed → Leave a Review; project details show an action
  for each accepted student.
- Completion notifications open the eligible participant's review form; a
  submitted review displays a status instead of another submit action.
- Both Profile overviews link to Reviews & Reputation. Professional Profile and
  Organization Profile details also display published review cards.
- Students can open View Client Reviews from project details before applying.
- Publication notifications open the recipient's reputation page.

The form offers interactive accessible stars, validation, optional written
feedback, a confirmation step and scrollable keyboard-safe layout.

## Reports and privacy

Published reviews can be reported with a reason. Reports are stored privately in
the local snapshot; the review receives `reported` moderation status and remains
visible and included in its average. Reporting twice from one account is blocked.
No external moderation team is contacted and no automated removal occurs. The UI
never pulls private profile contacts into review cards.

This is a local demo, using its existing actor IDs. It does not provide server
authentication, cross-device synchronization, authoritative server time or remote
moderation. The UI depends on ReviewRepository, with LocalReviewRepository as the
current persistence adapter, so a future backend can implement the same contract.

## Storage compatibility

Snapshot version remains 1. Optional `reviewSystem` stores review records,
completion membership/time and moderation reports. Optional notification fields
route review invitations and publication events. Stable project client IDs are
now explicitly persisted so renaming an organization cannot change review/chat
identity on restart. Optional acceptedTeamStudents retains additional explicitly
accepted students; the primary student remains backward-compatible.

The repository offers owner-only `acceptTeamStudent` for available team slots
before final review, and refreshes existing chat membership. Recommendations do
not grant membership. The existing primary-application UI remains in place; this
feature does not replace it with a new team recruitment workflow.

Old snapshots without reviews load with empty reputation and retain their
existing projects, messages, attachments, notifications and education state.
Historical completion records lacking actual passport evidence cannot be rated.

## Files changed

New:
- lib/features/reviews/review_models.dart
- lib/features/reviews/review_repository.dart
- lib/features/reviews/review_screens.dart
- test/mutual_reviews_test.dart
- MUTUAL_REVIEWS.md

Updated:
- lib/main.dart
- lib/features/demo/demo_storage.dart
- lib/features/settings/settings_repository.dart
- lib/features/settings/settings_screens.dart
- lib/features/profile/profile_overview.dart
- lib/features/professional/professional_screens.dart
- lib/features/professional/safety_screens.dart
- test/profile_overview_test.dart (scroll to the existing verification section)

## Verification

- flutter analyze --no-pub: no issues.
- flutter test --no-pub: 84 passed, 2 existing skipped tests.
- 14 new tests cover role eligibility, invalid ratings, duplicates/concurrency,
  pair-specific team publication, the exact 14-day boundary, late submission,
  averages, rollback on save failure, reporting, legacy snapshots, stable IDs,
  retained messages/team membership, restart/idempotent notifications, profile
  empty/published states, both forms at 360px width with keyboard inset, reporting
  UI and actual notification navigation through an application restart.
- flutter build apk --debug --no-pub --target-platform android-arm64: succeeded.
- flutter run --no-pub -d emulator-5554 --no-resident: built, installed as an update and launched successfully.

Backup before implementation:
/private/tmp/projectbridge-before-mutual-reviews-20261022.tgz
