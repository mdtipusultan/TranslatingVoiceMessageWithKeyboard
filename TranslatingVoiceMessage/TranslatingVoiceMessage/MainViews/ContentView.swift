//
//  PermissionInstructionView.swift
//  TranslatingVoiceMessage
//
//  Created by MacBook Pro M1 Pro on 3/30/26.
//

import SwiftUI

struct PermissionInstructionView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var pulseIcon = false
    @State private var shimmer = false
    
    // Gradient colors
    private let accentBlue = Color(red: 0.30, green: 0.55, blue: 1.0)
    private let accentPurple = Color(red: 0.58, green: 0.35, blue: 0.98)
    private let accentCyan = Color(red: 0.25, green: 0.80, blue: 0.95)
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.05, green: 0.10, blue: 0.22),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Decorative background orbs
            GeometryReader { geo in
                Circle()
                    .fill(accentBlue.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -80, y: -60)
                
                Circle()
                    .fill(accentPurple.opacity(0.10))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: geo.size.width - 120, y: geo.size.height * 0.35)
                
                Circle()
                    .fill(accentCyan.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: 40, y: geo.size.height * 0.7)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 50)
                    
                    // MARK: - Icon
                    ZStack {
                        // Pulsing ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [accentBlue.opacity(0.4), accentPurple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseIcon ? 1.15 : 1.0)
                            .opacity(pulseIcon ? 0.0 : 0.6)
                        
                        // Glass circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Image(systemName: "keyboard.badge.exclamationmark")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentCyan, accentBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.bottom, 28)
                    .offset(y: appeared ? 0 : -20)
                    .opacity(appeared ? 1 : 0)
                    
                    // MARK: - Title
                    Text("Keyboard Access\nRequired")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.bottom, 10)
                        .offset(y: appeared ? 0 : 15)
                        .opacity(appeared ? 1 : 0)
                    
                    Text("Enable keyboard permissions for the\nbest translation experience")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.bottom, 32)
                        .offset(y: appeared ? 0 : 15)
                        .opacity(appeared ? 1 : 0)
                    
                    // MARK: - Steps Card
                    VStack(spacing: 0) {
                        StepRow(
                            step: 1,
                            icon: "gearshape.fill",
                            title: "Open Settings",
                            subtitle: "Tap the button below to go to Settings",
                            color: accentBlue,
                            isLast: false
                        )
                        
                        StepRow(
                            step: 2,
                            icon: "lock.shield.fill",
                            title: "Keyboards",
                            subtitle: "Go to General → Keyboard → Keyboards",
                            color: accentPurple,
                            isLast: false
                        )
                        
                        StepRow(
                            step: 3,
                            icon: "checkmark.circle.fill",
                            title: "Enable Access",
                            subtitle: "Turn on TranslatingVoiceMessage and Allow Full Access",
                            color: accentCyan,
                            isLast: true
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .offset(y: appeared ? 0 : 25)
                    .opacity(appeared ? 1 : 0)
                    
                    Spacer().frame(height: 36)
                    
                    // MARK: - CTA Button
                    Button(action: openAppSettings) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Open Settings")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [accentBlue, accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: accentBlue.opacity(0.35), radius: 16, x: 0, y: 8)
                        .overlay(
                            // Shimmer effect
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            Color.white.opacity(0.15),
                                            .clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmer ? 250 : -250)
                                .mask(RoundedRectangle(cornerRadius: 16))
                        )
                    }
                    .padding(.horizontal, 28)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    
                    Spacer().frame(height: 16)
                    
                    // MARK: - Dismiss
                    Button {
                        dismiss()
                    } label: {
                        Text("I'll do this later")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .padding(.vertical, 8)
                    }
                    .offset(y: appeared ? 0 : 10)
                    .opacity(appeared ? 1 : 0)
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulseIcon = true
            }
            // Shimmer loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(2)) {
                    shimmer = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: Int
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline dot + line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 28)
                }
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview
#Preview {
    PermissionInstructionView()
        .preferredColorScheme(.dark)
}
