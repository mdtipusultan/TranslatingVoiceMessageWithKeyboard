//
//  ShareViewController.swift
//  TranslateVoiceShare
//
//  Share Extension for translating voice messages from any messaging app.
//  Runs inline — no app switch needed.
//
//  Flow: User shares voice message → transcribe → translate → show result
//

import UIKit
import Speech
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - UI
    
    private var containerView: UIView!
    private var headerView: UIView!
    private var titleLabel: UILabel!
    private var closeButton: UIButton!
    private var languageButton: UIButton!
    private var statusContainer: UIView!
    private var statusIcon: UILabel!
    private var statusLabel: UILabel!
    private var progressBar: UIProgressView!
    private var resultContainer: UIView!
    private var originalHeaderLabel: UILabel!
    private var originalTextLabel: UILabel!
    private var separatorView: UIView!
    private var translatedHeaderLabel: UILabel!
    private var translatedTextLabel: UILabel!
    private var copyButton: UIButton!
    private var languagePickerContainer: UIView?
    private var languageCollectionView: UICollectionView?
    
    // MARK: - State
    
    private var selectedLanguage: Language = SupportedLanguages.all[1] // English default
    private var transcribedText = ""
    private var translatedText = ""
    private var isLanguagePickerShown = false
    
    // MARK: - Services
    
    private var translationService = TranslationService()
    private var speechRecognizer: SFSpeechRecognizer?
    
    // MARK: - Colors
    
    private let bgColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1.0)
    private let cardColor = UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0)
    private let accentBlue = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0)
    private let accentGreen = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
    private let accentOrange = UIColor(red: 0.95, green: 0.62, blue: 0.22, alpha: 1.0)
    private let errorRed = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load language preference (shared with keyboard via App Group or UserDefaults)
        loadLanguagePreference()
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        
        setupUI()
        processSharedContent()
    }
    
    private func loadLanguagePreference() {
        if let code = UserDefaults.standard.string(forKey: "selectedLanguageCode"),
           let lang = SupportedLanguages.all.first(where: { $0.code == code }) {
            selectedLanguage = lang
        }
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(selectedLanguage.code, forKey: "selectedLanguageCode")
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Semi-transparent backdrop
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        
        // Main card container
        containerView = UIView()
        containerView.backgroundColor = bgColor
        containerView.layer.cornerRadius = 24
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.65),
        ])
        
        // Handle bar
        let handle = UIView()
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handle)
        
        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 5),
        ])
        
        setupHeader()
        setupLanguageSelector()
        setupStatusArea()
        setupResultArea()
        setupCopyButton()
        
        // Initial state
        resultContainer.isHidden = true
        copyButton.isHidden = true
        
        // Animate in
        containerView.transform = CGAffineTransform(translationX: 0, y: 400)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.containerView.transform = .identity
        }
    }
    
    private func setupHeader() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerView)
        
        // Icon
        let iconBg = UIView()
        iconBg.backgroundColor = accentBlue.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 16
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(iconBg)
        
        let icon = UILabel()
        icon.text = "🎤"
        icon.font = UIFont.systemFont(ofSize: 18)
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        
        titleLabel = UILabel()
        titleLabel.text = "Voice Translator"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        closeButton = UIButton(type: .custom)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        closeButton.layer.cornerRadius = 14
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 32),
            
            iconBg.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            iconBg.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 32),
            iconBg.heightAnchor.constraint(equalToConstant: 32),
            
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
    
    private func setupLanguageSelector() {
        languageButton = UIButton(type: .custom)
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        languageButton.backgroundColor = cardColor
        languageButton.layer.cornerRadius = 10
        languageButton.contentHorizontalAlignment = .leading
        languageButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        languageButton.setTitleColor(.white, for: .normal)
        languageButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        updateLanguageButtonTitle()
        
        let cfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let chev = UIImage(systemName: "chevron.down", withConfiguration: cfg)
        languageButton.setImage(chev?.withRenderingMode(.alwaysTemplate), for: .normal)
        languageButton.tintColor = UIColor.white.withAlphaComponent(0.4)
        languageButton.semanticContentAttribute = .forceRightToLeft
        languageButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        languageButton.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        containerView.addSubview(languageButton)
        
        NSLayoutConstraint.activate([
            languageButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 14),
            languageButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            languageButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            languageButton.heightAnchor.constraint(equalToConstant: 38),
        ])
    }
    
    private func updateLanguageButtonTitle() {
        languageButton?.setTitle("\(selectedLanguage.flag)  Translate to: \(selectedLanguage.name)", for: .normal)
    }
    
    private func setupStatusArea() {
        statusContainer = UIView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusContainer)
        
        statusIcon = UILabel()
        statusIcon.text = "⏳"
        statusIcon.font = UIFont.systemFont(ofSize: 28)
        statusIcon.textAlignment = .center
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusIcon)
        
        statusLabel = UILabel()
        statusLabel.text = "Processing voice message..."
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusLabel)
        
        progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.08)
        progressBar.progressTintColor = accentBlue
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(progressBar)
        
        NSLayoutConstraint.activate([
            statusContainer.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 20),
            statusContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            statusIcon.topAnchor.constraint(equalTo: statusContainer.topAnchor),
            statusIcon.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: statusIcon.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            
            progressBar.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            progressBar.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 40),
            progressBar.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -40),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
            progressBar.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor),
        ])
    }
    
    private func setupResultArea() {
        resultContainer = UIView()
        resultContainer.backgroundColor = cardColor
        resultContainer.layer.cornerRadius = 14
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(resultContainer)
        
        // Original section
        originalHeaderLabel = UILabel()
        originalHeaderLabel.text = "ORIGINAL"
        originalHeaderLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        originalHeaderLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        originalHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(originalHeaderLabel)
        
        originalTextLabel = UILabel()
        originalTextLabel.text = ""
        originalTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        originalTextLabel.textColor = .white
        originalTextLabel.numberOfLines = 0
        originalTextLabel.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(originalTextLabel)
        
        // Separator
        separatorView = UIView()
        separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(separatorView)
        
        // Translated section
        translatedHeaderLabel = UILabel()
        translatedHeaderLabel.text = "TRANSLATED"
        translatedHeaderLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        translatedHeaderLabel.textColor = accentGreen.withAlphaComponent(0.7)
        translatedHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(translatedHeaderLabel)
        
        translatedTextLabel = UILabel()
        translatedTextLabel.text = ""
        translatedTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        translatedTextLabel.textColor = accentGreen
        translatedTextLabel.numberOfLines = 0
        translatedTextLabel.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(translatedTextLabel)
        
        NSLayoutConstraint.activate([
            resultContainer.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 14),
            resultContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            resultContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            originalHeaderLabel.topAnchor.constraint(equalTo: resultContainer.topAnchor, constant: 14),
            originalHeaderLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            
            originalTextLabel.topAnchor.constraint(equalTo: originalHeaderLabel.bottomAnchor, constant: 4),
            originalTextLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            originalTextLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            
            separatorView.topAnchor.constraint(equalTo: originalTextLabel.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            separatorView.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            translatedHeaderLabel.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 12),
            translatedHeaderLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            
            translatedTextLabel.topAnchor.constraint(equalTo: translatedHeaderLabel.bottomAnchor, constant: 4),
            translatedTextLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 16),
            translatedTextLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -16),
            translatedTextLabel.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor, constant: -14),
        ])
    }
    
    private func setupCopyButton() {
        copyButton = UIButton(type: .custom)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.backgroundColor = accentBlue
        copyButton.layer.cornerRadius = 14
        
        let copyCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let copyIcon = UIImage(systemName: "doc.on.doc.fill", withConfiguration: copyCfg)
        copyButton.setImage(copyIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
        copyButton.tintColor = .white
        copyButton.setTitle("  Copy Translation", for: .normal)
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        copyButton.layer.shadowColor = accentBlue.cgColor
        copyButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        copyButton.layer.shadowRadius = 10
        copyButton.layer.shadowOpacity = 0.3
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        containerView.addSubview(copyButton)
        
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: resultContainer.bottomAnchor, constant: 14),
            copyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            copyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            copyButton.heightAnchor.constraint(equalToConstant: 50),
            copyButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -30),
        ])
    }
    
    // MARK: - Process Shared Content
    
    private func processSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError("No content to process")
            return
        }
        
        updateStatus(icon: "⏳", text: "Extracting audio...", progress: 0.1)
        
        for item in items {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // Log all registered types for debugging
                NSLog("[VoiceShare] Provider types: %@", provider.registeredTypeIdentifiers)
                
                // Try to load the shared item
                loadAudioFromProvider(provider)
                return
            }
        }
        
        showError("No audio file found. Share a voice message to translate.")
    }
    
    private func loadAudioFromProvider(_ provider: NSItemProvider) {
        // All type identifiers we want to try, in priority order
        let typeIdentifiers = [
            // Audio types
            "public.audio",
            "com.apple.m4a-audio",
            "public.mp3",
            "public.mpeg-4-audio",
            "org.xiph.opus",
            "org.xiph.ogg",
            "com.microsoft.waveform-audio",
            "public.aiff-audio",
            // Video types (voice notes sometimes come as video)
            "public.movie",
            "public.mpeg-4",
            "com.apple.quicktime-movie",
            // Generic
            "public.data",
            "public.content",
            "public.item",
        ]
        
        // Find first matching type
        var matchedType: String? = nil
        for type in typeIdentifiers {
            if provider.hasItemConformingToTypeIdentifier(type) {
                matchedType = type
                NSLog("[VoiceShare] ✅ Matched type: %@", type)
                break
            }
        }
        
        guard let typeToLoad = matchedType else {
            NSLog("[VoiceShare] ❌ No matching type found in: %@", provider.registeredTypeIdentifiers)
            showError("Unsupported file format. Try sharing an audio or voice message.")
            return
        }
        
        // Strategy 1: Try loadItem as URL (works for most file shares)
        NSLog("[VoiceShare] Trying loadItem as URL for type: %@", typeToLoad)
        
        provider.loadItem(forTypeIdentifier: typeToLoad, options: nil) { [weak self] item, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    NSLog("[VoiceShare] loadItem error: %@", error.localizedDescription)
                }
                
                if let url = item as? URL {
                    NSLog("[VoiceShare] ✅ Got URL: %@", url.path)
                    self.handleAudioURL(url)
                    return
                }
                
                if let data = item as? Data {
                    NSLog("[VoiceShare] ✅ Got Data (%d bytes)", data.count)
                    self.handleAudioData(data, ext: self.guessExtension(for: typeToLoad))
                    return
                }
                
                // If item is a string URL
                if let urlString = item as? String, let url = URL(string: urlString) {
                    NSLog("[VoiceShare] ✅ Got string URL: %@", urlString)
                    self.handleAudioURL(url)
                    return
                }
                
                NSLog("[VoiceShare] ❌ Item type: %@", String(describing: type(of: item)))
                
                // Strategy 2: Try loadFileRepresentation as fallback
                NSLog("[VoiceShare] Trying loadFileRepresentation...")
                provider.loadFileRepresentation(forTypeIdentifier: typeToLoad) { [weak self] url, error in
                    DispatchQueue.main.async {
                        if let url = url {
                            NSLog("[VoiceShare] ✅ Got file representation: %@", url.path)
                            self?.handleAudioURL(url)
                        } else {
                            NSLog("[VoiceShare] ❌ loadFileRepresentation failed: %@", error?.localizedDescription ?? "unknown")
                            
                            // Strategy 3: Try loadDataRepresentation
                            NSLog("[VoiceShare] Trying loadDataRepresentation...")
                            provider.loadDataRepresentation(forTypeIdentifier: typeToLoad) { data, error in
                                DispatchQueue.main.async {
                                    if let data = data, data.count > 0 {
                                        NSLog("[VoiceShare] ✅ Got data representation (%d bytes)", data.count)
                                        self?.handleAudioData(data, ext: self?.guessExtension(for: typeToLoad) ?? "m4a")
                                    } else {
                                        NSLog("[VoiceShare] ❌ All strategies failed")
                                        self?.showError("Could not read the audio file. Try saving it locally first, then sharing.")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func guessExtension(for typeIdentifier: String) -> String {
        switch typeIdentifier {
        case "public.mp3": return "mp3"
        case "com.apple.m4a-audio", "public.mpeg-4-audio": return "m4a"
        case "org.xiph.opus": return "opus"
        case "org.xiph.ogg": return "ogg"
        case "com.microsoft.waveform-audio": return "wav"
        case "public.aiff-audio": return "aiff"
        case "public.mpeg-4", "public.movie": return "mp4"
        case "com.apple.quicktime-movie": return "mov"
        default: return "m4a"
        }
    }
    
    private func handleAudioURL(_ url: URL) {
        updateStatus(icon: "🎤", text: "Transcribing voice message...", progress: 0.3)
        
        // Check if the file exists and is readable
        let fileManager = FileManager.default
        
        // If the URL is already accessible, use it directly or copy
        if fileManager.isReadableFile(atPath: url.path) {
            // Copy to our temp directory to ensure access persists
            let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent("voicetranslate_\(UUID().uuidString.prefix(8)).\(ext)")
            
            do {
                try fileManager.copyItem(at: url, to: tempURL)
                NSLog("[VoiceShare] ✅ Copied to: %@, size: %lld bytes", tempURL.path, (try? fileManager.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? 0)
                transcribeAudio(at: tempURL)
            } catch {
                NSLog("[VoiceShare] Copy failed: %@, trying direct access...", error.localizedDescription)
                // Try using the URL directly
                transcribeAudio(at: url)
            }
        } else {
            NSLog("[VoiceShare] File not readable at path, trying URL directly")
            // Try using the original URL — SFSpeechRecognizer might handle it
            transcribeAudio(at: url)
        }
    }
    
    private func handleAudioData(_ data: Data, ext: String) {
        updateStatus(icon: "🎤", text: "Transcribing voice message...", progress: 0.3)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voicetranslate_\(UUID().uuidString.prefix(8)).\(ext)")
        
        do {
            try data.write(to: tempURL)
            NSLog("[VoiceShare] ✅ Wrote %d bytes to %@", data.count, tempURL.path)
            transcribeAudio(at: tempURL)
        } catch {
            NSLog("[VoiceShare] ❌ Failed to write data: %@", error.localizedDescription)
            showError("Failed to save audio file")
        }
    }
    
    // MARK: - Speech Recognition
    
    private func transcribeAudio(at url: URL) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.performTranscription(at: url)
                case .denied, .restricted:
                    self?.showError("Speech recognition permission denied. Enable in Settings → Privacy → Speech Recognition.")
                case .notDetermined:
                    self?.showError("Speech recognition permission required")
                @unknown default:
                    self?.showError("Speech recognition unavailable")
                }
            }
        }
    }
    
    private func performTranscription(at url: URL) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            showError("Speech recognition is not available for your language")
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        
        if #available(iOS 13.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
        }
        
        updateStatus(icon: "🎤", text: "Listening to voice message...", progress: 0.4)
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.transcribedText = text
                        self.translateResult()
                    } else {
                        // Show partial results
                        self.updateStatus(
                            icon: "🎤",
                            text: "Hearing: \"\(text.prefix(60))...\"",
                            progress: 0.6
                        )
                    }
                }
                
                if let error = error, self.transcribedText.isEmpty {
                    self.showError("Could not transcribe: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Translation
    
    private func translateResult() {
        guard !transcribedText.isEmpty else {
            showError("No speech detected in voice message")
            return
        }
        
        if selectedLanguage.code == "none" {
            // No translation, just show original
            showResult(original: transcribedText, translated: transcribedText)
            return
        }
        
        updateStatus(icon: "🌐", text: "Translating to \(selectedLanguage.flag) \(selectedLanguage.name)...", progress: 0.8)
        
        translationService.translate(text: transcribedText, to: selectedLanguage.code) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let translated):
                    self.translatedText = translated
                    self.showResult(original: self.transcribedText, translated: translated)
                case .failure:
                    // Show original text if translation fails
                    self.showResult(original: self.transcribedText, translated: self.transcribedText)
                    self.translatedHeaderLabel.text = "TRANSLATION FAILED — SHOWING ORIGINAL"
                    self.translatedTextLabel.textColor = self.accentOrange
                }
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateStatus(icon: String, text: String, progress: Float) {
        statusContainer.isHidden = false
        resultContainer.isHidden = true
        copyButton.isHidden = true
        
        statusIcon.text = icon
        statusLabel.text = text
        
        UIView.animate(withDuration: 0.3) {
            self.progressBar.setProgress(progress, animated: true)
        }
    }
    
    private func showResult(original: String, translated: String) {
        statusContainer.isHidden = true
        resultContainer.isHidden = false
        copyButton.isHidden = false
        
        originalTextLabel.text = original
        translatedTextLabel.text = translated
        
        // Animate in
        resultContainer.alpha = 0
        resultContainer.transform = CGAffineTransform(translationX: 0, y: 10)
        copyButton.alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            self.resultContainer.alpha = 1
            self.resultContainer.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.15) {
            self.copyButton.alpha = 1
        }
    }
    
    private func showError(_ message: String) {
        statusContainer.isHidden = false
        resultContainer.isHidden = true
        copyButton.isHidden = true
        
        statusIcon.text = "⚠️"
        statusLabel.text = message
        statusLabel.textColor = errorRed
        progressBar.isHidden = true
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        UIView.animate(withDuration: 0.25, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: 400)
            self.view.backgroundColor = .clear
        }) { _ in
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
    
    @objc private func copyTapped() {
        let textToCopy = translatedText.isEmpty ? transcribedText : translatedText
        UIPasteboard.general.string = textToCopy
        
        // Visual feedback
        let originalTitle = copyButton.title(for: .normal)
        copyButton.setTitle("  Copied! ✓", for: .normal)
        copyButton.backgroundColor = accentGreen
        
        UIView.animate(withDuration: 0.1, animations: {
            self.copyButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.copyButton.transform = .identity
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.copyButton.setTitle(originalTitle, for: .normal)
            self.copyButton.backgroundColor = self.accentBlue
        }
    }
    
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            closeTapped()
        }
    }
    
    // MARK: - Language Picker
    
    @objc private func languageTapped() {
        isLanguagePickerShown ? hideLanguagePicker() : showLanguagePicker()
    }
    
    private func showLanguagePicker() {
        isLanguagePickerShown = true
        
        let c = UIView()
        c.backgroundColor = cardColor
        c.layer.cornerRadius = 14
        c.layer.borderWidth = 1
        c.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        c.translatesAutoresizingMaskIntoConstraints = false
        c.clipsToBounds = true
        containerView.addSubview(c)
        languagePickerContainer = c
        
        let h = UIView()
        h.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(h)
        
        let t = UILabel()
        t.text = "🌐 Select Language"
        t.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        t.textColor = .white
        t.translatesAutoresizingMaskIntoConstraints = false
        h.addSubview(t)
        
        let x = UIButton(type: .custom)
        x.setTitle("✕", for: .normal)
        x.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        x.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        x.translatesAutoresizingMaskIntoConstraints = false
        x.addTarget(self, action: #selector(hideLanguagePicker), for: .touchUpInside)
        h.addSubview(x)
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 4, left: 10, bottom: 10, right: 10)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(ShareLanguageCell.self, forCellWithReuseIdentifier: "ShareLangCell")
        cv.indicatorStyle = .white
        c.addSubview(cv)
        languageCollectionView = cv
        
        NSLayoutConstraint.activate([
            c.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 6),
            c.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            c.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            c.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            
            h.topAnchor.constraint(equalTo: c.topAnchor),
            h.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            h.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            h.heightAnchor.constraint(equalToConstant: 36),
            
            t.centerYAnchor.constraint(equalTo: h.centerYAnchor),
            t.leadingAnchor.constraint(equalTo: h.leadingAnchor, constant: 14),
            
            x.centerYAnchor.constraint(equalTo: h.centerYAnchor),
            x.trailingAnchor.constraint(equalTo: h.trailingAnchor, constant: -10),
            
            cv.topAnchor.constraint(equalTo: h.bottomAnchor),
            cv.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: c.bottomAnchor),
        ])
        
        c.alpha = 0
        UIView.animate(withDuration: 0.2) { c.alpha = 1 }
    }
    
    @objc private func hideLanguagePicker() {
        isLanguagePickerShown = false
        guard let c = languagePickerContainer else { return }
        UIView.animate(withDuration: 0.15, animations: { c.alpha = 0 }) { _ in
            c.removeFromSuperview()
            self.languagePickerContainer = nil
            self.languageCollectionView = nil
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ShareViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        return !containerView.frame.contains(location)
    }
}

