import XCTest
@testable import Whoordan

final class SupabaseConfigTests: XCTestCase {
    func testProjectIDAndPublishableKeyAreEnoughToConfigureClient() {
        let bundle = BundleStub(values: [
            "SUPABASE_PROJECT_ID": "exampleprojectid",
            "WHOORDAN_SUPABASE_PUBLISHABLE_KEY": "publishable-test-key"
        ])

        let config = SupabaseConfig.fromBundle(bundle)

        XCTAssertEqual(config.url?.absoluteString, "https://exampleprojectid.supabase.co")
        XCTAssertEqual(config.projectID, "exampleprojectid")
        XCTAssertEqual(config.publishableKey, "publishable-test-key")
        XCTAssertTrue(config.isConfigured)
    }

    func testSecretOrServiceRoleSupabaseKeysDoNotConfigureClient() {
        let serviceRolePayload = Data(#"{"role":"service_role"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let serviceRoleJWT = "header.\(serviceRolePayload).signature"

        for forbiddenKey in ["sb_secret_example", serviceRoleJWT] {
            let bundle = BundleStub(values: [
                "SUPABASE_PROJECT_ID": "exampleprojectid",
                "WHOORDAN_SUPABASE_PUBLISHABLE_KEY": forbiddenKey
            ])

            let config = SupabaseConfig.fromBundle(bundle)

            XCTAssertNil(config.publishableKey)
            XCTAssertFalse(config.isConfigured)
        }
    }

    func testExplicitURLOverridesDerivedProjectURL() {
        let bundle = BundleStub(values: [
            "SUPABASE_PROJECT_ID": "exampleprojectid",
            "WHOORDAN_SUPABASE_URL": "https://custom.example.test",
            "WHOORDAN_SUPABASE_PUBLISHABLE_KEY": "publishable-test-key"
        ])

        let config = SupabaseConfig.fromBundle(bundle)

        XCTAssertEqual(config.url?.absoluteString, "https://custom.example.test")
        XCTAssertTrue(config.isConfigured)
    }

    func testHostlessExplicitURLFallsBackToProjectDerivedURL() {
        let bundle = BundleStub(values: [
            "SUPABASE_PROJECT_ID": "exampleprojectid",
            "WHOORDAN_SUPABASE_URL": "https:",
            "WHOORDAN_SUPABASE_PUBLISHABLE_KEY": "publishable-test-key"
        ])

        let config = SupabaseConfig.fromBundle(bundle)

        XCTAssertEqual(config.url?.absoluteString, "https://exampleprojectid.supabase.co")
        XCTAssertTrue(config.isConfigured)
    }

    func testInvalidExplicitURLDoesNotMarkClientConfiguredWithoutProjectFallback() {
        let bundle = BundleStub(values: [
            "WHOORDAN_SUPABASE_URL": "https:",
            "WHOORDAN_SUPABASE_PUBLISHABLE_KEY": "publishable-test-key"
        ])

        let config = SupabaseConfig.fromBundle(bundle)

        XCTAssertNil(config.url)
        XCTAssertFalse(config.isConfigured)
    }

    func testHealthSyncServiceUsesInjectedHTTPClientAndBuildsSupabaseUpsertRequest() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/health_samples"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
        let sampleDate = Date(timeIntervalSince1970: 12_345)
        let sample = HealthSample(
            id: "sample-1",
            type: .heartRate,
            value: 64,
            unit: "count/min",
            startDate: sampleDate,
            endDate: nil,
            source: .appleHealth,
            sourceRecordID: "source-record-1",
            confidence: .high,
            metadata: [:]
        )

        let result = await service.uploadHealthSamples(
            [sample],
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        )

        XCTAssertEqual(result.status, .uploaded)
        XCTAssertEqual(httpClient.requests.count, 1)
        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")
        XCTAssertEqual(request.url?.host, "exampleprojectid.supabase.co")
        XCTAssertEqual(request.url?.path, "/rest/v1/health_samples")
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "on_conflict" })?
                .value,
            "user_id,dedupe_key"
        )

        let body = try XCTUnwrap(request.httpBody)
        let rows = try JSONDecoder.whoordan.decode([HealthSampleRow].self, from: body)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.userID, userID)
        XCTAssertNotEqual(rows.first?.dedupeKey, sample.dedupeID)
        let sourceRecordID = try XCTUnwrap(rows.first?.sourceRecordID)
        XCTAssertFalse(sourceRecordID.contains(sample.sourceRecordID))
    }

    func testHealthSyncServiceUploadsDailySummaryCacheToSupabase() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
        var summary = DailyHealthSummary.empty
        summary.date = Date(timeIntervalSince1970: 86_400)
        summary.sleepMinutes = 420
        summary.sleepNeedMinutes = 480
        summary.sleepDebtMinutes = 60
        summary.movement.walkingRunningDistanceMeters = 1_600
        summary.movement.movementMinutes = 42
        summary.movement.source = .wearableBLE
        summary.hrv = 55
        summary.hrvSource = .wearableBLE
        summary.hrvConfidence = .high
        summary.oxygenSaturation = 96.5
        summary.oxygenSaturationSource = .whoordanEstimate
        summary.oxygenSaturationConfidence = .low
        summary.rawWristTemperatureC = 31.25
        summary.rawWristTemperatureSource = .wearableBLE
        summary.rawWristTemperatureConfidence = .high
        summary.bodyTemperatureDelta = -0.4
        summary.confidence = .medium
        let readyMetric = WhoordanMetricSnapshot(
            id: .sleepDuration,
            title: "Sleep duration",
            value: "7h 0m",
            unit: nil,
            source: .direct,
            confidence: .medium,
            readiness: .showNow,
            accuracySummary: nil,
            accuracyDetail: nil,
            requirements: [],
            calibrationSummary: nil,
            lastUpdated: summary.date,
            unavailableReason: nil,
            context: "Ready for display",
            symbol: "moon"
        )

        let result = await service.uploadDailySummary(
            summary,
            metricSnapshots: [readyMetric],
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        )

        XCTAssertEqual(result.status, .uploaded)
        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/rest/v1/daily_health_summaries")
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "on_conflict" })?
                .value,
            "user_id,summary_date"
        )
        let body = try XCTUnwrap(request.httpBody)
        let rows = try JSONDecoder.whoordan.decode([DailyHealthSummaryRow].self, from: body)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.userID, userID)
        XCTAssertEqual(rows.first?.summaryDate, "1970-01-02")
        XCTAssertEqual(rows.first?.sleepSeconds, 25_200)
        XCTAssertEqual(rows.first?.metadata["sleep_need_minutes"], "480.0")
        XCTAssertEqual(rows.first?.metadata["distance_m"], "1600.0")
        XCTAssertEqual(rows.first?.metadata["movement_minutes"], "42.0")
        XCTAssertEqual(rows.first?.metadata["hrv_ms"], "55.0")
        XCTAssertEqual(rows.first?.metadata["hrv_source"], DataSource.wearableBLE.rawValue)
        XCTAssertEqual(rows.first?.metadata["oxygen_saturation_percent"], "96.5")
        XCTAssertEqual(rows.first?.metadata["oxygen_saturation_confidence"], ConfidenceLevel.low.rawValue)
        XCTAssertEqual(rows.first?.metadata["raw_wrist_temperature_c"], "31.25")
        XCTAssertEqual(rows.first?.metadata["skin_temperature_delta_c"], "-0.40")
        XCTAssertEqual(rows.first?.metricPayloadVersion, 1)
        XCTAssertEqual(rows.first?.summaryPayload.sleepMinutes, 420)
        XCTAssertEqual(rows.first?.readyMetricSnapshots, [readyMetric])
    }

    func testHealthSyncServiceDoesNotUploadEmptyDailySummaryCache() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
        var summary = DailyHealthSummary.empty
        summary.date = Date(timeIntervalSince1970: 86_400)

        let result = await service.uploadDailySummary(
            summary,
            metricSnapshots: [],
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        )

        XCTAssertEqual(result.status, .nothingToSync)
        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testHealthSyncServiceFetchesRecentMetricSummariesWithConsent() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
        var summary = DailyHealthSummary.empty
        summary.date = Date(timeIntervalSince1970: 86_400)
        summary.movement.steps = 8_432
        summary.sleepMinutes = 390
        summary.hrv = 61
        summary.confidence = .high
        let row = SupabaseHealthSyncService.makeDailySummaryRow(
            summary,
            metricSnapshots: [],
            userID: userID,
            syncedAt: Date(timeIntervalSince1970: 90_000)
        )
        let httpClient = CapturingHTTPClient(data: try JSONEncoder.whoordan.encode([row]), response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentDailySummaries(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        XCTAssertEqual(result.summaries.count, 1)
        XCTAssertEqual(result.summaries.first?.movement.steps, 8_432)
        XCTAssertEqual(result.summaries.first?.sleepMinutes, 390)
        XCTAssertEqual(result.summaries.first?.hrv, 61)
        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/rest/v1/daily_health_summaries")
        let queryItems = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(queryItems.first(where: { $0.name == "user_id" })?.value, "eq.\(userID.uuidString)")
        XCTAssertEqual(queryItems.first(where: { $0.name == "summary_date" })?.value, "gte.1970-01-01")
    }

    func testHealthSyncServiceBlocksCloudRestoreWithOfflineApprovedAccess() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
        let httpClient = CapturingHTTPClient(data: Data("[]".utf8), response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let session = AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil)
        let approval = ApprovalState(status: .offlineApproved, message: "Offline", checkedAt: Date(timeIntervalSince1970: 90_000))
        let consent = ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)

        let summaryResult = await service.fetchRecentDailySummaries(
            session: session,
            approval: approval,
            consent: consent,
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )
        let sampleResult = await service.fetchRecentHealthSamples(
            session: session,
            approval: approval,
            consent: consent,
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(summaryResult.status, .blocked)
        XCTAssertEqual(sampleResult.status, .blocked)
        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testHealthSyncServiceFallbackMetricSummaryPreservesAllMetricMetadata() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000003"))
        let data = Data("""
        [{
          "summary_date": "1970-01-02",
          "recovery_score": null,
          "sleep_seconds": 25200,
          "strain": null,
          "confidence": 0.75,
          "source": "wearable_ble",
          "metadata": {
            "sleep_need_minutes": "480",
            "sleep_debt_minutes": "60",
            "average_heart_rate_bpm": "68.5",
            "heart_rate_sample_count": "24",
            "hrv_ms": "55",
            "hrv_source": "wearable_ble",
            "hrv_confidence": "high",
            "oxygen_saturation_percent": "96.5",
            "oxygen_saturation_source": "whoordan_estimate",
            "oxygen_saturation_confidence": "low",
            "raw_wrist_temperature_c": "31.25",
            "raw_wrist_temperature_source": "wearable_ble",
            "raw_wrist_temperature_confidence": "high",
            "skin_temperature_delta_c": "-0.40",
            "steps": "8432",
            "active_energy_kcal": "320.5",
            "distance_m": "1600",
            "movement_minutes": "42",
            "movement_source": "wearable_ble"
          },
          "summary_payload": {},
          "ready_metric_snapshots": [],
          "metric_payload_version": 1,
          "last_synced_at": "1970-01-02T01:00:00Z"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentDailySummaries(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.summaries.first)
        XCTAssertEqual(restored.sleepMinutes, 420)
        XCTAssertEqual(restored.sleepNeedMinutes, 480)
        XCTAssertEqual(restored.sleepDebtMinutes, 60)
        XCTAssertEqual(restored.averageHeartRate, 68.5)
        XCTAssertEqual(restored.heartRateSampleCount, 24)
        XCTAssertEqual(restored.hrv, 55)
        XCTAssertEqual(restored.hrvSource, .wearableBLE)
        XCTAssertEqual(restored.hrvConfidence, .high)
        XCTAssertEqual(restored.oxygenSaturation, 96.5)
        XCTAssertEqual(restored.oxygenSaturationSource, .whoordanEstimate)
        XCTAssertEqual(restored.oxygenSaturationConfidence, .low)
        XCTAssertEqual(restored.rawWristTemperatureC, 31.25)
        XCTAssertEqual(restored.rawWristTemperatureSource, .wearableBLE)
        XCTAssertEqual(restored.rawWristTemperatureConfidence, .high)
        XCTAssertEqual(restored.bodyTemperatureDelta, -0.40)
        XCTAssertEqual(restored.movement.steps, 8_432)
        XCTAssertEqual(restored.movement.activeEnergyKilocalories, 320.5)
        XCTAssertEqual(restored.movement.walkingRunningDistanceMeters, 1_600)
        XCTAssertEqual(restored.movement.movementMinutes, 42)
        XCTAssertEqual(restored.movement.source, .wearableBLE)
    }

    func testHealthSyncServiceRestoresSupabaseSleepSummaryRowWithEmptyPayload() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000004"))
        let data = Data("""
        [{
          "summary_date": "2026-05-17",
          "recovery_score": null,
          "sleep_seconds": 30720,
          "strain": null,
          "confidence": 0.35,
          "source": "whoordan_estimate",
          "metadata": {
            "confidence": "low",
            "metric_policy": "r10_hr_imu_sleep_stage_estimate",
            "asleep_minutes": "512",
            "average_heart_rate_bpm": "67.4"
          },
          "summary_payload": {},
          "ready_metric_snapshots": [],
          "metric_payload_version": 1,
          "last_synced_at": "2026-05-17T09:47:12.320282+00:00"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentDailySummaries(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.summaries.first)
        XCTAssertEqual(restored.sleepMinutes, 512)
        XCTAssertEqual(restored.averageHeartRate, 67.4)
        XCTAssertEqual(restored.source, .whoordanEstimate)
        XCTAssertEqual(restored.confidence, .low)
    }

    func testHealthSyncServiceMergesTopLevelSleepIntoExistingSummaryPayload() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000004"))
        let data = Data("""
        [{
          "summary_date": "2026-05-16",
          "recovery_score": null,
          "sleep_seconds": 14400,
          "strain": null,
          "confidence": 0.75,
          "source": "wearable_ble",
          "metadata": {
            "confidence": "medium",
            "max_heart_rate_bpm": "93.0",
            "average_heart_rate_bpm": "92.8"
          },
          "summary_payload": {
            "date": "2026-05-16T21:00:00Z",
            "source": "wearable_ble",
            "movement": {
              "goal": 10000,
              "confidence": "unavailable",
              "lastUpdated": "2026-05-17T10:07:53Z"
            },
            "confidence": "medium",
            "averageHeartRate": 92.75,
            "heartRateSampleCount": 8
          },
          "ready_metric_snapshots": [],
          "metric_payload_version": 1,
          "last_synced_at": "2026-05-17 10:07:57+00"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentDailySummaries(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.summaries.first)
        XCTAssertEqual(restored.sleepMinutes, 240)
        XCTAssertEqual(restored.averageHeartRate, 92.75)
        XCTAssertEqual(restored.maxHeartRate, 93)
        XCTAssertEqual(restored.source, .wearableBLE)
        XCTAssertEqual(restored.confidence, .medium)
    }

    func testHealthSyncServiceFetchesRecentHealthSamplesWithConsent() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/health_samples"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let sampleDate = Date(timeIntervalSince1970: 172_800)
        let sample = HealthSample(
            id: "wearable-sample-1",
            type: .steps,
            value: 1_234,
            unit: "count",
            startDate: sampleDate,
            endDate: nil,
            source: .whoordanEstimate,
            sourceRecordID: "r10:steps:1",
            confidence: .low,
            metadata: ["metric_policy": "r10_imu_motion_step_estimate"]
        )
        let legacyAppleLabelledSample = HealthSample(
            id: "legacy-apple-labelled-1",
            type: .heartRate,
            value: 61,
            unit: "bpm",
            startDate: sampleDate.addingTimeInterval(60),
            endDate: nil,
            source: .appleHealth,
            sourceRecordID: "legacy-wearable-export-heart-rate",
            confidence: .high,
            metadata: ["source_label": "Apple Health"]
        )
        let rows = SupabaseHealthSyncService.makeHealthSampleRows(
            [sample, legacyAppleLabelledSample],
            userID: userID,
            syncedAt: Date(timeIntervalSince1970: 180_000)
        )
        let httpClient = CapturingHTTPClient(data: try JSONEncoder.whoordan.encode(rows), response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentHealthSamples(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.samples.first)
        XCTAssertEqual(restored.type, .steps)
        XCTAssertEqual(restored.value, 1_234)
        XCTAssertEqual(restored.source, .whoordanEstimate)
        XCTAssertEqual(restored.confidence, .low)
        XCTAssertEqual(restored.metadata["cloud_restored"], "true")
        XCTAssertEqual(restored.metadata["metric_policy"], "r10_imu_motion_step_estimate")
        let legacyRestored = try XCTUnwrap(result.samples.last)
        XCTAssertEqual(legacyRestored.source, .legacyWearableDeviceExport)
        XCTAssertEqual(legacyRestored.metadata["legacy_wearable_device_export"], "true")
        XCTAssertEqual(legacyRestored.metadata["cloud_original_source"], DataSource.appleHealth.rawValue)
        XCTAssertEqual(legacyRestored.metadata["source_label"], DataSource.legacyWearableDeviceExport.label)
        XCTAssertGreaterThanOrEqual(httpClient.requests.count, 5)
        XCTAssertTrue(httpClient.requests.allSatisfy { $0.httpMethod == "GET" })
        XCTAssertTrue(httpClient.requests.allSatisfy { $0.url?.path == "/rest/v1/health_samples" })
        let queryItems = URLComponents(url: try XCTUnwrap(httpClient.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(queryItems.first(where: { $0.name == "user_id" })?.value, "eq.\(userID.uuidString)")
        XCTAssertEqual(queryItems.first(where: { $0.name == "sync_status" })?.value, "eq.synced")
        XCTAssertEqual(queryItems.first(where: { $0.name == "order" })?.value, "sampled_at.desc")
        XCTAssertEqual(queryItems.first(where: { $0.name == "deleted_at" })?.value, "is.null")
        XCTAssertTrue(httpClient.requests.contains { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return items.first(where: { $0.name == "sample_type" })?.value?.contains("sleepAnalysis") == true
        })
        XCTAssertTrue(httpClient.requests.contains { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return items.first(where: { $0.name == "sample_type" })?.value?.contains("oxygenSaturation") == true
        })
    }

    func testHealthSyncServiceRestoresSampleWithMissingSourceRecordID() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/health_samples"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let row = HealthSampleRow(
            userID: userID,
            sampleType: HealthSampleType.steps.rawValue,
            value: 42,
            unit: "count",
            sampledAt: Date(timeIntervalSince1970: 172_800),
            endedAt: nil,
            source: DataSource.whoordanEstimate.rawValue,
            sourceRecordID: nil,
            metadata: [
                "confidence": ConfidenceLevel.low.rawValue,
                "device_only_derivation": "true",
                "metric_policy": "r10_imu_motion_step_estimate"
            ],
            dedupeKey: "cloud-null-source-record",
            syncStatus: "synced",
            lastSyncedAt: Date(timeIntervalSince1970: 180_000)
        )
        let httpClient = CapturingHTTPClient(data: try JSONEncoder.whoordan.encode([row]), response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentHealthSamples(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.samples.first)
        XCTAssertEqual(restored.sourceRecordID, "cloud:cloud-null-source-record")
        XCTAssertEqual(restored.metadata["cloud_dedupe_key"], "cloud-null-source-record")
    }

    func testHealthSyncServiceRestoresLegacySampleTypeAndLossyMetadata() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/health_samples"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000007"))
        let data = Data("""
        [{
          "user_id": "\(userID.uuidString)",
          "sample_type": "heart_rate",
          "value": 72,
          "unit": "bpm",
          "sampled_at": "1970-01-03T00:00:00Z",
          "ended_at": null,
          "source": "wearable_live",
          "source_record_id": "remote-heart-rate",
          "metadata": {
            "confidence": "high",
            "sequence": 42,
            "confirmed": true
          },
          "dedupe_key": "legacy-heart-rate-dedupe",
          "sync_status": "synced",
          "last_synced_at": "1970-01-03T00:01:00Z"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentHealthSamples(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.samples.first)
        XCTAssertEqual(restored.type, .heartRate)
        XCTAssertEqual(restored.source, .wearableBLE)
        XCTAssertEqual(restored.confidence, .high)
        XCTAssertEqual(restored.metadata["cloud_original_sample_type"], "heart_rate")
        XCTAssertEqual(restored.metadata["cloud_original_source"], "wearable_live")
        XCTAssertEqual(restored.metadata["sequence"], "42")
        XCTAssertEqual(restored.metadata["confirmed"], "true")
    }

    func testHealthSyncServiceRestoresSupabaseFractionalTimestamps() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/health_samples"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000008"))
        let data = Data("""
        [{
          "user_id": "\(userID.uuidString)",
          "sample_type": "sleepAnalysis",
          "value": 60,
          "unit": "min",
          "sampled_at": "2026-05-17T07:22:00.123456+00:00",
          "ended_at": "2026-05-17T08:22:00.654321+00:00",
          "source": "whoordan_estimate",
          "source_record_id": "remote-sleep",
          "metadata": {
            "sleep_category": "1",
            "confidence": "low"
          },
          "dedupe_key": "fractional-sleep-dedupe",
          "sync_status": "synced",
          "last_synced_at": "2026-05-17T09:47:12.320282+00:00"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentHealthSamples(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .restored)
        let restored = try XCTUnwrap(result.samples.first)
        XCTAssertEqual(restored.type, .sleepAnalysis)
        XCTAssertEqual(restored.value, 60)
        XCTAssertEqual(restored.startDate.timeIntervalSince1970, 1_779_002_520.123, accuracy: 0.01)
        XCTAssertEqual(restored.endDate?.timeIntervalSince1970 ?? 0, 1_779_006_120.654, accuracy: 0.01)
    }

    func testHealthSyncServiceDoesNotFetchMetricSummariesWithoutCloudSync() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/daily_health_summaries"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseHealthSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let result = await service.fetchRecentDailySummaries(
            session: AuthSession(userID: UUID(), email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false),
            since: Date(timeIntervalSince1970: 0),
            limit: 30
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testAccountSyncUploadsProfileAndSettingsWithoutHealthDataCloudConsent() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000003"))
        let birthDate = try XCTUnwrap(Self.utcCalendar.date(from: DateComponents(year: 1996, month: 5, day: 24)))
        let alarmID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000301"))
        let callSettings = CallVibrationSettings(enabled: true, patternID: VibrationPattern.standardID)
        let snapshot = AccountSyncSnapshot(
            email: "member@example.test",
            bodyProfile: BodyProfile(
                birthDate: birthDate,
                biologicalSex: .male,
                heightCentimeters: 181,
                weightKilograms: 82,
                configuredMaxHeartRate: 190
            ),
            consentState: ConsentState(
                cloudSyncEnabled: false,
                healthDataCloudConsent: false,
                appleHealthEnabled: true,
                cloudSyncPromptDismissed: true
            ),
            skinTemperatureBaselineProfile: SkinTemperatureBaselineProfile(
                activeBaselineC: 34.0,
                source: .temporaryCustom,
                eligibleDayCount: 3,
                requiredDayCount: 5,
                updatedAt: Date(timeIntervalSince1970: 1_700_000_001)
            ),
            callVibrationSettings: callSettings,
            alarms: [Alarm(id: alarmID, label: "Morning", enabled: true, hour: 7, minute: 15)],
            themePreference: "dark",
            movementGoal: 12_000,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let result = await service.uploadAccountSnapshot(
            snapshot,
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved()
        )

        XCTAssertEqual(result.status, .synced)
        XCTAssertEqual(httpClient.requests.count, 2)
        let profileRequest = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(profileRequest.httpMethod, "POST")
        XCTAssertEqual(profileRequest.url?.path, "/rest/v1/user_profiles")
        XCTAssertEqual(profileRequest.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        let profileJSON = try XCTUnwrap(Self.firstJSONObject(from: profileRequest))
        XCTAssertEqual(profileJSON["user_id"] as? String, userID.uuidString)
        XCTAssertEqual(profileJSON["birth_date"] as? String, "1996-05-24")
        XCTAssertEqual(profileJSON["biological_sex"] as? String, "male")
        XCTAssertEqual(profileJSON["height_centimeters"] as? Double, 181)
        XCTAssertEqual(profileJSON["weight_kilograms"] as? Double, 82)

        let settingsRequest = try XCTUnwrap(httpClient.requests.last)
        XCTAssertEqual(settingsRequest.httpMethod, "POST")
        XCTAssertEqual(settingsRequest.url?.path, "/rest/v1/user_settings")
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(settingsRequest.url), resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "on_conflict" })?
                .value,
            "user_id"
        )
        let settingsJSON = try XCTUnwrap(Self.firstJSONObject(from: settingsRequest))
        XCTAssertEqual(settingsJSON["apple_health_enabled"] as? Bool, true)
        XCTAssertEqual(settingsJSON["health_cloud_sync_enabled"] as? Bool, false)
        XCTAssertNil(settingsJSON["baseline_profiles"])
        let syncPreferences = try XCTUnwrap(settingsJSON["sync_preferences"] as? [String: Any])
        XCTAssertEqual(syncPreferences["healthDataCloudConsent"] as? Bool, false)
        let callJSON = try XCTUnwrap(settingsJSON["call_vibration_settings"] as? [String: Any])
        XCTAssertEqual(callJSON["enabled"] as? Bool, true)
        let uiJSON = try XCTUnwrap(settingsJSON["ui_preferences"] as? [String: Any])
        XCTAssertEqual(uiJSON["themePreference"] as? String, "dark")
        XCTAssertEqual(uiJSON["movementGoal"] as? Int, 12_000)
        let wearableJSON = try XCTUnwrap(settingsJSON["wearable_device_configuration"] as? [String: Any])
        let alarms = try XCTUnwrap(wearableJSON["alarms"] as? [[String: Any]])
        XCTAssertEqual(alarms.first?["id"] as? String, alarmID.uuidString)
    }

    func testAccountDeletionRequestUsesUserJWTAndRLSBackedTable() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/account_deletion_requests"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000123"))

        let result = await service.requestAccountDeletion(
            session: AuthSession(
                userID: userID,
                email: "member@example.test",
                accessToken: "access-token",
                refreshToken: nil,
                expiresAt: nil
            )
        )

        XCTAssertEqual(result.status, .synced)
        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/rest/v1/account_deletion_requests")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-test-key")
        let json = try XCTUnwrap(Self.firstJSONObject(from: request))
        XCTAssertEqual(json["user_id"] as? String, userID.uuidString)
        XCTAssertEqual(json["email"] as? String, "member@example.test")
        XCTAssertEqual(json["status"] as? String, "pending")
    }

    func testAccountSyncRestoresPartialCallVibrationSettingsWithoutFreshTimestamp() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let data = Data("""
        [{
          "apple_health_enabled": false,
          "health_cloud_sync_enabled": true,
          "sync_preferences": {
            "localModeEnabled": true,
            "cloudSyncEnabled": true,
            "healthDataCloudConsent": true,
            "cloudSyncPromptDismissed": true
          },
          "apple_health_preferences": {
            "enabled": false
          },
          "call_vibration_settings": {
            "enabled": true
          },
          "ui_preferences": {
            "themePreference": "system",
            "movementGoal": 10000
          },
          "wearable_device_configuration": {
            "alarms": []
          },
          "updated_at": "2026-05-17T09:47:12Z"
        }]
        """.utf8)
        let httpClient = CapturingHTTPClient(data: data, response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        let snapshot = await service.fetchAccountSnapshot(
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            includeHealthBaselines: false
        )

        let settings = try XCTUnwrap(snapshot?.callVibrationSettings)
        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.patternID, VibrationPattern.standardID)
        XCTAssertEqual(settings.platformStatus, .normalCellularPlatformBlocked)
        XCTAssertEqual(settings.lastUpdatedAt, .distantPast)
    }

    func testAccountSyncFetchesSnapshotWithOfflineApprovedAccessButDoesNotUpload() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(data: Data("[]".utf8), response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let session = AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil)
        let approval = ApprovalState(status: .offlineApproved, message: "Offline", checkedAt: Date(timeIntervalSince1970: 90_000))

        _ = await service.fetchAccountSnapshot(
            session: session,
            approval: approval,
            includeHealthBaselines: false
        )
        let result = await service.uploadAccountSnapshot(
            AccountSyncSnapshot(
                email: "member@example.test",
                bodyProfile: BodyProfile(),
                consentState: ConsentState(cloudSyncEnabled: true),
                callVibrationSettings: CallVibrationSettings(),
                alarms: [],
                themePreference: "system",
                movementGoal: 10_000,
                updatedAt: Date(timeIntervalSince1970: 90_000)
            ),
            session: session,
            approval: approval
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(httpClient.requests.filter { $0.httpMethod == "GET" }.count, 2)
        XCTAssertFalse(httpClient.requests.contains { $0.httpMethod == "POST" })
    }

    func testAccountSyncUploadsBaselineProfilesWhenHealthDataCloudConsentIsEnabled() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 201, httpVersion: nil, headerFields: nil))
        let httpClient = CapturingHTTPClient(response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000004"))
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = AccountSyncSnapshot(
            email: "member@example.test",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true),
            skinTemperatureBaselineProfile: SkinTemperatureBaselineProfile(
                activeBaselineC: 33.7,
                source: .automatic,
                eligibleDayCount: 12,
                requiredDayCount: 5,
                updatedAt: updatedAt,
                automaticBaselineSetAt: updatedAt
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: "system",
            movementGoal: 10_000,
            updatedAt: updatedAt
        )

        let result = await service.uploadAccountSnapshot(
            snapshot,
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved()
        )

        XCTAssertEqual(result.status, .synced)
        XCTAssertEqual(httpClient.requests.count, 2)
        let settingsRequest = try XCTUnwrap(httpClient.requests.last)
        let settingsJSON = try XCTUnwrap(Self.firstJSONObject(from: settingsRequest))
        let baselines = try XCTUnwrap(settingsJSON["baseline_profiles"] as? [String: Any])
        let skin = try XCTUnwrap(baselines["skinTemperature"] as? [String: Any])
        XCTAssertEqual(skin["activeBaselineC"] as? Double, 33.7)
        XCTAssertEqual(skin["source"] as? String, "automatic")
        XCTAssertEqual(skin["eligibleDayCount"] as? Int, 12)
    }

    func testAccountSyncSurfacesSupabaseRejectionDetails() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 400, httpVersion: nil, headerFields: nil))
        let errorBody = Data("""
        {"code":"PGRST204","message":"Could not find the 'baseline_profiles' column of 'user_settings' in the schema cache"}
        """.utf8)
        let httpClient = CapturingHTTPClient(data: errorBody, response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let snapshot = AccountSyncSnapshot(
            email: "member@example.test",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(cloudSyncEnabled: true),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: "system",
            movementGoal: 10_000,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let result = await service.uploadAccountSnapshot(
            snapshot,
            session: AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil),
            approval: .approved()
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.message.contains("PGRST204"))
        XCTAssertTrue(result.message.contains("baseline_profiles"))
    }

    func testAccountSyncFetchesBaselineProfilesOnlyWhenRequested() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co"))
        let responseURL = try XCTUnwrap(URL(string: "https://exampleprojectid.supabase.co/rest/v1/user_settings"))
        let response = try XCTUnwrap(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        let userID = try XCTUnwrap(UUID(uuidString: "00000000-0000-4000-8000-000000000005"))
        let session = AuthSession(userID: userID, email: "member@example.test", accessToken: "access-token", refreshToken: nil, expiresAt: nil)

        let settingsSelectWithoutBaseline = try await userSettingsSelectQuery(
            baseURL: baseURL,
            response: response,
            session: session,
            includeHealthBaselines: false
        )
        XCTAssertFalse(settingsSelectWithoutBaseline.contains("baseline_profiles"))

        let settingsSelectWithBaseline = try await userSettingsSelectQuery(
            baseURL: baseURL,
            response: response,
            session: session,
            includeHealthBaselines: true
        )
        XCTAssertTrue(settingsSelectWithBaseline.contains("baseline_profiles"))
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func firstJSONObject(from request: URLRequest) throws -> [String: Any]? {
        guard let body = request.httpBody else { return nil }
        let array = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        return array?.first
    }

    private func userSettingsSelectQuery(
        baseURL: URL,
        response: HTTPURLResponse,
        session: AuthSession,
        includeHealthBaselines: Bool
    ) async throws -> String {
        let httpClient = CapturingHTTPClient(data: Data("[]".utf8), response: response)
        let service = SupabaseAccountSyncService(
            config: SupabaseConfig(url: baseURL, publishableKey: "publishable-test-key", projectID: "exampleprojectid"),
            httpClient: httpClient
        )

        _ = await service.fetchAccountSnapshot(
            session: session,
            approval: .approved(),
            includeHealthBaselines: includeHealthBaselines
        )

        let settingsRequest = try XCTUnwrap(httpClient.requests.first { $0.url?.path == "/rest/v1/user_settings" })
        let queryItems = URLComponents(url: try XCTUnwrap(settingsRequest.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        return try XCTUnwrap(queryItems.first(where: { $0.name == "select" })?.value)
    }
}

private final class BundleStub: Bundle, @unchecked Sendable {
    private let values: [String: String]

    init(values: [String: String]) {
        self.values = values
        super.init()
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}

private final class CapturingHTTPClient: HTTPClienting {
    private var capturedRequests: [URLRequest] = []
    private let lock = NSLock()
    private let data: Data
    private let response: URLResponse

    var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    init(data: Data = Data(), response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock {
            capturedRequests.append(request)
        }
        return (data, response)
    }
}
