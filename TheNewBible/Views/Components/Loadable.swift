import SwiftUI

/// State of something loaded from the network.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(Error)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// Shows a spinner, the loaded content or an error with a retry button.
struct LoadableView<Value, Content: View>: View {
    let state: Loadable<Value>
    var retry: (() -> Void)?
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 160)
        case .loaded(let value):
            content(value)
        case .failed(let error):
            ErrorStateView(error: error, retry: retry)
        }
    }
}

struct ErrorStateView: View {
    let error: Error
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Не удалось загрузить", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retry {
                Button("Повторить", action: retry)
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Settings stored in `UserDefaults`, shared by the reader and the settings screen.
enum ReaderSettings {
    static let fontSizeKey = "settings.fontSize"
    static let serifKey = "settings.serif"
    static let defaultFontSize = 19.0

    static func font(size: Double, serif: Bool) -> Font {
        .system(size: size, design: serif ? .serif : .default)
    }
}
