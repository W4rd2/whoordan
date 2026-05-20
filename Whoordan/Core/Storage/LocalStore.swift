import Foundation

enum LocalSyncStatus: String, Codable, Equatable {
    case notQueued
    case pending
    case uploaded
    case failed
    case blocked
}

enum AppleHealthWriteStatus: String, Codable, Equatable {
    case notApplicable
    case pending
    case written
    case failed
    case unsupported
    case notAuthorized
}

struct LocalHealthRecord: Codable, Equatable, Identifiable {
    let id: String
    var sample: HealthSample
    var sourceSampleID: String
    var deviceID: String?
    var localDayKey: String
    var importedAt: Date
    var metadata: [String: String]
    var confidence: ConfidenceLevel
    var dedupeKey: String
    var supabaseSyncStatus: LocalSyncStatus
    var appleHealthWriteStatus: AppleHealthWriteStatus
}

struct LocalPersistenceResult: Codable, Equatable {
    var insertedCount: Int
    var deduplicatedCount: Int
    var queuedSupabaseUploadCount: Int
    var queuedAppleHealthWriteCount: Int

    static let empty = LocalPersistenceResult(
        insertedCount: 0,
        deduplicatedCount: 0,
        queuedSupabaseUploadCount: 0,
        queuedAppleHealthWriteCount: 0
    )
}

struct HealthKitCheckpoint: Codable, Equatable, Identifiable {
    var id: String { sampleType.rawValue }
    let sampleType: HealthSampleType
    let anchorToken: String
    let updatedAt: Date
}

struct BLECheckpoint: Codable, Equatable, Identifiable {
    var id: String { deviceID }
    let deviceID: String
    var lastBatchToken: String?
    var historicalSyncComplete: Bool
    var updatedAt: Date
}

struct SupabaseSyncQueueItem: Codable, Equatable, Identifiable {
    let id: String
    let userID: UUID?
    let recordID: String
    let dedupeKey: String
    let sampleType: HealthSampleType
    var status: LocalSyncStatus
    var attempts: Int
    var nextAttemptAt: Date
    var lastError: String?
    let createdAt: Date
    var updatedAt: Date

    var idempotencyKey: String { dedupeKey }
}

struct AppleHealthWriteQueueItem: Codable, Equatable, Identifiable {
    let id: String
    let recordID: String
    let dedupeKey: String
    let sampleType: HealthSampleType
    var sample: HealthSample?
    var status: AppleHealthWriteStatus
    var attempts: Int
    var lastError: String?
    let createdAt: Date
    var updatedAt: Date
}

struct QueuedHealthSampleUpload: Codable, Equatable {
    let queueItemID: String
    let userID: UUID?
    let dedupeKey: String
    let sample: HealthSample
}

protocol LocalStoring {
    func loadConsentState() async -> ConsentState
    func saveConsentState(_ state: ConsentState) async
    func loadTodaySummary() async -> DailyHealthSummary
    func saveTodaySummary(_ summary: DailyHealthSummary) async
    func loadBodyProfile() async -> BodyProfile
    func saveBodyProfile(_ profile: BodyProfile, updatedAt: Date) async throws
    func loadSkinTemperatureBaselineProfile() async -> SkinTemperatureBaselineProfile
    func saveSkinTemperatureBaselineProfile(_ profile: SkinTemperatureBaselineProfile) async throws
    func saveTemporarySkinTemperatureBaselineC(_ value: Double?, updatedAt: Date) async throws
    func loadCachedApprovalState() async -> ApprovalState?
    func saveCachedApprovalState(_ state: ApprovalState?) async
    func clearUnlockedCache() async
    func exportLocalUserData(createdAt: Date) async throws -> URL

    @discardableResult
    func saveHealthSamples(
        _ samples: [HealthSample],
        queueForSupabase: Bool,
        syncUserID: UUID?,
        queueForAppleHealth: Bool,
        importedAt: Date
    ) async throws -> LocalPersistenceResult
    func loadHealthSamples(on day: Date, calendar: Calendar) async -> [HealthSample]
    func loadHealthSamples(
        type: HealthSampleType?,
        source: DataSource?,
        start: Date?,
        end: Date?,
        limit: Int?
    ) async -> [HealthSample]
    func loadHealthSamples(
        types: [HealthSampleType]?,
        sources: [DataSource]?,
        start: Date?,
        end: Date?,
        limit: Int?
    ) async -> [HealthSample]
    func pendingSupabaseUploads(limit: Int, now: Date) async -> [QueuedHealthSampleUpload]
    func markSupabaseUploadsUploaded(dedupeKeys: [String], syncedAt: Date) async throws
    func markSupabaseUploadsFailed(dedupeKeys: [String], error: String, now: Date) async throws
    func repairSupabaseQueue(now: Date, userID: UUID?) async throws -> Int
    func repairAppleHealthWriteQueue(now: Date) async throws -> Int
    func pendingAppleHealthWrites(limit: Int) async -> [AppleHealthWriteQueueItem]
    func markAppleHealthWritesWritten(dedupeKeys: [String], writtenAt: Date) async throws
    func markAppleHealthWritesFailed(dedupeKeys: [String], error: String, now: Date) async throws
    func markAppleHealthWritesNotAuthorized(dedupeKeys: [String], error: String, now: Date) async throws

    func loadHealthKitCheckpoints() async -> [HealthKitCheckpoint]
    func saveHealthKitCheckpoints(_ checkpoints: [HealthKitCheckpoint]) async throws
    func loadBLECheckpoints() async -> [BLECheckpoint]
    func loadBLECheckpoint(deviceID: String) async -> BLECheckpoint?
    func saveBLECheckpoint(_ checkpoint: BLECheckpoint) async throws
    func saveWearableControlPlaneEvent(_ event: WearableControlPlaneEvent) async throws
    func loadWearableControlPlaneEvents(limit: Int) async -> [WearableControlPlaneEvent]

