import SwiftUI
import UIKit

struct GroupRideLobbyView: View {
    @Bindable var groupVM: GroupRideViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            Color.trBase.ignoresSafeArea()

            VStack(spacing: 24) {
                // Session code
                VStack(spacing: 8) {
                    Text("Session Code")
                        .font(.caption)
                        .foregroundStyle(.trTextSecondary)
                    Text(groupVM.sessionCode)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.trPrimary)
                    Text("Share this code with your riding crew")
                        .font(.caption)
                        .foregroundStyle(.trTextSecondary)

                    Button {
                        UIPasteboard.general.string = groupVM.sessionCode
                    } label: {
                        Label("Copy Code", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.trailGhost)
                }
                .padding()

                // Members list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Riders (\(groupVM.members.count))")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)
                        .padding(.horizontal)

                    ForEach(groupVM.members) { member in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.trPrimary)
                            VStack(alignment: .leading) {
                                Text(member.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.trTextPrimary)
                                Text("@\(member.username)")
                                    .font(.caption)
                                    .foregroundStyle(.trTextSecondary)
                            }
                            Spacer()
                            if member.isReady {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.trPrimary)
                            } else {
                                Text("Not Ready")
                                    .font(.caption)
                                    .foregroundStyle(.trTextSecondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .tactileCard()
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    if groupVM.isHost {
                        Button {
                            Task { await groupVM.startGroupRide() }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Group Ride")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.trailPrimary)
                        .disabled(!groupVM.allReady)
                    } else {
                        Button {
                            Task { await groupVM.toggleReady() }
                        } label: {
                            let amReady = groupVM.members.first(where: { $0.userId == authViewModel.currentUser?.id })?.isReady ?? false
                            HStack {
                                Image(systemName: amReady ? "checkmark.circle" : "hand.thumbsup.fill")
                                Text(amReady ? "Unready" : "Ready Up")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.trailPrimary)
                    }

                    Button(role: .destructive) {
                        Task { await groupVM.leaveSession() }
                    } label: {
                        Text(groupVM.isHost ? "End Session" : "Leave Session")
                            .font(.subheadline)
                            .foregroundStyle(.trDestructive)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Group Ride")
        .toolbar(.hidden, for: .tabBar)
    }
}
