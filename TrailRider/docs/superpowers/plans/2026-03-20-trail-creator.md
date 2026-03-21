# Trail Creator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a community-driven trail creation system where riders record trails by riding, publish to a shared database, and other riders discover, verify, and suggest edits.

**Architecture:** 3 new Codable models (CommunityTrail, Park, TrailEdit), 1 Firestore service (CommunityTrailService), 2 ViewModels (TrailCreatorViewModel for recording/drafts, CommunityTrailsViewModel for browsing/verification/edits), 6 new Views. Replaces the `#if DEBUG` Trail Mapper with a production feature on the Trails tab.

**Tech Stack:** SwiftUI, MapKit, Firebase Firestore, CoreLocation (via existing LocationService)

**Spec:** `docs/superpowers/specs/2026-03-20-trail-creator-design.md`

---

## File Structure

### New Files
```
TrailRider/Models/CommunityTrail.swift       — Codable model with enums for difficulty, type, direction, features
TrailRider/Models/Park.swift                  — Codable model for parks with geo center + radius
TrailRider/Models/TrailEdit.swift             — Codable model for edit suggestions + TrailConfirmation
TrailRider/Services/CommunityTrailService.swift — All Firestore CRUD: trails, parks, edits, confirmations
TrailRider/ViewModels/TrailCreatorViewModel.swift — GPS recording session, draft CRUD, publish, park detection
TrailRider/ViewModels/CommunityTrailsViewModel.swift — Browse, verify, suggest edits, pending edits
TrailRider/Views/Trails/TrailCreatorView.swift    — Full-screen map GPS recording
TrailRider/Views/Trails/TrailDraftListView.swift  — List of user's unpublished drafts
TrailRider/Views/Trails/TrailDraftEditView.swift  — Form to name/categorize/publish a draft
TrailRider/Views/Trails/CommunityTrailDetailView.swift — Public trail detail with verify/edit
TrailRider/Views/Trails/SuggestEditView.swift     — Edit suggestion form
TrailRider/Views/Trails/PendingEditsView.swift    — Creator/maintainer approval queue
```

### Modified Files
```
TrailRider/Views/Trails/TrailsView.swift      — Add "+" button, community trails section, drafts banner
TrailRider/Views/Ride/RideView.swift          — Remove #if DEBUG TrailMapper button
TrailRider/Views/Profile/ProfileView.swift    — Add pending edits badge
```

### Removed Files
```
TrailRider/ViewModels/TrailMapperViewModel.swift  — Replaced by TrailCreatorViewModel
TrailRider/Views/Ride/TrailMapperView.swift       — Replaced by TrailCreatorView
```

---

### Task 1: Data Models

**Files:**
- Create: `TrailRider/Models/CommunityTrail.swift`
- Create: `TrailRider/Models/Park.swift`
- Create: `TrailRider/Models/TrailEdit.swift`

- [ ] **Step 1: Create CommunityTrail model**

```swift
import Foundation
import FirebaseFirestore

struct CommunityTrail: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var creatorId: String
    var creatorUsername: String
    var name: String
    var description: String
    var difficulty: Difficulty
    var trailType: TrailType
    var direction: Direction
    var features: [String]
    var routeCoordinates: [GeoPoint]
    var distanceMiles: Double
    var parkId: String?
    var photoURLs: [String]
    var conditionReport: ConditionReport?
    var conditionDate: Date?
    var status: Status
    var verificationCount: Int
    var isVerified: Bool
    var flagCount: Int
    var createdAt: Date
    var updatedAt: Date

    enum Difficulty: String, Codable, Sendable, CaseIterable {
        case beginner, intermediate, advanced
    }

    enum TrailType: String, Codable, Sendable, CaseIterable {
        case singletrack, fireRoad = "fire-road", technical
    }

    enum Direction: String, Codable, Sendable, CaseIterable {
        case loop, outAndBack = "out-and-back", oneWay = "one-way"
    }

    enum ConditionReport: String, Codable, Sendable, CaseIterable {
        case dry, muddy, flooded, damaged
    }

    enum Status: String, Codable, Sendable {
        case draft, published
    }

    static let featureOptions = [
        "Jumps", "Drops", "Berms", "Rock Garden",
        "Bridge", "Roots", "Wooden Features"
    ]
}
```

