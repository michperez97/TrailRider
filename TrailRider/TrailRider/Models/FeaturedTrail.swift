import Foundation
import CoreLocation

struct FeaturedTrail: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let totalMiles: Double
    let difficulty: [String]
    let style: String
    let parking: String
    let hours: String
    let bikeRentals: String?
    let keyFeature: String
    let description: String
    let segments: [TrailSegment]
    let tips: [String]

    struct TrailSegment: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let difficulty: String
    }
}

// MARK: - Miami Featured Trails

extension FeaturedTrail {
    static let ameliaEarhart = FeaturedTrail(
        id: "amelia-earhart",
        name: "Amelia Earhart Park",
        subtitle: "XC Singletrack & Fire Road",
        address: "401 E 65th Street, Hialeah, FL 33013",
        coordinate: CLLocationCoordinate2D(latitude: 25.8844, longitude: -80.2789),
        totalMiles: 7.75,
        difficulty: ["Beginner", "Intermediate", "Advanced"],
        style: "XC (Cross-Country) — fast sections, not overly technical",
        parking: "Free weekdays / $8 weekends & holidays",
        hours: "Sunrise to sunset",
        bikeRentals: "Genesis MTB Rentals — weekends 9:30am–6pm",
        keyFeature: "All trails have bypasses — fully adaptive for all skill levels",
        description: "7.75-mile circuit of singletrack sequentially built with bypasses and connecting access roads. 21 trails from beginner through advanced with technical features including Big Dipper, Mount Amelia, Voodoo Climb, and the Tilted Container. Skills & jumps area atop Chupacabra Hill.",
        segments: [
            .init(name: "Potato Vine", description: "Mellow wide paths, perfect for beginners and kids", difficulty: "Beginner"),
            .init(name: "Coffee Trail", description: "Flowing singletrack through the park", difficulty: "Intermediate"),
            .init(name: "Gobble Gobble", description: "Intermediate loop with optional advanced section", difficulty: "Intermediate"),
            .init(name: "Chupacabra", description: "Advanced singletrack with skills area and jump lines on the hill", difficulty: "Advanced"),
            .init(name: "Golden Gate", description: "Technical section with advanced bypass option", difficulty: "Advanced"),
            .init(name: "Key Biscayne Loop", description: "Intermediate trail connecting to the main circuit", difficulty: "Intermediate"),
        ],
        tips: [
            "Check trail conditions after heavy rain — some sections flood",
            "Weekend parking is $8, plan accordingly",
            "Genesis MTB rents bikes on weekends if you need a loaner",
            "Mosquito spray is essential in summer months",
            "Enter trails via Sand Bowl or Potato Vine entrance",
        ]
    )

    static let virginiaKey = FeaturedTrail(
        id: "virginia-key",
        name: "Virginia Key North Point",
        subtitle: "Island Singletrack",
        address: "3801 Rickenbacker Cswy, Miami, FL",
        coordinate: CLLocationCoordinate2D(latitude: 25.7430, longitude: -80.1540),
        totalMiles: 10,
        difficulty: ["Green", "Blue", "Black Diamond", "Double Black"],
        style: "Island singletrack — sandy sections, wooden bridges, coastal views",
        parking: "Paid via Pay-by-Phone",
        hours: "Daily — check Miami Parks for current hours",
        bikeRentals: "Available at trailhead",
        keyFeature: "Biscayne Bay views, wooden stunts, island atmosphere",
        description: "10 miles of singletrack on a coastal island with sandy sections, wooden bridges, mangrove tunnels, and Biscayne Bay views. Ranges from mellow green loops to gnarly double black features.",
        segments: [
            .init(name: "War Pigs", description: "Advanced descent, fan favorite", difficulty: "Black Diamond"),
            .init(name: "Tom Sawyer", description: "Recently restored feature trail", difficulty: "Blue"),
            .init(name: "Jimbo", description: "New trail addition", difficulty: "Blue"),
            .init(name: "Main Loop", description: "Flows through mangroves along Biscayne Bay", difficulty: "Green"),
        ],
        tips: [
            "Muddy in rainy months — check conditions before heading out",
            "Mosquitoes are severe in summer, bring strong repellent",
            "Pay for parking via phone app before hitting the trail",
            "Bring extra water — no refill stations on trail",
        ]
    )

    static let all: [FeaturedTrail] = [ameliaEarhart, virginiaKey]
}
