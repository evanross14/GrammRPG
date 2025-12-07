//
//  ContentView.swift
//  GrammRPG
//
//  Created by Evan Ross on 6/19/25.
//

import SwiftUI
import SwiftData
import Foundation
import Darwin

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

//
// Main view control
// inventory button implementation
// text input implementation
// text bubble implementation
// gold and health implementation
//
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var messageText: String = ""
    private enum Role: Equatable { case user, story }
    private struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        let attributed: AttributedString?
        let remainingCount: Int?
    }
    @State private var messages: Array<ChatMessage> = []
    @State private var scrollToBottom: Int = 0
    @State private var showInventory: Bool = false
    @State private var showSettings: Bool = false

    @State private var showAISettingsAlert: Bool = false
    @State private var aiSettingsAlertMessage: String = ""
    
    @State private var showAIStartupAlert: Bool = false
    @State private var aiStartupMessage: String = ""

    @StateObject private var health = HealthModel()
    @StateObject private var gold = GoldModel(initialCoins: 100)

    @State private var gameplayMode: GameplayMode = .spellingCheck

    private struct GlassCapsule<Content: View>: View {
        var content: () -> Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        var body: some View {
            HStack { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.28), lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.7)
                )
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
                .overlay(
                    Capsule()
                        .stroke(LinearGradient(colors: [Color.black.opacity(0.10), Color.clear], startPoint: .bottom, endPoint: .top), lineWidth: 1)
                        .blendMode(.multiply)
                        .opacity(0.7)
                )
        }
    }

    private struct LiquidGlassBar: View {
        var progress: CGFloat // 0...1
        var tint: Color

        var body: some View {
            GeometryReader { geo in
                let w = max(0, min(1, progress)) * geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: w)
                }
            }
            .frame(height: 18)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.7)
            )
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        }
    }

    private struct ChatBubble: View {
        let message: ChatMessage
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            HStack {
                if message.role == .story {
                    // AI (story) bubbles on left
                    VStack(alignment: .leading, spacing: 0) {
                        if let attributed = message.attributed {
                            Text(attributed)
                        } else {
                            Text(message.text)
                        }
                        if let remaining = message.remainingCount {
                            Text("Count: \(remaining)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        .ultraThinMaterial.opacity(0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.30), lineWidth: 1.2)
                    )
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        if let attributed = message.attributed {
                            Text(attributed)
                        } else {
                            Text(message.text)
                        }
                        if let remaining = message.remainingCount {
                            Text("Count: \(remaining)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.85), lineWidth: 1.2)
                    )
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .padding(.horizontal, 10)
                                    .id(message.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.bottom, 76)
                    }
                    .onChange(of: scrollToBottom) { _, _ in
                        if let lastID = messages.last?.id { proxy.scrollTo(lastID, anchor: .bottom) }
                    }
                    .onAppear {
                        // Startup check for Apple Intelligence support/enabled state
                        let aiSupported = StoryEngine.isAppleIntelligenceAvailable()
                        let isRunningAsRoot = (getuid() == 0)
                        var aiEnabled = true
                        #if canImport(FoundationModels)
                        // Placeholder: in future, query actual authorization/enablement
                        aiEnabled = true
                        #else
                        aiEnabled = false
                        #endif
                        if isRunningAsRoot || !aiSupported || !aiEnabled {
                            aiStartupMessage = isRunningAsRoot ? "Running as root is not supported. Please run as a standard user." : (!aiSupported ? "This device or OS version does not support Apple Intelligence." : "Apple Intelligence is disabled. Enable it in Settings to continue the story.")
                            showAIStartupAlert = true
                        }
                        
                        seedSampleItemsIfNeeded()
                        // Show a one-time instructional message when chat is empty
                        if messages.isEmpty {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                messages.append(ChatMessage(role: .story, text: "To begin a story, give me some input describing what kind of story you would like to play. You can only use items you currently have in your inventory.", attributed: nil, remainingCount: nil))
                            }
                            scrollToBottom = messages.indices.last ?? -1
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                GlassCapsule {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityHidden(true)

                        LiquidGlassBar(
                            progress: CGFloat(max(min(health.current, max(health.total, 1)), 0)) / CGFloat(max(health.total, 1)),
                            tint: .red
                        )
                        .frame(width: 160, height: 18)
                        .animation(.easeOut(duration: 0.33), value: health.current)

                        Text("\(health.current)/\(health.total)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                }
                .padding(.leading)
                .padding(.top, 8)
            }
            .overlay(alignment: .topTrailing) {
                GlassCapsule {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard.circle.fill")
                            .foregroundStyle(.yellow, .gray)
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("\(gold.coins)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .padding(.trailing)
                .padding(.top, 8)
            }
            .zIndex(1)
            .safeAreaInset(edge: .bottom) {
                MessageInputBar(text: $messageText, onSend: sendMessage, onInventory: { showInventory = true })
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
        .alert("Apple Intelligence Disabled", isPresented: $showAISettingsAlert) {
            Button("Close App", role: .destructive) {
                #if os(macOS)
                NSApp.terminate(nil)
                #else
                exit(0)
                #endif
            }
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
        } message: {
            Text(aiSettingsAlertMessage.isEmpty ? "Apple Intelligence is disabled. Enable it in Settings to continue." : aiSettingsAlertMessage)
        }
#if !os(macOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
#endif
#if os(macOS)
        .popover(isPresented: $showInventory) {
            InventoryView(items: items, onClose: { showInventory = false })
                .frame(width: 520, height: 520)
        }
#else
        .sheet(isPresented: $showInventory) {
            NavigationStack {
                InventoryView(items: items)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showInventory = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                // Close inventory, then present settings to avoid sheet conflict
                                showInventory = false
                                DispatchQueue.main.async {
                                    showSettings = true
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
            }
        }
#endif
        .sheet(isPresented: $showSettings) {
            SettingsView(
                gameplayMode: $gameplayMode,
                onResetStory: { resetStory() },
                onClose: { showSettings = false }
            )
        }
        .alert("Apple Intelligence Required", isPresented: $showAIStartupAlert) {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            Button("Close App", role: .destructive) {
                #if os(macOS)
                NSApp.terminate(nil)
                #else
                exit(0)
                #endif
            }
        } message: {
            Text(aiStartupMessage.isEmpty ? "Go to Settings > Apple Intelligence & Siri and enable Apple Intelligence to continue." : aiStartupMessage + "\n\nGo to Settings > Apple Intelligence & Siri and enable Apple Intelligence.")
        }
    }

    private func resetStory() {
        // Clear chat
        messages.removeAll()
        // Reset stats
        health.current = 100
        health.total = max(health.total, 100)
        gold.set(100)
        // Reset inventory to original three
        let originals: Set<String> = ["Knife", "Rope", "Potion"]
        for item in items {
            let name = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { modelContext.delete(item); continue }
            if !originals.contains(name) { modelContext.delete(item) }
        }
        // Ensure originals exist
        let currentNames = Set(items.compactMap { $0.name })
        for name in originals where !currentNames.contains(name) {
            let newItem = Item(timestamp: Date(), name: name)
            modelContext.insert(newItem)
        }
        // Seed initial instruction message
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            messages.append(ChatMessage(role: .story, text: "To begin a story, give me some input describing what kind of story you would like to play. You can only use items you currently have in your inventory.", attributed: nil, remainingCount: nil))
        }
        scrollToBottom = messages.indices.last ?? -1
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            messages.append(ChatMessage(role: .user, text: trimmed, attributed: nil, remainingCount: nil))
        }
        // Apply post-send processing depending on mode
        var shouldCallAI = true
        if let idx = messages.indices.last {
            switch gameplayMode {
            case .spellingCheck:
                let protected: Set<String> = Set(items.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                let result = SpellChecker.analyze(text: messages[idx].text, protectedTerms: protected)

                messages[idx] = ChatMessage(role: .user, text: result.2, attributed: result.0, remainingCount: result.1)

                // If remaining count is low (< 3), produce a bad outcome and reduce health.
                if result.1 < 3 {
                    // Health penalty scales with how low the remaining count is: 2 -> -10, 1 -> -30, 0 -> -50
                    let penalty: Int
                    switch result.1 {
                    case 2: penalty = 10
                    case 1: penalty = 30
                    default: penalty = 50 // result.1 <= 0
                    }
                    health.current = max(0, health.current - penalty)

                    // Append a negative story event and skip AI continuation for this turn
                    let harmText: String
                    switch result.1 {
                    case 2:
                        harmText = "Your muddled words cause a minor mishap. You stumble and scrape your knee. (-\(penalty) HP)"
                    case 1:
                        harmText = "Your garbled command backfires. A trap snaps at your legs, leaving you limping. (-\(penalty) HP)"
                    default:
                        harmText = "The world misreads your intent entirely. A hidden force strikes hard, knocking the wind from you. (-\(penalty) HP)"
                    }

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        messages.append(ChatMessage(role: .story, text: harmText, attributed: nil, remainingCount: nil))
                    }
                    scrollToBottom = messages.indices.last ?? -1

                    shouldCallAI = false
                }

            case .diceRoll:
                // Dice roll: roll a d20 and append the result to the user's message as a neutral note
                let roll = Int.random(in: 1...20)
                let base = messages[idx].text + "\n(Rolled d20: \(roll))"
                messages[idx] = ChatMessage(role: .user, text: base, attributed: nil, remainingCount: nil)
            }
        }
        messageText = ""
        scrollToBottom = messages.indices.last ?? -1

        // If we appended a bad outcome due to low spelling score, skip AI continuation for this turn
        if !shouldCallAI {
            return
        }

        // Prevent calling Apple Intelligence when running as root (unsupported)
        if getuid() == 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                messages.append(ChatMessage(role: .story, text: "Apple Intelligence is unavailable when running as root. Please run the app as a standard user to continue the story.", attributed: nil, remainingCount: nil))
            }
            scrollToBottom = messages.indices.last ?? -1
            return
        }

        // Generate continuation from Apple Intelligence (with updated result type)
        Task {
            let engine = StoryEngine()
            let names = items.compactMap { $0.name }.filter { !$0.isEmpty }
            var variedHistory = messages.map { $0.text }

            // Use corrected text for the most recent user message if in spellingCheck mode
            let lastUserText: String = {
                if gameplayMode == .spellingCheck, let last = messages.last(where: { $0.role == .user }) {
                    return last.text
                }
                return trimmed
            }()

            if messages.filter({ $0.role == .user }).count == 1 {
                // On the very first user turn, start fresh: only the user's input
                variedHistory = [lastUserText]
            }

            // Artificial delay to simulate thinking (off main actor)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            let result: StoryEngine.ContinuationResult
            do {
                result = try await engine.generateContinuation(action: lastUserText, history: variedHistory, inventoryNames: names)
            } catch {
                if let err = error as? StoryEngine.StoryEngineError, case .appleIntelligenceDisabled = err {
                    await MainActor.run {
                        aiSettingsAlertMessage = err.localizedDescription
                        showAISettingsAlert = true
                    }
                    return
                }
                let inventoryText: String = names.isEmpty ? "empty hands" : names.joined(separator: ", ")
                let actionText: String = trimmed.lowercased()
                let fallbackText: String = "You steady yourself and take stock. With \(inventoryText) at the ready, you \(actionText). The air seems to shift as the world reacts, revealing a new path forward."
                result = StoryEngine.ContinuationResult(text: fallbackText, awardedItems: [], awardedGold: 0)
            }

            await MainActor.run {
                if !result.awardedItems.isEmpty {
                    for name in result.awardedItems {
                        let newItem = Item(timestamp: Date(), name: name)
                        modelContext.insert(newItem)
                    }
                }

                if result.awardedGold > 0 {
                    gold.add(result.awardedGold)
                }

                // Sanitize: remove bracketed control tokens and option lists
                let cleaned: String = {
                    // Remove any lines that look like options (bulleted or numbered)
                    let lines = result.text
                        .components(separatedBy: .newlines)
                        .filter { line in
                            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                            guard !trimmedLine.isEmpty else { return false }
                            if trimmedLine.hasPrefix("-") { return false }
                            if let first = trimmedLine.split(separator: " ").first, first.dropLast().allSatisfy({ $0.isNumber }) && trimmedLine.contains(".") { return false }
                            if trimmedLine.first?.isNumber == true && trimmedLine.dropFirst().first == "." { return false }
                            if trimmedLine.hasPrefix("[") && trimmedLine.contains("]") { return false }
                            return true
                        }
                    return lines.joined(separator: "\n")
                }()

                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    messages.append(ChatMessage(role: .story, text: cleaned, attributed: nil, remainingCount: nil))
                }

                scrollToBottom = messages.indices.last ?? -1
            }
        }
    }

    private func seedSampleItemsIfNeeded() {
        // Only seed if there are no items yet
        guard items.isEmpty else { return }
        let names = ["Potion", "Knife", "Rope"]
        for name in names {
            let newItem = Item(timestamp: Date(), name: name)
            modelContext.insert(newItem)
        }
    }

    private struct MessageInputBar: View {
        @Binding var text: String
        var onSend: () -> Void
        var onInventory: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        @State private var measuredHeight: CGFloat = 32
        private var barHeight: CGFloat { measuredHeight + 10 }

        var body: some View {
            HStack(spacing: 8) {
                Button(action: onInventory) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Image(systemName: "bag")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                            .accessibilityLabel("Inventory")
                    }
                    .frame(width: barHeight, height: barHeight)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.08), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.plusLighter)
                            .opacity(0.75)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 8)
                }
                #if os(macOS)
                .buttonStyle(.plain)
                .controlSize(.large)
                #endif
                
                HStack(spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        // Placeholder
                        if text.isEmpty {
                            Text("Type your next action...")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .padding(.leading, 16)
                                .padding(.trailing, 12)
                        }

                        AutoSizingTextEditor(text: $text, measuredHeight: $measuredHeight, maxHeight: 120)
                            .frame(minHeight: 32, maxHeight: measuredHeight)
                            .padding(.vertical, 4)
                            .padding(.leading, 8)
                            .padding(.trailing, 0)
                            .font(.body)
                            .onChange(of: text) { _, newValue in
                                // Trim leading newlines that TextEditor can insert
                                if newValue.hasPrefix("\n") {
                                    text = String(newValue.drop { $0 == "\n" })
                                }
                            }
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            #endif
                            #if os(macOS)
                            .focusEffectDisabled()
                            #endif
                    }

                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(text.isEmpty ? .gray : .accentColor)
                            .padding(2)
                    }
                    #if os(macOS)
                    .buttonStyle(.plain)
                    .controlSize(.large)
                    #endif
                    .disabled(text.isEmpty)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1).allowsHitTesting(false))
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.26), Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.75)
                        .allowsHitTesting(false)
                )
                .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
            }
            .padding(.vertical, 2)
        }
    }
    
    private struct AutoSizingTextEditor: View {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat
        var maxHeight: CGFloat

        @State private var intrinsicHeight: CGFloat = 32

        var body: some View {
            ZStack(alignment: .topLeading) {
                // Hidden measuring text mirrors TextEditor content to compute height
                Text(text.isEmpty ? " " : text)
                    .font(.body)
                    .foregroundStyle(.clear)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(GeometryReader { proxy in
                        Color.clear
                            .onAppear { updateHeight(proxy.size.height) }
                            .onChange(of: proxy.size.height) { _, new in updateHeight(new) }
                    })
                    .accessibilityHidden(true)

                // The actual editor overlays the measuring text
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: min(max(intrinsicHeight, 32), maxHeight))
            }
            .onChange(of: text) { _, _ in
                // Trigger re-measure on text changes
                // measured via the hidden Text's GeometryReader
            }
        }

        private func updateHeight(_ newHeight: CGFloat) {
            let clamped = min(max(newHeight, 32), maxHeight)
            intrinsicHeight = clamped
            measuredHeight = clamped
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

