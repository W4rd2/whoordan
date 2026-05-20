import Foundation

enum WearableProtocolError: Error, Equatable {
    case frameTooShort
    case invalidStartByte
    case invalidLength
    case invalidHeaderCRC
    case invalidContentCRC
}

enum WearablePacketType: UInt8 {
    case command = 0x23
    case commandResponse = 0x24
    case realtimeData = 0x28
    case rawRealtimeData = 0x2B
    case historicalData = 0x2F
    case event = 0x30
    case metadata = 0x31
    case firmwareLog = 0x32
}

enum WearableCommand: UInt8 {
    case realtimeHeartRate = 0x03
    case runHapticPatternMaverick = 0x13
    case sendHistoricalData = 0x16
    case getBatteryLevel = 0x1A
    case getDataRange = 0x22
    case getHelloHarvard = 0x23
    case sendR10R11Realtime = 0x3F
    case getAlarmTime = 0x43
    case getAdvertisingName = 0x4C
    case runHapticPatternHarvard = 0x4F
    case opticalMode = 0x6C
    case stopHaptics = 0x7A
    case persistentR21 = 0x9A
}

struct WearableUUIDs {
    static let service = "61080001-8D6D-82B8-614A-1C8CB0F8DCC6"
    static let commandWrite = "61080002-8D6D-82B8-614A-1C8CB0F8DCC6"
    static let commandResponse = "61080003-8D6D-82B8-614A-1C8CB0F8DCC6"
    static let events = "61080004-8D6D-82B8-614A-1C8CB0F8DCC6"
    static let sensorData = "61080005-8D6D-82B8-614A-1C8CB0F8DCC6"
    static let diagnostics = "61080007-8D6D-82B8-614A-1C8CB0F8DCC6"
}

enum StandardBLEUUIDs {
    static let deviceInformationService = "180A"
    static let heartRateService = "180D"
    static let batteryService = "180F"
    static let batteryLevel = "2A19"
    static let heartRateMeasurement = "2A37"
    static let bodySensorLocation = "2A38"
    static let manufacturerName = "2A29"
    static let modelNumber = "2A24"
    static let serialNumber = "2A25"
    static let firmwareRevision = "2A26"
    static let hardwareRevision = "2A27"
    static let softwareRevision = "2A28"
}

enum WearableServiceCompatibility {
    static func isProtocolCapable(advertisedServiceUUIDs: [String]) -> Bool {
        advertisedServiceUUIDs.contains { normalized($0) == normalized(WearableUUIDs.service) }
    }

    static func isConnectable(advertisedServiceUUIDs: [String]) -> Bool {
        advertisedServiceUUIDs.contains { uuid in
            let normalizedUUID = normalized(uuid)
            return normalizedUUID == normalized(WearableUUIDs.service)
                || normalizedUUID == normalized(StandardBLEUUIDs.heartRateService)
        }
    }

    private static func normalized(_ uuid: String) -> String {
        uuid.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

struct WearableStandardHeartRateMeasurement: Equatable {
    let bpm: Int
    let contactDetected: Bool?
    let rrIntervalsMS: [Double]
}

struct WearableDecodedPacket: Equatable {
    let packetType: WearablePacketType
    let recordType: UInt8?
    var sequence: UInt8?
    var commandResponse: WearableCommandResponse?
    var metadata: WearableMetadataPacket?
    var event: WearableEventPacket?
    var firmwareLog: WearableFirmwareLog?
    var dataRecord: WearableDataRecord?
    var heartRateBPM: Int?
    var imuSampleCount: Int = 0
    var ppgSampleCount: Int = 0
    var ppgChannelCount: Int = 0
    var eventType: UInt16?

    var recordLabel: String {
        guard let recordType else { return packetType.description }
        switch recordType {
        case 10: return "R10 realtime IMU/HR"
        case 11: return "R11 realtime raw"
        case 20: return "R20 raw"
        case 21: return "R21 optical PPG"
        case 24: return "R24 historical scalar candidate"
        case 7: return "R7 raw"
        default: return "record \(recordType)"
        }
    }
}

struct WearableCommandResponse: Equatable {
    let sequence: UInt8
    let commandByte: UInt8
    let command: WearableCommand?
    let requestSequence: UInt8?
    let statusByte: UInt8?
    let payloadByteCount: Int
    let advertisingName: String?
    let serialLikeValue: String?
    let deviceFingerprint: String?
    let hello: WearableHelloHarvardInfo?
    let dataRange: WearableDataRangeResponse?
    let alarm: WearableAlarmResponse?
    let historicalSync: WearableHistoricalSyncResponse?

    var kind: String {
        switch command {
        case .getHelloHarvard:
            return "helloHarvard"
        case .getAdvertisingName:
            return "advertisingName"
        case .getDataRange:
            return "dataRange"
        case .getAlarmTime:
            return "alarm"
        case .sendHistoricalData:
            return "historicalSync"
        default:
            return "command_0x\(String(format: "%02X", commandByte))"
        }
    }
}

struct WearableHelloHarvardInfo: Equatable {
    let batteryPercent: Double?
    let isCharging: Bool?
    let rtcSeconds: UInt32?
    let serialFingerprint: String?
    let isOnWrist: Bool?
    let payloadByteCount: Int
}

struct WearableDataRangeResponse: Equatable {
    let dateCandidates: [Date]
    let payloadByteCount: Int
}

struct WearableAlarmResponse: Equatable {
    let isConfigured: Bool?
    let payloadByteCount: Int
}

struct WearableHistoricalSyncResponse: Equatable {
    let statusByte: UInt8?
    let payloadByteCount: Int
}

struct WearableMetadataPacket: Equatable {
    let sequence: UInt8?
    let isBatchMarker: Bool
    let batchToken: Data?
    let isEndOfSync: Bool
    let payloadByteCount: Int
}

enum WearableEventKind: String, Equatable {
    case batteryLevel
    case chargingStarted
    case chargingStopped
    case wristOn
    case wristOff
    case doubleTap
    case realtimeHeartRateStarted
    case realtimeHeartRateStopped
    case temperature
    case alarmSet
    case alarmFired
    case alarmDisabled
    case hapticsFired
    case hapticsTerminated
    case unknown
}

struct WearableEventPacket: Equatable {
    let sequence: UInt8?
    let eventType: UInt16
    let kind: WearableEventKind
    let timestamp: Date?
    let numericValue: Double?
    let payloadByteCount: Int
}

struct WearableFirmwareLog: Equatable {
    let sequence: UInt8?
    let message: String
    let category: String?
}

struct WearableDataRecord: Equatable {
    let recordType: UInt8
    let label: String
    let rawTimestamp: UInt32?
    let payloadByteCount: Int
    let r10: WearableR10Record?
    let r11: WearableR11Record?
    let r21: WearableR21Record?
    let r24: WearableR24Record?
}

struct WearableAxisSummary: Equatable {
    let sampleCount: Int
    let minimum: Int
    let maximum: Int
    let average: Double
    let values: [Int]
}

struct WearableTriAxisSummary: Equatable {
    let x: WearableAxisSummary
    let y: WearableAxisSummary
    let z: WearableAxisSummary

    var sampleCount: Int {
        min(x.sampleCount, y.sampleCount, z.sampleCount)
    }
}

struct WearableR10Record: Equatable {
    let isCompleteChunk: Bool
    let heartRateBPM: Int?
    let skinTemperatureC: Double?
    let accelerometerSampleCount: Int
    let gyroscopeSampleCount: Int
    let rawTimestamp: UInt32?
    let accelerometer: WearableTriAxisSummary?
    let gyroscope: WearableTriAxisSummary?
}

struct WearableR11Record: Equatable {
    let payloadByteCount: Int
    let rawTimestamp: UInt32?
    let note: String
}

struct WearableOpticalChannelSummary: Equatable {
    let sampleCount: Int
    let minimum: Int
    let maximum: Int
    let average: Double
}

struct WearableR21Record: Equatable {
    let ledDriveLevel: Int?
    let sampleCount: Int
    let secondarySampleCount: Int?
    let channelCount: Int
    let channelSummaries: [String: WearableOpticalChannelSummary]
    let note: String
}

struct WearableR24Record: Equatable {
    let spo2CandidatePercent: Double?
    let rawTimestamp: UInt32?
    let note: String
}

struct WearableStepEstimate: Equatable {
    let count: Int
    let peakCount: Int
    let cadenceStepsPerMinute: Double
    let thresholdG: Double
}

struct WearableSleepStageEstimate: Equatable {
    let stage: SleepStage
    let confidence: ConfidenceLevel
    let confidenceScore: Double
    let heartRateBPM: Int
    let normalizedMotionRange: Double
    let accelerometerRange: Double
    let gyroscopeRange: Double
}

struct WearableIMUSampleBatch: Equatable {
    let id: String
    let deviceID: String
    let characteristicUUID: String
    let recordType: UInt8
    let sampleCount: Int
    let source: DataSource
    let confidence: ConfidenceLevel
    let metadata: [String: String]
}

enum WearableUnavailableSignal: String, Equatable {
    case heartRateVariability = "HRV requires standard RR/IBI data; unavailable in this proprietary packet"
    case oxygenSaturation = "Direct calibrated SpO2 unavailable; R24 can emit a low-confidence BLE-derived wellness estimate"
    case steps = "Direct steps unavailable; R10 IMU can emit a low-confidence BLE-derived estimate"
    case respiratoryRate = "Direct respiratory rate unavailable; RR intervals can emit a low-confidence BLE-derived estimate"
    case sleepStages = "Direct sleep stages unavailable; R10 HR/IMU can emit low-confidence BLE-derived stages"
}

enum WearableDedupe {
    static func id(
        deviceID: String,
        characteristicUUID: String,
        packetType: WearablePacketType,
        recordType: UInt8?,
        sequence: UInt8?,
        rawTimestamp: UInt32?,
        payloadByteCount: Int,
        sampleUnixMinute: Int? = nil
    ) -> String {
        var materialParts: [String] = []
        materialParts.append(deviceID)
        materialParts.append(characteristicUUID)
        materialParts.append(packetType.description)
        materialParts.append(recordType.map(String.init) ?? "none")
        materialParts.append(sequence.map(String.init) ?? "none")
        materialParts.append(rawTimestamp.map(String.init) ?? "none")
        materialParts.append(String(payloadByteCount))
        materialParts.append(sampleUnixMinute.map(String.init) ?? "none")
        let material = materialParts.joined(separator: "|")
        return "wearable_ble:\(WearablePrivacy.fingerprint(material))"
    }
}

enum WearablePrivacy {
    static func fingerprint(_ value: String) -> String {
        let bytes = [UInt8](value.utf8)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(format: "%016llX", hash)
    }
}

enum WearableStandardParser {
    static func parseBatteryLevel(_ data: Data) -> Int? {
        guard let value = data.first, value <= 100 else { return nil }
        return Int(value)
    }

    static func parseHeartRateMeasurement(_ data: Data) -> WearableStandardHeartRateMeasurement? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        let flags = bytes[0]
        let isUInt16 = (flags & 0x01) == 0x01
        let hasEnergyExpended = (flags & 0x08) == 0x08
        let hasRRIntervals = (flags & 0x10) == 0x10
        let bpm: Int
        var cursor = 1
        if isUInt16 {
            guard bytes.count >= 3 else { return nil }
            bpm = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
            cursor = 3
        } else {
            bpm = Int(bytes[1])
            cursor = 2
        }
        guard (25...240).contains(bpm) else { return nil }
        if hasEnergyExpended {
            guard bytes.count >= cursor + 2 else { return nil }
            cursor += 2
        }
        let rrIntervalsMS: [Double]
        if hasRRIntervals {
            rrIntervalsMS = stride(from: cursor, to: bytes.count - 1, by: 2).compactMap { index in
                guard index + 1 < bytes.count else { return nil }
                let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                let ms = (Double(raw) / 1024.0) * 1000.0
                return (250...2_200).contains(ms) ? ms : nil
            }
        } else {
            rrIntervalsMS = []
        }

        let contactFlag = (flags & 0x06) >> 1
        let contactDetected: Bool?
        switch contactFlag {
        case 0, 1:
            contactDetected = nil
        case 2:
            contactDetected = false
        case 3:
            contactDetected = true
        default:
            contactDetected = nil
        }
        return WearableStandardHeartRateMeasurement(
            bpm: bpm,
            contactDetected: contactDetected,
            rrIntervalsMS: rrIntervalsMS
        )
    }
}

enum WearableHRVCalculator {
    static let minimumProductionRRIntervalCount = 16

