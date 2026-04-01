//
//  TranslationService.swift
//  VoiceKeyboard
//
//  Translates text between languages using the MyMemory Translation API.
//  Free tier: up to 5000 chars/day without an API key.
//  https://mymemory.translated.net/doc/spec.php
//

import Foundation

// MARK: - Language Model

struct Language: Equatable {
    let code: String      // ISO 639-1 code (e.g. "en", "es")
    let name: String      // Display name (e.g. "English", "Spanish")
    let flag: String      // Emoji flag
    let nativeName: String // Name in native script
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        return lhs.code == rhs.code
    }
}

// MARK: - All Supported Languages

struct SupportedLanguages {
    static let all: [Language] = [
        // No translation option
        Language(code: "none", name: "No Translation", flag: "🔤", nativeName: "Original"),
        
        // Major world languages
        Language(code: "en", name: "English", flag: "🇺🇸", nativeName: "English"),
        Language(code: "es", name: "Spanish", flag: "🇪🇸", nativeName: "Español"),
        Language(code: "fr", name: "French", flag: "🇫🇷", nativeName: "Français"),
        Language(code: "de", name: "German", flag: "🇩🇪", nativeName: "Deutsch"),
        Language(code: "it", name: "Italian", flag: "🇮🇹", nativeName: "Italiano"),
        Language(code: "pt", name: "Portuguese", flag: "🇵🇹", nativeName: "Português"),
        Language(code: "ru", name: "Russian", flag: "🇷🇺", nativeName: "Русский"),
        Language(code: "ja", name: "Japanese", flag: "🇯🇵", nativeName: "日本語"),
        Language(code: "ko", name: "Korean", flag: "🇰🇷", nativeName: "한국어"),
        Language(code: "zh", name: "Chinese", flag: "🇨🇳", nativeName: "中文"),
        Language(code: "ar", name: "Arabic", flag: "🇸🇦", nativeName: "العربية"),
        Language(code: "hi", name: "Hindi", flag: "🇮🇳", nativeName: "हिन्दी"),
        Language(code: "bn", name: "Bengali", flag: "🇧🇩", nativeName: "বাংলা"),
        Language(code: "ur", name: "Urdu", flag: "🇵🇰", nativeName: "اردو"),
        Language(code: "tr", name: "Turkish", flag: "🇹🇷", nativeName: "Türkçe"),
        Language(code: "vi", name: "Vietnamese", flag: "🇻🇳", nativeName: "Tiếng Việt"),
        Language(code: "th", name: "Thai", flag: "🇹🇭", nativeName: "ภาษาไทย"),
        Language(code: "nl", name: "Dutch", flag: "🇳🇱", nativeName: "Nederlands"),
        Language(code: "pl", name: "Polish", flag: "🇵🇱", nativeName: "Polski"),
        Language(code: "sv", name: "Swedish", flag: "🇸🇪", nativeName: "Svenska"),
        Language(code: "da", name: "Danish", flag: "🇩🇰", nativeName: "Dansk"),
        Language(code: "fi", name: "Finnish", flag: "🇫🇮", nativeName: "Suomi"),
        Language(code: "no", name: "Norwegian", flag: "🇳🇴", nativeName: "Norsk"),
        Language(code: "cs", name: "Czech", flag: "🇨🇿", nativeName: "Čeština"),
        Language(code: "sk", name: "Slovak", flag: "🇸🇰", nativeName: "Slovenčina"),
        Language(code: "ro", name: "Romanian", flag: "🇷🇴", nativeName: "Română"),
        Language(code: "hu", name: "Hungarian", flag: "🇭🇺", nativeName: "Magyar"),
        Language(code: "el", name: "Greek", flag: "🇬🇷", nativeName: "Ελληνικά"),
        Language(code: "bg", name: "Bulgarian", flag: "🇧🇬", nativeName: "Български"),
        Language(code: "hr", name: "Croatian", flag: "🇭🇷", nativeName: "Hrvatski"),
        Language(code: "sr", name: "Serbian", flag: "🇷🇸", nativeName: "Српски"),
        Language(code: "sl", name: "Slovenian", flag: "🇸🇮", nativeName: "Slovenščina"),
        Language(code: "uk", name: "Ukrainian", flag: "🇺🇦", nativeName: "Українська"),
        Language(code: "lt", name: "Lithuanian", flag: "🇱🇹", nativeName: "Lietuvių"),
        Language(code: "lv", name: "Latvian", flag: "🇱🇻", nativeName: "Latviešu"),
        Language(code: "et", name: "Estonian", flag: "🇪🇪", nativeName: "Eesti"),
        Language(code: "id", name: "Indonesian", flag: "🇮🇩", nativeName: "Bahasa Indonesia"),
        Language(code: "ms", name: "Malay", flag: "🇲🇾", nativeName: "Bahasa Melayu"),
        Language(code: "tl", name: "Filipino", flag: "🇵🇭", nativeName: "Filipino"),
        Language(code: "sw", name: "Swahili", flag: "🇰🇪", nativeName: "Kiswahili"),
        Language(code: "fa", name: "Persian", flag: "🇮🇷", nativeName: "فارسی"),
        Language(code: "he", name: "Hebrew", flag: "🇮🇱", nativeName: "עברית"),
        Language(code: "ta", name: "Tamil", flag: "🇱🇰", nativeName: "தமிழ்"),
        Language(code: "te", name: "Telugu", flag: "🇮🇳", nativeName: "తెలుగు"),
        Language(code: "mr", name: "Marathi", flag: "🇮🇳", nativeName: "मराठी"),
        Language(code: "gu", name: "Gujarati", flag: "🇮🇳", nativeName: "ગુજરાતી"),
        Language(code: "kn", name: "Kannada", flag: "🇮🇳", nativeName: "ಕನ್ನಡ"),
        Language(code: "ml", name: "Malayalam", flag: "🇮🇳", nativeName: "മലയാളം"),
        Language(code: "pa", name: "Punjabi", flag: "🇮🇳", nativeName: "ਪੰਜਾਬੀ"),
        Language(code: "my", name: "Burmese", flag: "🇲🇲", nativeName: "မြန်မာ"),
        Language(code: "km", name: "Khmer", flag: "🇰🇭", nativeName: "ភាសាខ្មែរ"),
        Language(code: "ne", name: "Nepali", flag: "🇳🇵", nativeName: "नेपाली"),
        Language(code: "si", name: "Sinhala", flag: "🇱🇰", nativeName: "සිංහල"),
        Language(code: "ka", name: "Georgian", flag: "🇬🇪", nativeName: "ქართული"),
        Language(code: "hy", name: "Armenian", flag: "🇦🇲", nativeName: "Հայերեն"),
        Language(code: "az", name: "Azerbaijani", flag: "🇦🇿", nativeName: "Azərbaycan"),
        Language(code: "uz", name: "Uzbek", flag: "🇺🇿", nativeName: "Oʻzbek"),
        Language(code: "kk", name: "Kazakh", flag: "🇰🇿", nativeName: "Қазақ"),
        Language(code: "mn", name: "Mongolian", flag: "🇲🇳", nativeName: "Монгол"),
        Language(code: "af", name: "Afrikaans", flag: "🇿🇦", nativeName: "Afrikaans"),
        Language(code: "sq", name: "Albanian", flag: "🇦🇱", nativeName: "Shqip"),
        Language(code: "eu", name: "Basque", flag: "🇪🇸", nativeName: "Euskara"),
        Language(code: "ca", name: "Catalan", flag: "🇪🇸", nativeName: "Català"),
        Language(code: "gl", name: "Galician", flag: "🇪🇸", nativeName: "Galego"),
        Language(code: "is", name: "Icelandic", flag: "🇮🇸", nativeName: "Íslenska"),
        Language(code: "mk", name: "Macedonian", flag: "🇲🇰", nativeName: "Македонски"),
        Language(code: "mt", name: "Maltese", flag: "🇲🇹", nativeName: "Malti"),
    ]
}

