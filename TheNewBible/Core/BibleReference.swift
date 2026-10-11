import Foundation

/// A single verse: book, chapter and verse number (Synodal numbering).
public struct VerseRef: Hashable, Codable, Sendable, Comparable {
    public var book: Int
    public var chapter: Int
    public var verse: Int

    public init(book: Int, chapter: Int, verse: Int) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }

    public var chapterID: ChapterID { ChapterID(book: book, chapter: chapter) }
    public var bibleBook: BibleBook? { BibleBook.book(book) }

    public static func < (lhs: VerseRef, rhs: VerseRef) -> Bool {
        (lhs.book, lhs.chapter, lhs.verse) < (rhs.book, rhs.chapter, rhs.verse)
    }

    /// "Ин 3:16"
    public var title: String {
        "\(bibleBook?.abbreviation ?? "?") \(chapter):\(verse)"
    }

    /// "Jn.3:16" — the query azbyka.ru understands.
    public var azbykaQuery: String {
        "\(bibleBook?.azbykaCode ?? "Gen").\(chapter):\(verse)"
    }
}

/// An inclusive range of verses, possibly spanning several chapters of one book.
public struct VerseRange: Hashable, Codable, Sendable {
    public var start: VerseRef
    public var end: VerseRef

    public init(start: VerseRef, end: VerseRef) {
        self.start = start
        self.end = max(start, end)
    }

    public init(_ verse: VerseRef) {
        self.init(start: verse, end: verse)
    }

    public var isSingleVerse: Bool { start == end }
    public var bibleBook: BibleBook? { start.bibleBook }

    public func contains(_ verse: VerseRef) -> Bool {
        start <= verse && verse <= end
    }

    /// Chapters covered by the range, in order.
    public var chapters: [ChapterID] {
        guard start.book == end.book else { return [start.chapterID] }
        return (start.chapter...end.chapter).map { ChapterID(book: start.book, chapter: $0) }
    }

    /// "Мф 5:3–12", "Быт 1:1–2:3", "Ин 3:16"
    public var title: String {
        let name = bibleBook?.abbreviation ?? "?"
        if isSingleVerse { return start.title }
        if start.chapter == end.chapter {
            return "\(name) \(start.chapter):\(start.verse)–\(end.verse)"
        }
        return "\(name) \(start.chapter):\(start.verse)–\(end.chapter):\(end.verse)"
    }

    /// "Mt.5:3-12", "Gen.1:1-2:3"
    public var azbykaQuery: String {
        let code = bibleBook?.azbykaCode ?? "Gen"
        if isSingleVerse { return start.azbykaQuery }
        if start.chapter == end.chapter {
            return "\(code).\(start.chapter):\(start.verse)-\(end.verse)"
        }
        return "\(code).\(start.chapter):\(start.verse)-\(end.chapter):\(end.verse)"
    }
}

public enum AzbykaReference {
    /// Parses the query part of an azbyka.ru Bible link, e.g. `1Cor.1:13`,
    /// `Mt.5:3-12`, `Gen.1:1-2:3`, `Jn.3` or `Ps.22:1,3&utfcs`.
    /// Returns nil for anything that is not a recognisable reference.
    public static func parse(_ query: String) -> VerseRange? {
        var text = query
        if let amp = text.firstIndex(of: "&") { text = String(text[..<amp]) }
        text = text.removingPercentEncoding ?? text
        guard let dot = text.firstIndex(of: ".") else { return nil }
        let code = String(text[..<dot])
        guard let book = BibleBook.book(azbykaCode: code) else { return nil }
        var rest = String(text[text.index(after: dot)...])
        // Only the first part of lists like "1:1,3" or "1:1;2:5" is used.
        if let separator = rest.firstIndex(where: { $0 == "," || $0 == ";" }) {
            rest = String(rest[..<separator])
        }
        let parts = rest.split(separator: "-", maxSplits: 1).map(String.init)
        guard let first = parts.first, let start = position(first, defaultChapter: nil) else { return nil }
        let startRef = VerseRef(book: book.id, chapter: start.chapter, verse: start.verse ?? 1)
        guard parts.count == 2, let end = position(parts[1], defaultChapter: start.chapter) else {
            if start.verse == nil {
                // A whole chapter.
                return VerseRange(start: startRef, end: VerseRef(book: book.id, chapter: start.chapter, verse: 999))
            }
            return VerseRange(startRef)
        }
        let endChapter: Int
        let endVerse: Int
        if parts[1].contains(":") {
            endChapter = end.chapter
            endVerse = end.verse ?? 999
        } else if start.verse == nil {
            // "Jn.3-4": chapters 3 to 4.
            endChapter = end.chapter
            endVerse = 999
        } else {
            // "Mt.5:3-12": the number after the dash is a verse.
            endChapter = start.chapter
            endVerse = end.chapter
        }
        return VerseRange(start: startRef, end: VerseRef(book: book.id, chapter: endChapter, verse: endVerse))
    }

    private static func position(_ text: String, defaultChapter: Int?) -> (chapter: Int, verse: Int?)? {
        let pieces = text.split(separator: ":", maxSplits: 1)
        guard let chapter = Int(pieces[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        if pieces.count == 2 {
            let digits = pieces[1].prefix { $0.isNumber }
            guard let verse = Int(digits) else { return nil }
            return (chapter, verse)
        }
        return (chapter, nil)
    }

    /// Extracts a reference from a full azbyka.ru Bible URL such as
    /// `https://azbyka.ru/biblia/?1Cor.1:13`.
    public static func parse(url: URL) -> VerseRange? {
        guard let host = url.host, host.hasSuffix("azbyka.ru"),
              url.path.hasPrefix("/biblia"), !url.path.hasPrefix("/biblia/in"),
              let query = url.query, !query.isEmpty
        else { return nil }
        return parse(query)
    }
}
