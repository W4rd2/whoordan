import XCTest
@testable import Whoordan

final class HealthIngestionPipelineTests: XCTestCase {
    func testIngestionBlocksBeforeApprovalAndDoesNotPersistSamples() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 10_000)
        let userID = UUID()
        let result = await pipeline.ingest(
            samples: [sample(type: .steps, value: 2_500, id: "steps", date: now)],
            origin: .healthKit,
            approval: .pending(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true, appleHealthEnabled: true),
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            now: now
        )

        XCTAssertEqual(result.status, .blocked)
        let stored = await store.loadHealthSamples(on: now, calendar: .gregorianUTC)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertTrue(stored.isEmpty)
        XCTAssertTrue(pending.isEmpty)
    }

    func testIngestionWritesLocallyFirstAndQueuesCloudWhenConsentAllows() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 20_000)
        let userID = UUID()

        let result = await pipeline.ingest(
            samples: [
                sample(type: .steps, value: 7_500, id: "steps", date: now, source: .wearableBLE),
                sample(type: .activeEnergy, value: 280, id: "energy", date: now, source: .wearableBLE)
            ],
            origin: .wearableBLE,
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true, appleHealthEnabled: false),
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.storedSampleCount, 2)
        XCTAssertEqual(result.queuedSupabaseUploadCount, 2)
        XCTAssertEqual(result.queuedAppleHealthWriteCount, 0)
        XCTAssertEqual(result.updatedSummary?.movement.steps, 7_500)
        let stored = await store.loadHealthSamples(on: now, calendar: .gregorianUTC)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(pending.count, 2)
    }

    func testIngestionDoesNotQueueCloudWithoutCloudSyncEnabled() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 30_000)
        let userID = UUID()

        let result = await pipeline.ingest(
            samples: [sample(type: .heartRate, value: 71, id: "hr", date: now, source: .wearableBLE)],
            origin: .wearableBLE,
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false, appleHealthEnabled: false),
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.queuedSupabaseUploadCount, 0)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertTrue(pending.isEmpty)
        let stored = await store.loadHealthSamples(on: now, calendar: .gregorianUTC)
        XCTAssertEqual(stored.first?.source, .wearableBLE)
    }

    func testHealthKitOriginIsIgnoredInWearableDeviceOnlyMode() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 31_000)

        let result = await HealthIngestionPipeline().ingest(
            samples: [sample(type: .heartRate, value: 72, id: "apple-echo", date: now, source: .appleHealth)],
            origin: .healthKit,
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true, appleHealthEnabled: true),
            userID: UUID(),
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .noSamples)
        XCTAssertEqual(result.storedSampleCount, 0)
        let stored = await store.loadHealthSamples(on: now, calendar: .gregorianUTC)
        XCTAssertTrue(stored.isEmpty)
    }

    func testIngestionAppliesTemporarySkinTemperatureBaselineToTodaySummary() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 32_000)
        try await store.saveTemporarySkinTemperatureBaselineC(34.0, updatedAt: now)

        let result = await pipeline.ingest(
            samples: [sample(type: .wristTemperature, value: 34.5, id: "wrist-temp", date: now, source: .wearableBLE)],
            origin: .wearableBLE,
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false, healthDataCloudConsent: false, appleHealthEnabled: false),
            userID: UUID(),
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.updatedSummary?.rawWristTemperatureC, 34.5)
        XCTAssertEqual(result.updatedSummary?.bodyTemperatureDelta ?? 0, 0.5, accuracy: 0.0001)
    }

    func testOfflineApprovedHealthSampleCreatesPendingSupabaseQueueWhenConsented() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 35_000)
        let userID = UUID()

        let result = await pipeline.ingest(
            samples: [sample(type: .heartRate, value: 68, id: "offline-hr", date: now, source: .wearableBLE)],
            origin: .wearableBLE,
            approval: .offlineApproved(lastVerifiedAt: now.addingTimeInterval(-60)),
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true, appleHealthEnabled: false),
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.queuedSupabaseUploadCount, 1)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.userID, userID)
        XCTAssertEqual(pending.first?.sample.source, .wearableBLE)
    }

    func testOfflineApprovedDoesNotQueueWithoutCloudSyncOrAccountID() async {
        let now = Date(timeIntervalSince1970: 36_000)
        let approval = ApprovalState.offlineApproved(lastVerifiedAt: now.addingTimeInterval(-60))
        let cases: [(ConsentState, UUID?)] = [
            (ConsentState(cloudSyncEnabled: false), UUID()),
            (ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true), nil)
        ]

        for (index, testCase) in cases.enumerated() {
            let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
            let result = await HealthIngestionPipeline().ingest(
                samples: [sample(type: .steps, value: 100, id: "offline-blocked-\(index)", date: now)],
                origin: .healthKit,
                approval: approval,
                consent: testCase.0,
                userID: testCase.1,
                localStore: store,
                scoringService: WhoordanScoringService(),
                priorSummary: .empty,
                calendar: .gregorianUTC,
                now: now
            )

            XCTAssertEqual(result.status, .noSamples)
            XCTAssertEqual(result.queuedSupabaseUploadCount, 0)
            let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
            XCTAssertTrue(pending.isEmpty)
        }
    }

    func testLocalModeStaysEnabledWhileConsentedCloudQueueRunsAfterOnlineApproval() async {
        let now = Date(timeIntervalSince1970: 37_000)
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let consent = ConsentState(localModeEnabled: true, cloudSyncEnabled: true, healthDataCloudConsent: true)
        XCTAssertTrue(consent.localModeEnabled)
        XCTAssertTrue(consent.canUploadHealthData)

        let result = await HealthIngestionPipeline().ingest(
            samples: [sample(type: .steps, value: 250, id: "local-and-cloud", date: now)],
            origin: .wearableBLE,
            approval: .approved(),
            consent: consent,
            userID: UUID(),
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.queuedSupabaseUploadCount, 1)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertEqual(pending.count, 1)
    }

    func testOfflineApprovedDuplicateDoesNotDuplicateSupabaseQueueItem() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 37_000)
        let userID = UUID()
        let healthSample = sample(type: .steps, value: 1_200, id: "offline-steps", date: now, source: .wearableBLE)
        let consent = ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        let approval = ApprovalState.offlineApproved(lastVerifiedAt: now.addingTimeInterval(-60))

        let first = await pipeline.ingest(
            samples: [healthSample],
            origin: .wearableBLE,
            approval: approval,
            consent: consent,
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )
        let duplicate = await pipeline.ingest(
            samples: [healthSample],
            origin: .wearableBLE,
            approval: approval,
            consent: consent,
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: first.updatedSummary ?? .empty,
            calendar: .gregorianUTC,
            now: now
        )

        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertEqual(first.queuedSupabaseUploadCount, 1)
        XCTAssertEqual(duplicate.deduplicatedSampleCount, 1)
        XCTAssertEqual(duplicate.queuedSupabaseUploadCount, 0)
        XCTAssertEqual(pending.count, 1)
    }

    func testManualWorkoutCanQueueAppleHealthWriteButHealthKitImportDoesNotEchoBack() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let now = Date(timeIntervalSince1970: 40_000)
        let userID = UUID()
        let manualWorkout = HealthSample(
            id: "manual-workout",
            type: .workout,
            value: 30,
            unit: "min",
            startDate: now,
            endDate: now.addingTimeInterval(1_800),
            source: .localManual,
            sourceRecordID: "manual-workout",
            confidence: .high,
            metadata: ["source_label": "Manual workout"]
        )
        let consent = ConsentState(cloudSyncEnabled: false, healthDataCloudConsent: false, appleHealthEnabled: true)

        let manual = await pipeline.ingest(
            samples: [manualWorkout],
            origin: .manual,
            approval: .approved(),
            consent: consent,
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )
        let healthKitEcho = await pipeline.ingest(
            samples: [sample(type: .workout, value: 25, id: "hk-workout", date: now, source: .appleHealth)],
            origin: .healthKit,
            approval: .approved(),
            consent: consent,
            userID: userID,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: manual.updatedSummary ?? .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(manual.queuedAppleHealthWriteCount, 1)
        XCTAssertEqual(healthKitEcho.queuedAppleHealthWriteCount, 0)
        let pendingWrites = await store.pendingAppleHealthWrites(limit: 10)
        XCTAssertEqual(pendingWrites.count, 1)
    }

    func testWearableSamplesQueueAppleHealthExportWhenConsentEnabledWithoutEchoingAppleHealth() async {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 41_000)
        let consent = ConsentState(cloudSyncEnabled: false, healthDataCloudConsent: false, appleHealthEnabled: true)
        let pipeline = HealthIngestionPipeline()

        let wearable = await pipeline.ingest(
            samples: [sample(type: .heartRate, value: 71, id: "wearable-hr-write", date: now, source: .wearableBLE)],
            origin: .wearableBLE,
            approval: .approved(),
            consent: consent,
            userID: UUID(),
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )
        let healthKitEcho = await pipeline.ingest(
            samples: [sample(type: .heartRate, value: 72, id: "apple-hr-echo", date: now, source: .appleHealth)],
            origin: .healthKit,
            approval: .approved(),
            consent: consent,
            userID: UUID(),
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: wearable.updatedSummary ?? .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(wearable.queuedAppleHealthWriteCount, 1)
        XCTAssertEqual(healthKitEcho.queuedAppleHealthWriteCount, 0)
        let pendingWrites = await store.pendingAppleHealthWrites(limit: 10)
        XCTAssertEqual(pendingWrites.map(\.sampleType), [.heartRate])
    }

    func testWearableIngestionRebuildsSleepFromPreviousEveningEstimateWindow() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let pipeline = HealthIngestionPipeline()
        let day = Date(timeIntervalSince1970: 86_400)
        let now = day.addingTimeInterval(7 * 60 * 60)
        let sleepStart = day.addingTimeInterval(-30 * 60)
        let overnightChunks = (0..<45).map { index in
            sleepEstimate(
                id: "overnight-estimated-\(index)",
                start: sleepStart.addingTimeInterval(TimeInterval(index * 60)),
                minutes: 1
            )
        }
        _ = try await store.saveHealthSamples(
            overnightChunks,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: now
        )

        let result = await pipeline.ingest(
            samples: [sample(type: .heartRate, value: 61, id: "morning-hr", date: now, source: .wearableBLE)],
            origin: .wearableBLE,
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false, healthDataCloudConsent: false, appleHealthEnabled: false),
            userID: nil,
            localStore: store,
            scoringService: WhoordanScoringService(),
            priorSummary: .empty,
            calendar: .gregorianUTC,
            now: now
        )

        XCTAssertEqual(result.status, .stored)
        XCTAssertEqual(result.updatedSummary?.sleepMinutes, 45)
        XCTAssertEqual(result.updatedSummary?.sleepSummary?.source, .whoordanEstimate)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("whoordan-ingestion-store.json")
    }

    private func sample(
        type: HealthSampleType,
        value: Double,
        id: String,
        date: Date,
        source: DataSource = .appleHealth
    ) -> HealthSample {
        HealthSample(
            id: id,
            type: type,
            value: value,
            unit: type == .heartRate ? "bpm" : "unit",
            startDate: date,
            endDate: nil,
            source: source,
            sourceRecordID: id,
            confidence: .high,
            metadata: ["source_label": source.label]
        )
    }

    private func sleepEstimate(id: String, start: Date, minutes: Double) -> HealthSample {
        HealthSample(
            id: id,
            type: .sleepAnalysis,
            value: minutes,
            unit: "min",
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            source: .whoordanEstimate,
            sourceRecordID: id,
            confidence: .low,
            metadata: [
                "source_label": DataSource.whoordanEstimate.label,
                "device_only_derivation": "true",
                "metric_policy": "r10_hr_imu_sleep_stage_estimate",
                "sleep_category": "3"
            ]
        )
    }
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
