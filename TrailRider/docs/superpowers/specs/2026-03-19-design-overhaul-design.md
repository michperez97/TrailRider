# TrailRider Design Overhaul — "Rugged Earth"

**Date:** 2026-03-19
**Status:** Approved

## Overview

Comprehensive visual overhaul of the TrailRider mountain bike app. Replaces the current stock SwiftUI aesthetic (plain `.green` accent, `.ultraThinMaterial` backgrounds) with a cohesive "Rugged Earth" design system: dark forest-tinted backgrounds, earthy natural tones, tactile depth through layered shadows, and full animation polish.

**Minimum deployment target:** iOS 17+ (required for `@Observable`, `contentTransition`, `symbolEffect`)

## Approach

Design System First — build a `TrailRiderTheme` with colors, typography, card styles, button styles, and animation primitives as reusable SwiftUI components, then re-skin every screen against it.

## 1. Color Palette

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| Base | Dark forest black | `#111A12` | App background, deepest layer |
| Surface | Forest card | `#1E3322` | Cards, elevated surfaces |
| Surface Border | Moss edge | `#2A4A2E` | Card borders, dividers |
| Primary | Trail green | `#52B788` | CTAs, active states, route lines, tab selection |
| Accent | Warm amber | `#D4A574` | Secondary highlights, branding, labels |
| Alert/Destructive | Terracotta | `#E07A5F` | Stop button, errors, destructive actions |
| Warning | Golden dust | `#E9C46A` | Paused states, caution |
| Text Primary | Bone white | `#E8E0D8` | Headlines, stat values |
| Text Secondary | Faded sage | `#6A8A6A` | Captions, labels, supporting text |
| Text Tertiary | Deep moss | `#3A5A3C` | Disabled, hint text |
| Badge Dark | Charcoal | `#2C2C2E` | Black Diamond difficulty badge (visible on dark backgrounds, paired with bone white text) |

## 2. Typography Scale

| Style | Font | Usage |
|-------|------|-------|
| Stat display | `.system(size: 72, weight: .bold, design: .rounded)` | Speed, big numbers |
| Section header | `.title2.bold()` | Screen section titles |
| Card title | `.subheadline.bold()` | Trail names, friend names |
| Label | `.caption.bold()` + uppercase + letter spacing | "STREAK", "MILES", "MPH" |
| Body | `.subheadline` | Descriptions, trail details |
| Fine print | `.caption2` | Timestamps, meta info |

## 3. Card System — Stacked & Tactile

All cards share:
- Background: top-to-bottom gradient from Surface to slightly darker
- Top border: 1px lighter `#2A4A2E` for lit-edge effect
- Shadow stack: `0 2px` + `0 4px` solid shadow ledges + soft ambient shadow
- Corner radius: 16pt cards, 14pt buttons, 12pt icon containers
- Inner glow: subtle radial gradient in top-right corner matching the card's accent color

## 4. Component Library

### Buttons

| Style | Look | Usage |
|-------|------|-------|
| Primary | Solid trail green gradient, top highlight sheen, shadow ledges, 16pt radius | Start Ride, Let's Ride, Get Directions, Send Friend Request — main CTAs |
| Secondary | Outlined with amber border, transparent fill, 14pt radius | View Trail Map — navigation-style secondary actions |
| Ghost | Surface background with moss border, subtle shadow | Create/Join group ride tiles |
| Destructive | Terracotta fill with dark shadow ledges | Stop ride, Sign Out, End Session |
| Warning | Golden dust (`#E9C46A`) fill | Pause button during active ride |

All buttons: `.scaleEffect(isPressed ? 0.96 : 1.0)` press animation with `.spring(response: 0.3, dampingFraction: 0.7)`.

### Stat Cards

- **Compact:** icon + value + label, used in Home/Summary/History/Detail grids
- **Live:** large value + unit, used in ActiveRideView
- Values use `.monospacedDigit()` for stable layout during live updates
- Each card gets subtle inner glow matching its accent color
- `RideSummaryView` and `RideDetailView` share the same compact stat card component (consolidate `SummaryStatCard` and `DetailStatCard` into one)

