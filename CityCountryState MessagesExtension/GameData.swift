import Foundation

enum GameMode {
    case classic
    case battle
}

struct GameData {
    static var allCities = Set<String>()
    static var allCountries = Set<String>()
    static var allStates = Set<String>()
    
    static func loadData() {
        if let url = Bundle.main.url(forResource: "place_data", withExtension: "plist") {
            if let data = try? Data(contentsOf: url),
               let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: [String]] {
                allCities = Set((dict["cities"] ?? []).map { $0.lowercased() })
                allCountries = Set((dict["countries"] ?? []).map { $0.lowercased() })
                allStates = Set((dict["states"] ?? []).map { $0.lowercased() })
            }
        }
    }
}
