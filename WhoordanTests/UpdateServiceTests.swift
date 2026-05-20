import XCTest
@testable import Whoordan

final class UpdateServiceTests: XCTestCase {
    func testAutomaticUpdatePolicyCanBeDisabledForLocalValidation() {
        XCTAssertFalse(UpdateCheckPolicy.isAutomaticCheckEnabled(environment: ["WHOORDAN_DISABLE_UPDATE_CHECKS": "1"]))
        XCTAssertFalse(UpdateCheckPolicy.isAutomaticCheckEnabled(environment: ["WHOORDAN_DISABLE_UPDATE_CHECKS": "true"]))
        XCTAssertFalse(UpdateCheckPolicy.isAutomaticCheckEnabled(
            environment: ["XCTestConfigurationFilePath": "/tmp/whoordan.xctestconfiguration"]
        ))
        XCTAssertTrue(UpdateCheckPolicy.isAutomaticCheckEnabled(environment: [:]))
    }

    func testVersionComparisonUsesVersionBeforeBuild() {
        XCTAssertTrue(WhoordanAppBuild(version: "1.2.3", build: "1").isNewer(than: WhoordanAppBuild(version: "1.2.2", build: "999")))
        XCTAssertTrue(WhoordanAppBuild(version: "1.2.3", build: "124").isNewer(than: WhoordanAppBuild(version: "1.2.3", build: "123")))
        XCTAssertFalse(WhoordanAppBuild(version: "1.2.3", build: "123").isNewer(than: WhoordanAppBuild(version: "1.2.3", build: "123")))
    }

    func testMinimumOSBlocksIncompatibleUpdates() async throws {
        let service = DefaultUpdateService(
            manifestURL: URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
            httpClient: UpdateStubHTTPClient(data: manifestJSON(minimumOS: "18.0")),
            currentOSVersion: "17.5"
        )

        let result = await service.checkForUpdate(
            currentBuild: WhoordanAppBuild(version: "1.0.0", build: "1"),
            bundleIdentifier: "com.w4rd2.whoordan"
        )

        XCTAssertEqual(result, .none)
    }

    func testMalformedManifestFailsClosed() async throws {
        let service = DefaultUpdateService(
            manifestURL: URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
            httpClient: UpdateStubHTTPClient(data: Data(#"{"version": false}"#.utf8)),
            currentOSVersion: "17.5"
        )

        let result = await service.checkForUpdate(
            currentBuild: WhoordanAppBuild(version: "1.0.0", build: "1"),
            bundleIdentifier: "com.w4rd2.whoordan"
        )

        XCTAssertEqual(result, .none)
    }

    func testNoUpdateWhenManifestBuildIsCurrent() async throws {
        let service = DefaultUpdateService(
            manifestURL: URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
            httpClient: UpdateStubHTTPClient(data: manifestJSON(version: "1.2.3", build: "123")),
            currentOSVersion: "17.5"
        )

        let result = await service.checkForUpdate(
            currentBuild: WhoordanAppBuild(version: "1.2.3", build: "123"),
            bundleIdentifier: "com.w4rd2.whoordan"
        )

        XCTAssertEqual(result, .none)
    }

    func testUpdateAvailableForNewerCompatibleBuild() async throws {
        let service = DefaultUpdateService(
            manifestURL: URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
            httpClient: UpdateStubHTTPClient(data: manifestJSON(
                version: "1.2.3",
                build: "124",
                releaseNotes: "Better recovery trend clarity."
            )),
            currentOSVersion: "17.5"
        )

        let result = await service.checkForUpdate(
            currentBuild: WhoordanAppBuild(version: "1.2.3", build: "123"),
            bundleIdentifier: "com.w4rd2.whoordan"
        )

        guard case .available(let update) = result else {
            return XCTFail("Expected update to be available.")
        }
        XCTAssertEqual(update.version, "1.2.3")
        XCTAssertEqual(update.build, "124")
        XCTAssertEqual(update.releaseNotes, "Better recovery trend clarity.")
        XCTAssertEqual(update.installURL.absoluteString, "https://whoordan.w4rd2.tech/update")
    }

    func testUpdateCheckRequestSendsNoHealthDataAnalyticsOrUserIdentifiers() async throws {
        let httpClient = UpdateStubHTTPClient(data: manifestJSON(version: "1.2.3", build: "124"))
        let service = DefaultUpdateService(
            manifestURL: URL(string: "https://whoordan.w4rd2.tech/api/update-manifest")!,
            httpClient: httpClient,
            currentOSVersion: "17.5"
        )

        _ = await service.checkForUpdate(
            currentBuild: WhoordanAppBuild(version: "1.0.0", build: "1"),
            bundleIdentifier: "com.w4rd2.whoordan"
        )

        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-User-ID"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Analytics-ID"))
    }
}

private func manifestJSON(
    bundleIdentifier: String = "com.w4rd2.whoordan",
    version: String = "1.2.3",
    build: String = "123",
    minimumOS: String = "17.0",
    releaseNotes: String = "Release notes.",
    installURL: String = "https://whoordan.w4rd2.tech/update"
) -> Data {
    Data("""
    {
      "bundleIdentifier": "\(bundleIdentifier)",
      "version": "\(version)",
      "build": "\(build)",
      "minimumOS": "\(minimumOS)",
      "releaseNotes": "\(releaseNotes)",
      "installUrl": "\(installURL)"
    }
    """.utf8)
}

private final class UpdateStubHTTPClient: HTTPClienting {
    private let data: Data
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://whoordan.w4rd2.tech")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
