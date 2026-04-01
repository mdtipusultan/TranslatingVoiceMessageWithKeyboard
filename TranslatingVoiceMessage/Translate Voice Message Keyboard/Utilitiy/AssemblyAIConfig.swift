//
//  AssemblyAIService.swift
//  VoiceKeyboard
//
//  Handles communication with AssemblyAI's Speech-to-Text API.
//  Supports both pre-recorded transcription and real-time streaming.
//

import Foundation
import AVFoundation

// MARK: - Configuration

struct AssemblyAIConfig {
    /// Replace with your actual AssemblyAI API key
    /// Get one at: https://www.assemblyai.com/dashboard/signup
    static let apiKey = "..."
    
    /// Base URL for pre-recorded transcription
    static let baseURL = "https://api.assemblyai.com"
    
    /// WebSocket URL for real-time streaming
    static let streamingBaseURL = "wss://streaming.assemblyai.com/v3/ws"
    
    /// Audio sample rate (16kHz recommended for AssemblyAI)
    static let sampleRate: Int = 16000
    
    /// Speech model for streaming
    static let streamingSpeechModel = "u3-rt-pro"
}

// MARK: - Pre-recorded Transcription Service

/// Handles uploading audio files and getting transcriptions from AssemblyAI
class AssemblyAITranscriptionService {
    
