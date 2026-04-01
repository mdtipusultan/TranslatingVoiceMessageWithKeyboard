//
//  KeyboardViewController.swift
//  VoiceKeyboard
//
//  iOS Keyboard Extension — Translation Keyboard
//  Features:
//    - User types or uses iOS dictation to input text
//    - Tap "Translate" to translate typed text to selected language
//    - 65+ language options with country flags
//    - Translated text replaces original in the text field
//

import UIKit

class KeyboardViewController: UIInputViewController {
    
    // MARK: - UI Elements
    
    private var keyboardView: UIView!
    private var languageButton: UIButton!
    private var languagePickerContainer: UIView?
    private var languageCollectionView: UICollectionView?
    
    /// Text preview showing what user typed + translation
    private var inputPreviewLabel: UILabel!
    private var translatedPreviewLabel: UILabel!
    
    /// Action buttons
    private var translateButton: UIButton!
    private var backspaceButton: UIButton!
    private var spaceButton: UIButton!
    private var returnButton: UIButton!
    
    // MARK: - Services
    
    private var translationService: TranslationService!
    
    // MARK: - State
    
    private var isLanguagePickerShown = false
    private var selectedLanguage: Language = SupportedLanguages.all[0]
    private var lastTranslatedText = ""
    
    /// Track text changes for auto-translate
    private var previousDocumentText = ""
    private var autoTranslateTimer: Timer?
    
    // MARK: - Colors
    
