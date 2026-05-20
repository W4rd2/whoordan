import Foundation

enum HealthIngestionOrigin: String, Codable, Equatable {
    case healthKit
    case wearableBLE
    case manual
    case cloudRestore
}

enum HealthIngestionStatus: String, Codable, Equatable {
    case blocked
    case stored
    case noSamples
    case failed
}

struct HealthIngestionResult: Codable, Equatable {
    let status: HealthIngestionStatus
    let storedSampleCount: Int
    let deduplicatedSampleCount: Int
    let queuedSupabaseUploadCount: Int
    let queuedAppleHealthWriteCount: Int
    let updatedSummary: DailyHealthSummary?
    let message: String

    static let blocked = HealthIngestionResult(
        status: .blocked,
        storedSampleCount: 0,
        deduplicatedSampleCount: 0,
        queuedSupabaseUploadCount: 0,
        queuedAppleHealthWriteCount: 0,
        updatedSummary: nil,
        message: "Protected health processing requires admin approval."
    )
}

struct HealthIngestionPipeline {
    private static let sleepAggregationLookbackHours = 12

    private let privacyGuard = PrivacyAccessGuard()

    func ingest(
        samples: [HealthSample],
        origin: HealthIngestionOrigin,
        approval: ApprovalState?,
        consent: ConsentState,
        userID: UUID?,
        localStore: LocalStoring,
        scoringService: ScoringServicing,
        priorSummary: DailyHealthSummary,
        calendar: Calendar = .current,
        now: Date = Date()
    ) async -> HealthIngestionResult {
        guard privacyGuard.canStartProtectedService(approval: approval) else {
            return .blocked
        }
        guard origin != .healthKit else {
            return HealthIngestionResult(
                status: .noSamples,
                storedSampleCount: 0,
                deduplicatedSampleCount: 0,
                queuedSupabaseUploadCount: 0,
                queuedAppleHealthWriteCount: 0,
                updatedSummary: priorSummary,
                message: "HealthKit import is disabled; metrics are accepted only from trusted wearable or local source paths."
            )
        }
        guard !samples.isEmpty else {
            return HealthIngestionResult(
                status: .noSamples,
                storedSampleCount: 0,
                deduplicatedSampleCount: 0,
                queuedSupabaseUploadCount: 0,
                queuedAppleHealthWriteCount: 0,
                updatedSummary: priorSummary,
                message: "No source-labeled samples were available to store."
            )
        }

        do {
            let queueForSupabase = origin == .cloudRestore
                ? false
                : privacyGuard.canQueueHealthData(approval: approval, consent: consent, userID: userID)
            let queueForAppleHealth = origin == .cloudRestore ? false : consent.appleHealthEnabled
            let persistence = try await localStore.saveHealthSamples(
                samples,
                queueForSupabase: queueForSupabase,
                syncUserID: userID,
                queueForAppleHealth: queueForAppleHealth,
                importedAt: now
            )
            let dayStart = calendar.startOfDay(for: now)
            let aggregationStart = calendar.date(
                byAdding: .hour,
                value: -Self.sleepAggregationLookbackHours,
                to: dayStart
            ) ?? dayStart.addingTimeInterval(TimeInterval(-Self.sleepAggregationLookbackHours * 60 * 60))
            let aggregationEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
                ?? dayStart.addingTimeInterval(24 * 60 * 60)
            let daySamples = await localStore.loadHealthSamples(
                type: nil,
                source: nil,
                start: aggregationStart,
                end: aggregationEnd,
                limit: nil
            )
            let skinTemperatureBaseline = await localStore.loadSkinTemperatureBaselineProfile()
            let bodyProfile = await localStore.loadBodyProfile()
            var updated = DailyHealthAggregator.aggregate(
                samples: daySamples,
                day: now,
                goal: priorSummary.movement.goal,
                calendar: calendar,
                prior: priorSummary,
                skinTemperatureBaseline: skinTemperatureBaseline
            )
            updated = scoringService.score(summary: updated, bodyProfile: bodyProfile)
            await localStore.saveTodaySummary(updated)

            return HealthIngestionResult(
                status: .stored,
                storedSampleCount: persistence.insertedCount,
                deduplicatedSampleCount: persistence.deduplicatedCount,
                queuedSupabaseUploadCount: persistence.queuedSupabaseUploadCount,
                queuedAppleHealthWriteCount: persistence.queuedAppleHealthWriteCount,
                updatedSummary: updated,
                message: "Stored source-labeled health samples locally before downstream sync."
            )
        } catch {
            return HealthInestionFailure.make(error: error)
        }
    }
}

private enum HealthInestionFailure {
    static func make(error: Error) -> HealthIngestionResult {
        HealthIngestionResult(
            status: .failed,
            storedSampleCount: 0,
            deduplicatedSampleCount: 0,
            queuedSupabaseUploadCount: 0,
            queuedAppleHealthWriteCount: 0,
            updatedSummary: nil,
            message: "Local health persistence failed."
        )
    }
}
