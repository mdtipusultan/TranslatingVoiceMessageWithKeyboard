//
//  AudioRecorderManager.swift
//  VoiceKeyboard
//
//  Uses AVCaptureSession for microphone access in keyboard extensions.
//
//  KEY INSIGHT: The audio subsystem needs to be "warmed up" before
//  startRunning() will work. Set up the full capture session during
//  initialization, then just start/stop running when recording.
//

import Foundation
import AVFoundation

protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidStartRecording()
    func audioRecorderDidStopRecording(audioData: Data?, fileURL: URL?)
    func audioRecorderDidFailWithError(_ error: Error)
    func audioRecorderDidCaptureAudioChunk(_ data: Data)
}

extension AudioRecorderDelegate {
    func audioRecorderDidCaptureAudioChunk(_ data: Data) {}
}

class AudioRecorderManager: NSObject {
    
    weak var delegate: AudioRecorderDelegate?
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var recordingURL: URL?
    private var isRecording = false
    private var isWriterStarted = false
    private var sampleCount = 0
    private var isSessionConfigured = false
    
    var enableStreamingMode = false
    var maxRecordingDuration: TimeInterval = 60
    
    private var recordingTimer: Timer?
    
    private let sessionQueue = DispatchQueue(label: "com.voicekeyboard.session", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "com.voicekeyboard.capture", qos: .userInteractive)
    
    // MARK: - Pre-warm (call from viewDidLoad)
    
    /// Call this from viewDidLoad to pre-warm the audio subsystem.
    /// This sets up the capture session so it's ready when the user taps record.
    func prepareAudioSession() {
        NSLog("[VoiceKB-Audio] prepareAudioSession called — warming up audio subsystem")
        
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        NSLog("[VoiceKB-Audio] Configuring capture session on background queue...")
        
        let session = AVCaptureSession()
        
        // Let AVCaptureSession auto-configure audio session
        session.automaticallyConfiguresApplicationAudioSession = true
        
        // Begin configuration
        session.beginConfiguration()
        
        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            NSLog("[VoiceKB-Audio] ❌ No audio device available")
            return
        }
        
