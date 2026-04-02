//
//  MainTabView.swift
//  TranslatingVoiceMessage
//
//  Root TabView with custom styled dark tab bar.
//  Tabs: Voice Translator, Keyboard Setup, Settings
//

import SwiftUI

struct MainTabView: View {
    
    @State private var selectedTab: Tab = .voice
    @State private var tabBarVisible = true
    @State private var openedFromKeyboard = false
    
    enum Tab: String, CaseIterable {
        case voice
        case keyboard
        case settings
        
        var icon: String {
            switch self {
            case .voice: return "mic.fill"
            case .keyboard: return "keyboard"
            case .settings: return "gearshape.fill"
            }
        }
        
        var label: String {
            switch self {
            case .voice: return "Translate"
            case .keyboard: return "Keyboard"
            case .settings: return "Settings"
            }
        }
    }
    
    // Colors
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let tabBarColor = Color(red: 0.09, green: 0.09, blue: 0.13)
    private let accentBlue = Color(red: 0.30, green: 0.55, blue: 1.0)
    private let accentPurple = Color(red: 0.58, green: 0.35, blue: 0.98)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .voice:
                    VoiceTranslationView(autoStartListening: $openedFromKeyboard)
                case .keyboard:
                    PermissionInstructionView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            // Handle voicetranslator://voice from keyboard extension
            if url.scheme == "voicetranslator" {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = .voice
                    openedFromKeyboard = true
                }
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            tabBarBackground
        )
    }
    
    private func tabButton(for tab: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // Active indicator
                    if selectedTab == tab {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue.opacity(0.25), accentPurple.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 56, height: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Image(systemName: tab.icon)
                        .font(.system(size: selectedTab == tab ? 17 : 18, weight: .medium))
                        .foregroundStyle(
                            selectedTab == tab
                            ? AnyShapeStyle(LinearGradient(
                                colors: [accentBlue, accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.3))
                        )
                        .scaleEffect(selectedTab == tab ? 1.0 : 0.9)
                }
                .frame(height: 30)
                
                Text(tab.label)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private var tabBarBackground: some View {
        ZStack {
            // Blur backdrop
            Rectangle()
                .fill(tabBarColor.opacity(0.92))
            
            // Top border glow
            VStack {
                LinearGradient(
                    colors: [
                        accentBlue.opacity(0.15),
                        accentPurple.opacity(0.08),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                
                Spacer()
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    
    @State private var selectedLanguage: Language = SupportedLanguages.all[1]
    @AppStorage("selectedLanguageCode") private var savedLanguageCode = "en"
    
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let cardColor = Color(red: 0.12, green: 0.12, blue: 0.17)
    private let surfaceColor = Color(red: 0.16, green: 0.16, blue: 0.22)
    private let accentBlue = Color(red: 0.30, green: 0.55, blue: 1.0)
    private let accentPurple = Color(red: 0.58, green: 0.35, blue: 0.98)
    private let accentGreen = Color(red: 0.30, green: 0.78, blue: 0.55)
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            // Background orbs
            GeometryReader { geo in
                Circle()
                    .fill(accentPurple.opacity(0.06))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: geo.size.width - 100, y: 50)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Configure your translation preferences")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.top, 10)
                    
                    // About section
                    settingsCard {
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: [accentBlue, accentPurple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 52, height: 52)
                                    
                                    Image(systemName: "globe")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Voice Translator")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("Version 1.0")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Features section
                    sectionHeader("FEATURES")
                    
                    settingsCard {
                        VStack(spacing: 0) {
                            featureRow(icon: "mic.fill", color: accentBlue, title: "Voice Translation", subtitle: "Speak & translate in real-time")
                            
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 48)
                            
                            featureRow(icon: "keyboard", color: accentPurple, title: "Translation Keyboard", subtitle: "Translate while typing in any app")
                            
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 48)
                            
                            featureRow(icon: "square.and.arrow.up", color: accentGreen, title: "Share Extension", subtitle: "Translate voice messages from chats")
                        }
                    }
                    
                    // Info section
                    sectionHeader("TRANSLATION")
                    
                    settingsCard {
                        VStack(spacing: 0) {
                            infoRow(icon: "globe.americas", title: "Languages", value: "65+")
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 48)
                            infoRow(icon: "bolt.fill", title: "Speech Engine", value: "Apple On-Device")
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 48)
                            infoRow(icon: "network", title: "Translation API", value: "MyMemory (Free)")
                        }
                    }
                    
                    // Help section
                    sectionHeader("HELP")
                    
                    settingsCard {
                        VStack(spacing: 0) {
                            Button {
                                openAppSettings()
                            } label: {
                                settingsRow(icon: "gearshape.fill", color: .gray, title: "Open System Settings")
                            }
                            
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 48)
                            
                            settingsRow(icon: "questionmark.circle", color: accentBlue, title: "How to use the keyboard")
                                .onTapGesture { }
                        }
                    }
                    
                    // Footer
                    Text("Translation powered by MyMemory API\nSpeech recognition by Apple")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Components
    
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.3))
            .padding(.leading, 4)
    }
    
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(accentGreen)
        }
        .padding(.vertical, 6)
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 6)
    }
    
    private func settingsRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.vertical, 6)
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