    static func sdnnMS(from rrIntervalsMS: [Double]) -> Double? {
        let values = rrIntervalsMS.filter { (250...2_200).contains($0) }
        guard values.count >= 2 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        let sdnn = sqrt(variance)
        return sdnn.isFinite ? sdnn : nil
    }

    static func rmssdMS(from rrIntervalsMS: [Double]) -> Double? {
        let values = rrIntervalsMS.filter { (250...2_200).contains($0) }
        guard values.count >= 3 else { return nil }
        let diffs = zip(values.dropFirst(), values).map { current, previous in
            pow(current - previous, 2)
        }
        guard !diffs.isEmpty else { return nil }
        let rmssd = sqrt(diffs.reduce(0, +) / Double(diffs.count))
        return rmssd.isFinite ? rmssd : nil
    }
}

enum WearableRespiratoryRateEstimator {
    static let minimumRRIntervalCount = 30
    static let minimumWindowSeconds = 30.0

    static func estimateFromRRIntervals(_ rrIntervalsMS: [Double]) -> Double? {
        let values = rrIntervalsMS.filter { (250...2_200).contains($0) }
        guard values.count >= minimumRRIntervalCount else { return nil }
        let totalSeconds = values.reduce(0, +) / 1_000.0
        guard totalSeconds >= minimumWindowSeconds else { return nil }

        var elapsed = 0.0
        let times = values.map { interval -> Double in
            elapsed += interval / 1_000.0
            return elapsed
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let detrended = values.map { $0 - mean }
        guard detrended.contains(where: { abs($0) > 0.5 }) else { return nil }

        let candidates = stride(from: 6.0, through: 30.0, by: 0.25)
        let scored = candidates.compactMap { breathsPerMinute -> (rate: Double, score: Double)? in
            let frequency = breathsPerMinute / 60.0
            var sinProjection = 0.0
            var cosProjection = 0.0
            for (time, value) in zip(times, detrended) {
                let angle = 2.0 * Double.pi * frequency * time
                sinProjection += value * sin(angle)
                cosProjection += value * cos(angle)
            }
            let score = hypot(sinProjection, cosProjection)
            return score.isFinite ? (breathsPerMinute, score) : nil
        }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score > 0 else { return nil }
        return best.rate
    }
}

enum WearableR10DerivedMetricEstimator {
    static let assumedAccelerometerSampleRateHz = 50.0
    static let wristVectorMagnitudeThresholdG = 0.0359
    static let sleepStillnessNormalizedRange = 0.12
    static let sleepStageClassifierVersion = "r10_hr_imu_session_context_v1"

    static func estimatedStepCount(from r10: WearableR10Record) -> Int? {
        stepEstimate(from: r10)?.count
    }