// MARK: - Collection View

extension ShareViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        SupportedLanguages.all.count
    }
    
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "ShareLangCell", for: indexPath) as! ShareLanguageCell
        let lang = SupportedLanguages.all[indexPath.item]
        cell.configure(with: lang, isSelected: lang == selectedLanguage)
        return cell
    }
    
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: (cv.bounds.width - 25) / 2, height: 38)
    }
    
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedLanguage = SupportedLanguages.all[indexPath.item]
        saveLanguagePreference()
        updateLanguageButtonTitle()
        hideLanguagePicker()
        
        // Re-translate if we already have transcript
        if !transcribedText.isEmpty {
            translateResult()
        }
    }
}

// MARK: - Share Language Cell

class ShareLanguageCell: UICollectionViewCell {
    private let flagLabel = UILabel()
    private let nameLabel = UILabel()
    private let check = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 8
        
        flagLabel.font = UIFont.systemFont(ofSize: 16)
        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(flagLabel)
        
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        check.text = "✓"
        check.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        check.textColor = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
        check.isHidden = true
        check.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(check)
        
        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            flagLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 6),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -4),
            check.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            check.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with lang: Language, isSelected: Bool) {
        flagLabel.text = lang.flag
        nameLabel.text = lang.name
        check.isHidden = !isSelected
        contentView.backgroundColor = isSelected
            ? UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.3)
            : UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1.0)
        contentView.layer.borderWidth = isSelected ? 1 : 0
        contentView.layer.borderColor = isSelected ? UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.5).cgColor : nil
    }
}
