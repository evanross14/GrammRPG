//
//  Item.swift
//  GrammRPG
//
//  Created by Evan Ross on 6/19/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var name: String?
    var timestamp: Date
    
    init(timestamp: Date, name: String? = nil) {
        self.timestamp = timestamp
        self.name = name
    }
}