- [ ] **Step 2: Create Park model**

```swift
import Foundation
import FirebaseFirestore

struct Park: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var name: String
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double
    var maintainerIds: [String]
    var trailCount: Int
    var createdBy: String
    var createdAt: Date
}
```

- [ ] **Step 3: Create TrailEdit and TrailConfirmation models**

```swift
import Foundation
import FirebaseFirestore

struct TrailEdit: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var proposerId: String
    var proposerUsername: String
    var changes: [String: String]  // field name -> new value (String-typed for Codable simplicity)
    var status: Status
    var reviewedBy: String?
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case pending, approved, rejected
    }
}

struct TrailConfirmation: Codable, Sendable {
    var userId: String
    var confirmedAt: Date
}
```

- [ ] **Step 4: Build to verify models compile**

Run: `xcodebuild -project TrailRider.xcodeproj -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"`
Expected: BUILD SUCCEEDED

---

### Task 2: CommunityTrailService

**Files:**
- Create: `TrailRider/Services/CommunityTrailService.swift`

- [ ] **Step 1: Create the service with trail CRUD**

Singleton service following existing pattern (`final class`, `Sendable`, computed `db` property). Methods:
- `saveDraft(_ trail: CommunityTrail) async throws -> String`
- `publishTrail(id: String) async throws`
- `getDrafts(userId: String) async throws -> [CommunityTrail]`
- `getPublishedTrails(parkId: String) async throws -> [CommunityTrail]`
- `getAllPublishedTrails() async throws -> [CommunityTrail]`
- `getTrail(id: String) async throws -> CommunityTrail?`
- `updateTrail(id: String, fields: [String: Any]) async throws`
- `deleteDraft(id: String) async throws`

- [ ] **Step 2: Add park methods**

- `getParks() async throws -> [Park]`
- `findPark(latitude: Double, longitude: Double) async throws -> Park?` — queries all parks, calculates distance to center, returns first within radius
- `createPark(_ park: Park) async throws -> String`
- `addMaintainer(parkId: String, userId: String) async throws`
- `getUserTrailCount(userId: String, parkId: String) async throws -> Int`

- [ ] **Step 3: Add verification and edit methods**

- `confirmTrail(trailId: String, userId: String) async throws` — creates confirmation doc, increments count, sets isVerified if >= 3 (batch write)
- `hasConfirmed(trailId: String, userId: String) async throws -> Bool`
- `submitEdit(_ edit: TrailEdit, trailId: String) async throws`
- `getPendingEdits(trailId: String) async throws -> [TrailEdit]`
- `getPendingEditsForCreator(userId: String) async throws -> [(CommunityTrail, [TrailEdit])]` — gets all trails by creator that have pending edits
- `approveEdit(trailId: String, editId: String, changes: [String: String], reviewerId: String) async throws` — batch: update trail fields + mark edit approved
- `rejectEdit(trailId: String, editId: String, reviewerId: String) async throws`

- [ ] **Step 4: Add park seeding method**

```swift
func seedMiamiParks() async throws {
    let parks = try await getParks()
    guard parks.isEmpty else { return }  // already seeded

    let amelia = Park(name: "Amelia Earhart Park", centerLatitude: 25.8844, centerLongitude: -80.2789, radiusMeters: 800, maintainerIds: [], trailCount: 0, createdBy: "system", createdAt: Date())
    let virginiaKey = Park(name: "Virginia Key North Point", centerLatitude: 25.7430, centerLongitude: -80.1540, radiusMeters: 1000, maintainerIds: [], trailCount: 0, createdBy: "system", createdAt: Date())

    _ = try await createPark(amelia)
    _ = try await createPark(virginiaKey)
}
```

- [ ] **Step 5: Build to verify**

---

### Task 3: TrailCreatorViewModel

