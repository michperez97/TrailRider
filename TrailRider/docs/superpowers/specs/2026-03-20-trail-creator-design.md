# Trail Creator — Design Spec

## Goal

Transform the existing dev-only Trail Mapper into a production feature where any rider can record trails by riding them, name and categorize them, publish to a community database, and other riders can discover, verify, and suggest edits. This is TrailRider's key differentiator — community-driven trail mapping that scales from Miami to every park in the country.

## Strategy

TrailRider owns Miami (hand-mapped, verified, detailed). The Trail Creator gives every rider the tools to do the same for their local parks. The app becomes a platform: riders create content, social verification ensures quality, and maintainers curate their parks.

---

## Data Model

### CommunityTrail

Firestore collection: `communityTrails`

| Field | Type | Description |
|-------|------|-------------|
| id | String (DocumentID) | Auto-generated |
| creatorId | String | Firebase Auth UID of the creator |
| creatorUsername | String | Denormalized for display |
| name | String | Trail name (required) |
| description | String | One-line description |
| difficulty | String | beginner / intermediate / advanced |
| trailType | String | singletrack / fire-road / technical |
| direction | String | loop / out-and-back / one-way |
| features | [String] | Tags: jumps, drops, berms, rock-garden, bridge, roots, etc. |
| routeCoordinates | [GeoPoint] | GPS track from recording |
| distanceMiles | Double | Auto-calculated from GPS |
| parkId | String | Reference to Park document |
| photoURLs | [String] | Optional photos |
| conditionReport | String? | dry / muddy / flooded / damaged |
| conditionDate | Date? | When condition was last reported |
| status | String | draft / published |
| verificationCount | Int | Number of unique rider confirmations |
| isVerified | Bool | true when verificationCount >= 3 |
| flagCount | Int | Number of problem reports |
| createdAt | Date | |
| updatedAt | Date | |

### Park

Firestore collection: `parks`

| Field | Type | Description |
|-------|------|-------------|
| id | String (DocumentID) | Auto-generated |
| name | String | Park name |
| centerLatitude | Double | Center of park |
| centerLongitude | Double | Center of park |
| radiusMeters | Double | Bounding radius for auto-detection |
| maintainerIds | [String] | UIDs of park maintainers |
| trailCount | Int | Denormalized count |
| createdBy | String | UID of first creator |
| createdAt | Date | |

### TrailEdit

Firestore subcollection: `communityTrails/{trailId}/edits`

| Field | Type | Description |
|-------|------|-------------|
| id | String (DocumentID) | Auto-generated |
| proposerId | String | UID of person suggesting the edit |
| proposerUsername | String | Denormalized |
| changes | Map<String, Any> | Field name -> proposed new value |
| status | String | pending / approved / rejected |
| reviewedBy | String? | UID of approver/rejecter |
| createdAt | Date | |

### TrailConfirmation

Firestore subcollection: `communityTrails/{trailId}/confirmations`

| Field | Type | Description |
|-------|------|-------------|
| userId | String | Document ID = userId (prevents duplicates) |
| confirmedAt | Date | |

---

## User Flows

### Recording a Trail

1. User taps "+" button on the Trails tab
2. "Map a Trail" screen opens — full-screen map with GPS tracking
3. Live route drawn on map as they ride (green polyline)
4. Timer shows elapsed time, distance auto-calculated
5. User taps "Finish Recording" when done
6. Trail auto-saves as draft with GPS coordinates, distance, and timestamp
7. App shows: "Trail saved as draft. Name it and publish when ready."

### Editing and Publishing a Draft

1. Trails tab shows persistent banner: "You have X unpublished trails"
2. Tap banner -> list of drafts with route preview map thumbnails
3. Tap a draft -> edit form:
   - Name (required, text field)
   - Difficulty (segmented picker: Beginner / Intermediate / Advanced)
   - Trail Type (picker: Singletrack / Fire Road / Technical)
   - Direction (picker: Loop / Out-and-back / One-way)
   - Features (multi-select chips: Jumps, Drops, Berms, Rock Garden, Bridge, Roots, Wooden Features)
   - Description (text field, optional)
   - Condition (picker: Dry / Muddy / Flooded / Damaged)
   - Photos (photo picker, optional)
   - Park (auto-detected, editable text field)
4. "Publish Trail" button (disabled until name is filled)
5. "Delete Draft" button (destructive style)

### Park Auto-Detection

1. On draft save, calculate center coordinate of the recorded route
2. Query `parks` collection for parks where center is within `radiusMeters`
3. If match found -> auto-assign `parkId`
4. If no match -> on publish, prompt: "What park or area is this trail in?"
5. User names the park -> new Park document created with route bounding box as radius
6. User can always override the auto-detected park in the edit form

### Discovering Community Trails

1. Trails tab shows two sections:
   - "Featured Trails" (curated: Amelia Earhart, Virginia Key)
   - "Community Trails" (user-created, sorted by nearest / newest / most verified)