    func saveSleepSession(_ session: SleepSession) async throws
    func loadSleepSessions(on day: Date, calendar: Calendar) async -> [SleepSession]
    func saveWorkout(_ workout: Workout) async throws
    func loadWorkouts(on day: Date, calendar: Calendar) async -> [Workout]
    func saveJournalEntry(_ entry: JournalEntry) async throws
    func loadJournalEntries(on day: Date, calendar: Calendar) async -> [JournalEntry]
    func loadVibrationPatterns() async -> [VibrationPattern]
    func loadCallVibrationSettings() async -> CallVibrationSettings
    func saveCallVibrationSettings(_ settings: CallVibrationSettings) async throws
    func saveAlarm(_ alarm: Alarm) async throws
    func loadAlarms() async -> [Alarm]
    func replaceAlarms(_ alarms: [Alarm]) async throws
    func deleteAlarm(id: UUID) async throws
}

extension LocalStoring {
    func loadHealthSamples(
        type: HealthSampleType?,
        source: DataSource?,
        start: Date?,
        end: Date?
    ) async -> [HealthSample] {
        await loadHealthSamples(type: type, source: source, start: start, end: end, limit: nil)
    }

    func loadHealthSamples(
        types: [HealthSampleType]?,
        sources: [DataSource]?,
        start: Date?,
        end: Date?,
        limit: Int?
    ) async -> [HealthSample] {
        let queryTypes: [HealthSampleType?] = types?.isEmpty == false ? types!.map(Optional.some) : [nil]
        let querySources: [DataSource?] = sources?.isEmpty == false ? sources!.map(Optional.some) : [nil]
        var samples: [HealthSample] = []

        for type in queryTypes {
            for source in querySources {
                samples.append(contentsOf: await loadHealthSamples(
                    type: type,
                    source: source,
                    start: start,
                    end: end,
                    limit: nil
                ))
            }
        }

        let sorted = samples.sorted { $0.startDate < $1.startDate }
        guard let limit else { return sorted }
        return Array(sorted.suffix(max(1, limit)))
    }
}

enum LocalStoreValidationError: LocalizedError {
    case invalidSkinTemperatureBaseline
    case invalidBodyProfile(String)

    var errorDescription: String? {
        switch self {
        case .invalidSkinTemperatureBaseline:
            return "Skin temperature baseline must be between 20 and 45 C."
        case .invalidBodyProfile(let message):
            return message
        }
    }
}