    static func stepEstimate(from r10: WearableR10Record) -> WearableStepEstimate? {
        guard r10.isCompleteChunk,
              let accelerometer = r10.accelerometer,
              accelerometer.sampleCount >= 80 else {
            return nil
        }
        let magnitudes = vectorMagnitudes(from: accelerometer)
        guard magnitudes.count >= 80 else { return nil }
        let gravity = median(magnitudes)
        guard (500...20_000).contains(gravity) else { return nil }

        let normalized = magnitudes.map { ($0 - gravity) / gravity }
        guard let normalizedRange = normalized.range,
              normalizedRange >= 0.25 else {
            return nil
        }

        let smoothed = movingAverage(normalized, radius: 1)
        let baseline = median(smoothed)
        let noise = median(smoothed.map { abs($0 - baseline) })
        let threshold = max(wristVectorMagnitudeThresholdG, noise * 1.5)
        let peaks = recurrentPeaks(in: smoothed, threshold: threshold, minimumDistance: 12)
        guard peaks.count >= 2 else { return nil }

        let intervals = zip(peaks.dropFirst(), peaks).map { current, previous in
            current.index - previous.index
        }
        guard let medianInterval = optionalMedian(intervals.map(Double.init)), medianInterval > 0 else {
            return nil
        }
        let cadence = (60.0 * assumedAccelerometerSampleRateHz) / medianInterval
        guard (40...220).contains(cadence) else { return nil }
        if intervals.count >= 2, coefficientOfVariation(intervals.map(Double.init)) > 0.55 {
            return nil
        }

        return WearableStepEstimate(
            count: peaks.count,
            peakCount: peaks.count,
            cadenceStepsPerMinute: cadence,
            thresholdG: threshold
        )
    }

    static func estimatedSleepStage(from r10: WearableR10Record) -> SleepStage? {
        sleepStageEstimate(from: r10)?.stage
    }

    static func sleepStageEstimate(from r10: WearableR10Record) -> WearableSleepStageEstimate? {
        guard r10.isCompleteChunk,
              let heartRate = r10.heartRateBPM,
              (38...72).contains(heartRate),
              let accelerometer = r10.accelerometer else {
            return nil
        }
        let magnitudes = vectorMagnitudes(from: accelerometer)
        guard let gravity = optionalMedian(magnitudes),
              gravity > 0,
              let vectorRange = magnitudes.range,
              vectorRange / gravity <= sleepStillnessNormalizedRange else {
            return nil
        }
        let accelRange = rangeMagnitude(accelerometer)
        let gyroRange = r10.gyroscope.map(rangeMagnitude) ?? 0
        guard accelRange <= 450, gyroRange <= 450 else { return nil }
        let normalizedRange = vectorRange / gravity
        let stillnessScore = max(0, min(1, 1 - (normalizedRange / sleepStillnessNormalizedRange)))
        let movementPenalty = max(accelRange / 450, gyroRange / 450)
        let confidenceScore = max(0.15, min(0.55, (stillnessScore * 0.45) + ((1 - movementPenalty) * 0.10)))
        let stage: SleepStage
        if heartRate <= 55 {
            stage = .deep
        } else if heartRate <= 64 {
            stage = .core
        } else {
            stage = .asleep
        }
        return WearableSleepStageEstimate(
            stage: stage,
            confidence: .low,
            confidenceScore: confidenceScore,
            heartRateBPM: heartRate,
            normalizedMotionRange: normalizedRange,
            accelerometerRange: accelRange,
            gyroscopeRange: gyroRange
        )
    }

    private static func rangeMagnitude(_ summary: WearableTriAxisSummary) -> Double {
        let x = Double(summary.x.maximum - summary.x.minimum)
        let y = Double(summary.y.maximum - summary.y.minimum)
        let z = Double(summary.z.maximum - summary.z.minimum)
        return sqrt((x * x) + (y * y) + (z * z))
    }

    private static func vectorMagnitudes(from summary: WearableTriAxisSummary) -> [Double] {
        let sampleCount = min(summary.x.values.count, summary.y.values.count, summary.z.values.count)
        guard sampleCount > 0 else { return [] }
        return (0..<sampleCount).map { index in
            let x = Double(summary.x.values[index])
            let y = Double(summary.y.values[index])
            let z = Double(summary.z.values[index])
            return sqrt((x * x) + (y * y) + (z * z))
        }
    }

    private static func movingAverage(_ values: [Double], radius: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        return values.indices.map { index in
            let lower = max(values.startIndex, index - radius)
            let upper = min(values.endIndex - 1, index + radius)
            let window = values[lower...upper]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    private static func recurrentPeaks(
        in values: [Double],
        threshold: Double,
        minimumDistance: Int
    ) -> [(index: Int, value: Double)] {
        guard values.count >= 3 else { return [] }
        var peaks: [(index: Int, value: Double)] = []
        for index in 1..<(values.count - 1) where values[index] >= threshold
            && values[index] >= values[index - 1]
            && values[index] > values[index + 1] {
            if let last = peaks.last, index - last.index < minimumDistance {
                if values[index] > last.value {
                    peaks[peaks.count - 1] = (index, values[index])
                }
            } else {
                peaks.append((index, values[index]))
            }
        }
        return peaks
    }

    private static func median(_ values: [Double]) -> Double {
        optionalMedian(values) ?? 0
    }

    private static func optionalMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return .infinity }
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance) / mean
    }
}

private extension Array where Element == Double {
    var range: Double? {
        guard let minimum = self.min(), let maximum = self.max() else { return nil }
        return maximum - minimum
    }
}

enum WearableProtocol {
    static let maxFrameLength = 4096

    static func crc8(_ data: Data) -> UInt8 {
        data.reduce(UInt8(0)) { crc, byte in
            crc8Table[Int(crc ^ byte)]
        }
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            var current = (crc ^ UInt32(byte)) & 0xFF
            for _ in 0..<8 {
                current = (current & 1) == 1 ? (0xEDB8_8320 ^ (current >> 1)) : (current >> 1)
            }
            crc = (crc >> 8) ^ current
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func buildCommand(sequence: UInt8, command: WearableCommand, payload: [UInt8] = []) -> Data {
        var inner = Data([WearablePacketType.command.rawValue, sequence, command.rawValue])
        inner.append(contentsOf: payload.isEmpty ? [0x00] : payload)
        while inner.count % 4 != 0 {
            inner.append(0x00)
        }
        return frame(inner: inner)
    }

    static func frame(inner: Data) -> Data {
        let length = UInt16(inner.count + 4)
        let lengthBytes = Data([UInt8(length & 0xFF), UInt8((length >> 8) & 0xFF)])
        var data = Data([0xAA])
        data.append(lengthBytes)
        data.append(crc8(lengthBytes))
        data.append(inner)
        let crc = crc32(inner)
        data.append(contentsOf: [
            UInt8(crc & 0xFF),
            UInt8((crc >> 8) & 0xFF),
            UInt8((crc >> 16) & 0xFF),
            UInt8((crc >> 24) & 0xFF)
        ])
        return data
    }

    static func decodeFrame(_ frame: Data) throws -> Data {
        guard frame.count >= 8 else { throw WearableProtocolError.frameTooShort }
        guard frame[0] == 0xAA else { throw WearableProtocolError.invalidStartByte }
        let length = Int(UInt16(frame[1]) | (UInt16(frame[2]) << 8))
        guard length >= 4, length <= maxFrameLength, frame.count == length + 4 else {
            throw WearableProtocolError.invalidLength
        }
        let lengthBytes = frame.subdata(in: 1..<3)
        guard crc8(lengthBytes) == frame[3] else { throw WearableProtocolError.invalidHeaderCRC }
        let innerEnd = 4 + length - 4
        let inner = frame.subdata(in: 4..<innerEnd)
        let expected = UInt32(frame[innerEnd])
            | (UInt32(frame[innerEnd + 1]) << 8)
            | (UInt32(frame[innerEnd + 2]) << 16)
            | (UInt32(frame[innerEnd + 3]) << 24)
        guard crc32(inner) == expected else { throw WearableProtocolError.invalidContentCRC }
        return inner
    }

    static func initSequence() -> [Data] {
        [
            buildCommand(sequence: 0x00, command: .getHelloHarvard, payload: [0x00]),
            buildCommand(sequence: 0x01, command: .getAdvertisingName, payload: [0x00]),
            buildCommand(sequence: 0x02, command: .getDataRange, payload: [0x00]),
            buildCommand(sequence: 0x03, command: .getAlarmTime, payload: [0x01]),
            buildCommand(sequence: 0x04, command: .sendHistoricalData, payload: [0x00])
        ]
    }

    static func buildBatchAck(counter: UInt8, batchToken: Data) -> Data {
        precondition(batchToken.count == 8)
        var body = Data([0x23, counter, 0x17, 0x01])
        body.append(batchToken)
        return frame(inner: body)
    }

    static func realtimeEnableCommands(startSequence: UInt8) -> [Data] {
        [
            buildCommand(sequence: startSequence, command: .realtimeHeartRate, payload: [0x01]),
            buildCommand(sequence: startSequence &+ 1, command: .sendR10R11Realtime, payload: [0x01]),
            buildCommand(sequence: startSequence &+ 2, command: .persistentR21, payload: [0x01]),
            buildCommand(sequence: startSequence &+ 3, command: .opticalMode, payload: [0x01])
        ]
    }

    static func realtimeDisableCommands(startSequence: UInt8) -> [Data] {
        [
            buildCommand(sequence: startSequence, command: .realtimeHeartRate, payload: [0x00]),
            buildCommand(sequence: startSequence &+ 1, command: .sendR10R11Realtime, payload: [0x00]),
            buildCommand(sequence: startSequence &+ 2, command: .persistentR21, payload: [0x00]),
            buildCommand(sequence: startSequence &+ 3, command: .opticalMode, payload: [0x00])
        ]
    }

    private static let crc8Table: [UInt8] = [
        0,7,14,9,28,27,18,21,56,63,54,49,36,35,42,45,
        112,119,126,121,108,107,98,101,72,79,70,65,84,83,90,93,
        224,231,238,233,252,251,242,245,216,223,214,209,196,195,202,205,
        144,151,158,153,140,139,130,133,168,175,166,161,180,179,186,189,
        199,192,201,206,219,220,213,210,255,248,241,246,227,228,237,234,
        183,176,185,190,171,172,165,162,143,136,129,134,147,148,157,154,
        39,32,41,46,59,60,53,50,31,24,17,22,3,4,13,10,
        87,80,89,94,75,76,69,66,111,104,97,102,115,116,125,122,
        137,142,135,128,149,146,155,156,177,182,191,184,173,170,163,164,
        249,254,247,240,229,226,235,236,193,198,207,200,221,218,211,212,
        105,110,103,96,117,114,123,124,81,86,95,88,77,74,67,68,
        25,30,23,16,5,2,11,12,33,38,47,40,61,58,51,52,
        78,73,64,71,82,85,92,91,118,113,120,127,106,109,100,99,
        62,57,48,55,34,37,44,43,6,1,8,15,26,29,20,19,
        174,169,160,167,178,181,188,187,150,145,152,159,138,141,132,131,
        222,217,208,215,194,197,204,203,230,225,232,239,250,253,244,243
    ]
}

struct FrameReassembler {
    private(set) var buffer = Data()
    private(set) var droppedFragmentCount = 0
    let maxBufferSize: Int

