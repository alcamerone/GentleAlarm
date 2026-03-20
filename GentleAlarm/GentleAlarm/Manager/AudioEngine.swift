//
//  AudioEngine.swift
//  GentleAlarm
//

import AudioToolbox
import AVFoundation

/// Manages two responsibilities:
///  1. A silent looping heartbeat that keeps the app process alive in the background.
///  2. Alarm playback with a configurable volume ramp and optional vibration.
final class AudioEngine {

    // MARK: - Engine / nodes

    private let engine = AVAudioEngine()
    private let heartbeatNode = AVAudioPlayerNode()
    private let alarmNode     = AVAudioPlayerNode()

    // MARK: - Ramp state

    private var rampTimer: DispatchSourceTimer?
    private var vibrationTimer: DispatchSourceTimer?

    // MARK: - Init

    init() {
        configureSession()
        buildGraph()
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps the process alive when backgrounded.
            // Do NOT add .mixWithOthers — alarm needs exclusive audio focus.
            try session.setCategory(.playback, options: [])
            try session.setActive(true)
        } catch {
            print("AudioEngine: session setup failed: \(error)")
        }
    }

    // MARK: - Graph

    private func buildGraph() {
        engine.attach(heartbeatNode)
        engine.attach(alarmNode)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(heartbeatNode, to: engine.mainMixerNode, format: format)
        engine.connect(alarmNode, to: engine.mainMixerNode, format: format)

        // Near-silent, not literally 0 — AVAudioEngine may optimise a true-zero
        // mixer volume away, which would kill background execution.
        engine.mainMixerNode.outputVolume = 0.0001
    }

    // MARK: - Heartbeat

    /// Start playing a silent loop. Call this once at launch (or when backgrounding).
    func startHeartbeat() {
        guard !engine.isRunning else { return }

        scheduleHeartbeatBuffer()

        do {
            try engine.start()
            heartbeatNode.play()
        } catch {
            print("AudioEngine: engine start failed: \(error)")
        }
    }

    private func scheduleHeartbeatBuffer() {
        // Use the node's actual output format so the channel count matches the connection.
        let format = heartbeatNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 5)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            preconditionFailure("AVAudioPCMBuffer init failed for silent heartbeat buffer")
        }
        buffer.frameLength = frameCount
        // All PCM samples default to 0.0 — truly silent.
        heartbeatNode.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    /// Stop the heartbeat (call when foregrounding, if desired).
    func stopHeartbeat() {
        heartbeatNode.stop()
        engine.stop()
    }

    // MARK: - Alarm playback

    /// Begin playing `alarm.soundName` with a volume ramp over `alarm.rampDurationSeconds`.
    func startAlarm(soundName: String, rampDurationSeconds: Int, vibrate: Bool) {
        if !engine.isRunning { startHeartbeat() }

        // Restore full mixer volume for audible playback.
        engine.mainMixerNode.outputVolume = 1.0

        loadAndPlayAlarmSound(named: soundName)
        startRamp(durationSeconds: rampDurationSeconds)

        if vibrate {
            startVibration()
        }
    }

    private func loadAndPlayAlarmSound(named soundName: String) {
        guard
            let url = Bundle.main.url(forResource: soundName, withExtension: "caf")
        else {
            print("AudioEngine: sound file '\(soundName).caf' not found in bundle")
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            alarmNode.volume = 0
            alarmNode.scheduleFile(file, at: nil, completionHandler: nil)

            // Re-schedule on loop by observing completion.
            scheduleLoopingFile(url: url)

            if !alarmNode.isPlaying { alarmNode.play() }
        } catch {
            print("AudioEngine: failed to load alarm sound: \(error)")
        }
    }

    /// AVAudioPlayerNode doesn't have a native looping option for files,
    /// so we re-schedule the file from its completion handler.
    private func scheduleLoopingFile(url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else { return }
        alarmNode.scheduleFile(file, at: nil) { [weak self] in
            guard let self, self.alarmNode.isPlaying else { return }
            self.scheduleLoopingFile(url: url)
        }
    }

    private func startRamp(durationSeconds: Int) {
        rampTimer?.cancel()

        let step = Float(1.0) / Float(max(durationSeconds, 1) * 50) // 50 ticks/second
        let queue = DispatchQueue.global(qos: .userInteractive)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let next = min(self.alarmNode.volume + step, 1.0)
            self.alarmNode.volume = next
            if next >= 1.0 {
                self.rampTimer?.cancel()
                self.rampTimer = nil
            }
        }
        timer.resume()
        rampTimer = timer
    }

    // MARK: - Vibration

    private func startVibration() {
        vibrationTimer?.cancel()

        let queue = DispatchQueue.global(qos: .userInteractive)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(2))
        timer.setEventHandler {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        timer.resume()
        vibrationTimer = timer
    }

    // MARK: - Stop

    /// Stop alarm playback and vibration. Heartbeat continues running.
    func stopAlarm() {
        rampTimer?.cancel()
        rampTimer = nil

        vibrationTimer?.cancel()
        vibrationTimer = nil

        alarmNode.stop()

        // Drop mixer volume back to near-silent for the heartbeat.
        engine.mainMixerNode.outputVolume = 0.0001
    }
}
