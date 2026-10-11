import Foundation

/// Understands references typed by the reader: "Ин 3:16", "ин3", "1 Кор 13:4",
/// "Бытие 1", "мф 5:3-12", "Откровение".
public enum ReferenceParser {
    public struct Result: Equatable, Sendable {
        public var book: BibleBook
        /// nil when only the book was typed.
        public var chapter: Int?
        public var verse: Int?

        public var verseRef: VerseRef {
            VerseRef(book: book.id, chapter: chapter ?? 1, verse: verse ?? 1)
        }

        public var title: String {
            guard let chapter else { return book.name }
            guard let verse else { return "\(book.abbreviation) \(chapter)" }
            return "\(book.abbreviation) \(chapter):\(verse)"
        }
    }

    public static func parse(_ input: String) -> Result? {
        let text = normalize(input)
        guard !text.isEmpty else { return nil }

        // Split into the book part and the numbers that follow it.
        var bookPart = ""
        var index = text.startIndex
        if let first = text.first, first.isNumber {
            // A leading 1–4 belongs to the book ("1кор").
            bookPart.append(first)
            index = text.index(after: index)
        }
        while index < text.endIndex, text[index].isLetter || text[index] == " " || text[index] == "." {
            bookPart.append(text[index])
            index = text.index(after: index)
        }
        let key = bookPart.filter { $0.isLetter || $0.isNumber }
        guard key.contains(where: \.isLetter), let book = book(for: key) else { return nil }

        let numbers = text[index...]
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        var chapter = numbers.first
        var verse = numbers.count > 1 ? numbers[1] : nil
        if let value = chapter, value < 1 || value > book.chapterCount {
            chapter = nil
            verse = nil
        }
        if let value = verse, value < 1 { verse = nil }
        // One-chapter books: "Иуд 5" means verse 5.
        if book.chapterCount == 1, let value = numbers.first, numbers.count == 1, value > 1 {
            chapter = 1
            verse = value
        }
        return Result(book: book, chapter: chapter, verse: verse)
    }

    private static func normalize(_ input: String) -> String {
        input.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func book(for key: String) -> BibleBook? {
        if let exact = BibleBook.synodalOrder.first(where: { aliases($0).first == key }) {
            return exact
        }
        if let exact = BibleBook.synodalOrder.first(where: { aliases($0).contains(key) }) {
            return exact
        }
        guard key.count >= 2 else { return nil }
        return BibleBook.synodalOrder.first { book in
            aliases(book).contains { $0.hasPrefix(key) }
        }
    }

    /// Normalised spellings of a book; the abbreviation comes first.
    private static func aliases(_ book: BibleBook) -> [String] {
        func clean(_ text: String) -> String {
            normalize(text)
                .replacingOccurrences(of: "-е", with: "")
                .replacingOccurrences(of: "-я", with: "")
                .filter { $0.isLetter || $0.isNumber }
        }
        var result = [clean(book.abbreviation), clean(book.name)]
        if book.name.hasPrefix("От ") {
            result.append(clean(String(book.name.dropFirst(3))))
        }
        result += (extraAliases[book.id] ?? []).map(clean)
        return result
    }

    private static let extraAliases: [Int: [String]] = [
        6: ["Иисуса Навина", "Навин"],
        9: ["1 Самуила"], 10: ["2 Самуила"], 11: ["1 Царей"], 12: ["2 Царей"],
        13: ["1 Летопись"], 14: ["2 Летопись"],
        19: ["Псалмы", "Псалом"],
        21: ["Экклезиаст", "Проповедник"],
        22: ["Песня песней"],
        44: ["Деяния апостолов"],
        52: ["1 Фессалоникийцам", "1 Солунянам"], 53: ["2 Фессалоникийцам", "2 Солунянам"],
        59: ["Иаков"], 65: ["Иуда"],
        66: ["Апокалипсис", "Откр"],
    ]
}