    init(maxBufferSize: Int = 8192) {
        self.maxBufferSize = maxBufferSize
    }

    mutating func append(_ fragment: Data) -> [Data] {
        var frames: [Data] = []
        guard !fragment.isEmpty else { return frames }
        if isAwaitingIncompleteFrame, startsWithPlausibleFrameHeader(fragment) {
            buffer.removeAll()
            droppedFragmentCount += 1
        }
        buffer.append(fragment)
        resynchronizeBuffer()
        while let frame = extractFrame() {
            frames.append(frame)
            resynchronizeBuffer()
        }
        if buffer.count > maxBufferSize {
            buffer.removeAll()
            droppedFragmentCount += 1
        }
        return frames
    }

    private var isAwaitingIncompleteFrame: Bool {
        let bytes = [UInt8](buffer)
        guard bytes.count >= 4, bytes[0] == 0xAA else { return false }
        let length = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        guard length >= 4, length <= WearableProtocol.maxFrameLength else { return false }
        return bytes.count < length + 4
    }

    private func startsWithPlausibleFrameHeader(_ data: Data) -> Bool {
        let bytes = [UInt8](data.drop(while: { $0 == 0x00 }))
        guard bytes.count >= 4, bytes[0] == 0xAA else { return false }
        let length = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        return length >= 4 && length <= WearableProtocol.maxFrameLength
    }

    private mutating func resynchronizeBuffer() {
        while buffer.first == 0x00 {
            buffer.removeFirst()
        }
        guard let first = buffer.first, first != 0xAA else { return }
        if let start = buffer.firstIndex(of: 0xAA) {
            buffer.removeFirst(start)
        } else {
            buffer.removeAll()
        }
        droppedFragmentCount += 1
    }

    private mutating func extractFrame() -> Data? {
        let bytes = [UInt8](buffer)
        guard bytes.count >= 4 else { return nil }
        guard bytes[0] == 0xAA else {
            buffer.removeAll()
            droppedFragmentCount += 1
            return nil
        }
        let length = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        guard length >= 4, length <= WearableProtocol.maxFrameLength else {
            buffer.removeAll()
            droppedFragmentCount += 1
            return nil
        }
        let total = length + 4
        guard bytes.count >= total else { return nil }
        let frame = Data(bytes[0..<total])
        buffer = Data(bytes.dropFirst(total))
        while buffer.first == 0x00 {
            buffer.removeFirst()
        }
        return frame
    }
}

struct WearablePacketDecoder {
    static func decode(frame: Data) -> WearableDecodedPacket? {
        guard let inner = try? WearableProtocol.decodeFrame(frame),
              let packetType = inner.first.flatMap(WearablePacketType.init(rawValue:)) else {
            return nil
        }

        var decoded = WearableDecodedPacket(
            packetType: packetType,
            recordType: dataRecordType(inner: inner, packetType: packetType),
            sequence: sequence(inner: inner)
        )

        switch packetType {
        case .commandResponse:
            decoded.commandResponse = commandResponse(inner: inner)
        case .metadata:
            decoded.metadata = metadata(inner: inner, frame: frame)
        case .event:
            decoded.event = event(inner: inner)
            decoded.eventType = decoded.event?.eventType
        case .firmwareLog:
            decoded.firmwareLog = firmwareLog(inner: inner)
        case .realtimeData, .rawRealtimeData, .historicalData:
            decoded.dataRecord = dataRecord(inner: inner)
            switch decoded.dataRecord?.recordType {
            case 10:
                decoded.heartRateBPM = decoded.dataRecord?.r10?.heartRateBPM
                decoded.imuSampleCount = decoded.dataRecord?.r10?.accelerometerSampleCount ?? 0
            case 21:
                decoded.ppgSampleCount = decoded.dataRecord?.r21?.sampleCount ?? 0
                decoded.ppgChannelCount = decoded.dataRecord?.r21?.channelCount ?? 0
            case 24:
                decoded.ppgSampleCount = decoded.dataRecord?.r24?.spo2CandidatePercent == nil ? 0 : 1
            default:
                break
            }
        case .command:
            break
        }

        return decoded
    }

    static func isBatchMarker(frame: Data) -> Bool {
        frame.count >= 25 && frame.prefix(5).elementsEqual([0xAA, 0x1C, 0x00, 0xAB, WearablePacketType.metadata.rawValue])
    }

    static func batchToken(frame: Data) -> Data? {
        guard isBatchMarker(frame: frame) else { return nil }
        return frame.subdata(in: 17..<25)
    }

    static func eventType(frame: Data) -> UInt16? {
        guard frame.count >= 16, frame[4] == WearablePacketType.event.rawValue else { return nil }
        return UInt16(frame[6]) | (UInt16(frame[7]) << 8)
    }

    static func r10HeartRate(frame: Data) -> UInt8? {
        guard let inner = try? WearableProtocol.decodeFrame(frame) else { return nil }
        return r10HeartRate(inner: inner)
    }

    static func r21SampleCount(frame: Data) -> UInt8? {
        guard frame.count > 20, frame[5] == 21 else { return nil }
        return frame[20]
    }

