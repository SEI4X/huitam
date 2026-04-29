//
//  Item.swift
//  huitam
//
//  Created by Alexey Mashkov on 29.04.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
