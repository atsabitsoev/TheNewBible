import Foundation

/// Translations available in the reader.
public enum Translation: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Синодальный перевод (1876), public domain.
    case synodal
    /// Перевод епископа Кассиана (Безобразова), New Testament only.
    case kassian
    /// Новый русский перевод (Biblica).
    case nrt

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .synodal: "Синодальный"
        case .kassian: "Еп. Кассиан"
        case .nrt: "НРП"
        }
    }

    public var fullTitle: String {
        switch self {
        case .synodal: "Синодальный перевод"
        case .kassian: "Перевод еп. Кассиана (Безобразова)"
        case .nrt: "Новый русский перевод"
        }
    }

    /// Compact label for toolbars.
    public var shortTitle: String {
        switch self {
        case .synodal: "СП"
        case .kassian: "Кас"
        case .nrt: "НРП"
        }
    }

    /// Where the text is loaded from, shown in the reader footer.
    public var sourceName: String {
        switch self {
        case .synodal, .nrt: "bolls.life"
        case .kassian: "azbyka.ru"
        }
    }

    /// The translation of bishop Kassian covers the New Testament only.
    public func contains(_ book: BibleBook) -> Bool {
        self != .kassian || book.testament == .new
    }
}

public struct Verse: Identifiable, Hashable, Codable, Sendable {
    public var number: Int
    public var text: String

    public var id: Int { number }

    public init(number: Int, text: String) {
        self.number = number
        self.text = text
    }
}

public struct ChapterText: Hashable, Codable, Sendable {
    public var translation: Translation
    public var chapter: ChapterID
    public var verses: [Verse]

    public init(translation: Translation, chapter: ChapterID, verses: [Verse]) {
        self.translation = translation
        self.chapter = chapter
        self.verses = verses
    }

    public func verse(_ number: Int) -> Verse? {
        verses.first { $0.number == number }
    }
}
