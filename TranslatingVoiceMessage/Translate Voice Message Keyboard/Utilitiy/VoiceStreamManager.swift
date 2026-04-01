//
//  VoiceStreamManager.swift
//

import Foundation
import AVFoundation

class VoiceStreamManager: NSObject {
    
    private var audioEngine = AVAudioEngine()
    private var webSocket: URLSessionWebSocketTask?
    
    var onTranscript: ((String) -> Void)?
    
    private var isConnected = false
    
    // MARK: - Start
    
    func startStreaming(apiKey: String) {
        connectWebSocket(apiKey: apiKey)
        
        // ✅ Start audio AFTER socket ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.startAudioEngine()
        }
    }
    
    // MARK: - WebSocket
    
    private func connectWebSocket(apiKey: String) {
        let url = URL(string: "wss://api.assemblyai.com/v2/realtime/ws?sample_rate=16000")!
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        print("🔌 Connecting WebSocket...")
        
        // ✅ Delay start message (CRITICAL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendStartMessage()
        }
        
        receiveMessages()
    }
    
    private func sendStartMessage() {
        let startMessage: [String: Any] = [
            "type": "start",
            "sample_rate": 16000
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: startMessage),
           let text = String(data: data, encoding: .utf8) {
            
            webSocket?.send(.string(text)) { error in
                if let error = error {
                    print("❌ Start message error:", error)
                } else {
                    print("✅ Start message sent")
                    self.isConnected = true
                }
            }
        }
    }
    
    // MARK: - Receive
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("❌ WebSocket error:", error)
                
            case .success(let message):
                switch message {
                case .string(let text):
                    print("📩 WS:", text) // DEBUG
                    self.handleMessage(text)
                default:
                    break
                }
            }
            
            self.receiveMessages()
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let messageType = json["message_type"] as? String,
           let transcript = json["text"] as? String {

            if messageType == "PartialTranscript" || messageType == "FinalTranscript" {
                DispatchQueue.main.async {
                    self.onTranscript?(transcript)
                }
            }
        }
    }
    
    // MARK: - Audio
    
    private func startAudioEngine() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.sendAudio(buffer: buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            print("🎤 Audio engine started")
        } catch {
            print("❌ Audio engine error:", error)
        }
    }
    
    // MARK: - Send Audio
    
    private func sendAudio(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        guard isConnected else { return }
        
        let pointer = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        var pcmData = [Int16]()
        pcmData.reserveCapacity(frameLength)
        
        for i in 0..<frameLength {
            let sample = pointer[i]
            let clamped = max(-1.0, min(1.0, sample))
            pcmData.append(Int16(clamped * Float(Int16.max)))
        }
        
        let data = Data(bytes: pcmData, count: pcmData.count * MemoryLayout<Int16>.size)
        let base64 = data.base64EncodedString()
        
        let json: [String: Any] = [
            "audio_data": base64
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            webSocket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ Send error:", error)
                }
            }
        }
    }
    
    // MARK: - Stop
    
    func stopStreaming() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        
        print("🛑 Stopped")
    }
}

