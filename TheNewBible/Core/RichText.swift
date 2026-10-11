import Foundation

/// Platform-neutral formatted text produced from the small HTML fragments
/// the data sources return (Strong's lexicon articles, commentaries).
/// The UI turns it into an `AttributedString`.
public struct RichText: Hashable, Codable, Sendable {
    public var paragraphs: [RichParagraph]

    public init(paragraphs: [RichParagraph] = []) {
        self.paragraphs = paragraphs
    }

    public var isEmpty: Bool { paragraphs.isEmpty }

    public var plainText: String {
        paragraphs.map(\.plainText).joined(separator: "\n\n")
    }
}

public struct RichParagraph: Hashable, Codable, Sendable {
    public var runs: [RichRun]

    public init(runs: [RichRun] = []) {
        self.runs = runs
    }

    public var plainText: String { runs.map(\.text).joined() }
}

public struct RichRun: Hashable, Codable, Sendable {
    public struct Style: OptionSet, Hashable, Codable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let bold = Style(rawValue: 1 << 0)
        public static let italic = Style(rawValue: 1 << 1)
        /// Greek or Hebrew word.
        public static let original = Style(rawValue: 1 << 2)
        /// Field label in lexicon articles ("Этимология:").
        public static let label = Style(rawValue: 1 << 3)
        public static let superscript = Style(rawValue: 1 << 4)
    }

    public var text: String
    public var style: Style
    public var link: RichLink?

    public init(text: String, style: Style = [], link: RichLink? = nil) {
        self.text = text
        self.style = style
        self.link = link
    }
}

public enum RichLink: Hashable, Codable, Sendable {
    /// A Strong's number such as "G3056" or "H7225".
    case strong(String)
    /// A Bible reference.
    case bible(VerseRange)
    case web(URL)

    /// Resolves an `href` found in source HTML.
    public static func resolve(_ href: String, base: URL?) -> RichLink? {
        let href = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if href.hasPrefix("S:") {
            let number = String(href.dropFirst(2)).uppercased()
            return StrongNumber(number) != nil ? .strong(number) : nil
        }
        if href.hasPrefix("#") || href.lowercased().hasPrefix("javascript:") || href.isEmpty {
            return nil
        }
        guard let url = URL(string: href, relativeTo: base)?.absoluteURL else { return nil }
        if let range = AzbykaReference.parse(url: url) {
            return .bible(range)
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return .web(url)
    }
}

/// A minimal HTML reader: enough for lexicon articles and commentaries.
public enum HTMLText {
    /// Tags whose contents are dropped entirely.
    private static let skippedTags: Set<String> = ["script", "style", "noscript", "template", "svg", "button"]
    /// Tags that start a new paragraph.
    private static let blockTags: Set<String> = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "ul", "ol",
        "blockquote", "tr", "table", "section", "article", "dd", "dt",
    ]

    /// Strips tags and decodes entities; whitespace is collapsed.
    public static func plain(_ html: String) -> String {
        parse(html).paragraphs.map(\.plainText).joined(separator: " ")
    }

    public static func parse(_ html: String, base: URL? = nil) -> RichText {
        var builder = Builder()
        var styleStack: [(tag: String, style: RichRun.Style)] = []
        var linkStack: [(tag: String, link: RichLink?)] = []
        var skipDepth = 0
        var skipTag = ""

        var index = html.startIndex
        var textStart = index

        func flushText(upTo end: String.Index) {
            guard skipDepth == 0, textStart < end else { return }
            let style = styleStack.reduce(into: RichRun.Style()) { $0.formUnion($1.style) }
            let link = linkStack.last(where: { $0.link != nil })?.link
            builder.append(decodeEntities(String(html[textStart..<end])), style: style, link: link)
        }

        while index < html.endIndex {
            guard html[index] == "<" else {
                index = html.index(after: index)
                continue
            }
            // Comments.
            if html[index...].hasPrefix("<!--") {
                flushText(upTo: index)
                if let close = html.range(of: "-->", range: index..<html.endIndex) {
                    index = close.upperBound
                } else {
                    index = html.endIndex
                }
                textStart = index
                continue
            }
            guard let close = html[index...].firstIndex(of: ">") else { break }
            let inner = html[html.index(after: index)..<close]
            guard let tag = Tag(inner) else {
                // A lone "<" in text.
                index = html.index(after: index)
                continue
            }
            flushText(upTo: index)
            index = html.index(after: close)
            textStart = index

            if skipDepth > 0 {
                if tag.name == skipTag {
                    if tag.isClosing { skipDepth -= 1 } else if !tag.isSelfClosing { skipDepth += 1 }
                }
                continue
            }
            if skippedTags.contains(tag.name), !tag.isClosing, !tag.isSelfClosing {
                skipDepth = 1
                skipTag = tag.name
                continue
            }

            if tag.name == "br" {
                builder.lineBreak()
                continue
            }
            if blockTags.contains(tag.name) {
                builder.paragraphBreak()
            }

            let style = style(for: tag.name)
            if tag.isClosing {
                if let i = styleStack.lastIndex(where: { $0.tag == tag.name }) {
                    styleStack.remove(at: i)
                }
                if tag.name == "a", let i = linkStack.lastIndex(where: { $0.tag == "a" }) {
                    linkStack.remove(at: i)
                }
            } else if !tag.isSelfClosing {
                if !style.isEmpty { styleStack.append((tag.name, style)) }
                if tag.name == "a" {
                    let link = tag.attributes["href"].flatMap { RichLink.resolve($0, base: base) }
                    linkStack.append(("a", link))
                }
            }
        }
        flushText(upTo: html.endIndex)
        return builder.result()
    }

