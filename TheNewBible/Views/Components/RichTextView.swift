import SwiftUI

/// In-app links embedded in formatted text, handled by ``DetailSheet``.
enum AppLink {
    static let scheme = "thenewbible"

    static func url(for link: RichLink) -> URL? {
        switch link {
        case .strong(let number):
            URL(string: "\(scheme)://strong/\(number)")
        case .bible(let range):
            URL(string: "\(scheme)://passage/\(range.azbykaQuery)")
        case .web(let url):
            url
        }
    }

    static func route(from url: URL) -> SheetRoute? {
        guard url.scheme == scheme else { return nil }
        let value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch url.host {
        case "strong":
            return StrongNumber(value).map(SheetRoute.strong)
        case "passage":
            return AzbykaReference.parse(value).map(SheetRoute.passage)
        default:
            return nil
        }
    }
}

/// Renders ``RichText`` paragraphs with links.
struct RichTextView: View {
    let text: RichText
    var fontSize: Double = 17
    var serif: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.7) {
            ForEach(Array(text.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(attributed(paragraph))
                    .lineSpacing(fontSize * 0.25)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
    }

    private func attributed(_ paragraph: RichParagraph) -> AttributedString {
        var result = AttributedString()
        for run in paragraph.runs {
            var piece = AttributedString(run.text)
            let design: Font.Design = serif || run.style.contains(.original) ? .serif : .default
            var size = fontSize
            if run.style.contains(.original) { size *= 1.12 }
            if run.style.contains(.superscript) { size *= 0.7 }
            var font = Font.system(size: size, design: design)
            if run.style.contains(.bold) || run.style.contains(.label) { font = font.bold() }
            if run.style.contains(.italic) { font = font.italic() }
            piece.font = font
            if run.style.contains(.label) { piece.foregroundColor = Color.secondary }
            if run.style.contains(.superscript) {
                piece[AttributeScopes.SwiftUIAttributes.BaselineOffsetAttribute.self] = fontSize * 0.35
            }
            if let link = run.link, let url = AppLink.url(for: link) {
                piece.link = url
            }
            result += piece
        }
        return result
    }
}