    private let primaryColor = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0)
    private let darkBgColor = UIColor(red: 0.12, green: 0.13, blue: 0.17, alpha: 1.0)
    private let cardBgColor = UIColor(red: 0.17, green: 0.18, blue: 0.23, alpha: 1.0)
    private let buttonColor = UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1.0)
    private let accentGreen = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
    private let accentOrange = UIColor(red: 0.95, green: 0.62, blue: 0.22, alpha: 1.0)
    private let textColor = UIColor.white
    private let secondaryTextColor = UIColor(white: 0.55, alpha: 1.0)
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadLanguagePreference()
        translationService = TranslationService()
        setupUI()
    }
    
    // MARK: - Language Persistence
    
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
        view.isUserInteractionEnabled = true
        inputView?.isUserInteractionEnabled = true
        
        keyboardView = UIView()
        keyboardView.backgroundColor = darkBgColor
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.isUserInteractionEnabled = true
        view.addSubview(keyboardView)
        
        let hc = keyboardView.heightAnchor.constraint(equalToConstant: 260)
        hc.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hc
        ])
        
        setupLanguageSelector()
        setupPreviewArea()
        setupTranslateButton()
        setupUtilityButtons()
    }
    
    // MARK: - Language Selector
    
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
        
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let chevron = UIImage(systemName: "chevron.down", withConfiguration: chevConfig)
        languageButton.setImage(chevron?.withRenderingMode(.alwaysTemplate), for: .normal)
        languageButton.tintColor = secondaryTextColor
        languageButton.semanticContentAttribute = .forceRightToLeft
        languageButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        languageButton.addTarget(self, action: #selector(languageButtonTapped), for: .touchUpInside)
        
        keyboardView.addSubview(languageButton)
        
        NSLayoutConstraint.activate([
            languageButton.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 8),
            languageButton.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            languageButton.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            languageButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }
    
    private func updateLanguageButtonTitle() {
        if selectedLanguage.code == "none" {
            languageButton.setTitle("🔤  No translation selected", for: .normal)
        } else {
            languageButton.setTitle("\(selectedLanguage.flag)  Translate to: \(selectedLanguage.name)", for: .normal)
        }
    }
    
    // MARK: - Preview Area
    
    private func setupPreviewArea() {
        // Container for the preview text
        let previewContainer = UIView()
        previewContainer.backgroundColor = cardBgColor
        previewContainer.layer.cornerRadius = 12
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(previewContainer)
        
        // "Original" section
        let originalLabel = UILabel()
        originalLabel.text = "ORIGINAL"
        originalLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        originalLabel.textColor = secondaryTextColor
        originalLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(originalLabel)
        
        inputPreviewLabel = UILabel()
        inputPreviewLabel.text = "Type or dictate, then tap Translate"
        inputPreviewLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        inputPreviewLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        inputPreviewLabel.numberOfLines = 2
        inputPreviewLabel.lineBreakMode = .byTruncatingTail
        inputPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(inputPreviewLabel)
        
        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        separator.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(separator)
        
        // "Translated" section
        let translatedLabel = UILabel()
        translatedLabel.text = "TRANSLATED"
        translatedLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        translatedLabel.textColor = accentGreen.withAlphaComponent(0.7)
        translatedLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(translatedLabel)
        
        translatedPreviewLabel = UILabel()
        translatedPreviewLabel.text = "Translation will appear here"
        translatedPreviewLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        translatedPreviewLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        translatedPreviewLabel.numberOfLines = 2
        translatedPreviewLabel.lineBreakMode = .byTruncatingTail
        translatedPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(translatedPreviewLabel)
        
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 6),
            previewContainer.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            previewContainer.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            
            originalLabel.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 8),
            originalLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            
            inputPreviewLabel.topAnchor.constraint(equalTo: originalLabel.bottomAnchor, constant: 2),
            inputPreviewLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            inputPreviewLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            
            separator.topAnchor.constraint(equalTo: inputPreviewLabel.bottomAnchor, constant: 6),
            separator.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            translatedLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 6),
            translatedLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            
            translatedPreviewLabel.topAnchor.constraint(equalTo: translatedLabel.bottomAnchor, constant: 2),
            translatedPreviewLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            translatedPreviewLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            translatedPreviewLabel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -8),
        ])
    }
    
    // MARK: - Translate Button
    
    private func setupTranslateButton() {
        translateButton = UIButton(type: .custom)
        translateButton.translatesAutoresizingMaskIntoConstraints = false
        translateButton.backgroundColor = primaryColor
        translateButton.layer.cornerRadius = 10
        translateButton.setTitle("Translate & Replace", for: .normal)
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        let transIcon = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        translateButton.setImage(transIcon?.withRenderingMode(.alwaysTemplate), for: .normal)
        translateButton.tintColor = .white
        translateButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        
        translateButton.layer.shadowColor = primaryColor.cgColor
        translateButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        translateButton.layer.shadowRadius = 8
        translateButton.layer.shadowOpacity = 0.3
        
        translateButton.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        keyboardView.addSubview(translateButton)
        
        NSLayoutConstraint.activate([
            translateButton.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            translateButton.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            translateButton.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -52),
            translateButton.heightAnchor.constraint(equalToConstant: 42),
        ])
    }
    
    // MARK: - Utility Buttons
    
    private func setupUtilityButtons() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(stack)
        
        backspaceButton = makeButton(icon: "delete.left.fill", title: nil, action: #selector(backspaceTapped))
        stack.addArrangedSubview(backspaceButton)
        
        spaceButton = makeButton(icon: nil, title: "space", action: #selector(spaceTapped))
        stack.addArrangedSubview(spaceButton)
        
        returnButton = makeButton(icon: "return", title: nil, action: #selector(returnTapped))
        stack.addArrangedSubview(returnButton)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalToConstant: 38),
        ])
    }
    
    private func makeButton(icon: String?, title: String?, action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = buttonColor
        btn.layer.cornerRadius = 8
        btn.tintColor = textColor
        if let icon = icon {
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            btn.setImage(UIImage(systemName: icon, withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        if let title = title {
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(textColor, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    // MARK: - Text Change Detection
    
    override func textWillChange(_ textInput: UITextInput?) {}
    
    override func textDidChange(_ textInput: UITextInput?) {
        // Read current text from the document
        let currentText = readRecentText()
        
        if !currentText.isEmpty && currentText != previousDocumentText {
            previousDocumentText = currentText
            
            // Update the original preview
            inputPreviewLabel.text = currentText
            inputPreviewLabel.textColor = textColor
            
            // Auto-translate with debounce (wait for user to stop typing)
            autoTranslateTimer?.invalidate()
            
            if selectedLanguage.code != "none" {
                translatedPreviewLabel.text = "Translating..."
                translatedPreviewLabel.textColor = accentOrange
                
                autoTranslateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    self?.autoTranslatePreview(currentText)
                }
            }
        }
        
        if currentText.isEmpty {
            inputPreviewLabel.text = "Type or dictate, then tap Translate"
            inputPreviewLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
            translatedPreviewLabel.text = "Translation will appear here"
            translatedPreviewLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
        }
    }
    
    /// Read recent text from the text field (up to ~200 chars before cursor)
    private func readRecentText() -> String {
        guard let proxy = textDocumentProxy as? UITextDocumentProxy else { return "" }
        
        // Get text before cursor
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        
        // Get the last paragraph/line (text after last newline)
        let fullText = before + after
        
        // Get last meaningful chunk (last line or last 200 chars)
        if let lastNewline = before.lastIndex(of: "\n") {
            let lastLine = String(before[before.index(after: lastNewline)...])
            return lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // No newline — just use what's before the cursor
        return before.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Auto-translate for the preview (doesn't modify text)
    private func autoTranslatePreview(_ text: String) {
        guard selectedLanguage.code != "none" else { return }
        
        translationService.translate(text: text, to: selectedLanguage.code) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let translated):
                    self?.translatedPreviewLabel.text = translated
                    self?.translatedPreviewLabel.textColor = self?.accentGreen ?? .green
                    self?.lastTranslatedText = translated
                case .failure:
                    self?.translatedPreviewLabel.text = "Translation failed"
                    self?.translatedPreviewLabel.textColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func translateTapped() {
        if isLanguagePickerShown { hideLanguagePicker() }
        
        guard selectedLanguage.code != "none" else {
            translatedPreviewLabel.text = "Select a language first"
            translatedPreviewLabel.textColor = accentOrange
            return
        }
        
        let textToTranslate = readRecentText()
        
        guard !textToTranslate.isEmpty else {
            translatedPreviewLabel.text = "Type something to translate"
            translatedPreviewLabel.textColor = accentOrange
            return
        }
        
        // Show translating state
        translateButton.setTitle("Translating...", for: .normal)
        translateButton.backgroundColor = accentOrange
        translateButton.isEnabled = false
        
        // Animate button
        UIView.animate(withDuration: 0.08, animations: {
            self.translateButton.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                self.translateButton.transform = .identity
            }
        }
        
        translationService.translate(text: textToTranslate, to: selectedLanguage.code) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Reset button
                self.translateButton.setTitle("Translate & Replace", for: .normal)
                self.translateButton.backgroundColor = self.primaryColor
                self.translateButton.isEnabled = true
                
                switch result {
                case .success(let translated):
                    // Delete the original text
                    self.deleteCurrentLineText()
                    
                    // Insert translated text
                    self.textDocumentProxy.insertText(translated)
                    
                    // Update preview
                    self.translatedPreviewLabel.text = translated
                    self.translatedPreviewLabel.textColor = self.accentGreen
                    self.inputPreviewLabel.text = textToTranslate
                    
                    // Brief success animation
                    UIView.animate(withDuration: 0.15) {
                        self.translateButton.backgroundColor = self.accentGreen
                    }
                    UIView.animate(withDuration: 0.3, delay: 0.5) {
                        self.translateButton.backgroundColor = self.primaryColor
                    }
                    
                case .failure(let error):
                    self.translatedPreviewLabel.text = "Error: \(error.localizedDescription)"
                    self.translatedPreviewLabel.textColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
                }
            }
        }
    }
    
    /// Delete the current line's text (text before cursor until newline or start)
    private func deleteCurrentLineText() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        
        var charsToDelete: Int
        if let lastNewline = before.lastIndex(of: "\n") {
            charsToDelete = before.distance(from: before.index(after: lastNewline), to: before.endIndex)
        } else {
            charsToDelete = before.count
        }
        
        for _ in 0..<charsToDelete {
            textDocumentProxy.deleteBackward()
        }
    }
    
    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
    }
    
    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }
    
    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }
    
    // MARK: - Language Picker
    
    @objc private func languageButtonTapped() {
        isLanguagePickerShown ? hideLanguagePicker() : showLanguagePicker()
    }
    
    private func showLanguagePicker() {
        isLanguagePickerShown = true
        
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        keyboardView.addSubview(container)
        languagePickerContainer = container
        
        // Header
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        
        let title = UILabel()
        title.text = "🌐 Select Language"
        title.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        title.textColor = textColor
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)
        
        let close = UIButton(type: .custom)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(secondaryTextColor, for: .normal)
        close.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(hideLanguagePicker), for: .touchUpInside)
        header.addSubview(close)
        
        // Collection view
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 2, left: 8, bottom: 8, right: 8)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(LanguageCell.self, forCellWithReuseIdentifier: "LanguageCell")
        cv.showsVerticalScrollIndicator = true
        cv.indicatorStyle = .white
        container.addSubview(cv)
        languageCollectionView = cv
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 4),
            container.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 6),
            container.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -6),
            container.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -4),
            
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 34),
            
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            close.widthAnchor.constraint(equalToConstant: 30),
            close.heightAnchor.constraint(equalToConstant: 30),
            
            cv.topAnchor.constraint(equalTo: header.bottomAnchor),
            cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            container.alpha = 1
            container.transform = .identity
        }
    }
    
    @objc private func hideLanguagePicker() {
        isLanguagePickerShown = false
        guard let container = languagePickerContainer else { return }
        UIView.animate(withDuration: 0.15, animations: {
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            container.removeFromSuperview()
            self.languagePickerContainer = nil
            self.languageCollectionView = nil
        }
    }
}

