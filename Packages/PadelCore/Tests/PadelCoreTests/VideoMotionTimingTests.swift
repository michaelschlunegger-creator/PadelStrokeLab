import Foundation
import Testing
@testable import PadelCore

let videoTestPhoneRun = UUID(uuidString: "90000000-0000-0000-0000-000000000001")!
let videoTestWatchRun = UUID(uuidString: "90000000-0000-0000-0000-000000000002")!
let videoTestArm = UUID(uuidString: "90000000-0000-0000-0000-000000000003")!

func videoTestClockExchange(at time: Double, offset: Double = 0.2,
                            phoneEpoch: UUID = videoTestPhoneRun, watchEpoch: UUID = videoTestWatchRun) throws -> VideoMotionClockExchange {
    try VideoMotionClockExchange(phoneEpoch: phoneEpoch, watchEpoch: watchEpoch,
        phoneSent: time, watchReceived: time + 0.01 + offset,
        watchSent: time + 0.02 + offset, phoneReceived: time + 0.03)
}

func videoTestClockMapping() throws -> VideoMotionClockMapping {
    try VideoMotionClockMapping(exchanges: [videoTestClockExchange(at: 0),
        videoTestClockExchange(at: 5), videoTestClockExchange(at: 10)])
}

@Suite struct VideoMotionTimingTests {
    @Test func fourActualTimestampsDefineOffsetIntervalNotOneWayLatency() throws {
        let value = try VideoMotionClockExchange(phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun,
            phoneSent: 10, watchReceived: 10.12, watchSent: 10.14, phoneReceived: 10.06)
        #expect(abs(value.offsetLowerBound - 0.08) < 0.000_001)
        #expect(abs(value.offsetUpperBound - 0.12) < 0.000_001)
        #expect(abs(value.networkRoundTrip - 0.04) < 0.000_001)
        #expect(abs(value.phoneMidpoint - 10.03) < 0.000_001)
    }

    @Test func oneOrInsufficientlySeparatedObservationsLeaveDriftUnknown() throws {
        let one = try VideoMotionClockMapping(exchanges: [videoTestClockExchange(at: 1)])
        #expect(one.driftPPMRange == nil)
        #expect(throws: (any Error).self) { try one.estimateWatch(atPhone: 1.015) }
        let brief = try VideoMotionClockMapping(exchanges: [videoTestClockExchange(at: 1),
            videoTestClockExchange(at: 2), videoTestClockExchange(at: 3)])
        #expect(brief.driftPPMRange == nil)
    }

    @Test func mappedTimesRetainUncertaintyAndNeverExtrapolate() throws {
        let mapping = try videoTestClockMapping()
        let rate = try #require(mapping.driftPPMRange)
        #expect(rate.contains(0))
        let watch = try mapping.estimateWatch(atPhone: 6)
        #expect(abs(watch.timestamp - 6.2) <= watch.uncertaintySeconds)
        #expect(watch.uncertaintySeconds > 0)
        let phone = try mapping.estimatePhone(atWatch: 6.2)
        #expect(abs(phone.timestamp - 6) <= phone.uncertaintySeconds)
        #expect(throws: (any Error).self) { try mapping.estimateWatch(atPhone: 11) }
        #expect(throws: (any Error).self) { try mapping.estimatePhone(atWatch: 20) }
        #expect(throws: (any Error).self) { try mapping.estimateWatch(atPhone: .nan) }
    }

    @Test func affineDriftIsAnEstimatedRangeAndIncompatibleSeriesFails() throws {
        let mapping = try VideoMotionClockMapping(exchanges: [videoTestClockExchange(at: 0, offset: 0.2),
            videoTestClockExchange(at: 50, offset: 0.25), videoTestClockExchange(at: 100, offset: 0.3)])
        let rate = try #require(mapping.driftPPMRange)
        #expect(rate.contains(1_000))
        let value = try mapping.estimateWatch(atPhone: 60)
        #expect(abs(value.timestamp - 60.26) <= value.uncertaintySeconds)
        #expect(throws: (any Error).self) {
            try VideoMotionClockMapping(exchanges: [videoTestClockExchange(at: 0, offset: 0.2),
                videoTestClockExchange(at: 5, offset: 0.5), videoTestClockExchange(at: 10, offset: 0.2)])
        }
    }

    @Test func epochsReorderingDuplicateIDsAndImpossibleClockValuesFailClosed() throws {
        let first = try videoTestClockExchange(at: 0), later = try videoTestClockExchange(at: 5)
        for values in [[later, first], [first, first],
                       [first, try videoTestClockExchange(at: 5, watchEpoch: UUID())]] {
            #expect(throws: (any Error).self) { try VideoMotionClockMapping(exchanges: values) }
        }
        #expect(throws: (any Error).self) {
            try VideoMotionClockExchange(phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun,
                phoneSent: 1, watchReceived: 2, watchSent: 4, phoneReceived: 2)
        }
        #expect(throws: (any Error).self) {
            try VideoMotionClockExchange(phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun,
                phoneSent: .infinity, watchReceived: 1, watchSent: 2, phoneReceived: 3)
        }
        #expect(throws: (any Error).self) {
            try VideoMotionClockMapping(exchanges: (0...VideoMotionClockMapping.maximumExchanges).map {
                try videoTestClockExchange(at: Double($0) * 5)
            })
        }
    }
}
