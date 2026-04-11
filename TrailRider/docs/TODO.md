# TrailRider — TODO

Living punch list of work the project needs. Grouped by priority. Date of last update is in git.

## P0 — Block trail-ready release

- [ ] **Verify `ActiveRideView` elevation revert is intentional.** Commit `b5b305d` reverted the close-up `.flat` elevation branch that commit `518e64a` introduced to stop 3D buildings from occluding the trail. On actual mountain trails there are no buildings, so this likely does not bite in practice — but confirm on a ride, and if buildings reappear in close-up mode near the trailhead, restore the zoom-aware branch.
- [ ] **Confirm build is green on physical device.** The batch-write changes to `RideService` compile-check cleanly in Xcode, but run a full device build (`id=00008140-001C15403C6B001C`) before leaving for a ride.
- [ ] **End-to-end smoke test the ride flow:** start → pause → resume → save → appears in history → `totalMiles` increments on profile header → delete ride → `totalMiles` decrements. This exercises the new `WriteBatch` paths and the `refreshCurrentUser()` hooks.

## P1 — Data consistency follow-ups

- [ ] **Backfill drift from pre-batch rides.** Any ride saved before `b5b305d` may have succeeded while the `totalMiles` increment failed (or vice versa). Add a one-shot reconciliation: sum `distanceMiles` across a user's rides and overwrite `users/{uid}.totalMiles`. Run once per user on next app launch, guarded by a `miles_reconciled_at` field so it doesn't run twice.
- [ ] **Firestore security rule for `totalMiles`.** Right now the client can write any value to `users/{uid}.totalMiles`. Tighten rules so only `FieldValue.increment()` deltas bounded by a reasonable per-write max are allowed — prevents a compromised client from inflating leaderboard stats.
- [ ] **Dedup key hardening.** `rideExists(userId:startTime:)` uses `startTime` equality, which is fragile if the watch ever rounds timestamps differently than the phone. Consider a deterministic client-side ride ID derived from `hash(userId + startTime.rounded(to: .second))` and use it as the document ID — then dedup becomes a `getDocument` by ID, no index needed.
- [ ] **Composite index for the dedup query.** The `userId == X AND startTime == Y` query needs a composite index in Firestore. Add it to `firestore.indexes.json` and deploy via `npx firebase-tools deploy --only firestore:indexes` before the first real user hits this path in production.

## P1 — UX polish

- [ ] **Verify `followsHeading: true` feels right in hand.** Map now rotates with the rider's heading during active rides. On a winding trail this can feel disorienting if heading updates are noisy — if so, expose a toggle in the zoom/style control cluster rather than hardcoding it.
- [ ] **Loading state during `refreshCurrentUser()`.** Silent failure is fine, but the profile header could briefly show a shimmer while the fetch is in flight so the user has feedback.
- [ ] **Error surfacing for batch-commit failures.** `RideService.saveRide` now throws on batch commit failure. `RideViewModel.saveRide` already catches and sets `saveError`, but there's no retry — a failed save on flaky cell signal at the trailhead means the ride is lost. Queue failed saves to local storage and retry on reconnect.

## P2 — Ride replay (recently shipped — hardening)

- [ ] **Test replay with a long ride (>1 hr, >1000 route points).** The `RouteReplayViewModel` playback engine has not been stress-tested. Check memory, scrubber responsiveness, and frame rate.
- [ ] **Ghost ride edge case:** what happens if the ghost ride has fewer points than the active ride, or the active ride goes off-route? Confirm the delta badge degrades gracefully.

## P2 — Watch ↔ Phone sync

- [ ] **Standalone watch ride import UX.** Currently the import is silent — no banner, no confirmation. Add a toast or summary sheet so the user knows the ride was picked up.
- [ ] **Handle partial watch ride data.** `saveStandaloneWatchRide` bails silently if any key is missing. Log which key failed so we can diagnose field-drift bugs.

## P3 — Nice-to-haves

- [ ] Clean up the trailing blank line added to `ActiveRideView.swift` by the last commit.
- [ ] Prune unused tool allowlist entries in `.claude/settings.local.json`.
- [ ] Add a `CONTRIBUTING.md` note about the commit convention being used (`feat:`, `fix:`, `refactor:`).