actor FileProtectedLocalStore: LocalStoring {
    private let fileURL: URL
    private var snapshot: LocalStoreSnapshot?
    private static let maxWearableControlPlaneEvents = 500

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultStoreURL()
    }

    func loadConsentState() async -> ConsentState {
        ((try? await mutableSnapshot()).map(\.consentState) ?? ConsentState()).normalizedForCurrentPrivacyModel
    }

    func saveConsentState(_ state: ConsentState) async {
        do {
            var current = try await mutableSnapshot()
            current.consentState = state.normalizedForCurrentPrivacyModel
            try persist(current)
        } catch {
            snapshot = nil
        }
    }

    func loadTodaySummary() async -> DailyHealthSummary {
        (try? await mutableSnapshot()).map(\.todaySummary) ?? .empty
    }

    func saveTodaySummary(_ summary: DailyHealthSummary) async {
        do {
            var current = try await mutableSnapshot()
            current.todaySummary = summary
            try persist(current)
        } catch {
            snapshot = nil
        }
    }

    func loadBodyProfile() async -> BodyProfile {
        (try? await mutableSnapshot()).map(\.bodyProfile) ?? BodyProfile()
    }

    func saveBodyProfile(_ profile: BodyProfile, updatedAt: Date = Date()) async throws {
        if let validationError = profile.validationError(on: updatedAt) {
            throw LocalStoreValidationError.invalidBodyProfile(validationError)
        }
        var current = try await mutableSnapshot()
        current.bodyProfile = profile.normalized(updatedAt: updatedAt)
        try persist(current)
    }

    func loadSkinTemperatureBaselineProfile() async -> SkinTemperatureBaselineProfile {
        (try? await mutableSnapshot()).map(\.skinTemperatureBaseline) ?? SkinTemperatureBaselineProfile()
    }

    func saveSkinTemperatureBaselineProfile(_ profile: SkinTemperatureBaselineProfile) async throws {
        let sanitized = profile.sanitizedForCloudSync
        var current = try await mutableSnapshot()
        current.skinTemperatureBaseline = sanitized
        try persist(current)
    }

    func saveTemporarySkinTemperatureBaselineC(_ value: Double?, updatedAt: Date = Date()) async throws {
        var current = try await mutableSnapshot()
        guard current.skinTemperatureBaseline.canEditTemporaryBaseline else { return }
        if let value {
            guard SkinTemperatureBaselineProfile.validBaselineRangeC.contains(value) else {
                throw LocalStoreValidationError.invalidSkinTemperatureBaseline
            }
            current.skinTemperatureBaseline = SkinTemperatureBaselineProfile(
                activeBaselineC: value,
                source: .temporaryCustom,
                eligibleDayCount: current.skinTemperatureBaseline.eligibleDayCount,
                requiredDayCount: SkinTemperatureBaselineProfile.requiredDayCountDefault,
                updatedAt: updatedAt,
                automaticBaselineSetAt: nil
            )
        } else {
            current.skinTemperatureBaseline = SkinTemperatureBaselineProfile(
                activeBaselineC: nil,
                source: .none,
                eligibleDayCount: current.skinTemperatureBaseline.eligibleDayCount,
                requiredDayCount: SkinTemperatureBaselineProfile.requiredDayCountDefault,
                updatedAt: updatedAt,
                automaticBaselineSetAt: nil
            )
        }
        current.refreshSkinTemperatureBaseline(now: updatedAt)
        try persist(current)
    }

    func loadCachedApprovalState() async -> ApprovalState? {
        (try? await mutableSnapshot())?.cachedApprovalState
    }

    func saveCachedApprovalState(_ state: ApprovalState?) async {
        do {
            var current = try await mutableSnapshot()
            current.cachedApprovalState = state
            try persist(current)
        } catch {
            snapshot = nil
        }
    }

    func clearUnlockedCache() async {
        do {
            try persist(LocalStoreSnapshot())
        } catch {
            snapshot = LocalStoreSnapshot()
        }
    }

    func exportLocalUserData(createdAt: Date = Date()) async throws -> URL {
        let current = try await mutableSnapshot()
        let export = LocalDataExportEnvelope(
            formatVersion: 1,
            exportedAt: createdAt,
            snapshot: current
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Whoordan-Local-Data-Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "whoordan-local-data-\(Self.exportTimestampFormatter.string(from: createdAt)).json"
        let exportURL = directory.appendingPathComponent(filename)
        let data = try JSONEncoder.whoordan.encode(export)
        try data.write(to: exportURL, options: [.atomic])
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: exportURL.path
        )
        #endif
        return exportURL
    }

    @discardableResult
    func saveHealthSamples(
        _ samples: [HealthSample],
        queueForSupabase: Bool,
        syncUserID: UUID? = nil,
        queueForAppleHealth: Bool,
        importedAt: Date = Date()
    ) async throws -> LocalPersistenceResult {
        guard !samples.isEmpty else { return .empty }
        var current = try await mutableSnapshot()
        var existing = Dictionary(uniqueKeysWithValues: current.healthRecords.map { ($0.dedupeKey, $0.id) })
        var result = LocalPersistenceResult.empty

        for sample in samples {
            let dedupeKey = sample.dedupeID
            if existing[dedupeKey] != nil {
                result.deduplicatedCount += 1
                continue
            }

            let writeStatus = AppleHealthWritePolicy.initialStatus(
                for: sample,
                queueRequested: queueForAppleHealth
            )
            let shouldQueueSupabase = queueForSupabase && syncUserID != nil
            let syncStatus: LocalSyncStatus = shouldQueueSupabase ? .pending : .blocked
            let record = LocalHealthRecord(
                id: dedupeKey,
                sample: sample,
                sourceSampleID: sample.sourceRecordID,
                deviceID: sample.metadata["device_fingerprint"],
                localDayKey: LocalDayKey.make(for: sample.startDate),
                importedAt: importedAt,
                metadata: sample.metadata,
                confidence: sample.confidence,
                dedupeKey: dedupeKey,
                supabaseSyncStatus: syncStatus,
                appleHealthWriteStatus: writeStatus
            )
            current.healthRecords.append(record)
            existing[dedupeKey] = record.id
            result.insertedCount += 1

            if shouldQueueSupabase {
                current.upsertSupabaseQueueItem(for: record, userID: syncUserID, now: importedAt)
                result.queuedSupabaseUploadCount += 1
            }
            if writeStatus == .pending {
                current.upsertAppleHealthQueueItem(for: record, now: importedAt)
                result.queuedAppleHealthWriteCount += 1
            }
        }

        if result.insertedCount > 0 {
            current.refreshSkinTemperatureBaseline(now: importedAt)
        }
        try persist(current)
        return result
    }

    func loadHealthSamples(on day: Date, calendar: Calendar = .current) async -> [HealthSample] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return current.healthRecords
            .map(\.sample)
            .filter { Self.sampleOccurs($0, on: day, calendar: calendar) }
    }

    func loadHealthSamples(
        type: HealthSampleType? = nil,
        source: DataSource? = nil,
        start: Date? = nil,
        end: Date? = nil,
        limit: Int? = nil
    ) async -> [HealthSample] {
        guard let current = try? await mutableSnapshot() else { return [] }
        let filtered = current.healthRecords.map(\.sample).filter { sample in
            if let type, sample.type != type { return false }
            if let source, sample.source != source { return false }
            if let start, !Self.sampleOccursAfter(sample, start: start) { return false }
            if let end, !Self.sampleOccursBefore(sample, end: end) { return false }
            return true
        }
        .sorted { $0.startDate < $1.startDate }
        guard let limit else { return filtered }
        return Array(filtered.suffix(max(1, limit)))
    }

    func loadHealthSamples(
        types: [HealthSampleType]? = nil,
        sources: [DataSource]? = nil,
        start: Date? = nil,
        end: Date? = nil,
        limit: Int? = nil
    ) async -> [HealthSample] {
        guard let current = try? await mutableSnapshot() else { return [] }
        let filtered = current.healthRecords.map(\.sample).filter { sample in
            if let types, !types.isEmpty, !types.contains(sample.type) { return false }
            if let sources, !sources.isEmpty, !sources.contains(sample.source) { return false }
            if let start, !Self.sampleOccursAfter(sample, start: start) { return false }
            if let end, !Self.sampleOccursBefore(sample, end: end) { return false }
            return true
        }
        .sorted { $0.startDate < $1.startDate }
        guard let limit else { return filtered }
        return Array(filtered.suffix(max(1, limit)))
    }

    func pendingSupabaseUploads(limit: Int = 500, now: Date = Date()) async -> [QueuedHealthSampleUpload] {
        guard let current = try? await mutableSnapshot() else { return [] }
        let recordsByID = Dictionary(uniqueKeysWithValues: current.healthRecords.map { ($0.id, $0) })
        return current.supabaseQueue
            .filter { item in
                (item.status == .pending || item.status == .failed) && item.nextAttemptAt <= now
            }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(max(1, limit))
            .compactMap { item in
                guard let record = recordsByID[item.recordID] else { return nil }
                return QueuedHealthSampleUpload(
                    queueItemID: item.id,
                    userID: item.userID,
                    dedupeKey: item.dedupeKey,
                    sample: record.sample
                )
            }
    }

    func markSupabaseUploadsUploaded(dedupeKeys: [String], syncedAt: Date = Date()) async throws {
        guard !dedupeKeys.isEmpty else { return }
        var current = try await mutableSnapshot()
        let keySet = Set(dedupeKeys)
        for index in current.supabaseQueue.indices where keySet.contains(current.supabaseQueue[index].dedupeKey) {
            current.supabaseQueue[index].status = .uploaded
            current.supabaseQueue[index].updatedAt = syncedAt
            current.supabaseQueue[index].lastError = nil
        }
        for index in current.healthRecords.indices where keySet.contains(current.healthRecords[index].dedupeKey) {
            current.healthRecords[index].supabaseSyncStatus = .uploaded
        }
        try persist(current)
    }

    func markSupabaseUploadsFailed(dedupeKeys: [String], error: String, now: Date = Date()) async throws {
        guard !dedupeKeys.isEmpty else { return }
        var current = try await mutableSnapshot()
        let keySet = Set(dedupeKeys)
        for index in current.supabaseQueue.indices where keySet.contains(current.supabaseQueue[index].dedupeKey) {
            current.supabaseQueue[index].status = .failed
            current.supabaseQueue[index].attempts += 1
            current.supabaseQueue[index].updatedAt = now
            current.supabaseQueue[index].lastError = String(error.prefix(180))
            current.supabaseQueue[index].nextAttemptAt = now.addingTimeInterval(Self.backoff(for: current.supabaseQueue[index].attempts))
        }
        for index in current.healthRecords.indices where keySet.contains(current.healthRecords[index].dedupeKey) {
            current.healthRecords[index].supabaseSyncStatus = .failed
        }
        try persist(current)
    }

    func repairSupabaseQueue(now: Date = Date(), userID: UUID?) async throws -> Int {
        guard userID != nil else { return 0 }
        var current = try await mutableSnapshot()
        let queuedKeys = Set(current.supabaseQueue.map(\.dedupeKey))
        var repaired = 0
        for record in current.healthRecords where record.supabaseSyncStatus != .uploaded
            && !queuedKeys.contains(record.dedupeKey)
            && !record.isCloudRestoredSample {
            current.upsertSupabaseQueueItem(for: record, userID: userID, now: now)
            repaired += 1
        }
        try persist(current)
        return repaired
    }

    func repairAppleHealthWriteQueue(now: Date = Date()) async throws -> Int {
        var current = try await mutableSnapshot()
        let queuedKeys = Set(current.appleHealthWriteQueue.map(\.dedupeKey))
        var repaired = 0
        for index in current.healthRecords.indices {
            let record = current.healthRecords[index]
            guard record.appleHealthWriteStatus != .written,
                  !queuedKeys.contains(record.dedupeKey),
                  AppleHealthWritePolicy.isSupported(record.sample) else {
                continue
            }
            current.healthRecords[index].appleHealthWriteStatus = .pending
            current.upsertAppleHealthQueueItem(for: current.healthRecords[index], now: now)
            repaired += 1
        }
        try persist(current)
        return repaired
    }

    func pendingAppleHealthWrites(limit: Int = 100) async -> [AppleHealthWriteQueueItem] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return Array(current.appleHealthWriteQueue
            .filter { $0.status == .pending || $0.status == .failed || $0.status == .notAuthorized }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(max(1, limit)))
            .map { item in
                var resolved = item
                if resolved.sample == nil {
                    resolved.sample = current.healthRecords
                        .first { $0.id == item.recordID || $0.dedupeKey == item.dedupeKey }?
                        .sample
                }
                return resolved
            }
    }

    func markAppleHealthWritesWritten(dedupeKeys: [String], writtenAt: Date) async throws {
        guard !dedupeKeys.isEmpty else { return }
        var current = try await mutableSnapshot()
        for key in dedupeKeys {
            if let index = current.appleHealthWriteQueue.firstIndex(where: { $0.dedupeKey == key }) {
                current.appleHealthWriteQueue[index].status = .written
                current.appleHealthWriteQueue[index].updatedAt = writtenAt
                current.appleHealthWriteQueue[index].lastError = nil
            }
            if let recordIndex = current.healthRecords.firstIndex(where: { $0.dedupeKey == key }) {
                current.healthRecords[recordIndex].appleHealthWriteStatus = .written
            }
        }
        try persist(current)
    }

    func markAppleHealthWritesFailed(dedupeKeys: [String], error: String, now: Date) async throws {
        guard !dedupeKeys.isEmpty else { return }
        var current = try await mutableSnapshot()
        for key in dedupeKeys {
            if let index = current.appleHealthWriteQueue.firstIndex(where: { $0.dedupeKey == key }) {
                current.appleHealthWriteQueue[index].status = .failed
                current.appleHealthWriteQueue[index].attempts += 1
                current.appleHealthWriteQueue[index].updatedAt = now
                current.appleHealthWriteQueue[index].lastError = error
            }
            if let recordIndex = current.healthRecords.firstIndex(where: { $0.dedupeKey == key }) {
                current.healthRecords[recordIndex].appleHealthWriteStatus = .failed
            }
        }
        try persist(current)
    }

    func markAppleHealthWritesNotAuthorized(dedupeKeys: [String], error: String, now: Date) async throws {
        guard !dedupeKeys.isEmpty else { return }
        var current = try await mutableSnapshot()
        for key in dedupeKeys {
            if let index = current.appleHealthWriteQueue.firstIndex(where: { $0.dedupeKey == key }) {
                current.appleHealthWriteQueue[index].status = .notAuthorized
                current.appleHealthWriteQueue[index].attempts += 1
                current.appleHealthWriteQueue[index].updatedAt = now
                current.appleHealthWriteQueue[index].lastError = error
            }
            if let recordIndex = current.healthRecords.firstIndex(where: { $0.dedupeKey == key }) {
                current.healthRecords[recordIndex].appleHealthWriteStatus = .notAuthorized
            }
        }
        try persist(current)
    }

    func loadHealthKitCheckpoints() async -> [HealthKitCheckpoint] {
        (try? await mutableSnapshot()).map(\.healthKitCheckpoints) ?? []
    }

    func saveHealthKitCheckpoints(_ checkpoints: [HealthKitCheckpoint]) async throws {
        guard !checkpoints.isEmpty else { return }
        var current = try await mutableSnapshot()
        for checkpoint in checkpoints {
            if let index = current.healthKitCheckpoints.firstIndex(where: { $0.sampleType == checkpoint.sampleType }) {
                current.healthKitCheckpoints[index] = checkpoint
            } else {
                current.healthKitCheckpoints.append(checkpoint)
            }
        }
        try persist(current)
    }

    func loadBLECheckpoints() async -> [BLECheckpoint] {
        (try? await mutableSnapshot())?.bleCheckpoints.sorted { $0.updatedAt > $1.updatedAt } ?? []
    }

    func loadBLECheckpoint(deviceID: String) async -> BLECheckpoint? {
        (try? await mutableSnapshot())?.bleCheckpoints.first(where: { $0.deviceID == deviceID })
    }

    func saveBLECheckpoint(_ checkpoint: BLECheckpoint) async throws {
        var current = try await mutableSnapshot()
        if let index = current.bleCheckpoints.firstIndex(where: { $0.deviceID == checkpoint.deviceID }) {
            current.bleCheckpoints[index] = checkpoint
        } else {
            current.bleCheckpoints.append(checkpoint)
        }
        try persist(current)
    }

    func saveWearableControlPlaneEvent(_ event: WearableControlPlaneEvent) async throws {
        var current = try await mutableSnapshot()
        current.wearableControlPlaneEvents.append(event)
        if current.wearableControlPlaneEvents.count > Self.maxWearableControlPlaneEvents {
            current.wearableControlPlaneEvents.removeFirst(
                current.wearableControlPlaneEvents.count - Self.maxWearableControlPlaneEvents
            )
        }
        try persist(current)
    }

    func loadWearableControlPlaneEvents(limit: Int = 100) async -> [WearableControlPlaneEvent] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return Array(current.wearableControlPlaneEvents.sorted { $0.occurredAt < $1.occurredAt }.suffix(max(1, limit)))
    }

    func saveSleepSession(_ session: SleepSession) async throws {
        var current = try await mutableSnapshot()
        current.sleepSessions.removeAll { $0.id == session.id }
        current.sleepSessions.append(session)
        current.refreshSkinTemperatureBaseline(now: Date())
        try persist(current)
    }

    func loadSleepSessions(on day: Date, calendar: Calendar = .current) async -> [SleepSession] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return current.sleepSessions.filter { calendar.isDate($0.start, inSameDayAs: day) }
    }

    func saveWorkout(_ workout: Workout) async throws {
        var current = try await mutableSnapshot()
        current.workouts.removeAll { $0.id == workout.id }
        current.workouts.append(workout)
        try persist(current)
    }

    func loadWorkouts(on day: Date, calendar: Calendar = .current) async -> [Workout] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return current.workouts.filter { calendar.isDate($0.start, inSameDayAs: day) }
    }

    func saveJournalEntry(_ entry: JournalEntry) async throws {
        var current = try await mutableSnapshot()
        current.journalEntries.removeAll { $0.id == entry.id }
        current.journalEntries.append(entry)
        try persist(current)
    }

    func loadJournalEntries(on day: Date, calendar: Calendar = .current) async -> [JournalEntry] {
        guard let current = try? await mutableSnapshot() else { return [] }
        return current.journalEntries.filter { calendar.isDate($0.day, inSameDayAs: day) }
    }

    func loadVibrationPatterns() async -> [VibrationPattern] {
        VibrationPattern.builtIns
    }

    func loadCallVibrationSettings() async -> CallVibrationSettings {
        (try? await mutableSnapshot()).map(\.callVibrationSettings) ?? CallVibrationSettings()
    }

    func saveCallVibrationSettings(_ settings: CallVibrationSettings) async throws {
        var current = try await mutableSnapshot()
        current.callVibrationSettings = settings
        try persist(current)
    }

    func saveAlarm(_ alarm: Alarm) async throws {
        var current = try await mutableSnapshot()
        current.alarms.removeAll { $0.id == alarm.id }
        current.alarms.append(alarm)
        try persist(current)
    }

    func loadAlarms() async -> [Alarm] {
        (try? await mutableSnapshot()).map(\.alarms) ?? []
    }

    func replaceAlarms(_ alarms: [Alarm]) async throws {
        var current = try await mutableSnapshot()
        current.alarms = alarms.sorted { lhs, rhs in
            switch (lhs.nextTriggerAt, rhs.nextTriggerAt) {
            case let (left?, right?):
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.label < rhs.label
            }
        }
        try persist(current)
    }

    func deleteAlarm(id: UUID) async throws {
        var current = try await mutableSnapshot()
        current.alarms.removeAll { $0.id == id }
        try persist(current)
    }

    private func mutableSnapshot() async throws -> LocalStoreSnapshot {
        if let snapshot { return snapshot }
        let loaded = try Self.load(from: fileURL)
        snapshot = loaded
        return loaded
    }

    private func persist(_ newValue: LocalStoreSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.whoordan.encode(newValue)
        try data.write(to: fileURL, options: [.atomic])
        #if os(iOS)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: fileURL.path
        )
        #endif
        snapshot = newValue
    }

    private static func load(from url: URL) throws -> LocalStoreSnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LocalStoreSnapshot()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.whoordan.decode(LocalStoreSnapshot.self, from: data)
    }

    private static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Whoordan", isDirectory: true)
            .appendingPathComponent("whoordan-local-health-store.json")
    }

    private static let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static func backoff(for attempts: Int) -> TimeInterval {
        min(pow(2.0, Double(max(0, attempts - 1))) * 60, 60 * 60)
    }

    private static func sampleOccurs(_ sample: HealthSample, on day: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return calendar.isDate(sample.startDate, inSameDayAs: day)
        }
        guard let endDate = sample.endDate else {
            return sample.startDate >= dayStart && sample.startDate < nextDay
        }
        return sample.startDate < nextDay && endDate > dayStart
    }

    private static func sampleOccursAfter(_ sample: HealthSample, start: Date) -> Bool {
        guard let endDate = sample.endDate else {
            return sample.startDate >= start
        }
        return endDate > start
    }

    private static func sampleOccursBefore(_ sample: HealthSample, end: Date) -> Bool {
        sample.startDate < end
    }
}

