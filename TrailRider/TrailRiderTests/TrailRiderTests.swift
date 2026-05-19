//
//  TrailRiderTests.swift
//  TrailRiderTests
//
//  Created by Michel Perez Machado on 3/8/26.
//

import Foundation
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

}
