//
//  VoiceTranslationView.swift
//  TranslatingVoiceMessage
//
//  Main app voice translation screen.
//  Tap mic → speak → live transcription → auto-translate → copy result.
//  Full microphone access (no sandbox restrictions like keyboard extensions).
//

import SwiftUI
import Speech
import AVFoundation

// MARK: - Speech Manager

class SpeechManager: ObservableObject {
    
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isAvailable = true
    @Published var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                default:
                    self.errorMessage = "Speech recognition permission denied"
                    completion(false)
                }
            }
        }
    }
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition unavailable"
            return
        }
        
        // Reset
        recognitionTask?.cancel()
        recognitionTask = nil
        errorMessage = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        
        if #available(iOS 13.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
                if let error = error {
                    if self?.isListening == true {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        
        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func reset() {
        stopListening()
        transcribedText = ""
        errorMessage = nil
    }
}

// MARK: - Voice Translation View

struct VoiceTranslationView: View {
    
    @StateObject private var speechManager = SpeechManager()
    @State private var selectedLanguage: Language = SupportedLanguages.all[1]
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var showLanguagePicker = false
    @State private var copied = false
    @State private var permissionGranted = false
    
    private let translationService = TranslationService()
    
    // Colors
    private let accentBlue = Color(red: 0.29, green: 0.56, blue: 0.89)
    private let accentGreen = Color(red: 0.30, green: 0.78, blue: 0.55)
    private let accentPurple = Color(red: 0.58, green: 0.35, blue: 0.98)
    private let accentOrange = Color(red: 0.95, green: 0.62, blue: 0.22)
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let cardColor = Color(red: 0.12, green: 0.12, blue: 0.17)
    private let surfaceColor = Color(red: 0.16, green: 0.16, blue: 0.22)
    
    var body: some View {
        ZStack {
            // Background
            bgColor.ignoresSafeArea()
            backgroundOrbs
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    languageSelector
                    microphoneSection
                    transcriptionCard
                    translationCard
                    actionButtons
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            
            // Language picker overlay
            if showLanguagePicker {
                languagePickerOverlay
            }
        }
        .onAppear {
            loadLanguagePreference()
            speechManager.requestPermissions { granted in
                permissionGranted = granted
            }
        }
        .onDisappear {
            speechManager.stopListening()
        }
    }
    
    // MARK: - Background
    
    private var backgroundOrbs: some View {
        GeometryReader { geo in
            Circle()
                .fill(accentBlue.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -60, y: -40)
            
            Circle()
                .fill(accentPurple.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: geo.size.width - 100, y: geo.size.height * 0.4)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Translator")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Speak and translate in real-time")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer()
            
            // Status indicator
            Circle()
                .fill(permissionGranted ? accentGreen : accentOrange)
                .frame(width: 8, height: 8)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Language Selector
    
    private var languageSelector: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showLanguagePicker.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Text(selectedLanguage.flag)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Translate to")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Text(selectedLanguage.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .rotationEffect(.degrees(showLanguagePicker ? 180 : 0))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Microphone
    
    private var microphoneSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Pulse rings
                if speechManager.isListening {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                            .scaleEffect(speechManager.isListening ? 1.2 : 0.8)
                            .opacity(speechManager.isListening ? 0 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.3),
                                value: speechManager.isListening
                            )
                    }
                }
                
                // Mic button
                Button {
                    if speechManager.isListening {
                        speechManager.stopListening()
                        if !speechManager.transcribedText.isEmpty {
                            translateText()
                        }
                    } else {
                        translatedText = ""
                        speechManager.transcribedText = ""
                        speechManager.startListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                speechManager.isListening
                                ? LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [accentBlue, accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: (speechManager.isListening ? Color.red : accentBlue).opacity(0.4), radius: 15, y: 5)
                        
                        Image(systemName: speechManager.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 100)
            
            // Status text
            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(speechManager.isListening ? .red.opacity(0.8) : .white.opacity(0.4))
                .animation(.easeInOut(duration: 0.3), value: speechManager.isListening)
        }
        .padding(.vertical, 10)
    }
    
    private var statusText: String {
        if let error = speechManager.errorMessage {
            return "⚠️ \(error)"
        }
        if speechManager.isListening {
            return "🔴 Listening... Tap to stop"
        }
        if !speechManager.transcribedText.isEmpty {
            return "Tap mic to record again"
        }
        return "Tap the microphone to start"
    }
    
    // MARK: - Transcription Card
    
    private var transcriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ORIGINAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                
                Spacer()
                
                if !speechManager.transcribedText.isEmpty {
                    Button {
                        UIPasteboard.general.string = speechManager.transcribedText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            
            if speechManager.transcribedText.isEmpty {
                Text("Your speech will appear here...")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                Text(speechManager.transcribedText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            speechManager.isListening
                            ? Color.red.opacity(0.3)
                            : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Translation Card
    
    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("TRANSLATED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentGreen.opacity(0.7))
                    
                    if !translatedText.isEmpty {
                        Text("\(selectedLanguage.flag)")
                            .font(.system(size: 12))
                    }
                }
                
                Spacer()
                
                if isTranslating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(accentGreen)
                }
            }
            
            if translatedText.isEmpty && !isTranslating {
                Text("Translation will appear here...")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else if isTranslating {
                Text("Translating to \(selectedLanguage.name)...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(accentOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                Text(translatedText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(accentGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            translatedText.isEmpty
                            ? Color.white.opacity(0.05)
                            : accentGreen.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Copy Translation button
            if !translatedText.isEmpty {
                Button {
                    UIPasteboard.general.string = translatedText
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(copied ? "Copied!" : "Copy Translation")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                copied
                                ? AnyShapeStyle(accentGreen)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [accentBlue, accentPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: accentBlue.opacity(0.3), radius: 10, y: 4)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Translate button (when there's text but no translation yet)
            if !speechManager.transcribedText.isEmpty && translatedText.isEmpty && !isTranslating && !speechManager.isListening {
                Button {
                    translateText()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Translate to \(selectedLanguage.name)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(surfaceColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(accentBlue)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Reset button
            if !speechManager.transcribedText.isEmpty || !translatedText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        speechManager.reset()
                        translatedText = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Clear & Start Over")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.vertical, 8)
                }
            }
        }
        .animation(.spring(response: 0.4), value: translatedText.isEmpty)
        .animation(.spring(response: 0.4), value: speechManager.transcribedText.isEmpty)
    }
    
    // MARK: - Language Picker Overlay
    
    private var languagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showLanguagePicker = false
                    }
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("🌐 Select Language")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showLanguagePicker = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Language grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(SupportedLanguages.all, id: \.code) { lang in
                            Button {
                                selectedLanguage = lang
                                saveLanguagePreference()
                                withAnimation(.spring(response: 0.3)) {
                                    showLanguagePicker = false
                                }
                                // Re-translate if we have text
                                if !speechManager.transcribedText.isEmpty {
                                    translatedText = ""
                                    translateText()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(lang.flag)
                                        .font(.system(size: 18))
                                    Text(lang.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    if lang == selectedLanguage {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(accentGreen)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(lang == selectedLanguage ? accentBlue.opacity(0.2) : surfaceColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            lang == selectedLanguage ? accentBlue.opacity(0.4) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 60)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Translation
    
    private func translateText() {
        let text = speechManager.transcribedText
        guard !text.isEmpty, selectedLanguage.code != "none" else { return }
        
        isTranslating = true
        
        translationService.translate(text: text, to: selectedLanguage.code) { result in
            DispatchQueue.main.async {
                isTranslating = false
                switch result {
                case .success(let translated):
                    withAnimation(.spring(response: 0.3)) {
                        translatedText = translated
                    }
                case .failure(let error):
                    translatedText = "Translation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Preferences
    
    private func loadLanguagePreference() {
        if let code = UserDefaults.standard.string(forKey: "selectedLanguageCode"),
           let lang = SupportedLanguages.all.first(where: { $0.code == code }) {
            selectedLanguage = lang
        }
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(selectedLanguage.code, forKey: "selectedLanguageCode")
    }
}

// MARK: - Preview

#Preview {
    VoiceTranslationView()
        .preferredColorScheme(.dark)
}
