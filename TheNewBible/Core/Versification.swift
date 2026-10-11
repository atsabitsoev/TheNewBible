import Foundation

/// Converts Synodal verse numbers to the numbering of the original-language
/// texts (Westminster Leningrad Codex, Tischendorf).
///
/// Only the most noticeable differences are handled: the Psalms (Synodal
/// follows the Septuagint numbering), the chapter breaks of Joel and Malachi,
/// the Greek additions to Daniel and the doxology of Romans. Elsewhere the
/// numbers are kept as they are; the UI lets the reader step to a
/// neighbouring verse when the two texts are out of step.
public enum Versification {
    public static func originalPosition(for verse: VerseRef) -> VerseRef? {
        let book = verse.book
        let chapter = verse.chapter
        let number = verse.verse
        func ref(_ c: Int, _ v: Int) -> VerseRef { VerseRef(book: book, chapter: c, verse: v) }

        switch book {
        case 19:
            return psalm(chapter, number).map { ref($0.0, $0.1) }
        case 27: // Daniel
            if chapter >= 13 { return nil }
            if chapter == 3 {
                if number <= 23 { return ref(3, number) }
                if number <= 90 { return nil } // Prayer of Azariah and Song of the Three — Greek only.
                return ref(3, number - 67)
            }
            return verse
        case 29: // Joel
            if chapter == 2 && number >= 28 { return ref(3, number - 27) }
            if chapter == 3 { return ref(4, number) }
            return verse
        case 39: // Malachi
            if chapter == 4 { return ref(3, number + 18) }
            return verse
        case 45: // Romans
            if chapter == 14 && number >= 24 { return ref(16, number + 1) }
            return verse
        default:
            return verse
        }
    }

    /// Synodal psalm → Hebrew psalm. Both count the superscription as verse 1.
    static func psalm(_ psalm: Int, _ verse: Int) -> (Int, Int)? {
        switch psalm {
        case 1...8: (psalm, verse)
        case 9: verse <= 21 ? (9, verse) : (10, verse - 21)
        case 10...112: (psalm + 1, verse)
        case 113: verse <= 8 ? (114, verse) : (115, verse - 8)
        case 114: (116, verse)
        case 115: (116, verse + 9)
        case 116...145: (psalm + 1, verse)
        case 146: (147, verse)
        case 147: (147, verse + 11)
        case 148...150: (psalm, verse)
        default: nil // Psalm 151 has no Hebrew original.
        }
    }
}
