//
//  ContentView.swift
//  TranslatingVoiceMessage
//
//  Created by MacBook Pro M1 Pro on 3/30/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

//
//  PermissionInstructionView.swift
//  TranslatingVoiceMessage
//
//  Created by MacBook Pro M1 Pro on 3/30/26.
//

import SwiftUI

struct PermissionInstructionView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Icon
            Image(systemName: "keyboard.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .imageScale(.large)
            
            // Title
            Text("Keyboard Access Required")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            // Instruction Body
            VStack(alignment: .leading, spacing: 16) {
                Text("To provide the best translation experience, this app needs access to your keyboard.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(step: 1, text: "Tap the button below to open Settings")
                    InstructionRow(step: 2, text: "Go to \"Privacy & Security\" > \"Keyboards\"")
                    InstructionRow(step: 3, text: "Enable access for TranslatingVoiceMessage")
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
            
            // Action Button
            Button(action: openAppSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                    Text("Open Settings")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            // Secondary Option
            Button("Not Now") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
    }
    
    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Helper Subview
private struct InstructionRow: View {
    let step: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .cornerRadius(6)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(nil)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    PermissionInstructionView()
}
