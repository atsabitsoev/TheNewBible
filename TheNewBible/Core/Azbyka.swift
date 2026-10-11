import Foundation

/// One author's commentary on a verse or passage, as published on azbyka.ru.
public struct Commentary: Identifiable, Hashable, Codable, Sendable {
    /// Anchor of the commentary on the azbyka.ru page, unique per page.
    public var id: String
    /// "Иоанн Златоуст, свт."
    public var author: String
    /// "†407", if the page gives it.
    public var lifetime: String?
    public var text: RichText
    /// Title of the work the commentary is taken from.
    public var sourceTitle: String?
    public var sourceURL: URL?
    /// The azbyka.ru page with this commentary.
    public var pageURL: URL?

    public init(id: String, author: String, lifetime: String?, text: RichText,
                sourceTitle: String?, sourceURL: URL?, pageURL: URL?) {
        self.id = id
        self.author = author
        self.lifetime = lifetime
        self.text = text
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.pageURL = pageURL
    }

    /// The first sentences, for lists.
    public var preview: String {
        let plain = text.plainText.replacingOccurrences(of: "\n", with: " ")
        guard plain.count > 220 else { return plain }
        return String(plain.prefix(220)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

/// Endpoints and HTML parsing for azbyka.ru ("Азбука веры"):
/// the translation of bishop Kassian and the commentaries.
public enum Azbyka {
    public static let base = URL(string: "https://azbyka.ru/biblia/")!

    /// Chapter page in the Kassian translation (language code `b`).
    public static func kassianURL(_ chapter: ChapterID) -> URL? {
        guard let book = chapter.bibleBook else { return nil }
        return URL(string: "https://azbyka.ru/biblia/?\(book.azbykaCode).\(chapter.chapter)&b")
    }

    /// Page with commentaries on a verse or a passage.
    public static func commentaryURL(_ range: VerseRange) -> URL? {
        URL(string: "https://azbyka.ru/biblia/in/?\(range.azbykaQuery)")
    }

    /// Reading page for a range in the Synodal translation, for "open in browser".
    public static func readingURL(_ range: VerseRange) -> URL? {
        URL(string: "https://azbyka.ru/biblia/?\(range.azbykaQuery)&r")
    }

    // MARK: Kassian

    /// Extracts verses from a chapter page:
    /// `<div data-lang="b" data-chapter="3" data-line="16" … class="verse lang-b …">text<span …></span></div>`.
    public static func parseVerses(html: String, chapter: Int, languageCode: String = "b") -> [Verse] {
        var verses: [Verse] = []
        let marker = "data-lang=\"\(languageCode)\""
        var searchStart = html.startIndex
        while let markerRange = html.range(of: marker, range: searchStart..<html.endIndex) {
            searchStart = markerRange.upperBound
            guard let tagStart = html[..<markerRange.lowerBound].lastIndex(of: "<"),
                  let tagEnd = html[markerRange.upperBound...].firstIndex(of: ">")
            else { continue }
            let tag = html[tagStart..<tagEnd]
            guard tag.hasPrefix("<div"), tag.contains("class=\"verse"),
                  attribute("data-chapter", in: tag).flatMap(Int.init) == chapter,
                  let number = attribute("data-line", in: tag).flatMap(Int.init)
            else { continue }
            let contentStart = html.index(after: tagEnd)
            guard let contentEnd = closingDiv(in: html, from: contentStart) else { continue }
            let text = HTMLText.plain(String(html[contentStart..<contentEnd]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, !verses.contains(where: { $0.number == number }) {
                verses.append(Verse(number: number, text: text))
            }
            searchStart = contentEnd
        }
        return verses.sorted { $0.number < $1.number }
    }

    // MARK: Commentaries

    /// Extracts the commentaries from an `/biblia/in/?…` page. Each one is
    /// `<div class="interpretation"><h2 id="…">Author …</h2><div class="interp-content">…</div>
    /// <p class="interp-src"><a class="interp-src__link" href="…">Work</a></p></div>`.
    public static func parseCommentaries(html: String, pageURL: URL?) -> [Commentary] {
        let opening = "<div class=\"interpretation\">"
        var starts: [String.Index] = []
        var searchStart = html.startIndex
        while let range = html.range(of: opening, range: searchStart..<html.endIndex) {
            starts.append(range.lowerBound)
            searchStart = range.upperBound
        }
        let pageEnd = html.range(of: "bottom-menu-container")?.lowerBound ?? html.endIndex

        var result: [Commentary] = []
        for (i, start) in starts.enumerated() {
            var end = i + 1 < starts.count ? starts[i + 1] : pageEnd
            if end < start { end = html.endIndex }
            let block = html[start..<end]

            guard let h2Start = block.range(of: "<h2"),
                  let h2TagEnd = block[h2Start.upperBound...].firstIndex(of: ">"),
                  let h2End = block.range(of: "</h2>", range: h2TagEnd..<block.endIndex)
            else { continue }
            let h2Tag = block[h2Start.lowerBound..<h2TagEnd]
            let heading = HTMLText.plain(String(block[block.index(after: h2TagEnd)..<h2End.lowerBound]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heading.isEmpty else { continue }
            let (author, lifetime) = splitLifetime(heading)
            let anchor = attribute("id", in: h2Tag) ?? "commentary-\(result.count)"

            let contentMarker = "class=\"interp-content\">"
            guard let contentStart = block.range(of: contentMarker, range: h2End.upperBound..<block.endIndex)
            else { continue }
            let sourceStart = block.range(of: "<p class=\"interp-src\"", range: contentStart.upperBound..<block.endIndex)
            let contentHTML = String(block[contentStart.upperBound..<(sourceStart?.lowerBound ?? block.endIndex)])
            let text = HTMLText.parse(contentHTML, base: base)
            guard !text.isEmpty else { continue }

            var sourceTitle: String?
            var sourceURL: URL?
            if let sourceStart,
               let linkStart = block.range(of: "<a", range: sourceStart.upperBound..<block.endIndex),
               let linkTagEnd = block[linkStart.upperBound...].firstIndex(of: ">"),
               let linkEnd = block.range(of: "</a>", range: linkTagEnd..<block.endIndex) {
                let linkTag = block[linkStart.lowerBound..<linkTagEnd]
                if let href = attribute("href", in: linkTag), !href.isEmpty {
                    sourceURL = URL(string: href, relativeTo: base)?.absoluteURL
                }
                let title = HTMLText.plain(String(block[block.index(after: linkTagEnd)..<linkEnd.lowerBound]))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sourceTitle = title.isEmpty ? nil : title
            }

            let page = pageURL.flatMap { URL(string: "#\(anchor)", relativeTo: $0)?.absoluteURL }
            result.append(Commentary(id: anchor, author: author, lifetime: lifetime, text: text,
                                     sourceTitle: sourceTitle, sourceURL: sourceURL, pageURL: page))
        }
        return result
    }

    /// "Иоанн Златоуст, свт. (†407)" → ("Иоанн Златоуст, свт.", "†407")
    static func splitLifetime(_ heading: String) -> (String, String?) {
        guard heading.hasSuffix(")"), let open = heading.lastIndex(of: "(") else { return (heading, nil) }
        let inside = heading[heading.index(after: open)..<heading.index(before: heading.endIndex)]
        guard inside.contains("†") else { return (heading, nil) }
        let author = heading[..<open].trimmingCharacters(in: .whitespaces)
        return (author, String(inside))
    }

    // MARK: Helpers

    /// Value of an attribute inside a tag, quoted with " or '.
    static func attribute(_ name: String, in tag: Substring) -> String? {
        for quote in ["\"", "'"] {
            let needle = " \(name)=\(quote)"
            guard let range = tag.range(of: needle) else { continue }
            let rest = tag[range.upperBound...]
            guard let end = rest.firstIndex(of: Character(quote)) else { continue }
            return HTMLText.decodeEntities(String(rest[..<end]))
        }
        return nil
    }

    /// Finds the `</div>` that closes a `<div>` whose content starts at `from`.
    static func closingDiv(in html: String, from: String.Index) -> String.Index? {
        var depth = 1
        var index = from
        while let next = html.range(of: "<", range: index..<html.endIndex) {
            let rest = html[next.lowerBound...]
            if rest.hasPrefix("</div") {
                depth -= 1
                if depth == 0 { return next.lowerBound }
            } else if rest.hasPrefix("<div") {
                depth += 1
            }
            index = next.upperBound
        }
        return nil
    }
}