    private static func style(for tag: String) -> RichRun.Style {
        switch tag {
        case "b", "strong": .bold
        case "i", "em", "cite": .italic
        case "el", "he", "gr", "heb", "greek": .original
        case "df": .label
        case "sup": .superscript
        default: []
        }
    }

    // MARK: - Entities

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "laquo": "«", "raquo": "»", "bdquo": "„", "ldquo": "“", "rdquo": "”",
        "lsquo": "‘", "rsquo": "’", "sbquo": "‚", "mdash": "—", "ndash": "–",
        "hellip": "…", "shy": "", "times": "×", "deg": "°", "sect": "§", "prime": "′",
        "Prime": "″", "middot": "·", "bull": "•", "copy": "©", "thinsp": "\u{2009}",
        "ensp": "\u{2002}", "emsp": "\u{2003}", "dagger": "†", "Dagger": "‡",
        "acute": "\u{0301}", "uml": "¨", "para": "¶", "frac12": "½", "frac14": "¼",
    ]

    public static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&",
                  let semicolon = text[index...].prefix(12).firstIndex(of: ";")
            else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let name = text[text.index(after: index)..<semicolon]
            var replacement: String?
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                replacement = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String($0) }
            } else if name.hasPrefix("#") {
                replacement = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String($0) }
            } else {
                replacement = namedEntities[String(name)]
            }
            if let replacement {
                result += replacement
                index = text.index(after: semicolon)
            } else {
                result.append(character)
                index = text.index(after: index)
            }
        }
        return result
    }

    // MARK: - Tag

    private struct Tag {
        var name: String
        var isClosing: Bool
        var isSelfClosing: Bool
        var attributes: [String: String]

        init?(_ source: Substring) {
            var body = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            isClosing = body.hasPrefix("/")
            if isClosing { body.removeFirst() }
            isSelfClosing = body.hasSuffix("/")
            if isSelfClosing { body.removeLast() }
            let nameEnd = body.firstIndex(where: { $0.isWhitespace || $0 == "/" }) ?? body.endIndex
            let name = body[..<nameEnd].lowercased()
            guard let first = name.first, first.isLetter, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == ":" })
            else { return nil }
            self.name = name
            attributes = Tag.parseAttributes(body[nameEnd...])
        }

        private static func parseAttributes(_ text: Substring) -> [String: String] {
            var attributes: [String: String] = [:]
            var index = text.startIndex
            func skipSpaces() {
                while index < text.endIndex, text[index].isWhitespace || text[index] == "/" {
                    index = text.index(after: index)
                }
            }
            func skipSpacesOnly() {
                while index < text.endIndex, text[index].isWhitespace {
                    index = text.index(after: index)
                }
            }
            while true {
                skipSpaces()
                guard index < text.endIndex else { break }
                let nameStart = index
                while index < text.endIndex, !text[index].isWhitespace, text[index] != "=" {
                    index = text.index(after: index)
                }
                let name = text[nameStart..<index].lowercased()
                skipSpacesOnly()
                guard index < text.endIndex, text[index] == "=" else {
                    if !name.isEmpty { attributes[name] = "" }
                    continue
                }
                index = text.index(after: index)
                skipSpacesOnly()
                guard index < text.endIndex else { break }
                let value: Substring
                if text[index] == "\"" || text[index] == "'" {
                    let quote = text[index]
                    let valueStart = text.index(after: index)
                    let valueEnd = text[valueStart...].firstIndex(of: quote) ?? text.endIndex
                    value = text[valueStart..<valueEnd]
                    index = valueEnd < text.endIndex ? text.index(after: valueEnd) : valueEnd
                } else {
                    let valueStart = index
                    while index < text.endIndex, !text[index].isWhitespace {
                        index = text.index(after: index)
                    }
                    value = text[valueStart..<index]
                }
                attributes[name] = HTMLText.decodeEntities(String(value))
            }
            return attributes
        }
    }

    // MARK: - Builder

    /// Collects runs into paragraphs and normalises whitespace the way a browser would.
    private struct Builder {
        private var paragraphs: [RichParagraph] = []
        private var current: [RichRun] = []
        /// Whether the last appended character was whitespace (or nothing yet).
        private var trailingSpace = true

        mutating func append(_ raw: String, style: RichRun.Style, link: RichLink?) {
            var text = ""
            text.reserveCapacity(raw.count)
            for character in raw {
                if character.isWhitespace && character != "\u{00A0}" {
                    if !trailingSpace {
                        text.append(" ")
                        trailingSpace = true
                    }
                } else {
                    text.append(character)
                    trailingSpace = false
                }
            }
            guard !text.isEmpty else { return }
            if var last = current.last, last.style == style, last.link == link {
                last.text += text
                current[current.count - 1] = last
            } else {
                current.append(RichRun(text: text, style: style, link: link))
            }
        }

        mutating func lineBreak() {
            trimTrailingSpace()
            guard !current.isEmpty else { return }
            if var last = current.last {
                last.text += "\n"
                current[current.count - 1] = last
            }
            trailingSpace = true
        }

        mutating func paragraphBreak() {
            trimTrailingSpace()
            // Drop runs that hold nothing visible.
            if current.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                if var last = current.last {
                    while last.text.hasSuffix("\n") { last.text.removeLast() }
                    current[current.count - 1] = last
                }
                paragraphs.append(RichParagraph(runs: current))
            }
            current = []
            trailingSpace = true
        }

        private mutating func trimTrailingSpace() {
            guard var last = current.last, last.text.hasSuffix(" ") else { return }
            last.text.removeLast()
            if last.text.isEmpty {
                current.removeLast()
            } else {
                current[current.count - 1] = last
            }
        }

        mutating func result() -> RichText {
            paragraphBreak()
            return RichText(paragraphs: paragraphs)
        }
    }
}