// MARK: - Translation Service

class TranslationService {
    
    /// Detect the source language of text using simple heuristics
    /// In production, you'd use NaturalLanguage framework or API detection
    private func detectSourceLanguage(for text: String) -> String {
        // Default to English for now
        // AssemblyAI transcribes in the spoken language, so we detect from script
        let tagScheme = NSLinguisticTagger.dominantLanguage(for: text)
        return tagScheme ?? "en"
    }
    
    /// Translate text from source to target language
    /// Uses MyMemory Translation API (free, no key required)
    func translate(
        text: String,
        from sourceLanguage: String? = nil,
        to targetLanguage: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.success(""))
            return
        }
        
        // Skip if target is "none" (no translation)
        guard targetLanguage != "none" else {
            completion(.success(text))
            return
        }
        
        let sourceLang = sourceLanguage ?? detectSourceLanguage(for: text)
        
        // Skip if source == target
        guard sourceLang != targetLanguage else {
            completion(.success(text))
            return
        }
        
        NSLog("[VoiceKB-Trans] Translating: '%@' from %@ to %@", text, sourceLang, targetLanguage)
        
        // Build MyMemory API URL
        let langPair = "\(sourceLang)|\(targetLanguage)"
        
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPair = langPair.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(encodedPair)")
        else {
            completion(.failure(NSError(domain: "Translation", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                NSLog("[VoiceKB-Trans] ❌ Network error: %@", error.localizedDescription)
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "Translation", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseData = json["responseData"] as? [String: Any],
                   let translatedText = responseData["translatedText"] as? String {
                    
                    NSLog("[VoiceKB-Trans] ✅ Translated: '%@'", translatedText)
                    completion(.success(translatedText))
                } else {
                    NSLog("[VoiceKB-Trans] ❌ Unexpected response format")
                    completion(.failure(NSError(domain: "Translation", code: -3,
                                                userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                }
            } catch {
                NSLog("[VoiceKB-Trans] ❌ JSON parse error: %@", error.localizedDescription)
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}