**Files:**
- Create: `TrailRider/ViewModels/TrailCreatorViewModel.swift`
- Remove: `TrailRider/ViewModels/TrailMapperViewModel.swift`

- [ ] **Step 1: Create TrailCreatorViewModel**

`@Observable @MainActor` class. Evolves from TrailMapperViewModel but saves to Firestore instead of GPX. States: `.idle`, `.recording`, `.saving`. Uses LocationService for GPS. Key methods:
- `startRecording()` — requests location permission, starts GPS, starts timer
- `stopRecording(userId: String, username: String) async` — calculates distance, detects park, saves draft to Firestore
- `loadDrafts(userId: String) async` — fetches user's drafts
- `publishDraft(_ trail: CommunityTrail, parkName: String?) async` — publishes, creates park if needed
- `deleteDraft(_ trail: CommunityTrail) async`

Properties: `recordingState`, `routeCoordinates`, `elapsedSeconds`, `distanceMiles`, `drafts`, `isLoading`, `errorMessage`, `detectedPark`

Timer uses `RunLoop.main.add(t, forMode: .common)` pattern. Distance calculated same as RideViewModel (delta > 2m filter).

- [ ] **Step 2: Delete TrailMapperViewModel.swift**

- [ ] **Step 3: Build to verify**

---

### Task 4: CommunityTrailsViewModel

**Files:**
- Create: `TrailRider/ViewModels/CommunityTrailsViewModel.swift`

- [ ] **Step 1: Create CommunityTrailsViewModel**

`@Observable @MainActor` class. Manages browsing, verification, and edit suggestions. Key methods:
- `loadTrails(parkId: String?) async` — loads published community trails
- `loadAllTrails() async` — loads all published trails
- `confirmTrail(_ trail: CommunityTrail, userId: String) async`
- `checkConfirmation(_ trail: CommunityTrail, userId: String) async`
- `submitEdit(_ edit: TrailEdit, trailId: String) async`
- `loadPendingEdits(userId: String) async` — loads all edits pending for trails the user created
- `approveEdit(trailId: String, edit: TrailEdit) async`
- `rejectEdit(trailId: String, edit: TrailEdit) async`
- `checkMaintainerEligibility(userId: String, parkId: String) async` — checks if user has 3+ trails in park

Properties: `communityTrails`, `pendingEdits`, `hasConfirmed`, `isLoading`, `errorMessage`

- [ ] **Step 2: Build to verify**

---

### Task 5: TrailCreatorView (Recording Screen)

**Files:**
- Create: `TrailRider/Views/Trails/TrailCreatorView.swift`
- Remove: `TrailRider/Views/Ride/TrailMapperView.swift`

- [ ] **Step 1: Create TrailCreatorView**

Full-screen map with:
- `Map` showing `UserAnnotation` + live `MapPolyline` (green, `.trPrimary`)
- Top bar: elapsed time + distance (`.ultraThinMaterial` background)
- Bottom: large "Finish Recording" button when recording
- "Start Recording" button when idle
- Uses `TrailCreatorViewModel` via `@State`
- Hides tab bar (`.toolbar(.hidden, for: .tabBar)`)
- On finish: shows confirmation toast "Trail saved as draft"

Follow existing `ActiveRideView` patterns for map styling and stat display.

- [ ] **Step 2: Delete TrailMapperView.swift**

- [ ] **Step 3: Build to verify**

---

### Task 6: TrailDraftListView + TrailDraftEditView

**Files:**
- Create: `TrailRider/Views/Trails/TrailDraftListView.swift`
- Create: `TrailRider/Views/Trails/TrailDraftEditView.swift`

- [ ] **Step 1: Create TrailDraftListView**

List of user's unpublished drafts:
- Each row shows: small route map preview, distance, date recorded
- Tap → NavigationLink to `TrailDraftEditView`
- Swipe to delete
- Empty state: "No drafts — go record a trail!"

- [ ] **Step 2: Create TrailDraftEditView**

