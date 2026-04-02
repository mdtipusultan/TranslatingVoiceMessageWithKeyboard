//
//  KeyboardViewController.swift
//  VoiceKeyboard
//
//  iOS Keyboard Extension — Typing + Voice Translation
//  Features:
//    - Toggle between Typing and Translation modes
//    - Typing: full QWERTY with shift, numbers, symbols
//    - Translation: auto-translates typed/dictated text to 65+ languages
//    - Voice input: tap mic to speak, auto-transcribe + translate
//    - Works in any app (WhatsApp, Instagram, Messenger, etc.)
//

import UIKit
import Speech

class KeyboardViewController: UIInputViewController {
    
    // MARK: - Mode
    
    private enum KeyboardMode {
        case translation
        case typing
    }
    
    private var currentMode: KeyboardMode = .typing
    
    // MARK: - Shared UI
    
    private var keyboardView: UIView!
    private var modeToggleContainer: UIView!
    private var translationModeBtn: UIButton!
    private var typingModeBtn: UIButton!
    private var toggleIndicator: UIView!
    private var toggleIndicatorLeading: NSLayoutConstraint!
    
    // MARK: - Translation Mode UI
    
    private var translationContainer: UIView!
    private var languageButton: UIButton!
    private var languagePickerContainer: UIView?
    private var languageCollectionView: UICollectionView?
    private var inputPreviewLabel: UILabel!
    private var translatedPreviewLabel: UILabel!
    private var translateButton: UIButton!
    private var voiceButton: UIButton!
    private var voiceStatusLabel: UILabel!
    
    // MARK: - Typing Mode UI
    
    private var typingContainer: UIView!
    private var typingMicButton: UIButton!
    private var keyRows: [UIStackView] = []
    private var isShifted = true
    private var isCapsLock = false
    private var isNumberMode = false
    private var isSymbolMode = false
    
    // MARK: - Services
    
    private var translationService: TranslationService!
    private var speechManager: SpeechTranslationManager!
    
    // MARK: - State
    
    private var isLanguagePickerShown = false
    private var selectedLanguage: Language = SupportedLanguages.all[0]
    private var lastTranslatedText = ""
    private var previousDocumentText = ""
    private var autoTranslateTimer: Timer?
    private var recognizedText = ""
    
    // MARK: - Colors
    