2. Map view shows all published trails with difficulty-colored routes
3. Tap a trail -> CommunityTrailDetailView:
   - Route on map
   - Stats (distance, difficulty, type, direction)
   - Features tags
   - Creator name + verified badge (if applicable)
   - Condition report with date
   - Photos
   - "Confirm Trail" button
   - "Suggest Edit" button
   - "Export GPX" button

### Verifying a Trail

1. On CommunityTrailDetailView, tap "Confirm Trail"
2. Creates a document in `confirmations` subcollection with userId as document ID
3. Increments `verificationCount` on the trail
4. If count reaches 3, set `isVerified = true`
5. Button changes to "Confirmed" (disabled) if user already confirmed
6. Verified trails show a checkmark badge and rank higher in search/browse

### Suggesting an Edit

1. On CommunityTrailDetailView, tap "Suggest Edit"
2. Opens SuggestEditView — form pre-filled with current trail values
3. User modifies fields they think are wrong
4. Only changed fields are stored in the `TrailEdit.changes` map
5. Route GPS is NOT editable (if route is wrong, record a new trail)
6. Submit creates a TrailEdit document with status: pending

### Approving/Rejecting Edits

1. Creator sees badge on Profile tab: "X pending edits"
2. Tap -> PendingEditsView shows each suggestion as a diff:
   - "Difficulty: Intermediate -> Advanced" (proposed by @username)
   - Approve / Reject buttons per edit
3. Approve: Firestore batch write updates the trail fields + marks edit as approved
4. Reject: marks edit as rejected
5. If creator hasn't opened the app in 14+ days, park maintainers can approve edits for trails in their park

### Becoming a Maintainer

1. After a user publishes their 3rd trail in the same park, the app prompts:
   "You're the top contributor at [Park Name]. Want to become a trail maintainer?"
2. Accept -> userId added to park's `maintainerIds` array
3. Maintainers see a "Maintainer" badge on their profile for that park
4. Maintainers can approve pending edits for any trail in their park

---

## Architecture

### New Files

```
Models/
  CommunityTrail.swift         — Codable model
  Park.swift                   — Codable model
  TrailEdit.swift              — Codable model

Services/
  CommunityTrailService.swift  — CRUD for trails, parks, edits, confirmations

ViewModels/
  TrailCreatorViewModel.swift  — GPS recording, draft management, publish flow
  CommunityTrailsViewModel.swift — browse, search, verify, suggest edits

Views/Trails/
  TrailCreatorView.swift       — recording screen (full-screen map + GPS)
  TrailDraftListView.swift     — list of unpublished drafts
  TrailDraftEditView.swift     — form to name/categorize/publish a draft
  CommunityTrailDetailView.swift — public trail detail + verify/edit
  SuggestEditView.swift        — edit suggestion form
  PendingEditsView.swift       — creator/maintainer approval queue
```

### Modified Files

```
Views/Trails/TrailsView.swift  — add "+" button, community trails section, drafts banner
```

### Removed Files

```
ViewModels/TrailMapperViewModel.swift  — replaced by TrailCreatorViewModel
Views/Ride/TrailMapperView.swift       — replaced by TrailCreatorView
```

The Trail Mapper button in RideView (`#if DEBUG` block) is also removed since the Trail Creator is now a production feature accessible from the Trails tab.

### Reused

- `LocationService.swift` — GPS recording (no changes)
- `GPXExporter.swift` — optional GPX export of community trails (no changes)

---

## Firestore Indexes

Required composite indexes:
- `communityTrails`: `parkId` + `status` + `createdAt` (browse by park)
- `communityTrails`: `status` + `verificationCount` (sort by most verified)
- `communityTrails`: `creatorId` + `status` (user's drafts/published trails)
- `communityTrails/{id}/edits`: `status` + `createdAt` (pending edits queue)

---

## Seeding

On first launch (or via a migration check), create Park documents for:
- Amelia Earhart Park: center 25.8844, -80.2789, radius 800m
- Virginia Key North Point: center 25.7430, -80.1540, radius 1000m

These seed parks ensure auto-detection works immediately for Miami riders.

---

## Error Handling

- GPS recording fails: show "Unable to get GPS signal" and prevent saving empty trails
- Firestore write fails on publish: keep as draft, show error, user can retry
- Photo upload fails: publish trail without photos, show warning
- Park detection finds no match: prompt user to name the area (required before publish)
- Duplicate confirmation attempt: silently no-op (Firestore document ID = userId prevents it)

---

## Out of Scope (Phase 2+)

- Trail segment timing / leaderboards
- Trail favorites / bookmarks
- Trail condition history graph
- Offline trail creation (requires local-first storage)
- Trail merging (combining similar recordings into one canonical trail)
- Push notifications for edit approvals
- Photo moderation
- Trail difficulty voting (separate from verification)
