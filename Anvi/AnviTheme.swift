import SwiftUI

enum AnviTheme {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.12)
    static let mutedInk = Color(red: 0.38, green: 0.39, blue: 0.36)
    static let canvas = Color(red: 0.95, green: 0.94, blue: 0.89)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.94)
    static let sage = Color(red: 0.57, green: 0.65, blue: 0.51)
    static let moss = Color(red: 0.25, green: 0.34, blue: 0.25)
    static let clay = Color(red: 0.78, green: 0.48, blue: 0.34)
    static let sun = Color(red: 0.93, green: 0.72, blue: 0.35)
    static let lavender = Color(red: 0.63, green: 0.57, blue: 0.72)
}

extension View {
    func anviCard(cornerRadius: CGFloat = 30) -> some View {
        self
            .background(AnviTheme.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.08), radius: 20, y: 10)
    }
}