    static func commandResponse(inner: Data) -> WearableCommandResponse? {
        guard inner.count >= 3, inner[0] == WearablePacketType.commandResponse.rawValue else { return nil }
        let sequence = inner[1]
        let commandByte = inner[2]
        let command = WearableCommand(rawValue: commandByte)
        let requestSequence = inner.count > 3 ? inner[3] : nil
        let statusByte = inner.count > 4 ? inner[4] : nil
        let payload = inner.count > 5 ? inner.subdata(in: 5..<inner.count) : Data()
        let textTokens = printableTokens(in: payload)
        let advertisingName = command == .getAdvertisingName ? bestDeviceName(from: textTokens) : nil
        let serialLike = command == .getHelloHarvard ? serialLikeValue(from: textTokens) : nil
        let hello = command == .getHelloHarvard ? helloHarvardInfo(from: payload) : nil
        let fingerprint = serialLike.map(WearablePrivacy.fingerprint)
            ?? hello?.serialFingerprint
            ?? (payload.isEmpty ? nil : WearablePrivacy.fingerprint(payload.base64EncodedString()))
        let range = command == .getDataRange
            ? WearableDataRangeResponse(dateCandidates: dateCandidates(in: payload), payloadByteCount: payload.count)
            : nil
        let alarm = command == .getAlarmTime
            ? WearableAlarmResponse(isConfigured: payload.first.map { $0 != 0 }, payloadByteCount: payload.count)
            : nil
        let historical = command == .sendHistoricalData
            ? WearableHistoricalSyncResponse(statusByte: statusByte, payloadByteCount: payload.count)
            : nil
        return WearableCommandResponse(
            sequence: sequence,
            commandByte: commandByte,
            command: command,
            requestSequence: requestSequence,
            statusByte: statusByte,
            payloadByteCount: payload.count,
            advertisingName: advertisingName,
            serialLikeValue: serialLike,
            deviceFingerprint: fingerprint,
            hello: hello,
            dataRange: range,
            alarm: alarm,
            historicalSync: historical
        )
    }

    static func metadata(inner: Data, frame: Data) -> WearableMetadataPacket? {
        guard inner.first == WearablePacketType.metadata.rawValue else { return nil }
        let token = batchToken(frame: frame)
        return WearableMetadataPacket(
            sequence: sequence(inner: inner),
            isBatchMarker: token != nil,
            batchToken: token,
            isEndOfSync: token == nil,
            payloadByteCount: max(0, inner.count - 2)
        )
    }

    static func event(inner: Data) -> WearableEventPacket? {
        guard let eventType = eventType(inner: inner) else { return nil }
        let timestamp = eventTimestampSeconds(inner: inner).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let payload: Data
        if inner.count > 12 {
            payload = inner.subdata(in: 12..<inner.count)
        } else if inner.count > 4 {
            payload = inner.subdata(in: 4..<inner.count)
        } else {
            payload = Data()
        }
        let kind: WearableEventKind
        switch eventType {
        case 3:
            kind = .batteryLevel
        case 7:
            kind = .chargingStarted
        case 8:
            kind = .chargingStopped
        case 9:
            kind = .wristOn
        case 10:
            kind = .wristOff
        case 14:
            // Local controlled captures show event 14 outside double-tap-only actions.
            kind = .unknown
        case 33:
            kind = .realtimeHeartRateStarted
        case 34:
            kind = .realtimeHeartRateStopped
        case 17:
            kind = .temperature
        case 56:
            kind = .alarmSet
        case 57, 58:
            kind = .alarmFired
        case 59:
            kind = .alarmDisabled
        case 60:
            kind = .hapticsFired
        case 100:
            kind = .hapticsTerminated
        default:
            kind = .unknown
        }
        return WearableEventPacket(
            sequence: sequence(inner: inner),
            eventType: eventType,
            kind: kind,
            timestamp: timestamp,
            numericValue: numericEventValue(kind: kind, payload: payload),
            payloadByteCount: payload.count
        )
    }

    static func firmwareLog(inner: Data) -> WearableFirmwareLog? {
        guard inner.first == WearablePacketType.firmwareLog.rawValue else { return nil }
        let payload: Data
        let hasFirmwareHeader = inner.count > 17
            && inner[2..<13].contains { byte in byte < 32 || byte > 126 }
        if hasFirmwareHeader {
            payload = inner.subdata(in: 13..<inner.count)
        } else if inner.count > 2 {
            payload = inner.subdata(in: 2..<inner.count)
        } else {
            payload = Data()
        }
        let message = nullTerminatedASCII(in: payload) ?? printableTokens(in: payload).joined(separator: " ")
        guard !message.isEmpty else { return nil }
        let category = message.contains("Sensors") ? "Sensors" : nil
        return WearableFirmwareLog(sequence: sequence(inner: inner), message: message, category: category)
    }

    static func dataRecord(inner: Data) -> WearableDataRecord? {
        guard let type = inner.first.flatMap(WearablePacketType.init(rawValue:)),
              type == .realtimeData || type == .rawRealtimeData || type == .historicalData,
              let recordType = dataRecordType(inner: inner, packetType: type) else {
            return nil
        }
        let rawTimestamp = rawTimestamp(inner: inner)
        let r10Accelerometer = r10TriAxisSummary(inner: inner, xOffset: 85, yOffset: 285, zOffset: 485)
        let r10Gyroscope = r10TriAxisSummary(inner: inner, xOffset: 688, yOffset: 888, zOffset: 1_088)
        let r10IsComplete = recordType == 10
            && inner.count >= 1_288
            && r10Accelerometer != nil
            && r10Gyroscope != nil
        let r10 = recordType == 10
            ? WearableR10Record(
                isCompleteChunk: r10IsComplete,
                heartRateBPM: r10IsComplete ? r10HeartRate(inner: inner).map(Int.init) : nil,
                skinTemperatureC: r10IsComplete ? r10SkinTemperatureC(inner: inner) : nil,
                accelerometerSampleCount: r10Accelerometer?.sampleCount ?? 0,
                gyroscopeSampleCount: r10Gyroscope?.sampleCount ?? 0,
                rawTimestamp: rawTimestamp,
                accelerometer: r10Accelerometer,
                gyroscope: r10Gyroscope
            )
            : nil
        let r11 = recordType == 11
            ? WearableR11Record(
                payloadByteCount: max(0, inner.count - 2),
                rawTimestamp: rawTimestamp,
                note: "R11 payload preserved as raw realtime scaffold; no health metric emitted."
            )
            : nil
        let r21 = recordType == 21
            ? WearableR21Record(
                ledDriveLevel: r21LedDriveLevel(inner: inner),
                sampleCount: r21SampleCount(inner: inner).map(Int.init) ?? 0,
                secondarySampleCount: r21SecondarySampleCount(inner: inner).map(Int.init),
                channelCount: r21ChannelSummaries(inner: inner).count,
                channelSummaries: r21ChannelSummaries(inner: inner),
                note: "Optical samples are raw/debug only and are not converted to production SpO2 or true HRV."
            )
            : nil
        let r24 = recordType == 24
            ? WearableR24Record(
                spo2CandidatePercent: r24SpO2CandidatePercent(inner: inner),
                rawTimestamp: rawTimestamp,
                note: "R24 scalar is emitted as a low-confidence BLE-derived SpO2 wellness estimate, not a calibrated oximeter value."
            )
            : nil
        return WearableDataRecord(
            recordType: recordType,
            label: recordLabel(recordType),
            rawTimestamp: rawTimestamp,
            payloadByteCount: max(0, inner.count - 2),
            r10: r10,
            r11: r11,
            r21: r21,
            r24: r24
        )
    }

    private static func dataRecordType(inner: Data, packetType: WearablePacketType) -> UInt8? {
        guard packetType == .realtimeData || packetType == .rawRealtimeData || packetType == .historicalData,
              inner.count > 1 else {
            return nil
        }
        return inner[1]
    }

    private static func eventType(inner: Data) -> UInt16? {
        guard inner.count >= 4, inner[0] == WearablePacketType.event.rawValue else { return nil }
        return UInt16(inner[2]) | (UInt16(inner[3]) << 8)
    }

    private static func r10HeartRate(inner: Data) -> UInt8? {
        guard inner.count >= 1_288, inner[1] == 10 else { return nil }
        let hr = inner[17]
        return hr > 0 && hr < 240 ? hr : nil
    }

