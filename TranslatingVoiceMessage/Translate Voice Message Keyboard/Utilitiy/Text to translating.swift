////
////  KeyboardViewController.swift
////  Translate Voice Message Keyboard
////
////  Created by Tipu Sultan on 3/30/26.
////
//
//import UIKit
//
//class KeyboardViewController: UIInputViewController {
//
//    private var previewLabel: UILabel!
//    private var translateButton: UIButton!
//    private var languageButton: UIButton!
//    private var tableView: UITableView!
//
//    var selectedLanguage = "en"
//    var isDropdownVisible = false
//
//    let languages: [(name: String, code: String)] = [
//        ("Auto Detect 🌐", "auto"),
//        ("English 🇺🇸", "en"),
//        ("Bengali 🇧🇩", "bn"),
//        ("Hindi 🇮🇳", "hi"),
//        ("Arabic 🇸🇦", "ar"),
//        ("Spanish 🇪🇸", "es"),
//        ("French 🇫🇷", "fr"),
//        ("German 🇩🇪", "de"),
//        ("Chinese 🇨🇳", "zh"),
//        ("Japanese 🇯🇵", "ja"),
//        ("Korean 🇰🇷", "ko"),
//        ("Russian 🇷🇺", "ru"),
//        ("Portuguese 🇵🇹", "pt"),
//        ("Italian 🇮🇹", "it"),
//        ("Turkish 🇹🇷", "tr"),
//        ("Dutch 🇳🇱", "nl"),
//        ("Polish 🇵🇱", "pl"),
//        ("Swedish 🇸🇪", "sv"),
//        ("Danish 🇩🇰", "da"),
//        ("Finnish 🇫🇮", "fi"),
//        ("Norwegian 🇳🇴", "no"),
//        ("Greek 🇬🇷", "el"),
//        ("Hebrew 🇮🇱", "he"),
//        ("Thai 🇹🇭", "th"),
//        ("Vietnamese 🇻🇳", "vi"),
//        ("Indonesian 🇮🇩", "id"),
//        ("Malay 🇲🇾", "ms"),
//        ("Filipino 🇵🇭", "tl"),
//        ("Czech 🇨🇿", "cs"),
//        ("Hungarian 🇭🇺", "hu"),
//        ("Romanian 🇷🇴", "ro"),
//        ("Ukrainian 🇺🇦", "uk"),
//        ("Slovak 🇸🇰", "sk"),
//        ("Bulgarian 🇧🇬", "bg"),
//        ("Croatian 🇭🇷", "hr"),
//        ("Serbian 🇷🇸", "sr"),
//        ("Slovenian 🇸🇮", "sl"),
//        ("Estonian 🇪🇪", "et"),
//        ("Latvian 🇱🇻", "lv"),
//        ("Lithuanian 🇱🇹", "lt"),
//        ("Persian 🇮🇷", "fa"),
//        ("Urdu 🇵🇰", "ur"),
//        ("Punjabi 🇮🇳", "pa"),
//        ("Tamil 🇮🇳", "ta"),
//        ("Telugu 🇮🇳", "te"),
//        ("Gujarati 🇮🇳", "gu"),
//        ("Marathi 🇮🇳", "mr"),
//        ("Kannada 🇮🇳", "kn"),
//        ("Malayalam 🇮🇳", "ml"),
//        ("Sinhala 🇱🇰", "si"),
//        ("Nepali 🇳🇵", "ne"),
//        ("Khmer 🇰🇭", "km"),
//        ("Lao 🇱🇦", "lo"),
//        ("Mongolian 🇲🇳", "mn"),
//        ("Swahili 🌍", "sw"),
//        ("Zulu 🇿🇦", "zu"),
//        ("Afrikaans 🇿🇦", "af"),
//        ("Icelandic 🇮🇸", "is"),
//        ("Irish 🇮🇪", "ga"),
//        ("Welsh 🏴", "cy"),
//        ("Basque 🇪🇸", "eu"),
//        ("Catalan 🇪🇸", "ca"),
//        ("Galician 🇪🇸", "gl"),
//        ("Esperanto 🌐", "eo")
//    ]
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupHeight()
//        setupUI()
//    }
//
//    // ✅ VERY IMPORTANT (fix hidden UI issue)
//    func setupHeight() {
//        view.translatesAutoresizingMaskIntoConstraints = false
//        view.heightAnchor.constraint(equalToConstant: 260).isActive = true
//    }
//
//    func setupUI() {
//        view.backgroundColor = .systemGroupedBackground
//
//        // 🌍 Language Button (Pill Style)
//        languageButton = UIButton(type: .system)
//        languageButton.setTitle("🌍 English 🇺🇸", for: .normal)
//        languageButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
//        languageButton.backgroundColor = .secondarySystemBackground
//        languageButton.layer.cornerRadius = 20
//        languageButton.translatesAutoresizingMaskIntoConstraints = false
//        languageButton.addTarget(self, action: #selector(toggleDropdown), for: .touchUpInside)
//
//        // 📝 Preview (MAIN FOCUS)
//        previewLabel = UILabel()
//        previewLabel.text = "Translation will appear here..."
//        previewLabel.numberOfLines = 0
//        previewLabel.font = .systemFont(ofSize: 15)
//        previewLabel.textAlignment = .left
//        previewLabel.textColor = .label
//        previewLabel.translatesAutoresizingMaskIntoConstraints = false
//        previewLabel.applyCardStyle()
//        previewLabel.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
//
//        // 🔁 Translate Button (CTA STYLE)
//        translateButton = UIButton(type: .system)
//        translateButton.setTitle("Translate 🌐", for: .normal)
//        translateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
//        translateButton.backgroundColor = .systemBlue
//        translateButton.setTitleColor(.white, for: .normal)
//        translateButton.layer.cornerRadius = 14
//        translateButton.translatesAutoresizingMaskIntoConstraints = false
//        translateButton.addTarget(self, action: #selector(handleTranslate), for: .touchUpInside)
//
//        // 📋 Dropdown Table (Floating Card)
//        tableView = UITableView()
//        tableView.isHidden = true
//        tableView.layer.cornerRadius = 16
//        tableView.layer.masksToBounds = true
//        tableView.applyCardStyle()
//        tableView.delegate = self
//        tableView.dataSource = self
//        tableView.translatesAutoresizingMaskIntoConstraints = false
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
//
//        view.addSubview(languageButton)
//        view.addSubview(previewLabel)
//        view.addSubview(translateButton)
//        view.addSubview(tableView)
//
//        NSLayoutConstraint.activate([
//            // 🌍 Language
//            languageButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
//            languageButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
//            languageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
//            languageButton.heightAnchor.constraint(equalToConstant: 40),
//
//            // 📝 Preview
//            previewLabel.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 10),
//            previewLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
//            previewLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
//
//            // 🔁 Button
//            translateButton.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 10),
//            translateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
//            translateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
//            translateButton.heightAnchor.constraint(equalToConstant: 44),
//
//            translateButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
//
//            // 📋 Dropdown
//            tableView.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 6),
//            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
//            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
//            tableView.heightAnchor.constraint(equalToConstant: 180),
//        ])
//    }
//
//    // MARK: - Actions
//
//    @objc func handleTranslate() {
//
//        guard let text = textDocumentProxy.documentContextBeforeInput,
//              !text.isEmpty else {
//            previewLabel.text = "⚠️ No text to translate"
//            return
//        }
//
//        previewLabel.text = "🌍 Translating..."
//
//        translate(text: text, target: selectedLanguage) { translated in
//            DispatchQueue.main.async {
//                self.previewLabel.text = translated
//                self.replaceText(with: translated)
//            }
//        }
//    }
//
//    @objc func toggleDropdown() {
//        isDropdownVisible.toggle()
//        tableView.isHidden = !isDropdownVisible
//        translateButton.isHidden = isDropdownVisible // cleaner UI
//    }
//}
//
//// MARK: - TableView
//
//extension KeyboardViewController: UITableViewDelegate, UITableViewDataSource {
//
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        languages.count
//    }
//
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//
//        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
//        cell.textLabel?.text = languages[indexPath.row].name
//        cell.textLabel?.font = .systemFont(ofSize: 14)
//        return cell
//    }
//
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//
//        let selected = languages[indexPath.row]
//        selectedLanguage = selected.code
//
//        languageButton.setTitle("🌍 \(selected.name)", for: .normal)
//
//        tableView.isHidden = true
//        translateButton.isHidden = false
//        isDropdownVisible = false
//    }
//}
//
//// MARK: - Translation
//extension KeyboardViewController {
//
//    func translate(text: String, target: String, completion: @escaping (String) -> Void) {
//
//        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
//
//        //let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(target)&dt=t&q=\(encoded)"
//
//        let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(target)&dt=t&q=\(encoded)"
//
//        guard let url = URL(string: urlString) else {
//            completion(text)
//            return
//        }
//
//        URLSession.shared.dataTask(with: url) { data, _, error in
//
//            if let error = error {
//                print("❌ Error:", error)
//                completion(text)
//                return
//            }
//
//            guard let data = data,
//                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
//                  let firstArray = json.first as? [[Any]],
//                  let translated = firstArray.first?.first as? String else {
//
//                print("❌ Parse failed")
//                completion(text)
//                return
//            }
//
//            completion(translated)
//
//        }.resume()
//    }
//}
//
//// MARK: - Replace Text
//extension KeyboardViewController {
//
//    func replaceText(with newText: String) {
//
//        guard let existing = textDocumentProxy.documentContextBeforeInput else {
//            textDocumentProxy.insertText(newText)
//            return
//        }
//
//        for _ in existing {
//            textDocumentProxy.deleteBackward()
//        }
//
//        textDocumentProxy.insertText(newText)
//    }
//}
//
//extension UIView {
//    func applyCardStyle() {
//        self.backgroundColor = .secondarySystemBackground
//        self.layer.cornerRadius = 16
//        self.layer.shadowColor = UIColor.black.cgColor
//        self.layer.shadowOpacity = 0.08
//        self.layer.shadowOffset = CGSize(width: 0, height: 4)
//        self.layer.shadowRadius = 8
//    }
//}
//
