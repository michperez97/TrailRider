import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

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
    }
}
