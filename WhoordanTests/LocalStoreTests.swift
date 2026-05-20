import XCTest
@testable import Whoordan

final class LocalStoreTests: XCTestCase {
    func testLocalPrivacyExportAndEraseCoverStoredHealthData() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = healthSample(type: .heartRate, value: 72, id: "privacy-export-hr", date: now)
        try await store.saveHealthSamples(
            [sample],
            queueForSupabase: true,
            syncUserID: UUID(),
            queueForAppleHealth: false,
            importedAt: now
        )

        let exportURL = try await store.exportLocalUserData(createdAt: now)
        let exportData = try Data(contentsOf: exportURL)
        let exportJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: exportData) as? [String: Any]
        )
        let snapshot = try XCTUnwrap(exportJSON["snapshot"] as? [String: Any])
        let records = try XCTUnwrap(snapshot["healthRecords"] as? [[String: Any]])

        XCTAssertEqual(exportJSON["formatVersion"] as? Int, 1)
        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(String(decoding: exportData, as: UTF8.self).contains("access_token"))

        await store.clearUnlockedCache()
        let erasedSamples = await store.loadHealthSamples(on: now, calendar: .gregorianUTC)
        XCTAssertTrue(erasedSamples.isEmpty)
    }

    func testDurableStorePersistsSamplesAndDeduplicatesByStableKey() async throws {
        let url = temporaryStoreURL()
        let store = FileProtectedLocalStore(fileURL: url)
        let day = Date(timeIntervalSince1970: 1_000)
        let userID = UUID()
        let sample = healthSample(type: .steps, value: 4_200, id: "steps-1", date: day)

        let first = try await store.saveHealthSamples([sample], queueForSupabase: true, syncUserID: userID, queueForAppleHealth: false, importedAt: day)
        let duplicate = try await store.saveHealthSamples([sample], queueForSupabase: true, syncUserID: userID, queueForAppleHealth: false, importedAt: day)

        XCTAssertEqual(first.insertedCount, 1)
        XCTAssertEqual(first.queuedSupabaseUploadCount, 1)
        XCTAssertEqual(duplicate.insertedCount, 0)
        XCTAssertEqual(duplicate.deduplicatedCount, 1)

        let reloaded = FileProtectedLocalStore(fileURL: url)
        let samples = await reloaded.loadHealthSamples(on: day, calendar: .gregorianUTC)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.value, 4_200)
    }

    func testSupabaseQueueRetryBackoffUploadAndRepair() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 2_000)
        let userID = UUID()
        let sample = healthSample(type: .heartRate, value: 72, id: "hr-1", date: now)
        try await store.saveHealthSamples([sample], queueForSupabase: true, syncUserID: userID, queueForAppleHealth: false, importedAt: now)

        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.sample.type, .heartRate)

        try await store.markSupabaseUploadsFailed(dedupeKeys: pending.map(\.dedupeKey), error: "network unavailable", now: now)
        let immediateRetry = await store.pendingSupabaseUploads(limit: 10, now: now)
        let delayedRetry = await store.pendingSupabaseUploads(limit: 10, now: now.addingTimeInterval(61))
        XCTAssertTrue(immediateRetry.isEmpty)
        XCTAssertEqual(delayedRetry.count, 1)

        try await store.markSupabaseUploadsUploaded(dedupeKeys: pending.map(\.dedupeKey), syncedAt: now)
        let uploadedQueue = await store.pendingSupabaseUploads(limit: 10, now: now.addingTimeInterval(61))
        let repaired = try await store.repairSupabaseQueue(now: now, userID: userID)
        XCTAssertTrue(uploadedQueue.isEmpty)
        XCTAssertEqual(repaired, 0)
    }

    func testCloudRestoredSamplesAreNotRepairedIntoSupabaseUploadQueue() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 2_500)
        let userID = UUID()
        let sample = HealthSample(
            id: "cloud-restored-heart",
            type: .heartRate,
            value: 72,
            unit: "bpm",
            startDate: now,
            endDate: nil,
            source: .wearableBLE,
            sourceRecordID: "cloud:remote-dedupe-key",
            confidence: .high,
            metadata: [
                "cloud_restored": "true",
                "cloud_dedupe_key": "remote-dedupe-key",
                "source_label": DataSource.wearableBLE.label
            ]
        )
        try await store.saveHealthSamples(
            [sample],
            queueForSupabase: false,
            syncUserID: userID,
            queueForAppleHealth: false,
            importedAt: now
        )

        let repaired = try await store.repairSupabaseQueue(now: now, userID: userID)
        let pending = await store.pendingSupabaseUploads(limit: 10, now: now)

        XCTAssertEqual(repaired, 0)
        XCTAssertTrue(pending.isEmpty)
    }

    func testAppleHealthWriteQueueAcceptsSupportedWhoordanSamplesAndRejectsAppleEcho() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 3_000)
        let workout = HealthSample(
            id: "manual-workout",
            type: .workout,
            value: 35,
            unit: "min",
            startDate: now,
            endDate: now.addingTimeInterval(35 * 60),
            source: .localManual,
            sourceRecordID: "manual-workout",
            confidence: .high,
            metadata: ["source_label": "Manual workout"]
        )
        let wearableHR = healthSample(type: .heartRate, value: 70, id: "wearable-hr", date: now, source: .wearableBLE)
        let importedHeartRate = healthSample(type: .heartRate, value: 70, id: "apple-hr", date: now, source: .appleHealth)
        let estimatedSpO2 = healthSample(type: .oxygenSaturation, value: 97, id: "estimated-spo2", date: now, source: .whoordanEstimate)

        let result = try await store.saveHealthSamples(
            [workout, wearableHR, importedHeartRate, estimatedSpO2],
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: true,
            importedAt: now
        )

        XCTAssertEqual(result.insertedCount, 4)
        XCTAssertEqual(result.queuedAppleHealthWriteCount, 2)
        let pendingWrites = await store.pendingAppleHealthWrites(limit: 10)
        XCTAssertEqual(Set(pendingWrites.map(\.sampleType)), [.workout, .heartRate])
    }

    func testAppleHealthNotAuthorizedWritesRemainAvailableForPermissionRecheck() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let now = Date(timeIntervalSince1970: 3_100)
        let steps = healthSample(type: .steps, value: 1_200, id: "steps-denied", date: now, source: .wearableBLE)
        try await store.saveHealthSamples(
            [steps],
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: true,
            importedAt: now
        )

        let pendingWrites = await store.pendingAppleHealthWrites(limit: 10)
        XCTAssertEqual(pendingWrites.count, 1)
        try await store.markAppleHealthWritesNotAuthorized(
            dedupeKeys: pendingWrites.map(\.dedupeKey),
            error: "Steps write permission is off.",
            now: now
        )

        let recheckableWrites = await store.pendingAppleHealthWrites(limit: 10)
        XCTAssertEqual(recheckableWrites.count, 1)
        XCTAssertEqual(recheckableWrites.first?.status, .notAuthorized)
        XCTAssertEqual(recheckableWrites.first?.lastError, "Steps write permission is off.")
    }

    func testSkinTemperatureBaselineUsesTemporaryCustomUntilFiveDistinctTemperatureDays() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let firstDay = Date(timeIntervalSince1970: 86_400)
        let customBaseline = 33.1

        try await store.saveTemporarySkinTemperatureBaselineC(customBaseline, updatedAt: firstDay)
        var profile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(profile.source, .temporaryCustom)
        XCTAssertEqual(profile.activeBaselineC, customBaseline)
        XCTAssertTrue(profile.canEditTemporaryBaseline)

        let firstFourDays = (0..<4).map { offset in
            wristTemperatureSample(
                value: 34.0 + Double(offset) * 0.1,
                id: "temp-\(offset)",
                date: firstDay.addingTimeInterval(Double(offset) * 86_400)
            )
        }
        try await store.saveHealthSamples(
            firstFourDays,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: firstDay.addingTimeInterval(3 * 86_400)
        )

        profile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(profile.source, .temporaryCustom)
        XCTAssertEqual(profile.eligibleDayCount, 4)
        XCTAssertEqual(profile.activeBaselineC, customBaseline)
        XCTAssertTrue(profile.canEditTemporaryBaseline)

        try await store.saveHealthSamples(
            [
                wristTemperatureSample(
                    value: 34.4,
                    id: "temp-4",
                    date: firstDay.addingTimeInterval(4 * 86_400)
                )
            ],
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: firstDay.addingTimeInterval(4 * 86_400)
        )

        profile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(profile.source, .automatic)
        XCTAssertEqual(profile.eligibleDayCount, 5)
        XCTAssertEqual(profile.activeBaselineC ?? 0, 34.2, accuracy: 0.0001)
        XCTAssertFalse(profile.canEditTemporaryBaseline)

        try await store.saveTemporarySkinTemperatureBaselineC(32.0, updatedAt: firstDay.addingTimeInterval(5 * 86_400))
        let lockedProfile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(lockedProfile.source, .automatic)
        XCTAssertEqual(lockedProfile.activeBaselineC ?? 0, 34.2, accuracy: 0.0001)
    }

    func testBulkHealthSampleLoadFiltersTypesSourcesAndLimitInOneQuery() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let base = Date(timeIntervalSince1970: 172_800)
        let samples = [
            healthSample(type: .wristTemperature, value: 34.1, id: "wearable-temp-1", date: base, source: .wearableBLE),
            healthSample(type: .temperatureEvent, value: 34.2, id: "wearable-event", date: base.addingTimeInterval(60), source: .wearableBLE),
            healthSample(type: .bodyTemperature, value: 36.7, id: "wearable-body", date: base.addingTimeInterval(120), source: .wearableBLE),
            healthSample(type: .wristTemperature, value: 35.0, id: "apple-temp", date: base.addingTimeInterval(180), source: .appleHealth),
            healthSample(type: .heartRate, value: 62, id: "wearable-hr", date: base.addingTimeInterval(240), source: .wearableBLE)
        ]
        try await store.saveHealthSamples(
            samples,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: base
        )

        let loaded = await store.loadHealthSamples(
            types: [.wristTemperature, .temperatureEvent, .bodyTemperature],
            sources: [.wearableBLE],
            start: base.addingTimeInterval(-1),
            end: base.addingTimeInterval(300),
            limit: 2
        )

        XCTAssertEqual(loaded.map(\.id), ["wearable-event", "wearable-body"])
        XCTAssertEqual(loaded.map(\.value), [34.2, 36.7])
    }

    func testSkinTemperatureBaselineDoesNotAutoSetFromRawWearableContactTemperatureWithoutSleepContext() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let firstDay = Date(timeIntervalSince1970: 86_400)
        let rawContactSamples = (0..<5).map { offset in
            wristTemperatureSample(
                value: 34.0 + Double(offset) * 0.1,
                id: "raw-temp-\(offset)",
                date: firstDay.addingTimeInterval(Double(offset) * 86_400),
                source: .wearableBLE,
                metadata: ["metric_policy": "raw_device_contact_temperature_not_baseline_delta"]
            )
        }

        try await store.saveHealthSamples(
            rawContactSamples,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: firstDay.addingTimeInterval(4 * 86_400)
        )

        let profile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(profile.source, .none)
        XCTAssertEqual(profile.eligibleDayCount, 0)
        XCTAssertNil(profile.activeBaselineC)
        XCTAssertTrue(profile.canEditTemporaryBaseline)
    }

    func testSkinTemperatureBaselineIgnoresAppleHealthTemperaturesInWearableOnlyMode() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let firstDay = Date(timeIntervalSince1970: 86_400)
        let appleHealthSamples = (0..<5).map { offset in
            wristTemperatureSample(
                value: 34.0 + Double(offset) * 0.1,
                id: "apple-temp-\(offset)",
                date: firstDay.addingTimeInterval(Double(offset) * 86_400),
                source: .appleHealth,
                metadata: ["measurement_context": "sleep"]
            )
        }

        try await store.saveHealthSamples(
            appleHealthSamples,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: firstDay.addingTimeInterval(4 * 86_400)
        )

        let profile = await store.loadSkinTemperatureBaselineProfile()
        XCTAssertEqual(profile.source, .none)
        XCTAssertEqual(profile.eligibleDayCount, 0)
        XCTAssertNil(profile.activeBaselineC)
    }

    func testBodyProfilePersistsLocallyAndValidatesRanges() async throws {
        let url = temporaryStoreURL()
        let store = FileProtectedLocalStore(fileURL: url)
        let updatedAt = try XCTUnwrap(DateComponents(calendar: .gregorianUTC, year: 2024, month: 1, day: 1).date)
        let birthDate = try XCTUnwrap(DateComponents(calendar: .gregorianUTC, year: 1992, month: 1, day: 1).date)
        let profile = BodyProfile(
            birthDate: birthDate,
            biologicalSex: .male,
            heightCentimeters: 178,
            weightKilograms: 76,
            configuredMaxHeartRate: 191
        )

        try await store.saveBodyProfile(profile, updatedAt: updatedAt)
        let reloaded = FileProtectedLocalStore(fileURL: url)
        let loaded = await reloaded.loadBodyProfile()

        XCTAssertEqual(loaded.birthDate, birthDate)
        XCTAssertEqual(loaded.resolvedAgeYears(on: updatedAt, calendar: .gregorianUTC), 32)
        XCTAssertEqual(loaded.biologicalSex, .male)
        XCTAssertEqual(loaded.heightCentimeters, 178)
        XCTAssertEqual(loaded.weightKilograms, 76)
        XCTAssertEqual(loaded.configuredMaxHeartRate, 191)
        XCTAssertEqual(loaded.updatedAt, updatedAt)
        XCTAssertEqual(loaded.bmrKilocaloriesPerDay(on: updatedAt, calendar: .gregorianUTC) ?? 0, 1_717.5, accuracy: 0.001)
        XCTAssertEqual(BodyProfile(ageYears: 32).resolvedAgeYears(on: updatedAt, calendar: .gregorianUTC), 32)

        do {
            let tooYoungBirthDate = try XCTUnwrap(DateComponents(calendar: .gregorianUTC, year: 2020, month: 1, day: 1).date)
            try await store.saveBodyProfile(BodyProfile(birthDate: tooYoungBirthDate), updatedAt: updatedAt)
            XCTFail("Out-of-range birth date should be rejected.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Birth date"))
        }
    }

    func testStorePersistsSleepWorkoutJournalSettingsAndCheckpoints() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let day = Date(timeIntervalSince1970: 86_400)
        let sleep = SleepSession(
            id: "sleep-1",
            start: day,
            end: day.addingTimeInterval(7 * 60 * 60),
            asleepMinutes: 390,
            inBedMinutes: 420,
            efficiencyPercent: 92.8,
            source: .appleHealth,
            confidence: .high
        )
        let workout = Workout(
            id: "workout-1",
            start: day,
            end: day.addingTimeInterval(45 * 60),
            activityName: "Run",
            durationMinutes: 45,
            sourceEnergy: 330,
            maxHeartRate: 174,
            averageHeartRate: 149,
            zonePercentages: [3: 0.4, 4: 0.3],
            source: .appleHealth
        )
        let journal = JournalEntry(id: "journal-1", prompt: "Caffeine", answeredYes: true, day: day, source: .localManual)
        let alarm = Alarm(
            label: "Wake",
            hour: 7,
            minute: 15,
            timezone: "UTC",
            repeatDays: [2, 3],
            vibrationPatternID: VibrationPattern.standardID,
            syncStatus: .blocked
        ).withNextTrigger(after: day, calendar: .gregorianUTC)
        let callSettings = CallVibrationSettings(
            enabled: true,
            patternID: UUID(),
            declineOnDoubleTapEnabled: true,
            supportsDecline: false,
            platformStatus: .normalCellularPlatformBlocked
        )

        try await store.saveSleepSession(sleep)
        try await store.saveWorkout(workout)
        try await store.saveJournalEntry(journal)
        try await store.saveAlarm(alarm)
        try await store.saveCallVibrationSettings(callSettings)
        try await store.saveHealthKitCheckpoints([HealthKitCheckpoint(sampleType: .steps, anchorToken: "synthetic-anchor", updatedAt: day)])
        try await store.saveBLECheckpoint(BLECheckpoint(deviceID: "wearable-1", lastBatchToken: "token", historicalSyncComplete: false, updatedAt: day))

        let sleeps = await store.loadSleepSessions(on: day, calendar: .gregorianUTC)
        let workouts = await store.loadWorkouts(on: day, calendar: .gregorianUTC)
        let journals = await store.loadJournalEntries(on: day, calendar: .gregorianUTC)
        let patterns = await store.loadVibrationPatterns()
        let alarms = await store.loadAlarms()
        let reloadedCallSettings = await store.loadCallVibrationSettings()
        let checkpoints = await store.loadHealthKitCheckpoints()
        let bleCheckpoint = await store.loadBLECheckpoint(deviceID: "wearable-1")
        let bleCheckpoints = await store.loadBLECheckpoints()
        XCTAssertEqual(sleeps, [sleep])
        XCTAssertEqual(workouts, [workout])
        XCTAssertEqual(journals, [journal])
        XCTAssertEqual(patterns.map(\.id), [VibrationPattern.standardID])
        XCTAssertEqual(alarms, [alarm])
        XCTAssertEqual(reloadedCallSettings.enabled, true)
        XCTAssertEqual(reloadedCallSettings.platformStatus, .normalCellularPlatformBlocked)
        XCTAssertEqual(checkpoints, [HealthKitCheckpoint(sampleType: .steps, anchorToken: "synthetic-anchor", updatedAt: day)])
        XCTAssertEqual(bleCheckpoint?.lastBatchToken, "token")
        XCTAssertEqual(bleCheckpoints.map(\.deviceID), ["wearable-1"])
    }

    func testWearableControlPlaneEventsPersistWithoutPayloadBytes() async throws {
        let store = FileProtectedLocalStore(fileURL: temporaryStoreURL())
        let event = WearableControlPlaneEvent(
            kind: .batchAckDeferred,
            message: "Batch ACK deferred until local sample persistence completes.",
            occurredAt: Date(timeIntervalSince1970: 1_735_689_600),
            deviceID: "wearable-1",
            connectionState: .historicalSync
        )

        try await store.saveWearableControlPlaneEvent(event)
        let events = await store.loadWearableControlPlaneEvents(limit: 10)

        XCTAssertEqual(events, [event])
        XCTAssertFalse(events[0].message.localizedCaseInsensitiveContains("payload"))
    }

    func testProtectedLocalDataIsHiddenBeforeApprovalOrAfterRevocation() {
        let guardPolicy = PrivacyAccessGuard()
        XCTAssertFalse(guardPolicy.canAccessProtectedData(approval: nil))
        XCTAssertFalse(guardPolicy.canAccessProtectedData(approval: .pending()))
        XCTAssertFalse(guardPolicy.canAccessProtectedData(approval: ApprovalState(status: .revoked, message: "Revoked", checkedAt: Date())))
        XCTAssertTrue(guardPolicy.canAccessProtectedData(approval: .approved()))
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("whoordan-local-store.json")
    }

    private func healthSample(
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

    private func wristTemperatureSample(
        value: Double,
        id: String,
        date: Date,
            source: DataSource = .legacyWearableDeviceExport,
        metadata: [String: String] = [:]
    ) -> HealthSample {
        HealthSample(
            id: id,
            type: .wristTemperature,
            value: value,
            unit: "degC",
            startDate: date,
            endDate: nil,
            source: source,
            sourceRecordID: id,
            confidence: .high,
            metadata: ["source_label": source.label].merging(metadata) { current, _ in current }
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
