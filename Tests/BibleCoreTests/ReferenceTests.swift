import Foundation
import Testing
@testable import BibleCore

struct ReferenceTests {
    @Test func formatsVerseAndRanges() {
        let verse = VerseRef(book: 43, chapter: 3, verse: 16)
        #expect(verse.title == "Ин 3:16")
        #expect(verse.azbykaQuery == "Jn.3:16")

        let sameChapter = VerseRange(start: VerseRef(book: 40, chapter: 5, verse: 3),
                                     end: VerseRef(book: 40, chapter: 5, verse: 12))
        #expect(sameChapter.title == "Мф 5:3–12")
        #expect(sameChapter.azbykaQuery == "Mt.5:3-12")

        let crossChapter = VerseRange(start: VerseRef(book: 1, chapter: 1, verse: 1),
                                      end: VerseRef(book: 1, chapter: 2, verse: 3))
        #expect(crossChapter.title == "Быт 1:1–2:3")
        #expect(crossChapter.azbykaQuery == "Gen.1:1-2:3")
        #expect(crossChapter.chapters == [ChapterID(book: 1, chapter: 1), ChapterID(book: 1, chapter: 2)])
    }

    @Test func parsesAzbykaQueries() throws {
        let single = try #require(AzbykaReference.parse("1Cor.1:13"))
        #expect(single == VerseRange(VerseRef(book: 46, chapter: 1, verse: 13)))

        let range = try #require(AzbykaReference.parse("Mt.5:3-12&utfcs"))
        #expect(range.start == VerseRef(book: 40, chapter: 5, verse: 3))
        #expect(range.end == VerseRef(book: 40, chapter: 5, verse: 12))

        let cross = try #require(AzbykaReference.parse("Gen.1:1-2:3"))
        #expect(cross.end == VerseRef(book: 1, chapter: 2, verse: 3))

        let list = try #require(AzbykaReference.parse("Ps.22:1,3"))
        #expect(list == VerseRange(VerseRef(book: 19, chapter: 22, verse: 1)))

        let chapter = try #require(AzbykaReference.parse("Jn.3"))
        #expect(chapter.start == VerseRef(book: 43, chapter: 3, verse: 1))
        #expect(chapter.end.chapter == 3)

        #expect(AzbykaReference.parse("Unknown.1:1") == nil)
        #expect(AzbykaReference.parse("nonsense") == nil)
    }

    @Test func parsesAzbykaURLs() throws {
        let url = try #require(URL(string: "https://azbyka.ru/biblia/?Jn.3:16-18"))
        let range = try #require(AzbykaReference.parse(url: url))
        #expect(range.title == "Ин 3:16–18")
        // Commentary pages are not references to open in the reader.
        let commentary = try #require(URL(string: "https://azbyka.ru/biblia/in/?Jn.3:16"))
        #expect(AzbykaReference.parse(url: commentary) == nil)
        let other = try #require(URL(string: "https://example.com/?Jn.3:16"))
        #expect(AzbykaReference.parse(url: other) == nil)
    }

    @Test func navigatesChaptersInSynodalOrder() {
        #expect(ChapterID(book: 1, chapter: 1).next == ChapterID(book: 1, chapter: 2))
        #expect(ChapterID(book: 1, chapter: 50).next == ChapterID(book: 2, chapter: 1))
        // Acts is followed by James in Russian Bibles.
        #expect(ChapterID(book: 44, chapter: 28).next == ChapterID(book: 59, chapter: 1))
        #expect(ChapterID(book: 59, chapter: 1).previous == ChapterID(book: 44, chapter: 28))
        #expect(ChapterID(book: 65, chapter: 1).next == ChapterID(book: 45, chapter: 1))
        #expect(ChapterID(book: 58, chapter: 13).next == ChapterID(book: 66, chapter: 1))
        #expect(ChapterID(book: 66, chapter: 22).next == nil)
        #expect(ChapterID(book: 1, chapter: 1).previous == nil)
        #expect(BibleBook.synodalOrder.count == 66)
        #expect(Set(BibleBook.synodalOrder.map(\.id)).count == 66)
    }

    @Test func mapsSynodalNumberingToOriginal() {
        func map(_ book: Int, _ chapter: Int, _ verse: Int) -> VerseRef? {
            Versification.originalPosition(for: VerseRef(book: book, chapter: chapter, verse: verse))
        }
        // Psalm 22 (Synodal) is Psalm 23 in Hebrew.
        #expect(map(19, 22, 1) == VerseRef(book: 19, chapter: 23, verse: 1))
        #expect(map(19, 9, 22) == VerseRef(book: 19, chapter: 10, verse: 1))
        #expect(map(19, 115, 1) == VerseRef(book: 19, chapter: 116, verse: 10))
        #expect(map(19, 147, 1) == VerseRef(book: 19, chapter: 147, verse: 12))
        #expect(map(19, 151, 1) == nil)
        #expect(map(29, 2, 28) == VerseRef(book: 29, chapter: 3, verse: 1))
        #expect(map(39, 4, 1) == VerseRef(book: 39, chapter: 3, verse: 19))
        #expect(map(27, 3, 50) == nil)
        #expect(map(27, 3, 91) == VerseRef(book: 27, chapter: 3, verse: 24))
        #expect(map(45, 14, 24) == VerseRef(book: 45, chapter: 16, verse: 25))
        #expect(map(43, 3, 16) == VerseRef(book: 43, chapter: 3, verse: 16))
    }
}

struct ReferenceParserTests {
    @Test func parsesTypedReferences() throws {
        let john = try #require(ReferenceParser.parse("Ин 3:16"))
        #expect(john.verseRef == VerseRef(book: 43, chapter: 3, verse: 16))
        #expect(john.title == "Ин 3:16")

        #expect(ReferenceParser.parse("ин3")?.verseRef == VerseRef(book: 43, chapter: 3, verse: 1))
        #expect(ReferenceParser.parse("1 Кор 13:4")?.verseRef == VerseRef(book: 46, chapter: 13, verse: 4))
        #expect(ReferenceParser.parse("1кор.13")?.book.id == 46)
        #expect(ReferenceParser.parse("Бытие 1")?.verseRef == VerseRef(book: 1, chapter: 1, verse: 1))
        #expect(ReferenceParser.parse("мф 5:3-12")?.verseRef == VerseRef(book: 40, chapter: 5, verse: 3))
        #expect(ReferenceParser.parse("Матфея 5")?.book.id == 40)
        #expect(ReferenceParser.parse("пс 22")?.verseRef == VerseRef(book: 19, chapter: 22, verse: 1))
        #expect(ReferenceParser.parse("Иов 1")?.book.id == 18)
        #expect(ReferenceParser.parse("ис 53")?.book.id == 23)
        #expect(ReferenceParser.parse("Откровение")?.chapter == nil)
        #expect(ReferenceParser.parse("Апокалипсис 1")?.book.id == 66)
        #expect(ReferenceParser.parse("Иуд 5")?.verseRef == VerseRef(book: 65, chapter: 1, verse: 5))
        #expect(ReferenceParser.parse("1 ин 4:8")?.verseRef == VerseRef(book: 62, chapter: 4, verse: 8))
        // A chapter that does not exist is dropped.
        #expect(ReferenceParser.parse("Ин 99")?.chapter == nil)
        #expect(ReferenceParser.parse("") == nil)
        #expect(ReferenceParser.parse("123") == nil)
        #expect(ReferenceParser.parse("абракадабра 1") == nil)
    }
}
