import SwiftUI

/// Screens shown inside the details sheet.
enum SheetRoute: Hashable, Identifiable {
    case verse(VerseRef)
    case pericope(Pericope)
    case strong(StrongNumber)
    case commentary(Commentary)
    case passage(VerseRange)

    var id: String {
        switch self {
        case .verse(let verse): "verse-\(verse.book)-\(verse.chapter)-\(verse.verse)"
        case .pericope(let pericope): "pericope-\(pericope.id)"
        case .strong(let number): "strong-\(number)"
        case .commentary(let commentary): "commentary-\(commentary.id)"
        case .passage(let range): "passage-\(range.azbykaQuery)"
        }
    }
}

/// A sheet with its own navigation stack. Links inside formatted text
/// (Strong's numbers, Bible references) open as new screens in this stack,
/// so the reader's place underneath never changes.
struct DetailSheet: View {
    let root: SheetRoute
    @State private var path: [SheetRoute] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            screen(for: root)
                .navigationDestination(for: SheetRoute.self) { route in
                    screen(for: route)
                }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let route = AppLink.route(from: url) {
                path.append(route)
                return .handled
            }
            return .systemAction
        })
    }

    @ViewBuilder private func screen(for route: SheetRoute) -> some View {
        Group {
            switch route {
            case .verse(let verse):
                VerseDetailView(verse: verse)
            case .pericope(let pericope):
                PericopeDetailView(pericope: pericope)
            case .strong(let number):
                StrongEntryView(number: number)
            case .commentary(let commentary):
                CommentaryDetailView(commentary: commentary)
            case .passage(let range):
                PassagePreviewView(range: range)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Label("Закрыть", systemImage: "xmark")
                }
            }
        }
    }
}

/// Rounded background for content cards inside sheets.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.09), in: .rect(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// Section caption used across the detail screens.
struct SectionCaption: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
