import SwiftUI

enum SpielraumTheme {
    static let mint = Color(red: 0.55, green: 0.96, blue: 0.77)
    static let canvas = Color(red: 0.045, green: 0.063, blue: 0.067)
    static let surface = Color(red: 0.085, green: 0.11, blue: 0.115)
    static let muted = Color(red: 0.65, green: 0.73, blue: 0.71)
}
extension View {
    func budgetCard() -> some View {
        self.padding(18).background(SpielraumTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.065), lineWidth: 1))
    }
}