    private static func r10SkinTemperatureC(inner: Data) -> Double? {
        guard inner.count > 45, inner[1] == 10 else { return nil }
        let raw = Int16(bitPattern: UInt16(inner[44]) | (UInt16(inner[45]) << 8))
        let celsius = Double(raw) / 512.0
        return (20...45).contains(celsius) ? celsius : nil
    }

    private static func r21SampleCount(inner: Data) -> UInt8? {
        guard inner.count > 16, inner[1] == 21 else { return nil }
        return inner[16]
    }

    private static func r24SpO2CandidatePercent(inner: Data) -> Double? {
        guard inner.count > 80, inner[1] == 24 else { return nil }
        let raw = UInt16(inner[79]) << 8 | UInt16(inner[80])
        let percent = Double(raw) / 32.0
        return (50...100).contains(percent) ? percent : nil
    }

    private static func r21LedDriveLevel(inner: Data) -> Int? {
        guard inner.count > 14, inner[1] == 21 else { return nil }
        return Int(inner[14])
    }

    private static func r21SecondarySampleCount(inner: Data) -> UInt8? {
        guard inner.count > 622, inner[1] == 21 else { return nil }
        return inner[622]
    }

    private static func sequence(inner: Data) -> UInt8? {
        inner.count > 1 ? inner[1] : nil
    }

    private static func rawTimestamp(inner: Data) -> UInt32? {
        timestampSeconds(inner: inner)
    }

    private static func timestampSeconds(inner: Data) -> UInt32? {
        guard inner.count >= 11 else { return nil }
        return UInt32(inner[7])
            | (UInt32(inner[8]) << 8)
            | (UInt32(inner[9]) << 16)
            | (UInt32(inner[10]) << 24)
    }

    private static func eventTimestampSeconds(inner: Data) -> UInt32? {
        guard inner.count >= 8 else { return nil }
        return UInt32(inner[4])
            | (UInt32(inner[5]) << 8)
            | (UInt32(inner[6]) << 16)
            | (UInt32(inner[7]) << 24)
    }

    private static func recordLabel(_ recordType: UInt8) -> String {
        switch recordType {
        case 10:
            return "R10 realtime IMU/HR"
        case 11:
            return "R11 realtime raw"
        case 20:
            return "R20 raw"
        case 21:
            return "R21 optical PPG"
        case 24:
            return "R24 historical scalar candidate"
        case 7:
            return "R7 raw"
        default:
            return "record \(recordType)"
        }
    }

    private static func r10TriAxisSummary(
        inner: Data,
        xOffset: Int,
        yOffset: Int,
        zOffset: Int
    ) -> WearableTriAxisSummary? {
        guard inner.count >= zOffset + 200 else { return nil }
        guard let x = int16AxisSummary(inner: inner, offset: xOffset),
              let y = int16AxisSummary(inner: inner, offset: yOffset),
              let z = int16AxisSummary(inner: inner, offset: zOffset) else {
            return nil
        }
        return WearableTriAxisSummary(x: x, y: y, z: z)
    }

    private static func int16AxisSummary(inner: Data, offset: Int, count: Int = 100) -> WearableAxisSummary? {
        guard inner.count >= offset + count * 2 else { return nil }
        let values = (0..<count).map { index -> Int in
            let lower = UInt16(inner[offset + index * 2])
            let upper = UInt16(inner[offset + index * 2 + 1]) << 8
            return Int(Int16(bitPattern: lower | upper))
        }
        return WearableAxisSummary(
            sampleCount: values.count,
            minimum: values.min() ?? 0,
            maximum: values.max() ?? 0,
            average: Double(values.reduce(0, +)) / Double(max(values.count, 1)),
            values: values
        )
    }

    private static func r21ChannelSummaries(inner: Data) -> [String: WearableOpticalChannelSummary] {
        guard inner.count > 1, inner[1] == 21 else { return [:] }
        let offsets: [(String, Int)] = [
            ("chA", 20),
            ("chB", 220),
            ("chC", 420),
            ("chD", 632),
            ("chE", 832),
            ("chF", 1_032)
        ]
        return Dictionary(uniqueKeysWithValues: offsets.compactMap { label, offset in
            guard let summary = uint16ChannelSummary(inner: inner, offset: offset) else { return nil }
            return (label, summary)
        })
    }

    private static func uint16ChannelSummary(inner: Data, offset: Int, count: Int = 100) -> WearableOpticalChannelSummary? {
        guard inner.count >= offset + count * 2 else { return nil }
        let values = (0..<count).map { index -> Int in
            Int(UInt16(inner[offset + index * 2]) | (UInt16(inner[offset + index * 2 + 1]) << 8))
        }
        return WearableOpticalChannelSummary(
            sampleCount: values.count,
            minimum: values.min() ?? 0,
            maximum: values.max() ?? 0,
            average: Double(values.reduce(0, +)) / Double(max(values.count, 1))
        )
    }

    private static func numericEventValue(kind: WearableEventKind, payload: Data) -> Double? {
        switch kind {
        case .batteryLevel:
            if payload.count >= 4 {
                let raw = UInt32(payload[0])
                    | (UInt32(payload[1]) << 8)
                    | (UInt32(payload[2]) << 16)
                    | (UInt32(payload[3]) << 24)
                let percent = Double(raw) / 10.0
                return (0...100).contains(percent) ? percent : nil
            }
            guard let first = payload.first, first <= 100 else { return nil }
            return Double(first)
        case .temperature:
            guard payload.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(payload[0]) | (UInt16(payload[1]) << 8))
            let celsius = Double(raw) / 10.0
            return (20...45).contains(celsius) ? celsius : nil
        default:
            return nil
        }
    }

    private static func nullTerminatedASCII(in data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let body = data.prefix { $0 != 0 }
        guard !body.isEmpty, body.allSatisfy({ $0 >= 9 && $0 <= 126 }) else { return nil }
        let message = String(bytes: body, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message?.isEmpty == false ? message : nil
    }

    private static func helloHarvardInfo(from payload: Data) -> WearableHelloHarvardInfo? {
        guard payload.count >= 114 else { return nil }
        let bytes = [UInt8](payload)
        let offsetAdjustment = bytes[0] == 4 ? 1 : 0
        let wristOffset = 113 + offsetAdjustment
        guard bytes.indices.contains(wristOffset) else { return nil }

        let wholePercentCandidate = Int(bytes[1])
        let legacyBatteryRaw = Int32(bitPattern: UInt32(bytes[1])
            | (UInt32(bytes[2]) << 8)
            | (UInt32(bytes[3]) << 16)
            | (UInt32(bytes[4]) << 24))
        let legacyBatteryPercent = Double(legacyBatteryRaw) / 10.0
        let batteryPercent: Double?
        if (0...5).contains(wholePercentCandidate), (20...100).contains(legacyBatteryPercent) {
            batteryPercent = legacyBatteryPercent
        } else if (0...100).contains(wholePercentCandidate) {
            batteryPercent = Double(wholePercentCandidate)
        } else if (0...100).contains(legacyBatteryPercent) {
            batteryPercent = legacyBatteryPercent
        } else {
            batteryPercent = nil
        }
        let rtcSeconds = UInt32(bytes[6])
            | (UInt32(bytes[7]) << 8)
            | (UInt32(bytes[8]) << 16)
            | (UInt32(bytes[9]) << 24)
        let serialData = Data(bytes[14..<23])
        let wrist: Bool?
        switch bytes[wristOffset] {
        case 1:
            wrist = true
        case 2:
            wrist = false
        default:
            wrist = nil
        }

        return WearableHelloHarvardInfo(
            batteryPercent: batteryPercent,
            isCharging: bytes[5] != 0,
            rtcSeconds: rtcSeconds > 0 ? rtcSeconds : nil,
            serialFingerprint: WearablePrivacy.fingerprint(serialData.base64EncodedString()),
            isOnWrist: wrist,
            payloadByteCount: payload.count
        )
    }

    private static func printableTokens(in data: Data) -> [String] {
        var tokens: [String] = []
        var current = ""
        for byte in data {
            if byte >= 32 && byte <= 126 {
                current.append(Character(UnicodeScalar(byte)))
            } else {
                appendToken(current, to: &tokens)
                current = ""
            }
        }
        appendToken(current, to: &tokens)
        return tokens
    }

    private static func appendToken(_ token: String, to tokens: inout [String]) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return }
        tokens.append(trimmed)
    }

