import SwiftUI

// MARK: - Button Styles for the app
// Card button style for channel and movie cells
public struct CardButtonStyle: ButtonStyle {
    public init() {} // Explicit public initializer
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Remove the extension to avoid any ambiguity 