Form to edit and publish a draft:
- Route map at top (250h, non-interactive)
- Auto-calculated stats (distance, date)
- Name field (ThemedTextField, required)
- Difficulty picker (segmented: Beginner/Intermediate/Advanced)
- Trail Type picker (Singletrack/Fire Road/Technical)
- Direction picker (Loop/Out-and-back/One-way)
- Features multi-select (scrollable chip grid, toggleable)
- Description text field
- Condition picker
- Park (auto-detected label, editable text field if no match)
- "Publish Trail" button (`.trailPrimary`, disabled if no name)
- "Delete Draft" button (`.trailDestructive`)

Uses existing Theme components (ThemedTextField, tactileCard, TrailButton styles).

- [ ] **Step 3: Build to verify**

---

### Task 7: CommunityTrailDetailView

**Files:**
- Create: `TrailRider/Views/Trails/CommunityTrailDetailView.swift`

- [ ] **Step 1: Create CommunityTrailDetailView**

Scrollable detail view for a published community trail:
- Route map (280h) with difficulty-colored polyline
- Trail name, creator username, verified badge (checkmark if `isVerified`)
- Stats row: distance, difficulty badge, type, direction
- Feature tags (horizontal scroll of capsules)
- Condition report with date
- Photos (horizontal scroll if any)
- "Confirm Trail" button (disabled if already confirmed, shows count)
- "Suggest Edit" button → NavigationLink to SuggestEditView
- "Export GPX" button → uses existing GPXExporter

Follow existing `TrailCardView` patterns for layout and theme.

- [ ] **Step 2: Build to verify**

---

### Task 8: SuggestEditView + PendingEditsView

**Files:**
- Create: `TrailRider/Views/Trails/SuggestEditView.swift`
- Create: `TrailRider/Views/Trails/PendingEditsView.swift`

- [ ] **Step 1: Create SuggestEditView**

Form pre-filled with current trail values. Same fields as TrailDraftEditView but:
- Route map is display-only (no editing GPS)
- On submit, only changed fields are saved to TrailEdit.changes map
- Compare each field to original, only include diffs
- Submit button: "Submit Suggestion"

- [ ] **Step 2: Create PendingEditsView**

List of pending edit suggestions for trails the user created:
- Grouped by trail name
- Each edit shows: proposer username, diff (old → new for each changed field)
- Approve / Reject buttons per edit
- Uses CommunityTrailsViewModel methods

- [ ] **Step 3: Build to verify**

---

### Task 9: Wire Into TrailsView + Remove Old TrailMapper

**Files:**
- Modify: `TrailRider/Views/Trails/TrailsView.swift`
- Modify: `TrailRider/Views/Ride/RideView.swift`
- Modify: `TrailRider/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Update TrailsView**

Add to TrailsView:
- "+" toolbar button → NavigationLink to TrailCreatorView
- Drafts banner at top: "You have X unpublished trails" → NavigationLink to TrailDraftListView (only shown when drafts > 0)
- "Community Trails" section below "Featured Trails" with list of CommunityTrailListCards
- Each community trail card → NavigationLink to CommunityTrailDetailView
- Map shows both featured trail markers and community trail markers

- [ ] **Step 2: Remove TrailMapper from RideView**

Remove the `#if DEBUG` NavigationLink block for TrailMapperView (lines 129-130 area in RideView.swift).

- [ ] **Step 3: Add pending edits badge to ProfileView**

Add a NavigationLink showing "X Pending Edits" with a badge count, linking to PendingEditsView. Only visible when the user has created trails with pending suggestions.

- [ ] **Step 4: Call seedMiamiParks on app launch**

In `TrailRiderApp.swift` AppDelegate's `didFinishLaunchingWithOptions`, add:
```swift
Task { try? await CommunityTrailService.shared.seedMiamiParks() }
```

- [ ] **Step 5: Build both targets (iOS + Watch)**

Run: `xcodebuild -project TrailRider.xcodeproj -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Launch on simulator and verify**

- Install and launch on iPhone simulator
- Verify Trails tab shows "+" button
- Verify Featured Trails still display
- Verify no references to TrailMapperView remain
