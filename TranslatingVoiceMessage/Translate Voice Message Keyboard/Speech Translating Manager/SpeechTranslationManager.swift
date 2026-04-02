//
//  SpeechTranslationManager.swift
//  VoiceKeyboard
//
//  Handles voice-to-text using Apple's Speech framework + AVCaptureSession.
//  AVCaptureSession is the only audio API that works in keyboard extensions.
//  SFSpeechRecognizer provides on-device speech recognition (no API key).
//

import Foundation
import AVFoundation
import Speech

protocol SpeechTranslationDelegate: AnyObject {
    /// Called when recording + recognition starts
    func speechDidStart()
    /// Called with live partial transcription results
    func speechDidRecognize(text: String, isFinal: Bool)
    /// Called when an error occurs
    func speechDidFail(error: String)
    /// Called when recording stops
    func speechDidStop()
}

class SpeechTranslationManager: NSObject {
    
    weak var delegate: SpeechTranslationDelegate?
    
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private(set) var isListening = false
    private var isSessionConfigured = false
    private var audioFormat: AVAudioFormat?
    
    private let sessionQueue = DispatchQueue(label: "com.voicekb.session", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "com.voicekb.capture", qos: .userInteractive)
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Pre-warm
    
    /// Call from viewDidLoad to warm up the audio subsystem
    func prepare() {
        NSLog("[VoiceKB-Speech] Preparing audio subsystem...")
        
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            NSLog("[VoiceKB-Speech] Speech auth status: %d", status.rawValue)
        }
    }
    
    private func configureCaptureSession() {
        let session = AVCaptureSession()
        session.automaticallyConfiguresApplicationAudioSession = true
        
        guard let device = AVCaptureDevice.default(for: .audio) else {
            NSLog("[VoiceKB-Speech] ❌ No audio device")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else { return }
        } catch {
            NSLog("[VoiceKB-Speech] ❌ Input error: %@", error.localizedDescription)
            return
        }
        
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        audioOutput = output
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else { return }
        
        captureSession = session
        isSessionConfigured = true
        
        // Warm-up: start briefly then stop
        NSLog("[VoiceKB-Speech] Warm-up start...")
        session.startRunning()
        Thread.sleep(forTimeInterval: 0.3)
        if session.isRunning {
            NSLog("[VoiceKB-Speech] ✅ Warm-up OK")
            session.stopRunning()
        } else {
            NSLog("[VoiceKB-Speech] ⚠️ Warm-up: session didn't start (will retry)")
        }
    }
    
    // MARK: - Start Listening
    
    func startListening() {
        guard !isListening else { return }
        
        NSLog("[VoiceKB-Speech] startListening...")
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            NSLog("[VoiceKB-Speech] ❌ Speech recognizer unavailable")
            delegate?.speechDidFail(error: "Speech recognition unavailable")
            return
        }
        
        sessionQueue.async { [weak self] in
            self?.beginListeningSession()
        }
    }
    
    private func beginListeningSession() {
        // Configure session if needed
        if !isSessionConfigured || captureSession == nil {
            configureCaptureSession()
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        guard let session = captureSession else {
            DispatchQueue.main.async { self.delegate?.speechDidFail(error: "Microphone unavailable") }
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        // Use on-device recognition if available (faster, works offline)
        if #available(iOS 13.0, *) {
            if speechRecognizer?.supportsOnDeviceRecognition == true {
                recognitionRequest?.requiresOnDeviceRecognition = true
                NSLog("[VoiceKB-Speech] Using on-device recognition")
            }
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                NSLog("[VoiceKB-Speech] 🎤 %@: \"%@\"", isFinal ? "FINAL" : "partial", text)
                
                DispatchQueue.main.async {
                    self.delegate?.speechDidRecognize(text: text, isFinal: isFinal)
                }
                
                if isFinal {
                    self.stopListening()
                }
            }
            
            if let error = error {
                NSLog("[VoiceKB-Speech] Recognition error: %@", error.localizedDescription)
                // Don't report error if we just stopped
                if self.isListening {
                    DispatchQueue.main.async {
                        self.delegate?.speechDidFail(error: error.localizedDescription)
                    }
                }
            }
        }
        
        // Start audio capture
        if !session.isRunning {
            session.startRunning()
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        if session.isRunning {
            isListening = true
            NSLog("[VoiceKB-Speech] ✅ Listening started!")
            DispatchQueue.main.async {
                self.delegate?.speechDidStart()
            }
        } else {
            // Retry once
            NSLog("[VoiceKB-Speech] Retrying session start...")
            session.startRunning()
            Thread.sleep(forTimeInterval: 0.4)
            
            if session.isRunning {
                isListening = true
                NSLog("[VoiceKB-Speech] ✅ Retry succeeded!")
                DispatchQueue.main.async { self.delegate?.speechDidStart() }
            } else {
                NSLog("[VoiceKB-Speech] ❌ Session failed to start")
                recognitionRequest?.endAudio()
                recognitionTask?.cancel()
                DispatchQueue.main.async {
                    self.delegate?.speechDidFail(error: "Microphone failed. Close keyboard and try again.")
                }
            }
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        guard isListening else { return }
        
        NSLog("[VoiceKB-Speech] stopListening")
        isListening = false
        
        recognitionRequest?.endAudio()
        
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        
        DispatchQueue.main.async {
            self.delegate?.speechDidStop()
        }
    }
    
    deinit {
        stopListening()
        captureSession?.stopRunning()
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension SpeechTranslationManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isListening, let request = recognitionRequest else { return }
        
        // Convert CMSampleBuffer → AVAudioPCMBuffer for SFSpeechRecognizer
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }
        
        // Create AVAudioFormat from the stream description
        guard let format = AVAudioFormat(streamDescription: asbd) else { return }
        
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        
        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)
        
        // Copy PCM data into the buffer
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(numSamples),
            into: pcmBuffer.mutableAudioBufferList
        )
        
        guard status == noErr else { return }
        
        // Feed to speech recognizer
        request.append(pcmBuffer)
    }
}