// MARK: - Language Collection View

extension KeyboardViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return SupportedLanguages.all.count
    }
    
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "LanguageCell", for: indexPath) as! LanguageCell
        let lang = SupportedLanguages.all[indexPath.item]
        cell.configure(with: lang, isSelected: lang == selectedLanguage)
        return cell
    }
    
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (cv.bounds.width - 21) / 2
        return CGSize(width: width, height: 36)
    }
    
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedLanguage = SupportedLanguages.all[indexPath.item]
        saveLanguagePreference()
        updateLanguageButtonTitle()
        
        // Re-translate preview with new language
        let currentText = readRecentText()
        if !currentText.isEmpty && selectedLanguage.code != "none" {
            autoTranslatePreview(currentText)
        } else {
            translatedPreviewLabel.text = "Translation will appear here"
            translatedPreviewLabel.textColor = UIColor(white: 0.45, alpha: 1.0)
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
        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(flagLabel)
        
        nameLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        checkmark.text = "✓"
        checkmark.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        checkmark.textColor = UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1.0)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true
        contentView.addSubview(checkmark)
        
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
    
    func configure(with language: Language, isSelected: Bool) {
        flagLabel.text = language.flag
        nameLabel.text = language.name
        checkmark.isHidden = !isSelected
        
        if isSelected {
            contentView.backgroundColor = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.3)
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 0.5).cgColor
        } else {
            contentView.backgroundColor = UIColor(red: 0.22, green: 0.24, blue: 0.31, alpha: 1.0)
            contentView.layer.borderWidth = 0
        }
    }
}
