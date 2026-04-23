import Foundation

struct RideJournal: Identifiable, Codable, Equatable {
    let id: String
    var rideId: String
    var routeName: String
    var date: Date

    var intentions: String?
    var conditions: String?

    var rideEntries: [RideMoment]

    var reflection: String?
    var achievements: String?
    var nextGoal: String?

    var mood: RideMood?
    var effortRating: Int?
    var isFavorite: Bool
    var tags: [String]

    var distanceMiles: Double?
    var elapsedSeconds: Double?

    init(rideId: String, routeName: String, date: Date = .now, distanceMiles: Double? = nil, elapsedSeconds: Double? = nil) {
        self.id = UUID().uuidString
        self.rideId = rideId
        self.routeName = routeName
        self.date = date
        self.rideEntries = []
        self.isFavorite = false
        self.tags = []
        self.distanceMiles = distanceMiles
        self.elapsedSeconds = elapsedSeconds
    }
}

struct RideMoment: Identifiable, Codable, Equatable {
    let id: String
    var timestamp: Date
    var note: String
    var mood: RideMood?

    init(note: String, mood: RideMood? = nil) {
        self.id = UUID().uuidString
        self.timestamp = .now
        self.note = note
        self.mood = mood
    }
}

enum RideMood: String, Codable, CaseIterable {
    case pumped, strong, tired, scenic, challenging, proud, meditative, social, painful, joyful

    var emoji: String {
        switch self {
        case .pumped: "⚡"
        case .strong: "💪"
        case .tired: "😤"
        case .scenic: "🏔️"
        case .challenging: "🧗"
        case .proud: "🏆"
        case .meditative: "🧘"
        case .social: "🤝"
        case .painful: "😣"
        case .joyful: "😄"
        }
    }

    var label: String { rawValue.capitalized }
}
