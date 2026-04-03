import SwiftUI

struct RideView: View {
    @State private var rideVM = RideViewModel()
    @State private var groupVM = GroupRideViewModel()
    @Environment(AuthViewModel.self) private var authViewModel
    private let watchService = WatchConnectivityService.shared

    var body: some View {
        Group {
            switch rideVM.rideState {
            case .idle:
                if groupVM.groupState == .lobby {
                    GroupRideLobbyView(groupVM: groupVM)
                } else {
                    PreRideView(rideVM: rideVM, groupVM: groupVM)
                }
            case .riding, .paused:
                ActiveRideView(rideVM: rideVM)
            case .summary:
                RideSummaryView(rideVM: rideVM)
            }
        }
        .onChange(of: groupVM.groupState) { _, newState in
            if newState == .active {
                rideVM.startRide()
            }
        }
        .onChange(of: watchService.workoutDidStart) { _, started in
            if started && rideVM.rideState == .idle {
                rideVM.startRide()
                watchService.workoutDidStart = false
            }
        }
        .onChange(of: watchService.workoutDidEnd) { _, ended in
            if ended && (rideVM.rideState == .riding || rideVM.rideState == .paused) {
                rideVM.stopRide(userId: authViewModel.currentUser?.id)
                watchService.workoutDidEnd = false
            }
        }
        .onChange(of: watchService.hasStandaloneRide) { _, hasRide in
            if hasRide, let userId = authViewModel.currentUser?.id {
                Task {
                    await rideVM.saveStandaloneWatchRide(watchService.standaloneRideData, userId: userId)
                    watchService.hasStandaloneRide = false
                    watchService.standaloneRideData = [:]
                }
            }
        }
    }
}

struct PreRideView: View {
    @Bindable var rideVM: RideViewModel
    @Bindable var groupVM: GroupRideViewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.trBase.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    TrailRiderIcon(size: 160)

                    Text("Ready to Ride")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.trTextPrimary)

                    Text("Amelia Earhart Park")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)

                    // Solo ride
                    Button {
                        rideVM.startRide()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Solo Ride")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.trailPrimary)
                    .padding(.horizontal, 40)

                    // Group ride options
                    VStack(spacing: 12) {
                        Text("or ride with friends")
                            .font(.caption)
                            .foregroundStyle(.trTextSecondary)

                        HStack(spacing: 16) {
                            Button {
                                if let user = authViewModel.currentUser {
                                    Task { await groupVM.createSession(user: user) }
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.trTextPrimary)
                                    Text("Create")
                                        .font(.caption.bold())
                                        .foregroundStyle(.trTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                            }
                            .buttonStyle(.trailGhost)

                            Button {
                                showJoinSheet = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.trTextPrimary)
                                    Text("Join")
                                        .font(.caption.bold())
                                        .foregroundStyle(.trTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                            }
                            .buttonStyle(.trailGhost)
                        }
                        .padding(.horizontal, 40)
                    }

                    if let error = groupVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.trDestructive)
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Ride")
            .sheet(isPresented: $showJoinSheet) {
                JoinSessionSheet(groupVM: groupVM)
            }
        }
    }
}

struct JoinSessionSheet: View {
    @Bindable var groupVM: GroupRideViewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.trBase.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Enter the 6-digit session code")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)

                    ThemedTextField(placeholder: "000000", text: $code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 200)
                        .foregroundStyle(.trPrimary)

                    Button {
                        groupVM.joinCode = code
                        if let user = authViewModel.currentUser {
                            Task {
                                await groupVM.joinSession(user: user)
                                if groupVM.groupState == .lobby {
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Text("Join Ride")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.trailPrimary)
                    .disabled(code.count != 6)
                    .padding(.horizontal)

                    if let error = groupVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.trDestructive)
                    }

                    Spacer()
                }
            }
            .padding(.top, 40)
            .navigationTitle("Join Group Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