        NSLog("[VoiceKB-Audio] Audio device: %@", audioDevice.localizedName)
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                NSLog("[VoiceKB-Audio] ✅ Audio input added")
            } else {
                NSLog("[VoiceKB-Audio] ❌ Cannot add audio input")
                return
            }
        } catch {
            NSLog("[VoiceKB-Audio] ❌ Input error: %@", error.localizedDescription)
            return
        }
        
        // Add audio output
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        audioOutput = output
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            NSLog("[VoiceKB-Audio] ✅ Audio output added")
        } else {
            NSLog("[VoiceKB-Audio] ❌ Cannot add audio output")
            return
        }
        
        session.commitConfiguration()
        
        captureSession = session
        isSessionConfigured = true
        
        // Do a brief "warm-up" start/stop to prime the audio hardware
        NSLog("[VoiceKB-Audio] Warm-up: starting session briefly...")
        session.startRunning()
        Thread.sleep(forTimeInterval: 0.3)
        
        if session.isRunning {
            NSLog("[VoiceKB-Audio] ✅ Warm-up succeeded! Session is ready.")
            session.stopRunning()
            Thread.sleep(forTimeInterval: 0.1)
        } else {
            NSLog("[VoiceKB-Audio] ⚠️ Warm-up: session didn't start (will retry on record)")
            // That's OK — the warm-up still initializes the audio subsystem
            // so the next startRunning() should work
        }
        
        NSLog("[VoiceKB-Audio] Audio subsystem pre-warmed and ready")
    }
    
    // MARK: - Start Recording
    
    func startRecording() {
        guard !isRecording else { return }
        
        NSLog("[VoiceKB-Audio] ========== START RECORDING ==========")
        NSLog("[VoiceKB-Audio] isSessionConfigured: %d", isSessionConfigured ? 1 : 0)
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // If session wasn't pre-configured, do it now
            if !self.isSessionConfigured || self.captureSession == nil {
                NSLog("[VoiceKB-Audio] Session not pre-configured, configuring now...")
                self.configureCaptureSession()
                Thread.sleep(forTimeInterval: 0.2)
            }
            
            guard let session = self.captureSession else {
                NSLog("[VoiceKB-Audio] ❌ No capture session available")
                self.notifyError("Microphone not available")
                return
            }
            
            // Setup fresh asset writer for this recording
            self.setupAssetWriter()
            self.isWriterStarted = false
            self.sampleCount = 0
            
            // Start the capture session
            NSLog("[VoiceKB-Audio] Starting capture session...")
            
            if !session.isRunning {
                session.startRunning()
                Thread.sleep(forTimeInterval: 0.2)
            }
            
            if session.isRunning {
                self.isRecording = true
                NSLog("[VoiceKB-Audio] ✅✅✅ RECORDING STARTED ✅✅✅")
                
                DispatchQueue.main.async {
                    self.delegate?.audioRecorderDidStartRecording()
                    self.recordingTimer = Timer.scheduledTimer(
                        withTimeInterval: self.maxRecordingDuration, repeats: false
                    ) { [weak self] _ in self?.stopRecording() }
                }
            } else {
                // Retry: sometimes needs a second attempt after warm-up
                NSLog("[VoiceKB-Audio] Not running yet, retry #1...")
                session.startRunning()
                Thread.sleep(forTimeInterval: 0.5)
                
                if session.isRunning {
                    self.isRecording = true
                    NSLog("[VoiceKB-Audio] ✅ Retry #1 succeeded!")
                    DispatchQueue.main.async {
                        self.delegate?.audioRecorderDidStartRecording()
                    }
                } else {
                    // Recreate the entire session
                    NSLog("[VoiceKB-Audio] Retry #1 failed. Recreating session...")
                    self.captureSession = nil
                    self.isSessionConfigured = false
                    self.configureCaptureSession()
                    Thread.sleep(forTimeInterval: 0.3)
                    
                    self.captureSession?.startRunning()
                    Thread.sleep(forTimeInterval: 0.3)
                    
                    if self.captureSession?.isRunning == true {
                        self.isRecording = true
                        NSLog("[VoiceKB-Audio] ✅ Recreate + start succeeded!")
                        DispatchQueue.main.async {
                            self.delegate?.audioRecorderDidStartRecording()
                        }
                    } else {
                        NSLog("[VoiceKB-Audio] ❌❌❌ ALL ATTEMPTS FAILED")
                        self.notifyError("Microphone failed to start. Please close this keyboard, reopen it, and try again.")
                    }
                }
            }
        }
    }
    
    // MARK: - Stop Recording
    
    func stopRecording() {
        guard isRecording else { return }
        
        NSLog("[VoiceKB-Audio] stopRecording. sampleCount=%d", sampleCount)
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop the capture session
            self.captureSession?.stopRunning()
            
            // Finish writing
            if let writer = self.assetWriter, writer.status == .writing {
                self.assetWriterInput?.markAsFinished()
                let sem = DispatchSemaphore(value: 0)
                writer.finishWriting {
                    NSLog("[VoiceKB-Audio] Writer done. Status=%d", writer.status.rawValue)
                    sem.signal()
                }
                sem.wait()
            }
            
            // Read result
            var audioData: Data?
            if let url = self.recordingURL {
                audioData = try? Data(contentsOf: url)
                NSLog("[VoiceKB-Audio] File: %d bytes, %d samples captured", audioData?.count ?? 0, self.sampleCount)
            }
            
            // Clean up writer (keep session for reuse)
            self.assetWriter = nil
            self.assetWriterInput = nil
            
            DispatchQueue.main.async {
                self.delegate?.audioRecorderDidStopRecording(audioData: audioData, fileURL: self.recordingURL)
            }
        }
    }
    
    // MARK: - Asset Writer Setup
    
    private func setupAssetWriter() {
        let tempDir = NSTemporaryDirectory()
        let fileName = "kb_rec_\(Int(Date().timeIntervalSince1970)).m4a"
        recordingURL = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: recordingURL!, fileType: .m4a)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            if let w = assetWriter, let i = assetWriterInput, w.canAdd(i) { w.add(i) }
        } catch {
            NSLog("[VoiceKB-Audio] Writer setup error: %@", error.localizedDescription)
        }
    }
    
    private func notifyError(_ message: String) {
        DispatchQueue.main.async {
            self.delegate?.audioRecorderDidFailWithError(
                NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            )
        }
    }
    
    var recording: Bool { return isRecording }
    
    func cleanup() {
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
    }
    
    deinit {
        if isRecording { stopRecording() }
        captureSession?.stopRunning()
        cleanup()
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension AudioRecorderManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        
        sampleCount += 1
        
        if sampleCount <= 3 {
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            NSLog("[VoiceKB-Audio] 🎤 Sample #%d: %d frames", sampleCount, numSamples)
            
            if sampleCount == 1, let fd = CMSampleBufferGetFormatDescription(sampleBuffer) {
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee {
                    NSLog("[VoiceKB-Audio]   Format: SR=%.0f, ch=%d, bits=%d",
                          asbd.mSampleRate, asbd.mChannelsPerFrame, asbd.mBitsPerChannel)
                }
            }
        }
        
        // Write to file
        if let writer = assetWriter {
            if !isWriterStarted && writer.status == .unknown {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startWriting()
                writer.startSession(atSourceTime: time)
                isWriterStarted = true
                NSLog("[VoiceKB-Audio] ✅ Writer session started")
            }
            if writer.status == .writing, let input = assetWriterInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
        
        // Streaming
        if enableStreamingMode, let data = extractPCMData(from: sampleBuffer) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.audioRecorderDidCaptureAudioChunk(data)
            }
        }
    }
    
    private func extractPCMData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var data = Data(count: length)
        data.withUnsafeMutableBytes { ptr in
            if let base = ptr.baseAddress {
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
            }
        }
        return data
    }
}
