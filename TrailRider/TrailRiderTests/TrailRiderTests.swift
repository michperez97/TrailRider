//
//  TrailRiderTests.swift
//  TrailRiderTests
//
//  Created by Michel Perez Machado on 3/8/26.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import Testing
@testable import TrailRider

struct TrailRiderTests {

    @Test func standaloneWatchRidePayloadAllowsMissingRouteCoordinates() throws {
        let ride = try StandaloneWatchRidePayload.ride(
            from: [
                "startTime": TimeInterval(1_800),
                "endTime": TimeInterval(3_600),
                "durationSeconds": 1_800,
                "distanceMeters": 8_046.72
            ],
            userId: "user-1"
        )

        #expect(ride.userId == "user-1")
        #expect(ride.durationSeconds == 1_800)
        #expect(abs(ride.distanceMiles - 5.0) < 0.0001)
        #expect(ride.routePolyline.isEmpty)
    }

    @Test func standaloneWatchRidePayloadMapsRouteCoordinatesWhenPresent() throws {
        let ride = try StandaloneWatchRidePayload.ride(
            from: [
                "startTime": TimeInterval(1_800),
                "endTime": TimeInterval(3_600),
                "durationSeconds": 1_800,
                "distanceMeters": 1_609.344,
                "routeCoordinates": [
                    ["lat": 25.9101, "lon": -80.3117],
                    ["lat": 25.9102, "lon": -80.3118],
                    ["lat": 0.0]
                ]
            ],
            userId: "user-1"
        )

        #expect(ride.routePolyline.count == 2)
        #expect(ride.routePolyline[0].latitude == 25.9101)
        #expect(ride.routePolyline[0].longitude == -80.3117)
    }

    @Test func rideNavigationMatchesNearestMappedTrail() throws {
        let route = try #require(TrailMapData.routes(for: "amelia-earhart").first)
        let segment = TrailSegment(route: route, parkName: "Test Park")
        let graph = TrailGraph(segments: [segment])
        let coordinate = try #require(route.coordinates.dropFirst(3).first)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 180,
            speed: 3,
            timestamp: Date()
        )

        let state = RideNavigationEngine.navigationState(
            for: location,
            graph: graph,
            signalQuality: .strong
        )

        #expect(state.currentTrailName == route.name)
        #expect(state.confidence == .high)
        #expect(state.hasTrailMatch)
        #expect(!state.visibleAheadCoordinates.isEmpty)
        #expect(state.directionalProgressFraction > 0)
        #expect(state.directionalProgressFraction < 1)
        #expect(state.remainingSegmentMeters > 0)
        #expect(!state.progressPercentText.isEmpty)
        #expect(!state.remainingSegmentText.isEmpty)
    }

    @Test func rideNavigationDetectsUpcomingTrailFork() throws {
        let routes = TrailMapData.routes(for: "amelia-earhart")
        let corridor = try #require(routes.first { $0.name == "Trailhead Corridor" })
        let potatoVine = try #require(routes.first { $0.name == "Potato Vine" })
        let graph = TrailGraph(segments: [
            TrailSegment(route: corridor, parkName: "Test Park"),
            TrailSegment(route: potatoVine, parkName: "Test Park")
        ])
        let nearFork = try #require(corridor.coordinates.dropLast().last)
        let endpoint = try #require(corridor.coordinates.last)
        let location = CLLocation(
            coordinate: nearFork,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: nearFork.bearing(to: endpoint),
            speed: 4,
            timestamp: Date()
        )

        let state = RideNavigationEngine.navigationState(
            for: location,
            graph: graph,
            signalQuality: .strong
        )

        let hasForkCue: Bool
        if case .fork = state.cue?.kind {
            hasForkCue = true
        } else {
            hasForkCue = false
        }
        #expect(hasForkCue)
        #expect(state.cue?.distanceMeters != nil)
        #expect(state.cue?.detail.contains("Potato Vine") == true)
        #expect(state.upcomingForkChoices.count == 1)
        #expect(state.upcomingForkChoices.first?.trailName == "Potato Vine")
        #expect(state.upcomingForkChoices.first?.direction.label.isEmpty == false)
        #expect(state.upcomingForkChoices.first?.distanceMeters != nil)
    }

    @Test func rideNavigationReportsWeakGPSBeforeRouteCue() throws {
        let route = try #require(TrailMapData.routes(for: "amelia-earhart").first)
        let graph = TrailGraph(segments: [TrailSegment(route: route, parkName: "Test Park")])
        let coordinate = try #require(route.coordinates.dropFirst(3).first)
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 28,
            verticalAccuracy: 5,
            course: 180,
            speed: 3,
            timestamp: Date()
        )

        let state = RideNavigationEngine.navigationState(
            for: location,
            graph: graph,
            signalQuality: .weak
        )

        #expect(state.hasTrailMatch)
        let hasGPSWeakCue: Bool
        if case .gpsWeak = state.cue?.kind {
            hasGPSWeakCue = true
        } else {
            hasGPSWeakCue = false
        }
        #expect(hasGPSWeakCue)
    }

    @Test func rideNavigationReportsOffRouteWhenNoTrailIsNear() throws {
        let route = try #require(TrailMapData.routes(for: "amelia-earhart").first)
        let graph = TrailGraph(segments: [TrailSegment(route: route, parkName: "Test Park")])
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 25.0, longitude: -81.0),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 3,
            timestamp: Date()
        )

        let state = RideNavigationEngine.navigationState(
            for: location,
            graph: graph,
            signalQuality: .strong
        )

        #expect(state.confidence == .offRoute)
        let hasOffRouteCue: Bool
        if case .offRoute = state.cue?.kind {
            hasOffRouteCue = true
        } else {
            hasOffRouteCue = false
        }
        #expect(hasOffRouteCue)
    }

}
