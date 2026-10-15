import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var serverURLString: String {
        didSet { UserDefaults.standard.set(serverURLString, forKey: "serverURL") }
    }
    @Published var syncEnabled: Bool {
        didSet { UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled") }
    }

    var serverURL: URL? {
        guard !serverURLString.isEmpty else { return nil }
        return URL(string: serverURLString)
    }

    private init() {
        serverURLString = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        syncEnabled = UserDefaults.standard.object(forKey: "syncEnabled") as? Bool ?? true
    }
}
