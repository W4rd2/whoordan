import XCTest

final class ProjectArchitectureTests: XCTestCase {
    func testXcodeNavigatorMirrorsSwiftAppBoundaries() throws {
        let project = try String(
            contentsOf: projectRoot().appendingPathComponent("Whoordan.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let requiredGroups = [
            "/* App */ = {",
            "/* Core */ = {",
            "/* DesignSystem */ = {",
            "/* Features */ = {",
            "/* Resources */ = {"
        ]

        for group in requiredGroups {
            XCTAssertTrue(project.contains(group), "Xcode project navigator should expose \(group).")
        }

        let appGroup = try xcodeGroup(named: "Whoordan", in: project)
        for child in ["/* App */", "/* Core */", "/* DesignSystem */", "/* Features */", "/* Resources */"] {
            XCTAssertTrue(appGroup.contains(child), "Whoordan group should contain nested \(child) group.")
        }
        XCTAssertFalse(appGroup.contains("/* AppEnvironment.swift */"), "App files should be nested under the App group.")
        XCTAssertFalse(appGroup.contains("/* SupabaseClient.swift */"), "Core files should be nested under the Core group.")
        XCTAssertFalse(appGroup.contains("/* TodayView.swift */"), "Feature files should be nested under the Features group.")
    }

    private func xcodeGroup(named name: String, in project: String) throws -> Substring {
        let marker = "/* \(name) */ = {"
        guard
            let groupStart = project.range(of: marker),
            let groupEnd = project[groupStart.upperBound...].range(of: "};")
        else {
            throw XCTSkip("Missing Xcode group \(name).")
        }
        return project[groupStart.upperBound..<groupEnd.lowerBound]
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
