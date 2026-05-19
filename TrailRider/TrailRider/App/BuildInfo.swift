import Foundation

enum BuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "0"
    }

    static var gitCommit: String? {
        guard let url = Bundle.main.url(forResource: "GitCommit", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value != "unknown" else {
            return nil
        }
        return value
    }

    static var displayString: String {
        if let gitCommit {
            return "\(version) (\(build)) · \(gitCommit)"
        }
        return "\(version) (\(build))"
    }
}
