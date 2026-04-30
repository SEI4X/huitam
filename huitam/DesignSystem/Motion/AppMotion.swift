import SwiftUI

enum AppMotion {
    static func messageInsert(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.82)
    }

    static func bubbleReveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.14) : .spring(response: 0.28, dampingFraction: 0.9)
    }

    static func sheetPresent(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .smooth(duration: 0.28)
    }

    static func listRowTap(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.10) : .snappy(duration: 0.18)
    }

    static func inputFocus(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.86)
    }

    static func quickStateChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.2)
    }
}