    enum TranscriptionError: Error, LocalizedError {
        case invalidAPIKey
        case uploadFailed(String)
        case transcriptionFailed(String)
        case networkError(Error)
        case invalidResponse
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid API key. Please set your AssemblyAI API key."
            case .uploadFailed(let msg):
                return "Upload failed: \(msg)"
            case .transcriptionFailed(let msg):
                return "Transcription failed: \(msg)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server."
            case .timeout:
                return "Transcription timed out."
            }
        }
    }
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    /// Upload a local audio file to AssemblyAI and return the upload URL
    func uploadAudio(fileURL: URL, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard AssemblyAIConfig.apiKey != "..." else {
            completion(.failure(.invalidAPIKey))
            return
        }
        
        guard let audioData = try? Data(contentsOf: fileURL) else {
            completion(.failure(.uploadFailed("Cannot read audio file")))
            return
        }
        
        let uploadURL = URL(string: "\(AssemblyAIConfig.baseURL)/v2/upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(AssemblyAIConfig.apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let uploadUrl = json["upload_url"] as? String else {
                completion(.failure(.uploadFailed("Invalid upload response")))
                return
            }
            
            completion(.success(uploadUrl))
        }.resume()
    }
    
    /// Upload audio data directly (not from a file) to AssemblyAI
    func uploadAudioData(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard AssemblyAIConfig.apiKey != "..." else {
            completion(.failure(.invalidAPIKey))
            return
        }
        
        let uploadURL = URL(string: "\(AssemblyAIConfig.baseURL)/v2/upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(AssemblyAIConfig.apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let uploadUrl = json["upload_url"] as? String else {
                completion(.failure(.uploadFailed("Invalid upload response")))
                return
            }
            
            completion(.success(uploadUrl))
        }.resume()
    }
    
    /// Submit a transcription request and poll until complete
    func transcribe(audioURL: String, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        // Step 1: Submit transcription request
        let transcriptURL = URL(string: "\(AssemblyAIConfig.baseURL)/v2/transcript")!
        var request = URLRequest(url: transcriptURL)
        request.httpMethod = "POST"
        request.setValue(AssemblyAIConfig.apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "audio_url": audioURL,
            "speech_models": ["universal-3-pro", "universal-2"],
            "language_detection": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let transcriptId = json["id"] as? String else {
                completion(.failure(.transcriptionFailed("Failed to create transcription")))
                return
            }
            
            // Step 2: Poll for result
            self?.pollForResult(transcriptId: transcriptId, completion: completion)
        }.resume()
    }
    
    /// Poll the transcription endpoint until the result is ready
    private func pollForResult(transcriptId: String, attempts: Int = 0, maxAttempts: Int = 60, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard attempts < maxAttempts else {
            completion(.failure(.timeout))
            return
        }
        
        let pollingURL = URL(string: "\(AssemblyAIConfig.baseURL)/v2/transcript/\(transcriptId)")!
        var request = URLRequest(url: pollingURL)
        request.setValue(AssemblyAIConfig.apiKey, forHTTPHeaderField: "authorization")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                completion(.failure(.invalidResponse))
                return
            }
            
            switch status {
            case "completed":
                if let text = json["text"] as? String {
                    completion(.success(text))
                } else {
                    completion(.failure(.transcriptionFailed("No text in response")))
                }
                
            case "error":
                let errorMsg = json["error"] as? String ?? "Unknown error"
                completion(.failure(.transcriptionFailed(errorMsg)))
                
            default:
                // Still processing — wait 2 seconds and retry
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    self?.pollForResult(transcriptId: transcriptId, attempts: attempts + 1, maxAttempts: maxAttempts, completion: completion)
                }
            }
        }.resume()
    }
    
    /// Convenience: Record → Upload → Transcribe pipeline
    func uploadAndTranscribe(audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        uploadAudioData(audioData) { [weak self] result in
            switch result {
            case .success(let uploadUrl):
                self?.transcribe(audioURL: uploadUrl, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Real-time Streaming Transcription Service

/// Protocol for receiving real-time transcription updates
protocol AssemblyAIStreamingDelegate: AnyObject {
    func streamingDidConnect()
    func streamingDidReceivePartialTranscript(_ text: String)
    func streamingDidReceiveFinalTranscript(_ text: String)
    func streamingDidDisconnect()
    func streamingDidEncounterError(_ error: Error)
}

/// Handles real-time WebSocket streaming to AssemblyAI
class AssemblyAIStreamingService: NSObject {
    
    weak var delegate: AssemblyAIStreamingDelegate?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    
    /// Connect to AssemblyAI streaming WebSocket
    func connect() {
        guard AssemblyAIConfig.apiKey != "..." else {
            delegate?.streamingDidEncounterError(
                AssemblyAITranscriptionService.TranscriptionError.invalidAPIKey
            )
            return
        }
        
        let params = "speech_model=\(AssemblyAIConfig.streamingSpeechModel)&sample_rate=\(AssemblyAIConfig.sampleRate)"
        guard let url = URL(string: "\(AssemblyAIConfig.streamingBaseURL)?\(params)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(AssemblyAIConfig.apiKey, forHTTPHeaderField: "Authorization")
        
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isConnected = true
        delegate?.streamingDidConnect()
        
        // Start listening for messages
        receiveMessage()
    }
    
    /// Send raw audio data (PCM 16-bit, 16kHz, mono) to the WebSocket
    func sendAudioData(_ data: Data) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    /// Disconnect from the WebSocket
    func disconnect() {
        guard isConnected else { return }
        
        // Send termination message
        let terminateMsg = ["type": "Terminate"]
        if let data = try? JSONSerialization.data(withJSONObject: terminateMsg) {
            let message = URLSessionWebSocketTask.Message.string(String(data: data, encoding: .utf8) ?? "")
            webSocketTask?.send(message) { [weak self] _ in
                self?.webSocketTask?.cancel(with: .normalClosure, reason: nil)
                self?.isConnected = false
                self?.delegate?.streamingDidDisconnect()
            }
        } else {
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            isConnected = false
            delegate?.streamingDidDisconnect()
        }
    }
    
    /// Recursively receive WebSocket messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self?.receiveMessage()
                
            case .failure(let error):
                self?.isConnected = false
                self?.delegate?.streamingDidEncounterError(error)
            }
        }
    }
    
    /// Parse and handle incoming WebSocket messages
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgType = json["type"] as? String else { return }
        
        switch msgType {
        case "Begin":
            print("AssemblyAI streaming session began")
            
        case "Turn":
            let transcript = json["transcript"] as? String ?? ""
            let endOfTurn = json["end_of_turn"] as? Bool ?? false
            
            if endOfTurn {
                DispatchQueue.main.async {
                    self.delegate?.streamingDidReceiveFinalTranscript(transcript)
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.streamingDidReceivePartialTranscript(transcript)
                }
            }
            
        case "Termination":
            DispatchQueue.main.async {
                self.delegate?.streamingDidDisconnect()
            }
            
        default:
            break
        }
    }
}
