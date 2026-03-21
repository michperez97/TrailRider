import SwiftUI
import MapKit

struct TrailMapView: View {
    let trail: FeaturedTrail
    @State private var position: MapCameraPosition
    @State private var selectedRoute: TrailRoute?
    @State private var showLegend = true

    private var routes: [TrailRoute] {
        TrailMapData.routes(for: trail.id)
    }

    init(trail: FeaturedTrail) {
        self.trail = trail
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: trail.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        ))
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()

                ForEach(routes) { route in
                    if selectedRoute == nil || selectedRoute?.id == route.id {
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(route.color.swiftUIColor, lineWidth: 4)
                    }
                }

                Marker("Trailhead", systemImage: "flag.fill", coordinate: trail.coordinate)
                    .tint(.trPrimary)
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            VStack {
                Spacer()

                if showLegend {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Trail Routes")
                                .font(.caption.bold())
                                .foregroundStyle(.trTextPrimary)
                            Spacer()
                            Button { showLegend = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.trTextSecondary)
                            }
                        }

                        ForEach(routes) { route in
                            Button {
                                selectedRoute = selectedRoute?.id == route.id ? nil : route
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(route.color.swiftUIColor)
                                        .frame(width: 20, height: 4)
                                    Text(route.name)
                                        .font(.caption)
                                        .foregroundStyle(.trTextPrimary)
                                    Spacer()
                                    Text(route.difficulty)
                                        .font(.caption2)
                                        .foregroundStyle(.trTextSecondary)
                                }
                                .padding(.vertical, 2)
                                .opacity(selectedRoute == nil || selectedRoute?.id == route.id ? 1.0 : 0.4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(LinearGradient(colors: [.trSurface, .trSurfaceDarker], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.trSurfaceBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding()
                } else {
                    HStack {
                        Spacer()
                        Button { showLegend = true } label: {
                            Image(systemName: "map.fill")
                                .foregroundStyle(.trPrimary)
                                .padding(12)
                                .background(.trSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.trSurfaceBorder, lineWidth: 1))
                        }
                        .padding()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle(trail.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
