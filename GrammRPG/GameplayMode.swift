//
//  GameplayMode.swift
//  GrammRPG
//
//  Created by Assistant on 12/7/25.
//

import Foundation

// Top-level gameplay mode enum for use across the app
enum GameplayMode: String, CaseIterable, Identifiable {
    case spellingCheck = "Spelling Check"
    case diceRoll = "Dice Roll"

    var id: String { rawValue }
}