private extension LocalHealthRecord {
    var isCloudRestoredSample: Bool {
        sample.metadata["cloud_restored"] == "true" || metadata["cloud_restored"] == "true"
    }
}

private struct LocalStoreSnapshot: Codable, Equatable {
    var consentState = ConsentState()
    var cachedApprovalState: ApprovalState?
    var todaySummary = DailyHealthSummary.empty
    var bodyProfile = BodyProfile()
    var skinTemperatureBaseline = SkinTemperatureBaselineProfile()
    var healthRecords: [LocalHealthRecord] = []
    var sleepSessions: [SleepSession] = []
    var workouts: [Workout] = []
    var journalEntries: [JournalEntry] = []
    var callVibrationSettings = CallVibrationSettings()
    var alarms: [Alarm] = []
    var healthKitCheckpoints: [HealthKitCheckpoint] = []
    var bleCheckpoints: [BLECheckpoint] = []
    var wearableControlPlaneEvents: [WearableControlPlaneEvent] = []
    var supabaseQueue: [SupabaseSyncQueueItem] = []
    var appleHealthWriteQueue: [AppleHealthWriteQueueItem] = []
    var legacyWearableDeviceMigrationApplied = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case consentState
        case cachedApprovalState
        case todaySummary
        case bodyProfile
        case skinTemperatureBaseline
        case healthRecords
        case sleepSessions
        case workouts
        case journalEntries
        case callVibrationSettings
        case alarms
        case healthKitCheckpoints
        case bleCheckpoints
        case wearableControlPlaneEvents
        case supabaseQueue
        case appleHealthWriteQueue
        case legacyWearableDeviceMigrationApplied
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consentState = (try container.decodeIfPresent(ConsentState.self, forKey: .consentState) ?? ConsentState()).normalizedForCurrentPrivacyModel
        cachedApprovalState = try container.decodeIfPresent(ApprovalState.self, forKey: .cachedApprovalState)
        todaySummary = try container.decodeIfPresent(DailyHealthSummary.self, forKey: .todaySummary) ?? .empty
        bodyProfile = try container.decodeIfPresent(BodyProfile.self, forKey: .bodyProfile) ?? BodyProfile()
        skinTemperatureBaseline = try container.decodeIfPresent(SkinTemperatureBaselineProfile.self, forKey: .skinTemperatureBaseline) ?? SkinTemperatureBaselineProfile()
        healthRecords = try container.decodeIfPresent([LocalHealthRecord].self, forKey: .healthRecords) ?? []
        sleepSessions = try container.decodeIfPresent([SleepSession].self, forKey: .sleepSessions) ?? []
        workouts = try container.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        journalEntries = try container.decodeIfPresent([JournalEntry].self, forKey: .journalEntries) ?? []
        callVibrationSettings = try container.decodeIfPresent(CallVibrationSettings.self, forKey: .callVibrationSettings) ?? CallVibrationSettings()
        alarms = try container.decodeIfPresent([Alarm].self, forKey: .alarms) ?? []
        healthKitCheckpoints = try container.decodeIfPresent([HealthKitCheckpoint].self, forKey: .healthKitCheckpoints) ?? []
        bleCheckpoints = try container.decodeIfPresent([BLECheckpoint].self, forKey: .bleCheckpoints) ?? []
        wearableControlPlaneEvents = try container.decodeIfPresent(
            [WearableControlPlaneEvent].self,
            forKey: .wearableControlPlaneEvents
        ) ?? []
        supabaseQueue = try container.decodeIfPresent([SupabaseSyncQueueItem].self, forKey: .supabaseQueue) ?? []
        appleHealthWriteQueue = try container.decodeIfPresent([AppleHealthWriteQueueItem].self, forKey: .appleHealthWriteQueue) ?? []
        let migrationFlag = try container.decodeIfPresent(Bool.self, forKey: .legacyWearableDeviceMigrationApplied)
        legacyWearableDeviceMigrationApplied = migrationFlag ?? false
        if migrationFlag == nil {
            applyLegacyWearableDeviceMigration()
        }
    }

    private mutating func applyLegacyWearableDeviceMigration() {
        healthRecords = healthRecords.map { record in
            var migrated = record
            migrated.sample = Self.legacyTrustedSample(record.sample)
            migrated.metadata = migrated.sample.metadata
            return migrated
        }
        todaySummary = Self.legacyTrustedSummary(todaySummary)
        sleepSessions = sleepSessions.map(Self.legacyTrustedSleepSession)
        workouts = workouts.map(Self.legacyTrustedWorkout)
        legacyWearableDeviceMigrationApplied = true
    }

    private static func legacyTrustedSample(_ sample: HealthSample) -> HealthSample {
        guard let source = legacyTrustedSource(sample.source) else { return sample }
        return HealthSample(
            id: sample.id,
            type: sample.type,
            value: sample.value,
            unit: sample.unit,
            startDate: sample.startDate,
            endDate: sample.endDate,
            source: source,
            sourceRecordID: sample.sourceRecordID,
            confidence: sample.confidence,
            metadata: legacyTrustedMetadata(sample.metadata, originalSource: sample.source)
        )
    }

    private static func legacyTrustedSummary(_ summary: DailyHealthSummary) -> DailyHealthSummary {
        var migrated = summary
        migrated.movement.source = legacyTrustedSource(summary.movement.source) ?? summary.movement.source
        migrated.sleepSummary = summary.sleepSummary.map(legacyTrustedSleepSummary)
        migrated.restingHeartRateSource = legacyTrustedSource(summary.restingHeartRateSource) ?? summary.restingHeartRateSource
        migrated.hrvSource = legacyTrustedSource(summary.hrvSource ?? summary.source) ?? summary.hrvSource
        migrated.respiratoryRateSource = legacyTrustedSource(summary.respiratoryRateSource ?? summary.source)
            ?? summary.respiratoryRateSource
        migrated.oxygenSaturationSource = legacyTrustedSource(summary.oxygenSaturationSource ?? summary.source)
            ?? summary.oxygenSaturationSource
        migrated.vo2MaxSource = legacyTrustedSource(summary.vo2MaxSource ?? summary.source) ?? summary.vo2MaxSource
        migrated.rawWristTemperatureSource = legacyTrustedSource(summary.rawWristTemperatureSource ?? summary.source)
            ?? summary.rawWristTemperatureSource
        migrated.source = legacyTrustedSource(summary.source) ?? summary.source
        return migrated
    }

    private static func legacyTrustedSleepSummary(_ summary: SleepSummary) -> SleepSummary {
        SleepSummary(
            mainSleep: summary.mainSleep.map(legacyTrustedSleepSession),
            naps: summary.naps.map(legacyTrustedSleepSession),
            sessions: summary.sessions.map(legacyTrustedSleepSession),
            source: legacyTrustedSource(summary.source) ?? summary.source,
            confidence: summary.confidence,
            lastUpdated: summary.lastUpdated
        )
    }

    private static func legacyTrustedSleepSession(_ session: SleepSession) -> SleepSession {
        SleepSession(
            id: session.id,
            start: session.start,
            end: session.end,
            asleepMinutes: session.asleepMinutes,
            inBedMinutes: session.inBedMinutes,
            efficiencyPercent: session.efficiencyPercent,
            source: legacyTrustedSource(session.source) ?? session.source,
            confidence: session.confidence,
            stageSegments: session.stageSegments.map(legacyTrustedStageSegment)
        )
    }

    private static func legacyTrustedStageSegment(_ segment: SleepStageSegment) -> SleepStageSegment {
        SleepStageSegment(
            id: segment.id,
            stage: segment.stage,
            start: segment.start,
            end: segment.end,
            minutes: segment.minutes,
            source: legacyTrustedSource(segment.source) ?? segment.source,
            confidence: segment.confidence
        )
    }

    private static func legacyTrustedWorkout(_ workout: Workout) -> Workout {
        Workout(
            id: workout.id,
            start: workout.start,
            end: workout.end,
            activityName: workout.activityName,
            durationMinutes: workout.durationMinutes,
            sourceEnergy: workout.sourceEnergy,
            maxHeartRate: workout.maxHeartRate,
            averageHeartRate: workout.averageHeartRate,
            zonePercentages: workout.zonePercentages,
            source: legacyTrustedSource(workout.source) ?? workout.source
        )
    }

    private static func legacyTrustedSource(_ source: DataSource?) -> DataSource? {
        switch source {
        case .appleHealth, .cloudImport:
            return .legacyWearableDeviceExport
        default:
            return nil
        }
    }

    private static func legacyTrustedMetadata(_ metadata: [String: String], originalSource: DataSource) -> [String: String] {
        var updated = metadata
        updated["legacy_wearable_device_export"] = "true"
        updated["original_source"] = originalSource.rawValue
        updated["source_label"] = DataSource.legacyWearableDeviceExport.label
        return updated
    }

    mutating func upsertSupabaseQueueItem(for record: LocalHealthRecord, userID: UUID?, now: Date) {
        if let index = supabaseQueue.firstIndex(where: { $0.dedupeKey == record.dedupeKey }) {
            supabaseQueue[index].status = .pending
            supabaseQueue[index].updatedAt = now
            supabaseQueue[index].nextAttemptAt = now
            return
        }
        supabaseQueue.append(SupabaseSyncQueueItem(
            id: "supabase:\(record.dedupeKey)",
            userID: userID,
            recordID: record.id,
            dedupeKey: record.dedupeKey,
            sampleType: record.sample.type,
            status: .pending,
            attempts: 0,
            nextAttemptAt: now,
            lastError: nil,
            createdAt: now,
            updatedAt: now
        ))
    }

    mutating func upsertAppleHealthQueueItem(for record: LocalHealthRecord, now: Date) {
        if let index = appleHealthWriteQueue.firstIndex(where: { $0.dedupeKey == record.dedupeKey }) {
            appleHealthWriteQueue[index].status = .pending
            appleHealthWriteQueue[index].sample = record.sample
            appleHealthWriteQueue[index].updatedAt = now
            return
        }
        appleHealthWriteQueue.append(AppleHealthWriteQueueItem(
            id: "apple_health_write:\(record.dedupeKey)",
            recordID: record.id,
            dedupeKey: record.dedupeKey,
            sampleType: record.sample.type,
            sample: record.sample,
            status: .pending,
            attempts: 0,
            lastError: nil,
            createdAt: now,
            updatedAt: now
        ))
    }

    mutating func refreshSkinTemperatureBaseline(now: Date, calendar: Calendar = .current) {
        let result = SkinTemperatureBaselineCalculator.calculate(
            records: healthRecords,
            sleepSessions: sleepSessions,
            calendar: calendar
        )
        if result.eligibleDayCount >= SkinTemperatureBaselineProfile.requiredDayCountDefault,
           let automaticBaselineC = result.baselineC {
            skinTemperatureBaseline = SkinTemperatureBaselineProfile(
                activeBaselineC: automaticBaselineC,
                source: .automatic,
                eligibleDayCount: result.eligibleDayCount,
                requiredDayCount: SkinTemperatureBaselineProfile.requiredDayCountDefault,
                updatedAt: now,
                automaticBaselineSetAt: skinTemperatureBaseline.automaticBaselineSetAt ?? now
            )
            return
        }

        var updated = skinTemperatureBaseline
        updated.eligibleDayCount = result.eligibleDayCount
        updated.requiredDayCount = SkinTemperatureBaselineProfile.requiredDayCountDefault
        updated.updatedAt = now
        if updated.activeBaselineC == nil && updated.source != .automatic {
            updated.source = .none
        }
        skinTemperatureBaseline = updated
    }
}

