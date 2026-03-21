# Rugged Earth Design Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace TrailRider's stock SwiftUI aesthetic with the "Rugged Earth" design system — dark forest backgrounds, earthy tones, tactile depth, and animation polish across all 15+ views.

**Architecture:** Design System First. Build a theme layer (colors, reusable view modifiers, components) in `TrailRider/Theme/`, then systematically re-skin each screen against it. Components are SwiftUI `ViewModifier`s and standalone `View` structs.

**Tech Stack:** SwiftUI (iOS 17+), MapKit, SF Symbols. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-03-19-design-overhaul-design.md`

**Working directory:** All commands assume CWD is the project root containing `TrailRider.xcodeproj`. All `git add` paths are relative to this root. Build command: `xcodebuild -project TrailRider.xcodeproj -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

---

## File Structure

### New Files (Theme Layer)

| File | Responsibility |
|------|---------------|
| `TrailRider/Theme/ThemeColors.swift` | `Color` extension with all palette colors as static properties |
| `TrailRider/Theme/TactileCard.swift` | `ViewModifier` for the stacked & tactile card treatment |
| `TrailRider/Theme/TrailButton.swift` | 5 `ButtonStyle` variants (primary, secondary, ghost, destructive, warning) with press animation |
| `TrailRider/Theme/ThemeTextField.swift` | Custom `View` wrapper for dark forest themed text inputs |
| `TrailRider/Theme/ThemeStatCard.swift` | Shared `StatCard` component (compact + live variants, replaces `SummaryStatCard`/`DetailStatCard`/old `StatCard`) |
| `TrailRider/Theme/ShimmerView.swift` | Shimmer loading placeholder view |
| `TrailRider/Theme/AnimationModifiers.swift` | `ViewModifier`s for staggered entrance, pulse, and press feedback |

### Modified Files (All Views)

| File | Changes |
|------|---------|
| `App/RootView.swift` | Dark forest background, themed loading state |
| `App/MainTabView.swift` | Trail green/faded sage tab bar tint, `.symbolEffect(.bounce)` |
| `Views/Auth/SignInView.swift` | Dark forest BG, amber icon, split-color logo, floating animation |
| `Views/Auth/OnboardingView.swift` | Themed text fields, primary button, terracotta errors |
| `Views/Home/HomeView.swift` | Amber section headers, themed stat cards, tactile condition rows, pulsing dots, staggered entrance |
| `Views/Ride/RideView.swift` | PreRideView: amber icon, primary/ghost buttons. JoinSessionSheet: themed field, scale-in digits |
| `Views/Ride/ActiveRideView.swift` | Numeric text transitions, refactored pause/play single Image, tactile stats panel, themed controls |
| `Views/Ride/RideSummaryView.swift` | Use shared `ThemeStatCard`, primary Done button, staggered entrance, remove `SummaryStatCard` |
| `Views/Ride/GroupRideLobbyView.swift` | Tactile member cards, staggered code digits, themed buttons |
| `Views/Trails/TrailsView.swift` | Tactile trail list cards, staggered entrance |
| `Views/Trails/TrailCardView.swift` | Themed badges (charcoal for black diamond), secondary/primary buttons, themed filter chips |
| `Views/Trails/TrailMapView.swift` | Tactile legend panel, ghost toggle button (replaces `.ultraThinMaterial`) |
| `Views/Social/SocialView.swift` | Tactile friend rows, themed accept/decline, amber toolbar, themed empty state |
| `Views/Social/AddFriendView.swift` | Themed search field, shimmer spinner, tactile result card, primary CTA |
| `Views/Profile/ProfileView.swift` | Amber avatar, stat cards, tactile nav rows, destructive sign out |
| `Views/Profile/RideHistoryView.swift` | Tactile ride rows, shimmer loading, themed empty state, terracotta delete |
| `Views/Profile/RideDetailView.swift` | Use shared `ThemeStatCard`, staggered entrance, remove `DetailStatCard` |

---

## Task 1: Theme Colors

**Files:**
- Create: `TrailRider/Theme/ThemeColors.swift`

- [ ] **Step 1: Create the Color extension**

