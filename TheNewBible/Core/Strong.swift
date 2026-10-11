import Foundation

/// A Strong's number: "G3056" (Greek, New Testament) or "H7225" (Hebrew, Old Testament).
public struct StrongNumber: Hashable, Codable, Sendable, CustomStringConvertible {
    public enum Language: String, Codable, Sendable {
        case greek = "G"
        case hebrew = "H"
    }

    public var language: Language
    public var number: Int

    public init(language: Language, number: Int) {
        self.language = language
        self.number = number
    }

    /// Accepts "G3056", "h7225", "G03056".
    public init?(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard let first = text.first, let language = Language(rawValue: String(first)),
              let number = Int(text.dropFirst()), number > 0
        else { return nil }
        self.init(language: language, number: number)
    }

    public var description: String { "\(language.rawValue)\(number)" }
}

/// A word of the Greek or Hebrew text with the Strong's numbers attached to it.
public struct OriginalWord: Identifiable, Hashable, Sendable {
    public var id: Int
    public var text: String
    public var numbers: [StrongNumber]

    public init(id: Int, text: String, numbers: [StrongNumber]) {
        self.id = id
        self.text = text
        self.numbers = numbers
    }

    /// The word without trailing punctuation, for display in lists.
    public var bareText: String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces).union(CharacterSet(charactersIn: "׃־·")))
    }
}

public enum OriginalText {
    /// Splits a verse tagged like `λόγος,<S>3056</S> καὶ<S>2532</S>` into words.
    /// Untagged words are kept with an empty number list.
    public static func words(fromTagged text: String, language: StrongNumber.Language) -> [OriginalWord] {
        var words: [OriginalWord] = []
        var pending = ""

        func addUntagged(_ chunk: String) {
            for piece in chunk.split(whereSeparator: \.isWhitespace) {
                words.append(OriginalWord(id: words.count, text: String(piece), numbers: []))
            }
        }

        // Remove markup other than the Strong's tags (<br>, <i>, …).
        let cleaned = text
            .replacingOccurrences(of: "<S>", with: "\u{1}")
            .replacingOccurrences(of: "</S>", with: "\u{2}")
        let plain = HTMLText.decodeEntities(cleaned.replacingOccurrences(
            of: "<[^>]*>", with: " ", options: .regularExpression))

        var index = plain.startIndex
        while index < plain.endIndex {
            let character = plain[index]
            if character == "\u{1}" {
                let numberStart = plain.index(after: index)
                let numberEnd = plain[numberStart...].firstIndex(of: "\u{2}") ?? plain.endIndex
                let digits = plain[numberStart..<numberEnd].filter(\.isNumber)
                if let value = Int(digits), value > 0 {
                    let number = StrongNumber(language: language, number: value)
                    let trimmed = pending.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        // Several numbers for one word: "וְאֵת<S>853</S><S>...</S>".
                        if !words.isEmpty { words[words.count - 1].numbers.append(number) }
                    } else {
                        var pieces = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                        let last = pieces.removeLast()
                        addUntagged(pieces.joined(separator: " "))
                        words.append(OriginalWord(id: words.count, text: last, numbers: [number]))
                    }
                    pending = ""
                }
                index = numberEnd < plain.endIndex ? plain.index(after: numberEnd) : numberEnd
                continue
            }
            pending.append(character)
            index = plain.index(after: index)
        }
        addUntagged(pending)
        return words
    }
}

/// An article of the Russian Strong's lexicon ("Полный лексикон по Стронгу и Дворецкому").
public struct StrongEntry: Hashable, Codable, Sendable, Identifiable {
    public var number: StrongNumber
    /// The lemma in Greek or Hebrew.
    public var lexeme: String
    public var transliteration: String
    public var pronunciation: String
    public var shortDefinition: String
    /// The whole article.
    public var definition: RichText

    public var id: StrongNumber { number }

    public init(number: StrongNumber, lexeme: String, transliteration: String, pronunciation: String,
                shortDefinition: String, definition: RichText) {
        self.number = number
        self.lexeme = lexeme
        self.transliteration = transliteration
        self.pronunciation = pronunciation
        self.shortDefinition = shortDefinition
        self.definition = definition
    }
}
