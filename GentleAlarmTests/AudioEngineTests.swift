//
//  AudioEngineTests.swift
//  GentleAlarmTests
//

import AVFoundation
import Testing
@testable import GentleAlarm

// Session-mode tests mutate AVAudioSession.sharedInstance() — a process-level singleton —
// so they must not run in parallel with each other.
@Suite(.serialized)
struct AudioEngineTests {

    // MARK: - Session mode after init

    @Test func testSessionMixingAfterInit() {
        let engine = AudioEngine()
        // sessionIsExclusive is an internal flag set by configureSession — check that too.
        #expect(!engine.sessionIsExclusive)
        // Global session should reflect mixing mode.
        let options = AVAudioSession.sharedInstance().categoryOptions
        #expect(options.contains(.mixWithOthers))
    }

    // MARK: - Session mode during alarm
    //
    // The three tests below use engine.sessionIsExclusive (an internal flag updated
    // synchronously inside configureSession) rather than reading AVAudioSession.sharedInstance()
    // for the exclusive/restore assertions.  Reading the singleton directly would be racy:
    // AlarmManagerTests runs in a separate suite and creates its own AudioEngine instances
    // whose inits call configureSession(exclusive: false), potentially overwriting our
    // exclusive state between the startAlarm call and the assertion.

    @Test func testSessionExclusiveAfterStartAlarm() {
        let engine = AudioEngine()
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)
        engine.stopAlarm()
    }

    @Test func testSessionMixingRestoredAfterStopAlarm() {
        let engine = AudioEngine()
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        engine.stopAlarm()
        #expect(!engine.sessionIsExclusive)
    }

    // MARK: - Stability / no-crash guarantees

    @Test func testStartHeartbeatIdempotent() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        engine.startHeartbeat()  // must not crash or stack buffers
        engine.stopHeartbeat()
    }

    @Test func testStopHeartbeatWithoutStartDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopHeartbeat()  // must not crash on fresh engine
    }

    @Test func testStopAlarmWithoutStartDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopAlarm()  // must not crash on fresh engine
    }
}