```swift
import SwiftUI

extension Color {
    // MARK: - Rugged Earth Palette
    static let trBase = Color(red: 0x11/255, green: 0x1A/255, blue: 0x12/255)        // #111A12
    static let trSurface = Color(red: 0x1E/255, green: 0x33/255, blue: 0x22/255)     // #1E3322
    static let trSurfaceBorder = Color(red: 0x2A/255, green: 0x4A/255, blue: 0x2E/255) // #2A4A2E
    static let trPrimary = Color(red: 0x52/255, green: 0xB7/255, blue: 0x88/255)     // #52B788
    static let trAccent = Color(red: 0xD4/255, green: 0xA5/255, blue: 0x74/255)      // #D4A574
    static let trDestructive = Color(red: 0xE0/255, green: 0x7A/255, blue: 0x5F/255) // #E07A5F
    static let trWarning = Color(red: 0xE9/255, green: 0xC4/255, blue: 0x6A/255)     // #E9C46A
    static let trTextPrimary = Color(red: 0xE8/255, green: 0xE0/255, blue: 0xD8/255) // #E8E0D8
    static let trTextSecondary = Color(red: 0x6A/255, green: 0x8A/255, blue: 0x6A/255) // #6A8A6A
    static let trTextTertiary = Color(red: 0x3A/255, green: 0x5A/255, blue: 0x3C/255) // #3A5A3C
    static let trBadgeDark = Color(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255)   // #2C2C2E

    // Derived colors
    static let trSurfaceDarker = Color(red: 0x18/255, green: 0x2A/255, blue: 0x1C/255) // bottom of card gradient
    static let trSurfaceLighter = Color(red: 0x24/255, green: 0x3D/255, blue: 0x28/255) // top lit edge
    static let trPrimaryDarker = Color(red: 0x40/255, green: 0x91/255, blue: 0x6C/255) // button gradient bottom
}
```

- [ ] **Step 2: Add the file to Xcode project**

Open `TrailRider.xcodeproj` in Xcode and verify the file is included in the TrailRider target. If using folder references, it should auto-include. Otherwise, drag it into the project navigator under a new "Theme" group.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/Theme/ThemeColors.swift
git commit -m "feat: add Rugged Earth color palette"
```

---

## Task 2: Tactile Card Modifier

**Files:**
- Create: `TrailRider/Theme/TactileCard.swift`

- [ ] **Step 1: Create the TactileCard ViewModifier**

```swift
import SwiftUI