    private static func bestDeviceName(from tokens: [String]) -> String? {
        tokens.max(by: { $0.count < $1.count })
    }

    private static func serialLikeValue(from tokens: [String]) -> String? {
        tokens
            .flatMap { $0.split(separator: " ").map(String.init) }
            .first { token in
                token.count >= 8
                    && token.count <= 20
                    && token.allSatisfy { $0.isLetter || $0.isNumber }
            }
    }

    private static func dateCandidates(in data: Data) -> [Date] {
        var dates: [Date] = []
        let bytes = [UInt8](data)
        let minSeconds = 1_577_836_800.0
        let maxSeconds = 2_052_460_800.0
        guard bytes.count >= 4 else { return [] }
        for index in 0...(bytes.count - 4) {
            let value = UInt32(bytes[index])
                | (UInt32(bytes[index + 1]) << 8)
                | (UInt32(bytes[index + 2]) << 16)
                | (UInt32(bytes[index + 3]) << 24)
            let seconds = Double(value)
            if seconds >= minSeconds && seconds <= maxSeconds {
                dates.append(Date(timeIntervalSince1970: seconds))
            }
        }
        if bytes.count >= 8 {
            for index in 0...(bytes.count - 8) {
                let value = UInt64(bytes[index])
                    | (UInt64(bytes[index + 1]) << 8)
                    | (UInt64(bytes[index + 2]) << 16)
                    | (UInt64(bytes[index + 3]) << 24)
                    | (UInt64(bytes[index + 4]) << 32)
                    | (UInt64(bytes[index + 5]) << 40)
                    | (UInt64(bytes[index + 6]) << 48)
                    | (UInt64(bytes[index + 7]) << 56)
                let seconds = Double(value) / 1000.0
                if seconds >= minSeconds && seconds <= maxSeconds {
                    dates.append(Date(timeIntervalSince1970: seconds))
                }
            }
        }
        return Array(Set(dates.map { Int($0.timeIntervalSince1970) }))
            .sorted()
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
            .prefix(8)
            .map { $0 }
    }
}