    private let primaryColor = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0)
    private let darkBgColor = UIColor(red: 0.11, green: 0.11, blue: 0.15, alpha: 1.0)
    private let cardBgColor = UIColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1.0)
    private let buttonColor = UIColor(red: 0.24, green: 0.24, blue: 0.30, alpha: 1.0)
    private let keyColor = UIColor(red: 0.28, green: 0.28, blue: 0.35, alpha: 1.0)
    private let keyHighlight = UIColor(red: 0.38, green: 0.38, blue: 0.46, alpha: 1.0)
    private let recordingColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
    private let accentGreen = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
    private let accentOrange = UIColor(red: 0.95, green: 0.62, blue: 0.22, alpha: 1.0)
    private let textColor = UIColor.white
    private let secondaryTextColor = UIColor(white: 0.50, alpha: 1.0)
    
    // MARK: - Key Layouts
    
    private let letterRow1 = ["q","w","e","r","t","y","u","i","o","p"]
    private let letterRow2 = ["a","s","d","f","g","h","j","k","l"]
    private let letterRow3 = ["z","x","c","v","b","n","m"]
    
    private let numberRow1 = ["1","2","3","4","5","6","7","8","9","0"]
    private let numberRow2 = ["-","/",":",";","(",")","$","&","@","\""]
    private let numberRow3 = [".",",","?","!","'"]
    
    private let symbolRow1 = ["[","]","{","}","#","%","^","*","+","="]
    private let symbolRow2 = ["_","\\","|","~","<",">","€","£","¥","•"]
    private let symbolRow3 = [".",",","?","!","'"]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadLanguagePreference()
        loadModePreference()
        
        translationService = TranslationService()
        speechManager = SpeechTranslationManager()
        speechManager.delegate = self
        speechManager.prepare()
        
        setupUI()
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
    
    private func loadModePreference() {
        let s = UserDefaults.standard.string(forKey: "keyboardMode") ?? "typing"
        currentMode = s == "translation" ? .translation : .typing
    }
    
    private func saveModePreference() {
        UserDefaults.standard.set(currentMode == .translation ? "translation" : "typing", forKey: "keyboardMode")
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.isUserInteractionEnabled = true
        inputView?.isUserInteractionEnabled = true
        
        keyboardView = UIView()
        keyboardView.backgroundColor = darkBgColor
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.isUserInteractionEnabled = true
        view.addSubview(keyboardView)
        
        let hc = keyboardView.heightAnchor.constraint(equalToConstant: 300)
        hc.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hc
        ])
        
        setupModeToggle()
        setupTranslationMode()
        setupTypingMode()
        applyMode(animated: false)
    }
    
    // MARK: - Mode Toggle
    
    private func setupModeToggle() {
        modeToggleContainer = UIView()
        modeToggleContainer.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        modeToggleContainer.layer.cornerRadius = 10
        modeToggleContainer.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(modeToggleContainer)
        
        toggleIndicator = UIView()
        toggleIndicator.backgroundColor = primaryColor
        toggleIndicator.layer.cornerRadius = 8
        toggleIndicator.translatesAutoresizingMaskIntoConstraints = false
        modeToggleContainer.addSubview(toggleIndicator)
        
        typingModeBtn = UIButton(type: .custom)
        typingModeBtn.setTitle("⌨ Typing", for: .normal)
        typingModeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        typingModeBtn.setTitleColor(.white, for: .normal)
        typingModeBtn.translatesAutoresizingMaskIntoConstraints = false
        typingModeBtn.addTarget(self, action: #selector(switchToTyping), for: .touchUpInside)
        modeToggleContainer.addSubview(typingModeBtn)
        
        translationModeBtn = UIButton(type: .custom)
        translationModeBtn.setTitle("🌐 Translate", for: .normal)
        translationModeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        translationModeBtn.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .normal)
        translationModeBtn.translatesAutoresizingMaskIntoConstraints = false
        translationModeBtn.addTarget(self, action: #selector(switchToTranslation), for: .touchUpInside)
        modeToggleContainer.addSubview(translationModeBtn)
        
        toggleIndicatorLeading = toggleIndicator.leadingAnchor.constraint(equalTo: modeToggleContainer.leadingAnchor, constant: 3)
        
        NSLayoutConstraint.activate([
            modeToggleContainer.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 6),
            modeToggleContainer.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            modeToggleContainer.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            modeToggleContainer.heightAnchor.constraint(equalToConstant: 34),
            toggleIndicatorLeading,
            toggleIndicator.topAnchor.constraint(equalTo: modeToggleContainer.topAnchor, constant: 3),
            toggleIndicator.bottomAnchor.constraint(equalTo: modeToggleContainer.bottomAnchor, constant: -3),
            toggleIndicator.widthAnchor.constraint(equalTo: modeToggleContainer.widthAnchor, multiplier: 0.5, constant: -4),
            typingModeBtn.leadingAnchor.constraint(equalTo: modeToggleContainer.leadingAnchor),
            typingModeBtn.topAnchor.constraint(equalTo: modeToggleContainer.topAnchor),
            typingModeBtn.bottomAnchor.constraint(equalTo: modeToggleContainer.bottomAnchor),
            typingModeBtn.widthAnchor.constraint(equalTo: modeToggleContainer.widthAnchor, multiplier: 0.5),
            translationModeBtn.trailingAnchor.constraint(equalTo: modeToggleContainer.trailingAnchor),
            translationModeBtn.topAnchor.constraint(equalTo: modeToggleContainer.topAnchor),
            translationModeBtn.bottomAnchor.constraint(equalTo: modeToggleContainer.bottomAnchor),
            translationModeBtn.widthAnchor.constraint(equalTo: modeToggleContainer.widthAnchor, multiplier: 0.5),
        ])
    }
    
    @objc private func switchToTyping() {
        guard currentMode != .typing else { return }
        if speechManager.isListening { speechManager.stopListening() }
        currentMode = .typing
        saveModePreference()
        applyMode(animated: true)
    }
    
    @objc private func switchToTranslation() {
        guard currentMode != .translation else { return }
        if speechManager.isListening { speechManager.stopListening() }
        currentMode = .translation
        saveModePreference()
        applyMode(animated: true)
    }
    
    private func applyMode(animated: Bool) {
        let isTyping = currentMode == .typing
        let changes = {
            let half = self.modeToggleContainer.bounds.width / 2
            self.toggleIndicatorLeading.constant = isTyping ? 3 : half + 1
            self.typingModeBtn.setTitleColor(isTyping ? .white : UIColor.white.withAlphaComponent(0.45), for: .normal)
            self.translationModeBtn.setTitleColor(isTyping ? UIColor.white.withAlphaComponent(0.45) : .white, for: .normal)
            self.typingContainer?.alpha = isTyping ? 1 : 0
            self.translationContainer?.alpha = isTyping ? 0 : 1
            self.modeToggleContainer.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) { changes() }
        } else {
            DispatchQueue.main.async { changes() }
        }
        typingContainer?.isUserInteractionEnabled = isTyping
        translationContainer?.isUserInteractionEnabled = !isTyping
    }
    
    // ============================================================
    // MARK: - TYPING MODE
    // ============================================================
    
    private func setupTypingMode() {
        typingContainer = UIView()
        typingContainer.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(typingContainer)
        
        NSLayoutConstraint.activate([
            typingContainer.topAnchor.constraint(equalTo: modeToggleContainer.bottomAnchor, constant: 6),
            typingContainer.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            typingContainer.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            typingContainer.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
        ])
        
        buildKeyboardLayout()
    }
    
    private func buildKeyboardLayout() {
        typingContainer.subviews.forEach { $0.removeFromSuperview() }
        keyRows = []
        
        let r1, r2, r3: [String]
        if isSymbolMode { r1 = symbolRow1; r2 = symbolRow2; r3 = symbolRow3 }
        else if isNumberMode { r1 = numberRow1; r2 = numberRow2; r3 = numberRow3 }
        else { r1 = letterRow1; r2 = letterRow2; r3 = letterRow3 }
        
        let row1 = makeKeyRow(keys: r1)
        let row2 = makeKeyRow(keys: r2)
        let row3 = makeSpecialRow3(keys: r3)
        let row4 = makeBottomRow()
        
        let stack = UIStackView(arrangedSubviews: [row1, row2, row3, row4])
        stack.axis = .vertical
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        typingContainer.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: typingContainer.topAnchor, constant: 2),
            stack.leadingAnchor.constraint(equalTo: typingContainer.leadingAnchor, constant: 3),
            stack.trailingAnchor.constraint(equalTo: typingContainer.trailingAnchor, constant: -3),
            stack.bottomAnchor.constraint(equalTo: typingContainer.bottomAnchor, constant: -4),
        ])
    }
    
    private func makeKeyRow(keys: [String]) -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal; s.spacing = 4; s.distribution = .fillEqually
        for key in keys { s.addArrangedSubview(makeKeyButton(key)) }
        keyRows.append(s)
        return s
    }
    
    private func makeSpecialRow3(keys: [String]) -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal; s.spacing = 4; s.distribution = .fill
        
        if !isNumberMode && !isSymbolMode {
            let shiftBtn = UIButton(type: .custom)
            let icon = isShifted || isCapsLock ? "shift.fill" : "shift"
            let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            shiftBtn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            shiftBtn.tintColor = (isShifted || isCapsLock) ? .white : secondaryTextColor
            shiftBtn.backgroundColor = (isShifted || isCapsLock) ? primaryColor : buttonColor
            shiftBtn.layer.cornerRadius = 6
            shiftBtn.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
            shiftBtn.translatesAutoresizingMaskIntoConstraints = false
            shiftBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
            s.addArrangedSubview(shiftBtn)
        }
        
        let inner = UIStackView()
        inner.axis = .horizontal; inner.spacing = 4; inner.distribution = .fillEqually
        for key in keys { inner.addArrangedSubview(makeKeyButton(key)) }
        s.addArrangedSubview(inner)
        
        let bsBtn = UIButton(type: .custom)
        let bsCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        bsBtn.setImage(UIImage(systemName: "delete.left.fill", withConfiguration: bsCfg), for: .normal)
        bsBtn.tintColor = textColor; bsBtn.backgroundColor = buttonColor; bsBtn.layer.cornerRadius = 6
        bsBtn.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        bsBtn.translatesAutoresizingMaskIntoConstraints = false
        bsBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        s.addArrangedSubview(bsBtn)
        
        return s
    }
    
    private func makeBottomRow() -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal; s.spacing = 4; s.distribution = .fill
        
        // 123/ABC
        let toggleBtn = UIButton(type: .custom)
        toggleBtn.setTitle(isNumberMode || isSymbolMode ? "ABC" : "123", for: .normal)
        toggleBtn.setTitleColor(textColor, for: .normal)
        toggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        toggleBtn.backgroundColor = buttonColor; toggleBtn.layer.cornerRadius = 6
        toggleBtn.addTarget(self, action: #selector(numberToggleTapped), for: .touchUpInside)
        toggleBtn.translatesAutoresizingMaskIntoConstraints = false
        toggleBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        s.addArrangedSubview(toggleBtn)
        
        if isNumberMode || isSymbolMode {
            let symBtn = UIButton(type: .custom)
            symBtn.setTitle(isSymbolMode ? "123" : "#+=", for: .normal)
            symBtn.setTitleColor(textColor, for: .normal)
            symBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            symBtn.backgroundColor = buttonColor; symBtn.layer.cornerRadius = 6
            symBtn.addTarget(self, action: #selector(symbolToggleTapped), for: .touchUpInside)
            symBtn.translatesAutoresizingMaskIntoConstraints = false
            symBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            s.addArrangedSubview(symBtn)
        }
        
        // Mic button in typing mode
        let micBtn = UIButton(type: .custom)
        let micCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        micBtn.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg), for: .normal)
        micBtn.tintColor = .white
        micBtn.backgroundColor = accentGreen
        micBtn.layer.cornerRadius = 6
        micBtn.addTarget(self, action: #selector(typingMicTapped), for: .touchUpInside)
        micBtn.translatesAutoresizingMaskIntoConstraints = false
        micBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        s.addArrangedSubview(micBtn)
        typingMicButton = micBtn
        
        // Space
        let spaceBtn = UIButton(type: .custom)
        spaceBtn.setTitle("space", for: .normal)
        spaceBtn.setTitleColor(textColor, for: .normal)
        spaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        spaceBtn.backgroundColor = keyColor; spaceBtn.layer.cornerRadius = 6
        spaceBtn.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        s.addArrangedSubview(spaceBtn)
        
        // Return
        let retBtn = UIButton(type: .custom)
        retBtn.setTitle("return", for: .normal)
        retBtn.setTitleColor(.white, for: .normal)
        retBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        retBtn.backgroundColor = primaryColor; retBtn.layer.cornerRadius = 6
        retBtn.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        retBtn.translatesAutoresizingMaskIntoConstraints = false
        retBtn.widthAnchor.constraint(equalToConstant: 72).isActive = true
        s.addArrangedSubview(retBtn)
        
        return s
    }
    
    private func makeKeyButton(_ key: String) -> UIButton {
        let btn = UIButton(type: .custom)
        let display = (!isNumberMode && !isSymbolMode && (isShifted || isCapsLock)) ? key.uppercased() : key
        btn.setTitle(display, for: .normal)
        btn.setTitleColor(textColor, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        btn.backgroundColor = keyColor; btn.layer.cornerRadius = 6
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowRadius = 1; btn.layer.shadowOpacity = 0.3
        btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        return btn
    }
    
    // MARK: - Typing Actions
    
    @objc private func keyTapped(_ sender: UIButton) {
        guard let key = sender.titleLabel?.text else { return }
        UIView.animate(withDuration: 0.05, animations: {
            sender.backgroundColor = self.keyHighlight
            sender.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                sender.backgroundColor = self.keyColor
                sender.transform = .identity
            }
        }
        textDocumentProxy.insertText(key)
        if isShifted && !isCapsLock && !isNumberMode && !isSymbolMode {
            isShifted = false; buildKeyboardLayout()
        }
    }
    
    @objc private func shiftTapped() {
        if isCapsLock { isCapsLock = false; isShifted = false }
        else if isShifted { isCapsLock = true }
        else { isShifted = true }
        buildKeyboardLayout()
    }
    
    @objc private func numberToggleTapped() {
        if isNumberMode || isSymbolMode { isNumberMode = false; isSymbolMode = false }
        else { isNumberMode = true; isSymbolMode = false }
        buildKeyboardLayout()
    }
    
    @objc private func symbolToggleTapped() {
        isSymbolMode.toggle(); isNumberMode = !isSymbolMode; buildKeyboardLayout()
    }
    
    @objc private func backspaceTapped() { textDocumentProxy.deleteBackward() }
    @objc private func spaceTapped() { textDocumentProxy.insertText(" ") }
    @objc private func returnTapped() { textDocumentProxy.insertText("\n") }
    
    /// Mic button in typing mode: speak → insert text (+ translate if language selected)
    @objc private func typingMicTapped() {
        if speechManager.isListening {
            speechManager.stopListening()
            updateTypingMicState(listening: false)
        } else {
            recognizedText = ""
            speechManager.startListening()
        }
    }
    
    private func updateTypingMicState(listening: Bool) {
        if listening {
            typingMicButton?.backgroundColor = recordingColor
            typingMicButton?.tintColor = .white
            
            // Add pulse
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0; pulse.toValue = 0.4
            pulse.duration = 0.6; pulse.autoreverses = true
            pulse.repeatCount = .infinity
            typingMicButton?.layer.add(pulse, forKey: "pulse")
        } else {
            typingMicButton?.backgroundColor = accentGreen
            typingMicButton?.tintColor = .white
            typingMicButton?.layer.removeAllAnimations()
        }
    }
    
    // ============================================================
    // MARK: - TRANSLATION MODE
    // ============================================================
    
    private func setupTranslationMode() {
        translationContainer = UIView()
        translationContainer.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(translationContainer)
        
        NSLayoutConstraint.activate([
            translationContainer.topAnchor.constraint(equalTo: modeToggleContainer.bottomAnchor, constant: 6),
            translationContainer.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            translationContainer.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            translationContainer.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
        ])
        
        setupLanguageSelector()
        setupPreviewArea()
        setupVoiceAndTranslateButtons()
        setupTranslationUtilityButtons()
    }
    
    private func setupLanguageSelector() {
        languageButton = UIButton(type: .custom)
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        languageButton.backgroundColor = cardBgColor
        languageButton.layer.cornerRadius = 10
        languageButton.contentHorizontalAlignment = .leading
        languageButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        languageButton.setTitleColor(textColor, for: .normal)
        languageButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        updateLanguageButtonTitle()
        
        let chevCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let chev = UIImage(systemName: "chevron.down", withConfiguration: chevCfg)
        languageButton.setImage(chev?.withRenderingMode(.alwaysTemplate), for: .normal)
        languageButton.tintColor = secondaryTextColor
        languageButton.semanticContentAttribute = .forceRightToLeft
        languageButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        languageButton.addTarget(self, action: #selector(languageButtonTapped), for: .touchUpInside)
        translationContainer.addSubview(languageButton)
        
        NSLayoutConstraint.activate([
            languageButton.topAnchor.constraint(equalTo: translationContainer.topAnchor, constant: 2),
            languageButton.leadingAnchor.constraint(equalTo: translationContainer.leadingAnchor, constant: 8),
            languageButton.trailingAnchor.constraint(equalTo: translationContainer.trailingAnchor, constant: -8),
            languageButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
    
    private func updateLanguageButtonTitle() {
        if selectedLanguage.code == "none" {
            languageButton?.setTitle("🔤  No translation selected", for: .normal)
        } else {
            languageButton?.setTitle("\(selectedLanguage.flag)  Translate to: \(selectedLanguage.name)", for: .normal)
        }
    }
    
    private func setupPreviewArea() {
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        translationContainer.addSubview(container)
        
        let origLabel = UILabel()
        origLabel.text = "ORIGINAL"
        origLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        origLabel.textColor = secondaryTextColor
        origLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(origLabel)
        
        inputPreviewLabel = UILabel()
        inputPreviewLabel.text = "Type, dictate, or tap 🎤 to speak"
        inputPreviewLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        inputPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
        inputPreviewLabel.numberOfLines = 2
        inputPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inputPreviewLabel)
        
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        
        let transLabel = UILabel()
        transLabel.text = "TRANSLATED"
        transLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        transLabel.textColor = accentGreen.withAlphaComponent(0.7)
        transLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(transLabel)
        
        translatedPreviewLabel = UILabel()
        translatedPreviewLabel.text = "Translation appears here"
        translatedPreviewLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        translatedPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
        translatedPreviewLabel.numberOfLines = 2
        translatedPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(translatedPreviewLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 5),
            container.leadingAnchor.constraint(equalTo: translationContainer.leadingAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: translationContainer.trailingAnchor, constant: -8),
            origLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 7),
            origLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            inputPreviewLabel.topAnchor.constraint(equalTo: origLabel.bottomAnchor, constant: 2),
            inputPreviewLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            inputPreviewLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            sep.topAnchor.constraint(equalTo: inputPreviewLabel.bottomAnchor, constant: 5),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            sep.heightAnchor.constraint(equalToConstant: 1),
            transLabel.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 5),
            transLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            translatedPreviewLabel.topAnchor.constraint(equalTo: transLabel.bottomAnchor, constant: 2),
            translatedPreviewLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            translatedPreviewLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            translatedPreviewLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -7),
        ])
    }
    
    private func setupVoiceAndTranslateButtons() {
        // Voice button (mic)
        voiceButton = UIButton(type: .custom)
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.backgroundColor = accentGreen
        voiceButton.layer.cornerRadius = 10
        
        let micCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        voiceButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg)?.withRenderingMode(.alwaysTemplate), for: .normal)
        voiceButton.tintColor = .white
        voiceButton.layer.shadowColor = accentGreen.cgColor
        voiceButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        voiceButton.layer.shadowRadius = 6; voiceButton.layer.shadowOpacity = 0.3
        voiceButton.addTarget(self, action: #selector(voiceMicTapped), for: .touchUpInside)
        translationContainer.addSubview(voiceButton)
        
        // Voice status label
        voiceStatusLabel = UILabel()
        voiceStatusLabel.text = ""
        voiceStatusLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        voiceStatusLabel.textColor = secondaryTextColor
        voiceStatusLabel.textAlignment = .center
        voiceStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        voiceStatusLabel.isHidden = true
        translationContainer.addSubview(voiceStatusLabel)
        
        // Translate button
        translateButton = UIButton(type: .custom)
        translateButton.translatesAutoresizingMaskIntoConstraints = false
        translateButton.backgroundColor = primaryColor
        translateButton.layer.cornerRadius = 10
        translateButton.setTitle("Translate & Replace", for: .normal)
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        let gIcon = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        translateButton.setImage(gIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
        translateButton.tintColor = .white
        translateButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        translateButton.layer.shadowColor = primaryColor.cgColor
        translateButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        translateButton.layer.shadowRadius = 6; translateButton.layer.shadowOpacity = 0.25
        translateButton.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        translationContainer.addSubview(translateButton)
        
        NSLayoutConstraint.activate([
            // Voice button - left side
            voiceButton.leadingAnchor.constraint(equalTo: translationContainer.leadingAnchor, constant: 8),
            voiceButton.bottomAnchor.constraint(equalTo: translationContainer.bottomAnchor, constant: -48),
            voiceButton.widthAnchor.constraint(equalToConstant: 52),
            voiceButton.heightAnchor.constraint(equalToConstant: 40),
            
            voiceStatusLabel.centerXAnchor.constraint(equalTo: voiceButton.centerXAnchor),
            voiceStatusLabel.topAnchor.constraint(equalTo: voiceButton.bottomAnchor, constant: 1),
            
            // Translate button - right of mic
            translateButton.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 6),
            translateButton.trailingAnchor.constraint(equalTo: translationContainer.trailingAnchor, constant: -8),
            translateButton.bottomAnchor.constraint(equalTo: voiceButton.bottomAnchor),
            translateButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    
    /// Mic button in translation mode
    @objc private func voiceMicTapped() {
        if isLanguagePickerShown { hideLanguagePicker() }
        
        if speechManager.isListening {
            speechManager.stopListening()
        } else {
            recognizedText = ""
            speechManager.startListening()
        }
    }
    
    private func updateVoiceButtonState(listening: Bool) {
        if listening {
            voiceButton.backgroundColor = recordingColor
            voiceButton.layer.shadowColor = recordingColor.cgColor
            let stopCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            voiceButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: stopCfg), for: .normal)
            voiceStatusLabel.text = "Listening..."
            voiceStatusLabel.textColor = recordingColor
            voiceStatusLabel.isHidden = false
            
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0; pulse.toValue = 1.08
            pulse.duration = 0.5; pulse.autoreverses = true
            pulse.repeatCount = .infinity
            voiceButton.layer.add(pulse, forKey: "pulse")
        } else {
            voiceButton.backgroundColor = accentGreen
            voiceButton.layer.shadowColor = accentGreen.cgColor
            let micCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            voiceButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg), for: .normal)
            voiceStatusLabel.isHidden = true
            voiceButton.layer.removeAllAnimations()
        }
    }
    
    private func setupTranslationUtilityButtons() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 6; stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        translationContainer.addSubview(stack)
        
        stack.addArrangedSubview(makeUtilButton(icon: "delete.left.fill", title: nil, action: #selector(backspaceTapped)))
        stack.addArrangedSubview(makeUtilButton(icon: nil, title: "space", action: #selector(spaceTapped)))
        stack.addArrangedSubview(makeUtilButton(icon: "return", title: nil, action: #selector(returnTapped)))
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: translationContainer.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: translationContainer.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: translationContainer.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    private func makeUtilButton(icon: String?, title: String?, action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = buttonColor; btn.layer.cornerRadius = 8; btn.tintColor = textColor
        if let icon = icon {
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            btn.setImage(UIImage(systemName: icon, withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        if let title = title {
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(textColor, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    // MARK: - Translation Actions
    
    override func textWillChange(_ textInput: UITextInput?) {}
    
    override func textDidChange(_ textInput: UITextInput?) {
        guard currentMode == .translation else { return }
        let text = readRecentText()
        if !text.isEmpty && text != previousDocumentText {
            previousDocumentText = text
            inputPreviewLabel.text = text
            inputPreviewLabel.textColor = textColor
            autoTranslateTimer?.invalidate()
            if selectedLanguage.code != "none" {
                translatedPreviewLabel.text = "Translating..."
                translatedPreviewLabel.textColor = accentOrange
                autoTranslateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    self?.autoTranslatePreview(text)
                }
            }
        }
        if text.isEmpty {
            inputPreviewLabel.text = "Type, dictate, or tap 🎤 to speak"
            inputPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
            translatedPreviewLabel.text = "Translation appears here"
            translatedPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
        }
    }
    
    private func readRecentText() -> String {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if let nl = before.lastIndex(of: "\n") {
            return String(before[before.index(after: nl)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return before.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func autoTranslatePreview(_ text: String) {
        guard selectedLanguage.code != "none" else { return }
        translationService.translate(text: text, to: selectedLanguage.code) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let t):
                    self?.translatedPreviewLabel.text = t
                    self?.translatedPreviewLabel.textColor = self?.accentGreen
                case .failure:
                    self?.translatedPreviewLabel.text = "Translation failed"
                    self?.translatedPreviewLabel.textColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1)
                }
            }
        }
    }
    
    @objc private func translateTapped() {
        if isLanguagePickerShown { hideLanguagePicker() }
        guard selectedLanguage.code != "none" else {
            translatedPreviewLabel.text = "Select a language first"
            translatedPreviewLabel.textColor = accentOrange; return
        }
        let text = readRecentText()
        guard !text.isEmpty else {
            translatedPreviewLabel.text = "Type or speak something first"
            translatedPreviewLabel.textColor = accentOrange; return
        }
        
        translateButton.setTitle("Translating...", for: .normal)
        translateButton.backgroundColor = accentOrange; translateButton.isEnabled = false
        
        translationService.translate(text: text, to: selectedLanguage.code) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.translateButton.setTitle("Translate & Replace", for: .normal)
                self.translateButton.backgroundColor = self.primaryColor; self.translateButton.isEnabled = true
                switch result {
                case .success(let translated):
                    self.deleteCurrentLineText()
                    self.textDocumentProxy.insertText(translated)
                    self.translatedPreviewLabel.text = translated
                    self.translatedPreviewLabel.textColor = self.accentGreen
                    UIView.animate(withDuration: 0.15) { self.translateButton.backgroundColor = self.accentGreen }
                    UIView.animate(withDuration: 0.3, delay: 0.5) { self.translateButton.backgroundColor = self.primaryColor }
                case .failure(let error):
                    self.translatedPreviewLabel.text = "Error: \(error.localizedDescription)"
                    self.translatedPreviewLabel.textColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1)
                }
            }
        }
    }
    
    private func deleteCurrentLineText() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let count: Int
        if let nl = before.lastIndex(of: "\n") {
            count = before.distance(from: before.index(after: nl), to: before.endIndex)
        } else { count = before.count }
        for _ in 0..<count { textDocumentProxy.deleteBackward() }
    }
    
    // MARK: - Language Picker
    
    @objc private func languageButtonTapped() {
        isLanguagePickerShown ? hideLanguagePicker() : showLanguagePicker()
    }
    
    private func showLanguagePicker() {
        isLanguagePickerShown = true
        let c = UIView()
        c.backgroundColor = cardBgColor; c.layer.cornerRadius = 14
        c.layer.borderWidth = 1; c.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        c.translatesAutoresizingMaskIntoConstraints = false; c.clipsToBounds = true
        translationContainer.addSubview(c); languagePickerContainer = c
        
        let h = UIView(); h.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(h)
        let t = UILabel(); t.text = "🌐 Select Language"
        t.font = UIFont.systemFont(ofSize: 14, weight: .bold); t.textColor = textColor
        t.translatesAutoresizingMaskIntoConstraints = false; h.addSubview(t)
        let x = UIButton(type: .custom); x.setTitle("✕", for: .normal)
        x.setTitleColor(secondaryTextColor, for: .normal)
        x.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        x.translatesAutoresizingMaskIntoConstraints = false
        x.addTarget(self, action: #selector(hideLanguagePicker), for: .touchUpInside); h.addSubview(x)
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 5; layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 2, left: 8, bottom: 8, right: 8)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear; cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self; cv.dataSource = self
        cv.register(LanguageCell.self, forCellWithReuseIdentifier: "LanguageCell")
        cv.indicatorStyle = .white; c.addSubview(cv); languageCollectionView = cv
        
        NSLayoutConstraint.activate([
            c.topAnchor.constraint(equalTo: translationContainer.topAnchor, constant: 2),
            c.leadingAnchor.constraint(equalTo: translationContainer.leadingAnchor, constant: 6),
            c.trailingAnchor.constraint(equalTo: translationContainer.trailingAnchor, constant: -6),
            c.bottomAnchor.constraint(equalTo: translationContainer.bottomAnchor, constant: -4),
            h.topAnchor.constraint(equalTo: c.topAnchor), h.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            h.trailingAnchor.constraint(equalTo: c.trailingAnchor), h.heightAnchor.constraint(equalToConstant: 34),
            t.centerYAnchor.constraint(equalTo: h.centerYAnchor), t.leadingAnchor.constraint(equalTo: h.leadingAnchor, constant: 12),
            x.centerYAnchor.constraint(equalTo: h.centerYAnchor), x.trailingAnchor.constraint(equalTo: h.trailingAnchor, constant: -8),
            x.widthAnchor.constraint(equalToConstant: 30), x.heightAnchor.constraint(equalToConstant: 30),
            cv.topAnchor.constraint(equalTo: h.bottomAnchor), cv.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: c.trailingAnchor), cv.bottomAnchor.constraint(equalTo: c.bottomAnchor),
        ])
        
        c.alpha = 0; c.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) { c.alpha = 1; c.transform = .identity }
    }
    
    @objc private func hideLanguagePicker() {
        isLanguagePickerShown = false
        guard let c = languagePickerContainer else { return }
        UIView.animate(withDuration: 0.15, animations: {
            c.alpha = 0; c.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in c.removeFromSuperview(); self.languagePickerContainer = nil; self.languageCollectionView = nil }
    }
}

// MARK: - SpeechTranslationDelegate

extension KeyboardViewController: SpeechTranslationDelegate {
    
    func speechDidStart() {
        if currentMode == .translation {
            updateVoiceButtonState(listening: true)
            inputPreviewLabel.text = "Listening..."
            inputPreviewLabel.textColor = recordingColor
        } else {
            updateTypingMicState(listening: true)
        }
    }
    
    func speechDidRecognize(text: String, isFinal: Bool) {
        recognizedText = text
        
        if currentMode == .translation {
            // Show recognized text in preview
            inputPreviewLabel.text = text
            inputPreviewLabel.textColor = textColor
            
            if isFinal && selectedLanguage.code != "none" {
                // Auto-translate the final result
                translatedPreviewLabel.text = "Translating..."
                translatedPreviewLabel.textColor = accentOrange
                
                translationService.translate(text: text, to: selectedLanguage.code) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        switch result {
                        case .success(let translated):
                            self.translatedPreviewLabel.text = translated
                            self.translatedPreviewLabel.textColor = self.accentGreen
                            // Insert translated text
                            self.textDocumentProxy.insertText(translated)
                        case .failure:
                            self.translatedPreviewLabel.text = text
                            self.translatedPreviewLabel.textColor = self.textColor
                            // Insert original if translation fails
                            self.textDocumentProxy.insertText(text)
                        }
                    }
                }
            } else if isFinal && selectedLanguage.code == "none" {
                // No translation, just insert
                textDocumentProxy.insertText(text)
            }
        } else {
            // Typing mode: insert text directly as recognized
            if isFinal {
                textDocumentProxy.insertText(text + " ")
            }
        }
    }
    
    func speechDidFail(error: String) {
        if currentMode == .translation {
            updateVoiceButtonState(listening: false)
            inputPreviewLabel.text = "Error: \(error)"
            inputPreviewLabel.textColor = recordingColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.inputPreviewLabel.text = "Type, dictate, or tap 🎤 to speak"
                self?.inputPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
            }
        } else {
            updateTypingMicState(listening: false)
        }
    }
    
    func speechDidStop() {
        if currentMode == .translation {
            updateVoiceButtonState(listening: false)
        } else {
            updateTypingMicState(listening: false)
        }
    }
}

// MARK: - Language Collection

extension KeyboardViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { SupportedLanguages.all.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "LanguageCell", for: indexPath) as! LanguageCell
        cell.configure(with: SupportedLanguages.all[indexPath.item], isSelected: SupportedLanguages.all[indexPath.item] == selectedLanguage)
        return cell
    }
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: (cv.bounds.width - 21) / 2, height: 36)
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedLanguage = SupportedLanguages.all[indexPath.item]
        saveLanguagePreference(); updateLanguageButtonTitle()
        let t = readRecentText()
        if !t.isEmpty && selectedLanguage.code != "none" { autoTranslatePreview(t) }
        else {
            translatedPreviewLabel.text = "Translation appears here"
            translatedPreviewLabel.textColor = UIColor(white: 0.40, alpha: 1.0)
        }
        hideLanguagePicker()
    }
}

// MARK: - Language Cell

class LanguageCell: UICollectionViewCell {
    private let flagLabel = UILabel()
    private let nameLabel = UILabel()
    private let checkmark = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1.0)
        contentView.layer.cornerRadius = 8
        flagLabel.font = UIFont.systemFont(ofSize: 16)
        flagLabel.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(flagLabel)
        nameLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium); nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(nameLabel)
        checkmark.text = "✓"; checkmark.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        checkmark.textColor = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
        checkmark.translatesAutoresizingMaskIntoConstraints = false; checkmark.isHidden = true; contentView.addSubview(checkmark)
        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            flagLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 5),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmark.leadingAnchor, constant: -2),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmark.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(with lang: Language, isSelected: Bool) {
        flagLabel.text = lang.flag; nameLabel.text = lang.name; checkmark.isHidden = !isSelected
        contentView.backgroundColor = isSelected ? UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.3) : UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1.0)
        contentView.layer.borderWidth = isSelected ? 1 : 0
        contentView.layer.borderColor = isSelected ? UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.5).cgColor : nil
    }
}