struct TactileCard: ViewModifier {
    var glowColor: Color = .trPrimary
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Card gradient
                    LinearGradient(
                        colors: [.trSurface, .trSurfaceDarker],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Inner glow
                    RadialGradient(
                        colors: [glowColor.opacity(0.08), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 120
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trSurfaceDarker, radius: 0, y: 2)
            .shadow(color: .trSurfaceDarker.opacity(0.8), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.35), radius: isPressed ? 4 : 10, y: isPressed ? 4 : 10)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

extension View {
    func tactileCard(glowColor: Color = .trPrimary, isPressed: Bool = false) -> some View {
        modifier(TactileCard(glowColor: glowColor, isPressed: isPressed))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrailRider/TrailRider/Theme/TactileCard.swift
git commit -m "feat: add TactileCard ViewModifier with stacked shadow depth"
```

---

## Task 3: Button Styles

**Files:**
- Create: `TrailRider/Theme/TrailButton.swift`

- [ ] **Step 1: Create all 5 button styles**

```swift
import SwiftUI

// MARK: - Primary Button (Trail Green)
struct TrailPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.trPrimary, .trPrimaryDarker],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Top sheen
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .trPrimaryDarker, radius: 0, y: 2)
            .shadow(color: .trPrimary.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Amber Outline)
struct TrailSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.trAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.trAccent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button (Surface + Moss Border)
struct TrailGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.trTextPrimary)
            .background(
                LinearGradient(
                    colors: [.trSurface, .trSurfaceDarker],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button (Terracotta)
struct TrailDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.trDestructive)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trDestructive.opacity(0.5), radius: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Warning Button (Golden Dust)
struct TrailWarningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.trBase)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.trWarning)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trWarning.opacity(0.4), radius: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Convenience extensions
extension ButtonStyle where Self == TrailPrimaryButtonStyle {
    static var trailPrimary: TrailPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailSecondaryButtonStyle {
    static var trailSecondary: TrailSecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailGhostButtonStyle {
    static var trailGhost: TrailGhostButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailDestructiveButtonStyle {
    static var trailDestructive: TrailDestructiveButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailWarningButtonStyle {
    static var trailWarning: TrailWarningButtonStyle { .init() }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrailRider/TrailRider/Theme/TrailButton.swift
git commit -m "feat: add 5 themed button styles (primary, secondary, ghost, destructive, warning)"
```

---

## Task 4: Themed Text Field, Stat Card, Shimmer & Animation Modifiers

**Files:**
- Create: `TrailRider/Theme/ThemeTextField.swift`
- Create: `TrailRider/Theme/ThemeStatCard.swift`
- Create: `TrailRider/Theme/ShimmerView.swift`
- Create: `TrailRider/Theme/AnimationModifiers.swift`

- [ ] **Step 1: Create ThemedTextField**

A custom `View` wrapper instead of `TextFieldStyle` (which has no public customization API). This gives full control over background, border, placeholder, and text colors.

```swift
import SwiftUI

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.trTextTertiary))
            .padding(12)
            .foregroundStyle(.trTextPrimary)
            .background(.trBase)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

Usage: replace `TextField("Display Name", text: $displayName).textFieldStyle(.roundedBorder)` with `ThemedTextField(placeholder: "Display Name", text: $displayName)`. Apply any additional modifiers (`.textContentType`, `.autocorrectionDisabled`, etc.) directly to the `ThemedTextField`.

- [ ] **Step 2: Create ThemeStatCard**

This replaces `StatCard` (HomeView), `SummaryStatCard` (RideSummaryView), and `DetailStatCard` (RideDetailView).

```swift
import SwiftUI

struct ThemeStatCard: View {
    let title: String
    let value: String
    let icon: String
    var glowColor: Color = .trPrimary
    var animationDelay: Double = 0

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(glowColor)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.trTextPrimary)
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.trTextSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .tactileCard(glowColor: glowColor)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay),
            value: appeared
        )
        .onAppear { appeared = true }
    }
}
```

- [ ] **Step 3: Create ShimmerView**

```swift
import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.trSurface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .trSurfaceBorder.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                }
                .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct ShimmerCardPlaceholder: View {
    var height: CGFloat = 60

    var body: some View {
        ShimmerView()
            .frame(height: height)
            .padding(.horizontal)
    }
}
```

- [ ] **Step 4: Create AnimationModifiers**

```swift
import SwiftUI

// MARK: - Staggered Entrance
struct StaggeredEntrance: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Pulse Animation (for condition dots)
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.6)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Floating Animation (for SignInView icon)
struct FloatingAnimation: ViewModifier {
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -6 : 6)
            .animation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear { isFloating = true }
    }
}

extension View {
    func staggeredEntrance(delay: Double) -> some View {
        modifier(StaggeredEntrance(delay: delay))
    }

    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }

    func floatingAnimation() -> some View {
        modifier(FloatingAnimation())
    }
}
```

- [ ] **Step 5: Build to verify all 4 files**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add TrailRider/TrailRider/Theme/ThemeTextField.swift TrailRider/Theme/ThemeStatCard.swift TrailRider/Theme/ShimmerView.swift TrailRider/Theme/AnimationModifiers.swift
git commit -m "feat: add themed text field, stat card, shimmer, and animation modifiers"
```

---

## Task 5: Theme RootView & MainTabView

**Files:**
- Modify: `TrailRider/App/RootView.swift`
- Modify: `TrailRider/App/MainTabView.swift`

- [ ] **Step 1: Theme RootView**

Replace `ProgressView("Loading...")` with a themed loading state on dark forest background. Add dark forest background to the root.

In `RootView.swift`, update `body`:
```swift
var body: some View {
    Group {
        switch authViewModel.authState {
        case .loading:
            ZStack {
                Color.trBase.ignoresSafeArea()
                ProgressView()
                    .tint(.trPrimary)
            }
        case .signedOut:
            SignInView()
        case .onboarding:
            OnboardingView()
        case .signedIn:
            MainTabView()
        }
    }
    .animation(.easeInOut(duration: 0.5), value: authViewModel.authState)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Theme MainTabView**

Update tab bar tinting and add `.symbolEffect(.bounce)` on selection.

In `MainTabView.swift`, update the struct to add a bounce effect on tab selection. Since `.tabItem` labels don't support `.symbolEffect` directly, use `onChange` to trigger a state-driven bounce:

```swift
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var bounceTrigger: Int = 0

    enum Tab: String, CaseIterable {
        case home, trails, ride, social, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            TrailsView()
                .tabItem {
                    Label("Trails", systemImage: "map.fill")
                }
                .tag(Tab.trails)

            RideView()
                .tabItem {
                    Label("Ride", systemImage: "play.fill")
                }
                .tag(Tab.ride)

            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
                .tag(Tab.social)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
        .tint(.trPrimary)
        .onChange(of: selectedTab) {
            bounceTrigger += 1
        }
    }
}
```

Note: SwiftUI's standard `TabView` `.tabItem` does not directly support `.symbolEffect(.bounce)` in iOS 17. The `.tint(.trPrimary)` applies the trail green color to selected tab icons. Full custom tab bars with per-icon bounce effects are deferred to a future enhancement — the tinting alone delivers the core visual improvement.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/App/RootView.swift TrailRider/App/MainTabView.swift
git commit -m "feat: theme RootView and MainTabView with Rugged Earth palette"
```

---

## Task 6: Theme SignInView & OnboardingView

**Files:**
- Modify: `TrailRider/Views/Auth/SignInView.swift`
- Modify: `TrailRider/Views/Auth/OnboardingView.swift`

- [ ] **Step 1: Restyle SignInView**

Full rewrite of `body` in `SignInView.swift`:
```swift
var body: some View {
    ZStack {
        Color.trBase.ignoresSafeArea()

        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "bicycle")
                    .font(.system(size: 80))
                    .foregroundStyle(.trAccent)
                    .floatingAnimation()

                HStack(spacing: 0) {
                    Text("TRAIL")
                        .foregroundStyle(.trTextPrimary)
                    Text("RIDER")
                        .foregroundStyle(.trPrimary)
                }
                .font(.system(size: 42, weight: .bold))

                Text("Track rides. Find friends. Own the trail.")
                    .font(.subheadline)
                    .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                authViewModel.handleSignInRequest(request)
            } onCompletion: { result in
                authViewModel.handleSignInCompletion(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 54)
            .padding(.horizontal, 40)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.trDestructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            #if DEBUG
            Button("Skip to App (Dev)") {
                authViewModel.devBypass()
            }
            .font(.caption)
            .foregroundStyle(.trTextSecondary)
            #endif

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}
```

- [ ] **Step 2: Restyle OnboardingView**

Update `body` in `OnboardingView.swift`:
```swift
var body: some View {
    NavigationStack {
        ZStack {
            Color.trBase.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Set Up Your Profile")
                        .font(.title.bold())
                        .foregroundStyle(.trTextPrimary)

                    Text("Choose a username and display name")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                }

                VStack(spacing: 16) {
                    ThemedTextField(placeholder: "Display Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    ThemedTextField(placeholder: "Username (min 3 characters)", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 24)

                Button {
                    isSubmitting = true
                    Task {
                        await authViewModel.completeOnboarding(
                            username: username,
                            displayName: displayName
                        )
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Let's Ride")
                    }
                }
                .buttonStyle(.trailPrimary)
                .disabled(!isFormValid || isSubmitting)
                .padding(.horizontal, 24)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.trDestructive)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/Views/Auth/SignInView.swift TrailRider/Views/Auth/OnboardingView.swift
git commit -m "feat: theme SignInView and OnboardingView with Rugged Earth"
```

---

## Task 7: Theme HomeView

**Files:**
- Modify: `TrailRider/Views/Home/HomeView.swift`

- [ ] **Step 1: Restyle HomeView body, StatCard, and TrailConditionRow**

Replace the entire file content. Key changes: use `ThemeStatCard`, add amber section headers, tactile condition rows with pulsing dots, staggered entrances, dark forest nav background.

```swift
import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let user = authViewModel.currentUser {
                        Text("Hey, \(user.displayName)!")
                            .font(.title.bold())
                            .foregroundStyle(.trTextPrimary)
                            .padding(.horizontal)
                    }

                    // Quick start ride button
                    Button {
                        // TODO: Navigate to ride tab
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start a Ride")
                        }
                    }
                    .buttonStyle(.trailPrimary)
                    .padding(.horizontal)
                    .staggeredEntrance(delay: 0)

                    // Stats summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR STATS")
                            .font(.caption.bold())
                            .foregroundStyle(.trAccent)
                            .tracking(2)

                        HStack(spacing: 16) {
                            ThemeStatCard(
                                title: "Total Miles",
                                value: String(format: "%.1f", authViewModel.currentUser?.totalMiles ?? 0),
                                icon: "road.lanes",
                                animationDelay: 0.1
                            )
                            ThemeStatCard(
                                title: "Streak",
                                value: "\(authViewModel.currentUser?.currentStreak ?? 0)",
                                icon: "flame.fill",
                                glowColor: .trAccent,
                                animationDelay: 0.2
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Trail conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRAIL CONDITIONS")
                            .font(.caption.bold())
                            .foregroundStyle(.trAccent)
                            .tracking(2)

                        TrailConditionRow(
                            name: "Amelia Earhart Park",
                            condition: "Dry",
                            color: .trPrimary
                        )
                        .staggeredEntrance(delay: 0.3)

                        TrailConditionRow(
                            name: "Virginia Key North Point",
                            condition: "Dry",
                            color: .trPrimary
                        )
                        .staggeredEntrance(delay: 0.4)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(.trBase)
            .navigationTitle("TrailRider")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Components

struct TrailConditionRow: View {
    let name: String
    let condition: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .pulseAnimation()
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.trTextPrimary)
            Spacer()
            Text(condition)
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .padding()
        .tactileCard(glowColor: color)
    }
}
```

Note: `StatCard` is removed from this file — replaced by `ThemeStatCard` from the theme layer.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrailRider/TrailRider/Views/Home/HomeView.swift
git commit -m "feat: theme HomeView with Rugged Earth - tactile cards, amber headers, staggered entrance"
```

---

## Task 8: Theme RideView (PreRideView + JoinSessionSheet)

**Files:**
- Modify: `TrailRider/Views/Ride/RideView.swift`

- [ ] **Step 1: Restyle PreRideView and JoinSessionSheet**

Update `PreRideView` body to use themed components. Key changes: amber bicycle icon, primary/ghost button styles, themed text field in JoinSessionSheet, dark forest backgrounds.

In `PreRideView`, update the body — replace `.background(.green)` / `.foregroundStyle(.white)` / `.clipShape(...)` button styling with `.buttonStyle(.trailPrimary)`, replace `.background(.ultraThinMaterial)` on Create/Join tiles with `.buttonStyle(.trailGhost)`, add `Color.trBase` background, update text colors to `.trTextPrimary` / `.trTextSecondary` / `.trDestructive`, change bicycle icon to `.foregroundStyle(.trAccent)`.

In `JoinSessionSheet`, update: background to `.trBase`, text colors to `.trTextSecondary`, error text to `.trDestructive`. Replace the `TextField` with a `ThemedTextField`. Replace button styling: remove `.buttonStyle(.borderedProminent)` and `.tint(.green)`, use `.buttonStyle(.trailPrimary)`.

For the digit scale-in animation, add `.contentTransition(.numericText())` and `.animation(.spring(response: 0.3), value: code)` to the `TextField` so digits animate smoothly as the user types. The monospaced font should use `.foregroundStyle(.trPrimary)` for trail green digits.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrailRider/TrailRider/Views/Ride/RideView.swift
git commit -m "feat: theme PreRideView and JoinSessionSheet with Rugged Earth"
```

---

## Task 9: Theme ActiveRideView

**Files:**
- Modify: `TrailRider/Views/Ride/ActiveRideView.swift`

- [ ] **Step 1: Restyle ActiveRideView**

Key changes:
1. Add `contentTransition(.numericText())` + `.animation(.default, value:)` to speed Text and all StatColumn values
2. Refactor pause/play into single Button with single Image + `.contentTransition(.symbolEffect(.replace))`
3. Theme the bottom stats panel with tactile card treatment
4. Theme control buttons: golden dust pause, trail green play, terracotta stop

Replace the stats overlay VStack bottom section with tactile-themed panel. Replace the two separate pause/play buttons with:

```swift
// Pause/Play toggle (single view for symbol morphing)
if rideVM.rideState == .riding || rideVM.rideState == .paused {
    Button {
        rideVM.rideState == .riding ? rideVM.pauseRide() : rideVM.resumeRide()
    } label: {
        Image(systemName: rideVM.rideState == .riding ? "pause.fill" : "play.fill")
            .contentTransition(.symbolEffect(.replace))
            .font(.title)
            .frame(width: 64, height: 64)
            .background(rideVM.rideState == .riding ? Color.trWarning : Color.trPrimary)
            .foregroundStyle(rideVM.rideState == .riding ? Color.trBase : Color.white)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rideVM.rideState)
}
```

Update speed Text:
```swift
Text(rideVM.formattedSpeed)
    .font(.system(size: 72, weight: .bold, design: .rounded))
    .foregroundStyle(.trTextPrimary)
    .contentTransition(.numericText())
    .animation(.default, value: rideVM.formattedSpeed)
```

Update `StatColumn` to also use `.contentTransition(.numericText())` and themed colors.

Update the bottom panel `.background(.ultraThinMaterial)` to use tactile card treatment.

Update the stop button to use `.background(.trDestructive)`.

- [ ] **Step 2: Add route polyline progressive draw animation**

The route polyline should draw progressively as new coordinates arrive. Add a `@State private var drawProgress: CGFloat = 0` property and use `.trimmedPath` on the `MapPolyline`. Since `MapPolyline` doesn't support `.trim()` directly, apply the animation by updating route coordinates progressively — the polyline already grows as `rideVM.routeCoordinates` appends points. To make this visually smooth, ensure the map updates are animated:

After `MapPolyline(coordinates: rideVM.routeCoordinates).stroke(.trPrimary, lineWidth: 4)`, add `.animation(.easeInOut(duration: 0.3), value: rideVM.routeCoordinates.count)` to the `Map` view.

- [ ] **Step 3: Add milestone pulse animation**

Add a milestone pulse to `StatColumn` when distance hits round numbers. In `ActiveRideView`, add:

```swift
@State private var milestonePulse = false
```

Add an `onChange` modifier that watches distance:

```swift
.onChange(of: rideVM.formattedDistance) { oldVal, newVal in
    if let miles = Double(newVal), miles > 0, miles.truncatingRemainder(dividingBy: 5) < 0.05 {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            milestonePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { milestonePulse = false }
        }
    }
}
```

Apply `.scaleEffect(milestonePulse ? 1.15 : 1.0)` and `.shadow(color: .trPrimary.opacity(milestonePulse ? 0.5 : 0), radius: 10)` to the distance `StatColumn`.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TrailRider/TrailRider/Views/Ride/ActiveRideView.swift
git commit -m "feat: theme ActiveRideView - symbol morphing, numeric transitions, tactile panel, milestone pulse"
```

---

## Task 10: Theme RideSummaryView & RideDetailView

**Files:**
- Modify: `TrailRider/Views/Ride/RideSummaryView.swift`
- Modify: `TrailRider/Views/Profile/RideDetailView.swift`

- [ ] **Step 1: Restyle RideSummaryView**

Replace `SummaryStatCard` usage with `ThemeStatCard`. Remove the `SummaryStatCard` struct definition. Add `.background(.trBase)` to ScrollView. Update "Done" button to `.buttonStyle(.trailPrimary)`, remove `.buttonStyle(.borderedProminent)` and `.tint(.green)`. Add staggered delays to each `ThemeStatCard`. Update route polyline stroke to `.trPrimary`.

- [ ] **Step 2: Restyle RideDetailView**

Replace `DetailStatCard` usage with `ThemeStatCard`. Remove the `DetailStatCard` struct definition. Add `.background(.trBase)` to ScrollView. Update text colors: date `.trTextPrimary`, time `.trTextSecondary`. Add staggered delays to each `ThemeStatCard`. Update route polyline stroke to `.trPrimary`.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/Views/Ride/RideSummaryView.swift TrailRider/Views/Profile/RideDetailView.swift
git commit -m "feat: theme RideSummaryView and RideDetailView with shared ThemeStatCard"
```

---

## Task 11: Theme TrailsView, TrailCardView & TrailMapView

**Files:**
- Modify: `TrailRider/Views/Trails/TrailsView.swift`
- Modify: `TrailRider/Views/Trails/TrailCardView.swift`
- Modify: `TrailRider/Views/Trails/TrailMapView.swift`

- [ ] **Step 1: Restyle TrailsView**

Update `TrailListCard`: replace `.background(.ultraThinMaterial)` with `.tactileCard()`, update text colors (`.trTextPrimary` for name, `.trTextSecondary` for subtitle/labels), update icon container to use `.trPrimary` gradient background, chevron to `.trPrimary`. Add staggered entrance to trail cards. Add `.background(.trBase)` to ScrollView. Update section header "Featured Trails" to amber accent.

- [ ] **Step 2: Restyle TrailCardView**

Update `difficultyColor()`: change `"advanced", "black diamond"` case to return `.trBadgeDark`. Add `.foregroundStyle(.trTextPrimary)` to difficulty badge text (so it's visible on charcoal). Change "Double Black" to return `.trDestructive`.

Update button styling. Replace the "View Trail Map" `NavigationLink` block (lines 184-196) with:

```swift
NavigationLink(destination: TrailMapView(trail: trail)) {
    HStack {
        Image(systemName: "map.fill")
        Text("View Trail Map")
            .font(.headline)
    }
    .foregroundStyle(.trAccent)
    .frame(maxWidth: .infinity)
    .frame(height: 50)
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(.trAccent, lineWidth: 1.5)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
}
```

Replace the "Get Directions" button styling: remove `.buttonStyle(.borderedProminent)` and `.tint(.secondary)`, replace with `.buttonStyle(.trailPrimary)`.

Update route filter chips: selected state to `.trPrimary` fill, unselected to `.trSurface` with `.trSurfaceBorder` border.

Update all text colors and section headers. Update `QuickStat` and `DetailRow` to use theme colors. Add `.background(.trBase)` to ScrollView.

- [ ] **Step 3: Restyle TrailMapView**

Replace legend panel `.background(.ultraThinMaterial)` with `.tactileCard()`. Replace toggle button `.background(.ultraThinMaterial)` with ghost style (`.trSurface` bg + `.trSurfaceBorder` stroke). Update text colors in legend. Update trailhead marker tint to `.trPrimary`.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TrailRider/TrailRider/Views/Trails/TrailsView.swift TrailRider/Views/Trails/TrailCardView.swift TrailRider/Views/Trails/TrailMapView.swift
git commit -m "feat: theme Trails views - tactile cards, charcoal badges, amber outline buttons"
```

---

## Task 12: Theme SocialView & AddFriendView

**Files:**
- Modify: `TrailRider/Views/Social/SocialView.swift`
- Modify: `TrailRider/Views/Social/AddFriendView.swift`

- [ ] **Step 1: Restyle SocialView**

Update `FriendRequestRow` and `FriendRow`: replace `.foregroundStyle(.green)` with `.trPrimary` on avatars. Update accept button to `.trPrimary`, decline to `.trDestructive`. Add tactile card treatment to friend rows. Update `ContentUnavailableView` styling. Update toolbar add-friend button to `.trAccent`. Replace `ProgressView("Loading...")` with shimmer placeholders. Add `.background(.trBase)` to List via `.scrollContentBackground(.hidden)`. Update section header text.

For List rows with tactile cards, add these modifiers to each `ForEach` item or `Section` content to remove system row chrome:
```swift
.listRowBackground(Color.clear)
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
```
This prevents the system `listRowBackground` from overlapping the tactile card styling.

- [ ] **Step 2: Restyle AddFriendView**

Add `Color.trBase.ignoresSafeArea()` background. Update heading to `.trTextPrimary`. Replace `TextField("Enter username", text: $searchText).textFieldStyle(.roundedBorder)` with `ThemedTextField(placeholder: "Enter username", text: $searchText)`. Replace search button `.background(.green)` with `.background(.trPrimary)`. Replace result card `.background(.ultraThinMaterial)` with `.tactileCard()`. Update avatar `.foregroundStyle(.green)` to `.trPrimary`. Replace `.buttonStyle(.borderedProminent) .tint(.green)` with `.buttonStyle(.trailPrimary)`. Update message text `.foregroundStyle(.green)` to `.trPrimary`. Update error text `.foregroundStyle(.red)` to `.trDestructive`. Replace `ProgressView()` search spinner with `ShimmerCardPlaceholder()`. Update all text colors.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/Views/Social/SocialView.swift TrailRider/Views/Social/AddFriendView.swift
git commit -m "feat: theme SocialView and AddFriendView with Rugged Earth"
```

---

## Task 13: Theme ProfileView & RideHistoryView

**Files:**
- Modify: `TrailRider/Views/Profile/ProfileView.swift`
- Modify: `TrailRider/Views/Profile/RideHistoryView.swift`

- [ ] **Step 1: Restyle ProfileView**

Replace avatar icon `.foregroundStyle(.green)` with `.trAccent`. Replace `LabeledContent` stats section with `ThemeStatCard` in a 2-column grid. Replace `Label` navigation links with tactile card styled rows. Replace sign-out button: remove `role: .destructive`, use themed terracotta styling with `.foregroundStyle(.trDestructive)`. Add `.scrollContentBackground(.hidden)` and `.background(.trBase)` to List. Update all text colors (`.trTextPrimary` for display name, `.trTextSecondary` for username).

- [ ] **Step 2: Restyle RideHistoryView**

Replace `ProgressView("Loading rides...")` with shimmer placeholders (3x `ShimmerCardPlaceholder`). Add `.scrollContentBackground(.hidden)` and `.background(.trBase)` to List. Theme `RideRow`: update date text to `.trTextPrimary`, time text to `.trTextSecondary`, distance to `.trTextPrimary`, duration to `.trTextSecondary`. Theme `ContentUnavailableView` empty state. Add `.tint(.trDestructive)` for swipe-to-delete.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrailRider/TrailRider/Views/Profile/ProfileView.swift TrailRider/Views/Profile/RideHistoryView.swift
git commit -m "feat: theme ProfileView and RideHistoryView with Rugged Earth"
```

---

## Task 14: Theme GroupRideLobbyView

**Files:**
- Modify: `TrailRider/Views/Ride/GroupRideLobbyView.swift`

- [ ] **Step 1: Restyle GroupRideLobbyView**

Add `Color.trBase.ignoresSafeArea()` background via ZStack. Update session code color from `.foregroundStyle(.green)` to `.trPrimary`. Add staggered digit drop-in animation — split the code string into individual characters displayed with staggered delays.

Update "Copy Code" button to `.buttonStyle(.trailGhost)`.

Update member rows: replace `.background(.ultraThinMaterial)` with `.tactileCard()`. Update avatar `.foregroundStyle(.green)` to `.trPrimary`. Update ready checkmark `.foregroundStyle(.green)` to `.trPrimary`. Update "Not Ready" text to `.trTextSecondary`.

Update "Start Group Ride" / "Ready Up" button: replace `.buttonStyle(.borderedProminent) .tint(.green)` with `.buttonStyle(.trailPrimary)`.

Update "End/Leave Session" button: add `.foregroundStyle(.trDestructive)`.

Update section header "Riders" to `.trTextPrimary`.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrailRider/TrailRider/Views/Ride/GroupRideLobbyView.swift
git commit -m "feat: theme GroupRideLobbyView with Rugged Earth - staggered code, tactile member cards"
```

---

## Task 15: Final Visual QA Pass

- [ ] **Step 1: Run the app in Simulator**

Run: `xcodebuild -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Then open the Simulator and navigate through every screen:
1. SignInView → verify dark forest BG, amber icon floats, split-color logo
2. OnboardingView → verify themed text fields, green CTA
3. HomeView → verify amber headers, tactile stat cards, pulsing condition dots
4. TrailsView → verify tactile trail cards, staggered entrance
5. TrailCardView → verify charcoal Black Diamond badges, amber/green buttons
6. TrailMapView → verify tactile legend panel
7. RideView → verify amber icon, green/ghost buttons
8. ActiveRideView → verify symbol morphing, numeric transitions, themed controls
9. RideSummaryView → verify shared ThemeStatCard, staggered entrance
10. SocialView → verify themed friend rows, accept/decline colors
11. AddFriendView → verify themed search, shimmer, tactile result
12. ProfileView → verify amber avatar, stat cards, tactile nav rows
13. RideHistoryView → verify shimmer loading, themed rows
14. RideDetailView → verify shared ThemeStatCard
15. GroupRideLobbyView → verify staggered code, tactile members

- [ ] **Step 2: Fix any visual inconsistencies found**

Address any remaining hardcoded `.green`, `.ultraThinMaterial`, or unstyled components.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "fix: visual QA pass - resolve remaining theme inconsistencies"
```
