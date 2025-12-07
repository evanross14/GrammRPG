//
//  SettingsView.swift
//  GrammRPG
//
//  Created by Assistant on 12/7/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding var gameplayMode: GameplayMode

    // Actions provided by the host
    var onResetStory: () -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Gameplay") {
                    Picker("Mode", selection: $gameplayMode) {
                        ForEach(GameplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Story") {
                    Button(role: .destructive) {
                        onResetStory()
                        onClose()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundStyle(.red)
                            Text("Reset Story")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

#Preview {
    SettingsView(gameplayMode: .constant(GameplayMode.spellingCheck), onResetStory: {}, onClose: {})
}
