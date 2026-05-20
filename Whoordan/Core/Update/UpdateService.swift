import Foundation

struct WhoordanAppBuild: Equatable {
    let version: String
    let build: String

    static func current(bundle: Bundle = .main) -> WhoordanAppBuild {
        WhoordanAppBuild(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )
    }

    func isNewer(than current: WhoordanAppBuild) -> Bool {
        let versionComparison = Self.compareVersion(version, current.version)
        if versionComparison != 0 {
            return versionComparison > 0
        }
        return Self.compareVersion(build, current.build) > 0
    }

    static func compareVersion(_ left: String, _ right: String) -> Int {
        let leftParts = left.split(separator: ".").map(String.init)
        let rightParts = right.split(separator: ".").map(String.init)
        let count = max(leftParts.count, rightParts.count)
        for index in 0..<count {
            let leftValue = numericValue(leftParts[safe: index] ?? "0")
            let rightValue = numericValue(rightParts[safe: index] ?? "0")
            if leftValue != rightValue {
                return leftValue > rightValue ? 1 : -1
            }
        }
        return 0
    }

    private static func numericValue(_ value: String) -> Int {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}

struct WhoordanUpdate: Equatable, Identifiable {
    let bundleIdentifier: String
    let version: String
    let build: String
    let minimumOS: String
    let releaseNotes: String
    let installURL: URL

    var id: String {
        "\(version)-\(build)"
    }

    var appBuild: WhoordanAppBuild {
        WhoordanAppBuild(version: version, build: build)
    }
}

enum UpdateCheckResult: Equatable {
    case none
    case available(WhoordanUpdate)
}

protocol UpdateServicing {
    func checkForUpdate(currentBuild: WhoordanAppBuild, bundleIdentifier: String) async -> UpdateCheckResult
}

struct NoopUpdateService: UpdateServicing {
    func checkForUpdate(currentBuild: WhoordanAppBuild, bundleIdentifier: String) async -> UpdateCheckResult {
        .none
    }
}

enum UpdateCheckPolicy {
    static let disableEnvironmentKey = "WHOORDAN_DISABLE_UPDATE_CHECKS"
    static let xctestConfigurationKey = "XCTestConfigurationFilePath"

    static func isAutomaticCheckEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let rawValue = environment[disableEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if rawValue == "1" || rawValue == "true" || rawValue == "yes" {
            return false
        }
        return environment[xctestConfigurationKey] == nil
    }
}

struct DefaultUpdateService: UpdateServicing {
    private let manifestURL: URL
    private let httpClient: HTTPClienting
    private let currentOSVersion: String

    init(
        manifestURL: URL = URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
        httpClient: HTTPClienting = URLSession.shared,
        currentOSVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) {
        self.manifestURL = manifestURL
        self.httpClient = httpClient
        self.currentOSVersion = currentOSVersion
    }

    func checkForUpdate(currentBuild: WhoordanAppBuild, bundleIdentifier: String) async -> UpdateCheckResult {
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await httpClient.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let manifest = try? JSONDecoder.whoordan.decode(UpdateManifestPayload.self, from: data),
                  manifest.bundleIdentifier == bundleIdentifier,
                  let installURL = URL(string: manifest.installUrl),
                  Self.isOSVersion(currentOSVersion, compatibleWithMinimum: manifest.minimumOS)
            else {
                return .none
            }

            let update = WhoordanUpdate(
                bundleIdentifier: manifest.bundleIdentifier,
                version: manifest.version,
                build: manifest.build,
                minimumOS: manifest.minimumOS,
                releaseNotes: manifest.releaseNotes,
                installURL: installURL
            )
            return update.appBuild.isNewer(than: currentBuild) ? .available(update) : .none
        } catch {
            return .none
        }
    }

    static func isOSVersion(_ current: String, compatibleWithMinimum minimum: String) -> Bool {
        let cleanedCurrent = current
            .replacingOccurrences(of: "Version ", with: "")
            .split(separator: " ")
            .first
            .map(String.init) ?? current
        return WhoordanAppBuild.compareVersion(cleanedCurrent, minimum) >= 0
    }
}

private struct UpdateManifestPayload: Decodable {
    let bundleIdentifier: String
    let version: String
    let build: String
    let minimumOS: String
    let releaseNotes: String
    let installUrl: String
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