### Trail Cards

- Left icon container: gradient surface with inset shadow, 12pt radius
- Right chevron: trail green
- Condition dot: green/amber/terracotta based on trail status
- Difficulty badges: capsule pills — green (Beginner), blue (Intermediate), charcoal `#2C2C2E` with bone white text (Advanced/Black Diamond), terracotta (Double Black)

### Trail Condition Rows (HomeView)

- Full tactile card treatment: surface gradient background, top border, shadow stack
- Pulsing condition dot (opacity 0.6 → 1.0, looping)
- Trail name in bone white, condition text in faded sage

### User/Friend Rows

- Same tactile card treatment as trail cards
- Avatar: `person.circle.fill` in trail green on gradient icon container
- Accept/decline: green checkmark / terracotta X with scale press feedback

### Text Fields

- Dark forest background with moss border, bone white text, faded sage placeholder
- Replaces `.roundedBorder` style across OnboardingView, AddFriendView, JoinSessionSheet
- Search button: trail green background with bone white icon, 12pt radius

### Navigation & Tab Bar

- Tab bar tint: trail green selected, faded sage unselected
- Navigation titles: bone white on dark forest background
- Section headers: amber accent color

### Empty States & Messages

- `ContentUnavailableView`: themed with faded sage icon and text on dark forest background
- Success messages: trail green text
- Error messages: terracotta text

## 5. Animations & Micro-interactions

### Screen Transitions

- Tab switches: default SwiftUI tab animation
- Navigation pushes: `.transition(.move(edge: .trailing))` with `.spring(response: 0.4, dampingFraction: 0.85)`
- Sheets/modals: slightly overdamped spring
- Auth state changes: `.easeInOut(duration: 0.5)` crossfade

### Ride Experience

- Speed counter: apply `contentTransition(.numericText())` to the `Text` view, paired with `.animation(.default, value: rideVM.formattedSpeed)` to trigger digit-roll on value change
- Stats (distance, elevation, duration): same `contentTransition(.numericText())` + `.animation(.default, value:)` pairing on each `StatColumn` `Text`
- Route polyline: progressive draw with `.trim(from:to:)` animation
- Ride state changes: refactor pause/play into a single `Image(systemName: rideVM.rideState == .riding ? "pause.fill" : "play.fill")` with `.contentTransition(.symbolEffect(.replace))` for smooth symbol morphing. Button background animates between golden dust (pause) and trail green (play).
- Milestone pulse: at round numbers (5 mi, 10 mi), stat value `scaleEffect` pulse (1.0 → 1.15 → 1.0) with green glow flash

### Micro-interactions

- Button press: `.scaleEffect(isPressed ? 0.96 : 1.0)` with `.spring(response: 0.3, dampingFraction: 0.7)`
- Card tap: same scale press + shadow reduction (10px → 4px)
- Loading states: shimmer effect (gradient sweep) on placeholder cards instead of plain `ProgressView` — applies to RideHistory, Friends, and AddFriend search
- Session code (GroupRideLobbyView): staggered `.opacity` + `.offset` digit drop-in
- Code entry (JoinSessionSheet): digits scale in as typed
- Tab bar icons: `.symbolEffect(.bounce)` on selection
- Trail condition dot: gentle pulse animation (opacity 0.6 → 1.0, looping)

### Entrance Animations

- Home stat cards: stagger in with `.offset(y: 20)` + `.opacity(0)`, 0.1s delay between each
- Trail list cards: same stagger pattern
- Ride summary/detail stats: cards fan in from bottom with staggered spring

## 6. Screen-by-Screen Application

### SignInView
- Dark forest background fills entire screen
- Amber bicycle icon (80pt) with subtle floating animation (gentle y-offset loop)
- Split-color logo: "TRAIL" in bone white + "RIDER" in trail green
- Tagline in faded sage
- Sign In with Apple button stays native, sits on themed background

