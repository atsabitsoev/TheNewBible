import Foundation

public enum Testament: String, Codable, Sendable {
    case old
    case new
}

/// One of the 66 canonical books.
///
/// `id` follows the Protestant order (1 — Genesis, 40 — Matthew, 66 — Revelation),
/// the numbering bolls.life uses. Russian Bibles print the New Testament in a
/// different order (the general epistles follow Acts), see ``synodalOrder``.
public struct BibleBook: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let abbreviation: String
    /// Book code used by azbyka.ru links, e.g. `Jn` in `?Jn.3:16`.
    public let azbykaCode: String
    /// Number of chapters in the Synodal translation (the largest of the three).
    public let chapterCount: Int

    public var testament: Testament { id >= 40 ? .new : .old }

    public static func book(_ id: Int) -> BibleBook? {
        guard id >= 1, id <= all.count else { return nil }
        return all[id - 1]
    }

    public static func book(azbykaCode code: String) -> BibleBook? {
        all.first { $0.azbykaCode.caseInsensitiveCompare(code) == .orderedSame }
    }

    public static let all: [BibleBook] = [
        BibleBook(id: 1, name: "Бытие", abbreviation: "Быт", azbykaCode: "Gen", chapterCount: 50),
        BibleBook(id: 2, name: "Исход", abbreviation: "Исх", azbykaCode: "Ex", chapterCount: 40),
        BibleBook(id: 3, name: "Левит", abbreviation: "Лев", azbykaCode: "Lev", chapterCount: 27),
        BibleBook(id: 4, name: "Числа", abbreviation: "Чис", azbykaCode: "Num", chapterCount: 36),
        BibleBook(id: 5, name: "Второзаконие", abbreviation: "Втор", azbykaCode: "Deut", chapterCount: 34),
        BibleBook(id: 6, name: "Иисус Навин", abbreviation: "Нав", azbykaCode: "Nav", chapterCount: 24),
        BibleBook(id: 7, name: "Судьи", abbreviation: "Суд", azbykaCode: "Judg", chapterCount: 21),
        BibleBook(id: 8, name: "Руфь", abbreviation: "Руфь", azbykaCode: "Rth", chapterCount: 4),
        BibleBook(id: 9, name: "1-я Царств", abbreviation: "1Цар", azbykaCode: "1Sam", chapterCount: 31),
        BibleBook(id: 10, name: "2-я Царств", abbreviation: "2Цар", azbykaCode: "2Sam", chapterCount: 24),
        BibleBook(id: 11, name: "3-я Царств", abbreviation: "3Цар", azbykaCode: "1King", chapterCount: 22),
        BibleBook(id: 12, name: "4-я Царств", abbreviation: "4Цар", azbykaCode: "2King", chapterCount: 25),
        BibleBook(id: 13, name: "1-я Паралипоменон", abbreviation: "1Пар", azbykaCode: "1Chron", chapterCount: 29),
        BibleBook(id: 14, name: "2-я Паралипоменон", abbreviation: "2Пар", azbykaCode: "2Chron", chapterCount: 36),
        BibleBook(id: 15, name: "Ездра", abbreviation: "Езд", azbykaCode: "Ezr", chapterCount: 10),
        BibleBook(id: 16, name: "Неемия", abbreviation: "Неем", azbykaCode: "Nehem", chapterCount: 13),
        BibleBook(id: 17, name: "Есфирь", abbreviation: "Есф", azbykaCode: "Est", chapterCount: 10),
        BibleBook(id: 18, name: "Иов", abbreviation: "Иов", azbykaCode: "Job", chapterCount: 42),
        BibleBook(id: 19, name: "Псалтирь", abbreviation: "Пс", azbykaCode: "Ps", chapterCount: 151),
        BibleBook(id: 20, name: "Притчи", abbreviation: "Притч", azbykaCode: "Prov", chapterCount: 31),
        BibleBook(id: 21, name: "Екклесиаст", abbreviation: "Еккл", azbykaCode: "Eccl", chapterCount: 12),
        BibleBook(id: 22, name: "Песнь песней", abbreviation: "Песн", azbykaCode: "Song", chapterCount: 8),
        BibleBook(id: 23, name: "Исаия", abbreviation: "Ис", azbykaCode: "Is", chapterCount: 66),
        BibleBook(id: 24, name: "Иеремия", abbreviation: "Иер", azbykaCode: "Jer", chapterCount: 52),
        BibleBook(id: 25, name: "Плач Иеремии", abbreviation: "Плач", azbykaCode: "Lam", chapterCount: 5),
        BibleBook(id: 26, name: "Иезекииль", abbreviation: "Иез", azbykaCode: "Ezek", chapterCount: 48),
        BibleBook(id: 27, name: "Даниил", abbreviation: "Дан", azbykaCode: "Dan", chapterCount: 14),
        BibleBook(id: 28, name: "Осия", abbreviation: "Ос", azbykaCode: "Hos", chapterCount: 14),
        BibleBook(id: 29, name: "Иоиль", abbreviation: "Иоил", azbykaCode: "Joel", chapterCount: 3),
        BibleBook(id: 30, name: "Амос", abbreviation: "Ам", azbykaCode: "Am", chapterCount: 9),
        BibleBook(id: 31, name: "Авдий", abbreviation: "Авд", azbykaCode: "Avd", chapterCount: 1),
        BibleBook(id: 32, name: "Иона", abbreviation: "Иона", azbykaCode: "Jona", chapterCount: 4),
        BibleBook(id: 33, name: "Михей", abbreviation: "Мих", azbykaCode: "Mic", chapterCount: 7),
        BibleBook(id: 34, name: "Наум", abbreviation: "Наум", azbykaCode: "Naum", chapterCount: 3),
        BibleBook(id: 35, name: "Аввакум", abbreviation: "Авв", azbykaCode: "Habak", chapterCount: 3),
        BibleBook(id: 36, name: "Софония", abbreviation: "Соф", azbykaCode: "Sofon", chapterCount: 3),
        BibleBook(id: 37, name: "Аггей", abbreviation: "Агг", azbykaCode: "Hag", chapterCount: 2),
        BibleBook(id: 38, name: "Захария", abbreviation: "Зах", azbykaCode: "Zah", chapterCount: 14),
        BibleBook(id: 39, name: "Малахия", abbreviation: "Мал", azbykaCode: "Mal", chapterCount: 4),
        BibleBook(id: 40, name: "От Матфея", abbreviation: "Мф", azbykaCode: "Mt", chapterCount: 28),
        BibleBook(id: 41, name: "От Марка", abbreviation: "Мк", azbykaCode: "Mk", chapterCount: 16),
        BibleBook(id: 42, name: "От Луки", abbreviation: "Лк", azbykaCode: "Lk", chapterCount: 24),
        BibleBook(id: 43, name: "От Иоанна", abbreviation: "Ин", azbykaCode: "Jn", chapterCount: 21),
        BibleBook(id: 44, name: "Деяния", abbreviation: "Деян", azbykaCode: "Act", chapterCount: 28),
        BibleBook(id: 45, name: "Римлянам", abbreviation: "Рим", azbykaCode: "Rom", chapterCount: 16),
        BibleBook(id: 46, name: "1-е Коринфянам", abbreviation: "1Кор", azbykaCode: "1Cor", chapterCount: 16),
        BibleBook(id: 47, name: "2-е Коринфянам", abbreviation: "2Кор", azbykaCode: "2Cor", chapterCount: 13),
        BibleBook(id: 48, name: "Галатам", abbreviation: "Гал", azbykaCode: "Gal", chapterCount: 6),
        BibleBook(id: 49, name: "Ефесянам", abbreviation: "Еф", azbykaCode: "Eph", chapterCount: 6),
        BibleBook(id: 50, name: "Филиппийцам", abbreviation: "Флп", azbykaCode: "Phil", chapterCount: 4),
        BibleBook(id: 51, name: "Колоссянам", abbreviation: "Кол", azbykaCode: "Col", chapterCount: 4),
        BibleBook(id: 52, name: "1-е Фессалоникийцам", abbreviation: "1Фес", azbykaCode: "1Thes", chapterCount: 5),
        BibleBook(id: 53, name: "2-е Фессалоникийцам", abbreviation: "2Фес", azbykaCode: "2Thes", chapterCount: 3),
        BibleBook(id: 54, name: "1-е Тимофею", abbreviation: "1Тим", azbykaCode: "1Tim", chapterCount: 6),
        BibleBook(id: 55, name: "2-е Тимофею", abbreviation: "2Тим", azbykaCode: "2Tim", chapterCount: 4),
        BibleBook(id: 56, name: "Титу", abbreviation: "Тит", azbykaCode: "Tit", chapterCount: 3),
        BibleBook(id: 57, name: "Филимону", abbreviation: "Флм", azbykaCode: "Phlm", chapterCount: 1),
        BibleBook(id: 58, name: "Евреям", abbreviation: "Евр", azbykaCode: "Hebr", chapterCount: 13),
        BibleBook(id: 59, name: "Иакова", abbreviation: "Иак", azbykaCode: "Jac", chapterCount: 5),
        BibleBook(id: 60, name: "1-е Петра", abbreviation: "1Пет", azbykaCode: "1Pet", chapterCount: 5),
        BibleBook(id: 61, name: "2-е Петра", abbreviation: "2Пет", azbykaCode: "2Pet", chapterCount: 3),
        BibleBook(id: 62, name: "1-е Иоанна", abbreviation: "1Ин", azbykaCode: "1Jn", chapterCount: 5),
        BibleBook(id: 63, name: "2-е Иоанна", abbreviation: "2Ин", azbykaCode: "2Jn", chapterCount: 1),
        BibleBook(id: 64, name: "3-е Иоанна", abbreviation: "3Ин", azbykaCode: "3Jn", chapterCount: 1),
        BibleBook(id: 65, name: "Иуды", abbreviation: "Иуд", azbykaCode: "Juda", chapterCount: 1),
        BibleBook(id: 66, name: "Откровение", abbreviation: "Откр", azbykaCode: "Apok", chapterCount: 22),
    ]

    /// Book order of Russian Bibles: Gospels, Acts, general epistles, Pauline epistles, Revelation.
    public static let synodalOrder: [BibleBook] = {
        let order = Array(1...44) + Array(59...65) + Array(45...58) + [66]
        return order.map { all[$0 - 1] }
    }()

    public static var oldTestament: [BibleBook] { synodalOrder.filter { $0.testament == .old } }
    public static var newTestament: [BibleBook] { synodalOrder.filter { $0.testament == .new } }
}

/// A chapter of a book, the unit the reader displays.
public struct ChapterID: Hashable, Codable, Sendable {
    public var book: Int
    public var chapter: Int

    public init(book: Int, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }

    public var bibleBook: BibleBook? { BibleBook.book(book) }

    /// The following chapter in Synodal book order, crossing into the next book.
    public var next: ChapterID? {
        guard let current = bibleBook else { return nil }
        if chapter < current.chapterCount { return ChapterID(book: book, chapter: chapter + 1) }
        let order = BibleBook.synodalOrder
        guard let index = order.firstIndex(of: current), index + 1 < order.count else { return nil }
        return ChapterID(book: order[index + 1].id, chapter: 1)
    }

    /// The preceding chapter in Synodal book order, crossing into the previous book.
    public var previous: ChapterID? {
        guard let current = bibleBook else { return nil }
        if chapter > 1 { return ChapterID(book: book, chapter: chapter - 1) }
        let order = BibleBook.synodalOrder
        guard let index = order.firstIndex(of: current), index > 0 else { return nil }
        let book = order[index - 1]
        return ChapterID(book: book.id, chapter: book.chapterCount)
    }
}