private struct LocalDataExportEnvelope: Codable, Equatable {
    let formatVersion: Int
    let exportedAt: Date
    let product: String
    let notice: String
    let snapshot: LocalStoreSnapshot

    init(formatVersion: Int, exportedAt: Date, snapshot: LocalStoreSnapshot) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        product = "Whoordan"
        notice = "User-requested local device export. It may contain wellness and fitness data."
        self.snapshot = snapshot
    }
}

private enum SkinTemperatureBaselineCalculator {
    static func calculate(
        records: [LocalHealthRecord],
        sleepSessions: [SleepSession],
        calendar: Calendar
    ) -> (baselineC: Double?, eligibleDayCount: Int) {
        let samples = records
            .map(\.sample)
            .filter { sample in
                sample.type == .wristTemperature
                    && sample.confidence != .unavailable
                    && DeviceMetricSourcePolicy.isProductionMetricSample(sample)
                    && SkinTemperatureBaselineProfile.validBaselineRangeC.contains(sample.value)
                    && isEligibleNightTemperature(sample, sleepSessions: sleepSessions)
            }
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.startDate)
        }
        let dayAverages = grouped.map { day, samples in
            (
                day: day,
                averageC: samples.reduce(0) { $0 + $1.value } / Double(samples.count)
            )
        }
        .sorted { $0.day > $1.day }
        let eligibleDayCount = dayAverages.count
        guard eligibleDayCount >= SkinTemperatureBaselineProfile.requiredDayCountDefault else {
            return (nil, eligibleDayCount)
        }
        let baselineDays = dayAverages.prefix(SkinTemperatureBaselineProfile.requiredDayCountDefault)
        let baseline = baselineDays.reduce(0) { $0 + $1.averageC } / Double(baselineDays.count)
        return (baseline, eligibleDayCount)
    }

    private static func isEligibleNightTemperature(_ sample: HealthSample, sleepSessions: [SleepSession]) -> Bool {
        if sample.source == .legacyWearableDeviceExport {
            return true
        }
        if let context = sample.metadata["measurement_context"] ?? sample.metadata["context"] {
            let normalized = context.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["sleep", "night", "nightly"].contains(normalized) {
                return true
            }
        }
        let sampleEnd = sample.endDate ?? sample.startDate
        return sleepSessions.contains { session in
            sample.startDate < session.end && sampleEnd > session.start
        }
    }
}

enum LocalDayKey {
    static func make(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum AppleHealthWritePolicy {
    static let supportedSampleTypes: Set<HealthSampleType> = [
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .respiratoryRate,
        .sleepAnalysis,
        .steps,
        .activeEnergy,
        .distanceWalkingRunning,
        .oxygenSaturation,
        .bodyTemperature,
        .workout,
        .vo2Max
    ]

    static func initialStatus(for sample: HealthSample, queueRequested: Bool) -> AppleHealthWriteStatus {
        guard queueRequested else { return .notApplicable }
        guard sample.source != .appleHealth else { return .notApplicable }
        guard sample.source != .whoordanEstimate else { return .unsupported }
        guard isSupported(sample) else { return .unsupported }
        return .pending
    }

    static func isSupported(_ sample: HealthSample) -> Bool {
        sample.source != .appleHealth
            && sample.source != .whoordanEstimate
            && supportedSampleTypes.contains(sample.type)
    }
}