### OnboardingView
- Dark forest background, "Set Up Your Profile" heading in bone white
- Text fields: themed style (dark forest fill, moss border, bone white text)
- "Let's Ride" CTA: primary green button style
- Error text: terracotta
- Submitting state: shimmer placeholder on button instead of plain ProgressView

### HomeView
- Bone white greeting, dark forest nav background
- "Start a Ride" CTA: primary green button style
- Stat cards: compact variant in 2-column layout with staggered entrance
- Trail condition rows: full tactile card treatment with pulsing condition dots
- Section headers ("Your Stats", "Trail Conditions"): amber accent color

### PreRideView
- Amber bicycle icon, "Ready to Ride?" in bone white
- "Start Solo Ride": primary green CTA
- Create/Join tiles: ghost button style
- Error text: terracotta

### JoinSessionSheet
- Dark forest background, "Enter the 6-digit session code" in faded sage
- Code input: themed text field, large monospaced digits in trail green
- "Join Ride" CTA: primary green button style
- Digits scale-in animation as typed

### ActiveRideView
- Map: `.standard(elevation: .realistic)` — keeps the map readable behind the speed/stats overlay; hybrid would be too visually busy during an active ride
- Speed display: numeric text content transition with animation
- Bottom stats panel: tactile card (surface gradient + shadow ledges) with blur over map
- Pause/Play: single Image view with `.contentTransition(.symbolEffect(.replace))`, golden dust background (pause state) / trail green background (riding state)
- Stop: terracotta destructive button

### RideSummaryView
- Green polyline on standard map style
- Stats grid: compact stat cards (shared component) with inner glow, staggered entrance
- "Done": primary green button style

### TrailsView
- Map: `.standard(elevation: .realistic)` style (keeps the overview map lighter for readability)
- Trail list cards: full tactile card treatment with staggered entrance

### TrailCardView (Trail Detail)
- Map: `.standard(elevation: .realistic)` for the embedded detail map
- Route filter chips: trail green fill when selected, surface + moss border when unselected
- Difficulty badges: themed capsule pills (green/blue/charcoal/terracotta)
- Detail rows: green icon tint
- "View Trail Map": secondary button (amber outline)
- "Get Directions": primary button (trail green)

### TrailMapView
- Full-screen map: `.hybrid(elevation: .realistic)` — satellite view for immersive exploration
- Route legend panel: tactile card treatment (surface gradient + shadow ledges, replaces `.ultraThinMaterial`)
- Route color swatches and difficulty labels: themed
- Toggle button: ghost style (surface + moss border circle)

### SocialView
- Friend rows: tactile card style with trail green avatars
- Friend request accept/decline: green/terracotta with scale press feedback
- Empty state: themed `ContentUnavailableView`
- Add friend toolbar button: amber tinted

### AddFriendView
- Dark forest background
- "Find a rider" heading: bone white
- Search field: themed text field style + trail green search icon button
- Search spinner: shimmer placeholder instead of plain ProgressView
- Result card: tactile card with trail green avatar, bone white name, faded sage username/stats
- "Send Friend Request": primary green CTA
- Success message: trail green, error message: terracotta

### RideHistoryView
- Dark forest list background
- Ride rows: tactile card style — date in bone white, time in faded sage, distance in bone white bold, duration in faded sage
- Empty state: themed `ContentUnavailableView`
- Swipe-to-delete: terracotta tint
- Loading: shimmer placeholders

### RideDetailView
- Green polyline on standard map
- Date/time header: bone white date, faded sage time
- Stats grid: same shared compact stat card component as RideSummaryView, with staggered entrance

### ProfileView
- Large amber avatar icon
- User info: bone white display name, faded sage username
- Stats section: compact stat cards instead of plain `LabeledContent`
- Navigation rows (Ride History, My Bikes): tactile card style
- Sign Out: terracotta destructive button

### GroupRideLobbyView
- Session code: large monospaced digits in trail green with staggered drop-in animation
- "Copy Code": ghost button style
- Member rows: tactile cards with trail green avatars, green ready checkmark
- "Start Group Ride" / "Ready Up": primary green CTA
- "End/Leave Session": terracotta text button