extension WearableDecodedPacket {
    func safeHealthSamples(
        deviceID: String,
        characteristicUUID: String,
        receivedAt: Date
    ) -> [HealthSample] {
        var samples: [HealthSample] = []
        let sampleDate = healthSampleDate(receivedAt: receivedAt)
        let sampleUnixMinute = dedupeSampleUnixMinute(sampleDate: sampleDate, receivedAt: receivedAt)
        if let heartRateBPM, (25...240).contains(heartRateBPM) {
            let sourceRecordID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: dataRecord?.rawTimestamp,
                payloadByteCount: dataRecord?.payloadByteCount ?? 0,
                sampleUnixMinute: sampleUnixMinute
            )
            samples.append(
                HealthSample(
                    id: sourceRecordID,
                    type: .heartRate,
                    value: Double(heartRateBPM),
                    unit: "bpm",
                    startDate: sampleDate,
                    endDate: nil,
                    source: .wearableBLE,
                    sourceRecordID: sourceRecordID,
                    confidence: .medium,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    )
                )
            )
        }

        if let temperature = dataRecord?.r10?.skinTemperatureC {
            let sourceRecordID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: dataRecord?.rawTimestamp,
                payloadByteCount: dataRecord?.payloadByteCount ?? 0,
                sampleUnixMinute: sampleUnixMinute
            ) + ":skin_temp"
            samples.append(
                HealthSample(
                    id: sourceRecordID,
                    type: .wristTemperature,
                    value: temperature,
                    unit: "degC",
                    startDate: sampleDate,
                    endDate: nil,
                    source: .wearableBLE,
                    sourceRecordID: sourceRecordID,
                    confidence: .medium,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    ).merging([
                        "source_label": "Wearable R10 raw skin temperature",
                        "metric_policy": "raw_device_contact_temperature_not_baseline_delta",
                        "formula": "int16_le(r10_inner_bytes[44:46]) / 512"
                    ]) { current, _ in current }
                )
            )
        }

        if let r10 = dataRecord?.r10,
           let stepEstimate = WearableR10DerivedMetricEstimator.stepEstimate(from: r10) {
            let sourceRecordID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: dataRecord?.rawTimestamp,
                payloadByteCount: dataRecord?.payloadByteCount ?? 0,
                sampleUnixMinute: sampleUnixMinute
            ) + ":estimated_steps"
            samples.append(
                HealthSample(
                    id: sourceRecordID,
                    type: .steps,
                    value: Double(stepEstimate.count),
                    unit: "count",
                    startDate: sampleDate,
                    endDate: nil,
                    source: .whoordanEstimate,
                    sourceRecordID: sourceRecordID,
                    confidence: .low,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    ).merging([
                        "source_label": "BLE-derived R10 motion step estimate",
                        "device_only_derivation": "true",
                        "metric_policy": "r10_imu_motion_step_estimate",
                        "algorithm": "wrist_vm_peak_detector_v1",
                        "formula": "median-normalized R10 accelerometer VM recurrent peak count",
                        "peak_count": "\(stepEstimate.peakCount)",
                        "cadence_steps_per_minute": String(format: "%.1f", stepEstimate.cadenceStepsPerMinute),
                        "threshold_g": String(format: "%.4f", stepEstimate.thresholdG),
                        "local_accuracy": "needs_labeled_step_ground_truth"
                    ]) { current, _ in current }
                )
            )
        }

        if let r10 = dataRecord?.r10,
           let stageEstimate = WearableR10DerivedMetricEstimator.sleepStageEstimate(from: r10) {
            let sourceRecordID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: dataRecord?.rawTimestamp,
                payloadByteCount: dataRecord?.payloadByteCount ?? 0,
                sampleUnixMinute: sampleUnixMinute
            ) + ":estimated_sleep"
            samples.append(
                HealthSample(
                    id: sourceRecordID,
                    type: .sleepAnalysis,
                    value: 1,
                    unit: "min",
                    startDate: sampleDate,
                    endDate: sampleDate.addingTimeInterval(60),
                    source: .whoordanEstimate,
                    sourceRecordID: sourceRecordID,
                    confidence: stageEstimate.confidence,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    ).merging([
                        "source_label": "BLE-derived R10 sleep-stage estimate",
                        "device_only_derivation": "true",
                        "metric_policy": "r10_hr_imu_sleep_stage_estimate",
                        "sleep_category": sleepCategoryCode(for: stageEstimate.stage),
                        "algorithm": WearableR10DerivedMetricEstimator.sleepStageClassifierVersion,
                        "formula": "R10 accelerometer vector-stillness and gyroscope gate plus heart-rate band heuristic; SleepAggregator refines with session context and nearby BLE HR/HRV.",
                        "minimum_session_coverage_minutes": "20",
                        "heart_rate_bpm": "\(stageEstimate.heartRateBPM)",
                        "sleep_motion_normalized_range": String(format: "%.5f", stageEstimate.normalizedMotionRange),
                        "sleep_accelerometer_range": String(format: "%.2f", stageEstimate.accelerometerRange),
                        "sleep_gyroscope_range": String(format: "%.2f", stageEstimate.gyroscopeRange),
                        "stage_confidence_score": String(format: "%.2f", stageEstimate.confidenceScore),
                        "stage_context_refinement": "session_hr_motion_hypnogram_prior"
                    ]) { current, _ in current }
                )
            )
        }

        if packetType == .event,
           event?.kind == .temperature,
           let temperature = event?.numericValue {
            let eventID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: event?.timestamp.map { UInt32(max(0, $0.timeIntervalSince1970)) },
                payloadByteCount: event?.payloadByteCount ?? 0
            )
            samples.append(
                HealthSample(
                    id: eventID,
                    type: .temperatureEvent,
                    value: temperature,
                    unit: "degC",
                    startDate: event?.timestamp ?? receivedAt,
                    endDate: nil,
                    source: .wearableBLE,
                    sourceRecordID: eventID,
                    confidence: .medium,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    ).merging([
                        "source_label": "Wearable skin temperature event",
                        "metric_policy": "device_temperature_event_not_body_temperature"
                    ]) { current, _ in current }
                )
            )
        }

        if let oxygen = dataRecord?.r24?.spo2CandidatePercent {
            let sourceRecordID = WearableDedupe.id(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                packetType: packetType,
                recordType: recordType,
                sequence: sequence,
                rawTimestamp: dataRecord?.rawTimestamp,
                payloadByteCount: dataRecord?.payloadByteCount ?? 0,
                sampleUnixMinute: sampleUnixMinute
            ) + ":estimated_spo2"
            samples.append(
                HealthSample(
                    id: sourceRecordID,
                    type: .oxygenSaturation,
                    value: oxygen,
                    unit: "%",
                    startDate: sampleDate,
                    endDate: nil,
                    source: .whoordanEstimate,
                    sourceRecordID: sourceRecordID,
                    confidence: .low,
                    metadata: sourceMetadata(
                        deviceID: deviceID,
                        characteristicUUID: characteristicUUID,
                        receivedAt: receivedAt
                    ).merging([
                        "source_label": "BLE-derived R24 SpO2 candidate",
                        "device_only_derivation": "true",
                        "metric_policy": "r24_candidate_ble_derived_spo2",
                        "verification_basis": "crc_valid_r24_frames",
                        "formula": "uint16_be(r24_inner_bytes[79:81]) / 32"
                    ]) { current, _ in current }
                )
            )
        }

        return samples
    }

    private func dedupeSampleUnixMinute(sampleDate: Date, receivedAt: Date) -> Int? {
        guard sampleTimeBasis(receivedAt: receivedAt) == "received_at" else { return nil }
        return Self.sampleUnixMinute(for: sampleDate)
    }

    private static func sampleUnixMinute(for date: Date) -> Int {
        Int(floor(date.timeIntervalSince1970 / 60))
    }

    func imuSampleBatch(
        deviceID: String,
        characteristicUUID: String,
        receivedAt: Date
    ) -> WearableIMUSampleBatch? {
        guard let dataRecord, let r10 = dataRecord.r10, r10.accelerometerSampleCount > 0 else {
            return nil
        }
        let id = WearableDedupe.id(
            deviceID: deviceID,
            characteristicUUID: characteristicUUID,
            packetType: packetType,
            recordType: dataRecord.recordType,
            sequence: sequence,
            rawTimestamp: dataRecord.rawTimestamp,
            payloadByteCount: dataRecord.payloadByteCount
        )
        return WearableIMUSampleBatch(
            id: id,
            deviceID: deviceID,
            characteristicUUID: characteristicUUID,
            recordType: dataRecord.recordType,
            sampleCount: r10.accelerometerSampleCount,
            source: .wearableBLE,
            confidence: .low,
            metadata: sourceMetadata(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                receivedAt: receivedAt
            ).merging(imuMetadata(from: r10)) { current, _ in current }
        )
    }

    var unavailableSignals: [WearableUnavailableSignal] {
        [
            .heartRateVariability,
            .oxygenSaturation,
            .steps,
            .respiratoryRate,
            .sleepStages
        ]
    }

    func sourceMetadata(
        deviceID: String,
        characteristicUUID: String,
        receivedAt: Date
    ) -> [String: String] {
        [
            "source": DataSource.wearableBLE.rawValue,
            "device_fingerprint": WearablePrivacy.fingerprint(deviceID),
            "characteristic_uuid": characteristicUUID,
            "packet_type": packetType.description,
            "record_type": recordType.map(String.init) ?? "",
            "sequence": sequence.map(String.init) ?? "",
            "received_at_unix": String(Int(receivedAt.timeIntervalSince1970)),
            "sample_at_unix": String(Int(healthSampleDate(receivedAt: receivedAt).timeIntervalSince1970)),
            "sample_time_basis": sampleTimeBasis(receivedAt: receivedAt)
        ]
    }

    private func healthSampleDate(receivedAt: Date) -> Date {
        guard let rawTimestamp = dataRecord?.rawTimestamp else {
            return receivedAt
        }
        let deviceDate = Date(timeIntervalSince1970: TimeInterval(rawTimestamp))
        guard hasValidDeviceDate(deviceDate, receivedAt: receivedAt) else {
            return receivedAt
        }
        return deviceDate
    }

    private func sampleTimeBasis(receivedAt: Date) -> String {
        guard let rawTimestamp = dataRecord?.rawTimestamp else {
            return "received_at"
        }
        let deviceDate = Date(timeIntervalSince1970: TimeInterval(rawTimestamp))
        return hasValidDeviceDate(deviceDate, receivedAt: receivedAt) ? "device_timestamp" : "received_at"
    }

    private func hasValidDeviceDate(_ deviceDate: Date, receivedAt: Date) -> Bool {
        let earliestAllowedDeviceTime = Date(timeIntervalSince1970: 1_577_836_800)
        let latestAllowedDeviceTime = Date(timeIntervalSince1970: 2_052_460_800)
        return deviceDate >= earliestAllowedDeviceTime
            && deviceDate <= latestAllowedDeviceTime
            && deviceDate <= receivedAt.addingTimeInterval(24 * 60 * 60)
    }

    private func imuMetadata(from r10: WearableR10Record) -> [String: String] {
        var metadata: [String: String] = [
            "imu_policy": "raw_axis_summary_not_steps",
            "accelerometer_sample_count": "\(r10.accelerometerSampleCount)",
            "gyroscope_sample_count": "\(r10.gyroscopeSampleCount)"
        ]
        if let accelerometer = r10.accelerometer {
            metadata["accel_x_range"] = "\(accelerometer.x.minimum)..\(accelerometer.x.maximum)"
            metadata["accel_y_range"] = "\(accelerometer.y.minimum)..\(accelerometer.y.maximum)"
            metadata["accel_z_range"] = "\(accelerometer.z.minimum)..\(accelerometer.z.maximum)"
        }
        if let gyroscope = r10.gyroscope {
            metadata["gyro_x_range"] = "\(gyroscope.x.minimum)..\(gyroscope.x.maximum)"
            metadata["gyro_y_range"] = "\(gyroscope.y.minimum)..\(gyroscope.y.maximum)"
            metadata["gyro_z_range"] = "\(gyroscope.z.minimum)..\(gyroscope.z.maximum)"
        }
        return metadata
    }

    private func sleepCategoryCode(for stage: SleepStage) -> String {
        switch stage {
        case .inBed:
            return "0"
        case .asleep:
            return "1"
        case .awake:
            return "2"
        case .core:
            return "3"
        case .deep:
            return "4"
        case .rem:
            return "5"
        case .unknown:
            return "6"
        }
    }
}

enum WearableDevPayloadFixtureParser {
    struct CapturedNotification: Equatable {
        let characteristicUUID: String
        let data: Data
    }

    private struct JSONLineRecord: Decodable {
        let characteristicUUID: String
        let payloadBase64: String
    }

    static func notifications(fromJSONLines text: String) throws -> [CapturedNotification] {
        try text
            .split(whereSeparator: \.isNewline)
            .map { line in
                let data = Data(line.utf8)
                let record = try JSONDecoder().decode(JSONLineRecord.self, from: data)
                guard let payload = Data(base64Encoded: record.payloadBase64) else {
                    throw WearableDevPayloadFixtureParserError.invalidBase64
                }
                return CapturedNotification(characteristicUUID: record.characteristicUUID, data: payload)
            }
    }

    static func frames(fromJSONLines text: String) throws -> [Data] {
        var reassembler = FrameReassembler()
        return try notifications(fromJSONLines: text).flatMap { notification in
            reassembler.append(notification.data)
        }
    }
}

enum WearableDevPayloadFixtureParserError: Error, Equatable {
    case invalidBase64
}
