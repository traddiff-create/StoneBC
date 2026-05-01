import Foundation

@Observable
class RideJournalService {
    static let shared = RideJournalService()

    private(set) var journals: [RideJournal] = []
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "rideJournals") {
        self.defaults = defaults
        self.key = key
        load()
    }

    func save(_ journal: RideJournal) {
        if let idx = journals.firstIndex(where: { $0.id == journal.id }) {
            journals[idx] = journal
        } else {
            journals.insert(journal, at: 0)
        }
        persist()
    }

    func delete(_ journal: RideJournal) {
        journals.removeAll { $0.id == journal.id }
        persist()
    }

    func journal(forRideId id: String) -> RideJournal? {
        journals.first { $0.rideId == id }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RideJournal].self, from: data)
        else { return }
        journals = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(journals) else { return }
        defaults.set(data, forKey: key)
    }
}
