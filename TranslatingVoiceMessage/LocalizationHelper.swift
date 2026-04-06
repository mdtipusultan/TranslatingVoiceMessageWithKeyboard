// ============================================================
//  LocalizationHelper.swift
//  TranslatingVoiceMessage
//
//  Drop this file into your project (and all targets that need it).
//  It gives you:
//    • A simple NSLocalizedString wrapper
//    • Typed keys (compile-time safety)
//    • A convenient format helper
// ============================================================

import Foundation

// MARK: - Top-level shorthand

/// Shorthand: L("voice.title")
@inline(__always)
func L(_ key: LocalizedKey) -> String {
    NSLocalizedString(key.rawValue, comment: "")
}

/// Shorthand with format args: L(.voice_translating, "French")
@inline(__always)
func L(_ key: LocalizedKey, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key.rawValue, comment: ""), arguments: args)
}

// MARK: - All Localized Keys

enum LocalizedKey: String {

    // ── Tab Bar ──────────────────────────────────────────────
    case tab_translate  = "tab.translate"
    case tab_keyboard   = "tab.keyboard"
    case tab_settings   = "tab.settings"

    // ── Voice Translation View ───────────────────────────────
    case voice_title                = "voice.title"
    case voice_subtitle             = "voice.subtitle"
    case voice_status_tap_to_start  = "voice.status.tap_to_start"
    case voice_status_listening     = "voice.status.listening"
    case voice_status_tap_to_record = "voice.status.tap_to_record"
    case voice_banner_from_keyboard = "voice.banner.from_keyboard"
    case voice_label_original       = "voice.label.original"
    case voice_label_translated     = "voice.label.translated"
    case voice_placeholder_speech   = "voice.placeholder.speech"
    case voice_placeholder_translation = "voice.placeholder.translation"
    case voice_translating          = "voice.translating"       // 1 arg: language name
    case voice_copy_translation     = "voice.copy_translation"
    case voice_copied               = "voice.copied"
    case voice_translate_to         = "voice.translate_to"      // 1 arg: language name
    case voice_clear                = "voice.clear"
    case voice_translate_to_label   = "voice.translate_to_label"

    // ── Language Picker ──────────────────────────────────────
    case picker_title = "picker.title"
    case picker_close = "picker.close"

    // ── Settings ─────────────────────────────────────────────
    case settings_title                     = "settings.title"
    case settings_subtitle                  = "settings.subtitle"
    case settings_app_name                  = "settings.app_name"
    case settings_version                   = "settings.version"
    case settings_section_features          = "settings.section.features"
    case settings_section_translation       = "settings.section.translation"
    case settings_section_help              = "settings.section.help"
    case settings_feature_voice             = "settings.feature.voice"
    case settings_feature_voice_sub         = "settings.feature.voice_sub"
    case settings_feature_keyboard          = "settings.feature.keyboard"
    case settings_feature_keyboard_sub      = "settings.feature.keyboard_sub"
    case settings_feature_share             = "settings.feature.share"
    case settings_feature_share_sub         = "settings.feature.share_sub"
    case settings_info_languages            = "settings.info.languages"
    case settings_info_languages_value      = "settings.info.languages_value"
    case settings_info_speech_engine        = "settings.info.speech_engine"
    case settings_info_speech_engine_value  = "settings.info.speech_engine_value"
    case settings_info_translation_api      = "settings.info.translation_api"
    case settings_info_translation_api_value = "settings.info.translation_api_value"
    case settings_help_system_settings      = "settings.help.system_settings"
    case settings_help_how_to_use           = "settings.help.how_to_use"
    case settings_footer                    = "settings.footer"

    // ── Permission / Keyboard Setup ──────────────────────────
    case permission_title       = "permission.title"
    case permission_subtitle    = "permission.subtitle"
    case permission_step1_title = "permission.step1.title"
    case permission_step1_sub   = "permission.step1.sub"
    case permission_step2_title = "permission.step2.title"
    case permission_step2_sub   = "permission.step2.sub"
    case permission_step3_title = "permission.step3.title"
    case permission_step3_sub   = "permission.step3.sub"
    case permission_cta         = "permission.cta"
    case permission_later       = "permission.later"

    // ── Share Extension ──────────────────────────────────────
    case share_title                    = "share.title"
    case share_status_extracting        = "share.status.extracting"
    case share_status_transcribing      = "share.status.transcribing"
    case share_status_listening         = "share.status.listening"
    case share_status_translating       = "share.status.translating"  // 2 args: flag, lang name
    case share_label_original           = "share.label.original"
    case share_label_translated         = "share.label.translated"
    case share_label_translation_failed = "share.label.translation_failed"
    case share_copy                     = "share.copy"
    case share_copied                   = "share.copied"
    case share_translate_to             = "share.translate_to"  // 1 arg: lang name
    case share_error_no_audio           = "share.error.no_audio"
    case share_error_unsupported        = "share.error.unsupported"
    case share_error_no_speech          = "share.error.no_speech"
    case share_error_permission_denied  = "share.error.permission_denied"
    case share_error_permission_req     = "share.error.permission_req"
    case share_error_unavailable        = "share.error.unavailable"
    case share_error_save_failed        = "share.error.save_failed"
    case share_error_read_failed        = "share.error.read_failed"

    // ── Keyboard Extension ───────────────────────────────────
    case keyboard_mode_typing               = "keyboard.mode.typing"
    case keyboard_mode_translate            = "keyboard.mode.translate"
    case keyboard_language_none             = "keyboard.language.none"
    case keyboard_language_translate_to     = "keyboard.language.translate_to" // 1 arg: lang name
    case keyboard_preview_placeholder       = "keyboard.preview.placeholder"
    case keyboard_preview_translation       = "keyboard.preview.translation"
    case keyboard_preview_translating       = "keyboard.preview.translating"
    case keyboard_preview_failed            = "keyboard.preview.failed"
    case keyboard_button_translate_replace  = "keyboard.button.translate_replace"
    case keyboard_button_translating        = "keyboard.button.translating"
    case keyboard_button_select_language    = "keyboard.button.select_language"
    case keyboard_button_type_something     = "keyboard.button.type_something"
    case keyboard_space                     = "keyboard.space"
    case keyboard_return                    = "keyboard.return"

    // ── Errors ───────────────────────────────────────────────
    case error_speech_unavailable       = "error.speech_unavailable"
    case error_audio_session            = "error.audio_session"          // 1 arg
    case error_audio_engine             = "error.audio_engine"           // 1 arg
    case error_mic_unavailable          = "error.mic_unavailable"
    case error_mic_failed               = "error.mic_failed"
    case error_permission_denied        = "error.permission_denied"
    case error_transcription            = "error.transcription"          // 1 arg
    case error_translation_invalid_url  = "error.translation_invalid_url"
    case error_translation_no_data      = "error.translation_no_data"
    case error_translation_invalid_resp = "error.translation_invalid_resp"
    case error_translation_failed       = "error.translation_failed"     // 1 arg
}
