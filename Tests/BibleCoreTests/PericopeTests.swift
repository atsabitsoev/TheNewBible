import Foundation
import Testing
@testable import BibleCore

/// Checks the bundled data files in TheNewBible/Resources.
struct PericopeTests {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("TheNewBible/Resources")

    static func load() throws -> (VerseCounts, PericopeIndex) {
        let counts = VerseCounts(tsv: try String(contentsOf: resources.appendingPathComponent("versecounts.tsv"), encoding: .utf8))
        let index = PericopeIndex(
            tsv: try String(contentsOf: resources.appendingPathComponent("pericopes.tsv"), encoding: .utf8),
            verseCounts: counts
        )
        return (counts, index)
    }

    @Test func verseCountsCoverEveryChapter() throws {
        let (counts, _) = try Self.load()
        for book in BibleBook.all {
            for chapter in 1...book.chapterCount {
                #expect(counts.count(ChapterID(book: book.id, chapter: chapter)) != nil, "\(book.name) \(chapter)")
            }
        }
        #expect(counts.count(ChapterID(book: 43, chapter: 3)) == 36)
    }

    @Test func pericopesTileEveryBook() throws {
        let (counts, index) = try Self.load()
        #expect(index.pericopes.count > 3000)
        for book in BibleBook.all {
            let pericopes = index.pericopes.filter { $0.start.book == book.id }
            let first = try #require(pericopes.first, "\(book.name)")
            #expect(first.start.chapter == 1 && first.start.verse == 1, "\(book.name)")
            for (current, next) in zip(pericopes, pericopes.dropFirst()) {
                #expect(current.range.end < next.start)
                #expect(current.range.start <= current.range.end)
            }
            let last = try #require(pericopes.last)
            #expect(last.range.end.chapter == book.chapterCount)
            #expect(last.range.end.verse == counts.count(ChapterID(book: book.id, chapter: book.chapterCount)))
        }
    }

    @Test func findsPericopesForVersesAndChapters() throws {
        let (_, index) = try Self.load()
        let beatitudes = try #require(index.pericope(containing: VerseRef(book: 40, chapter: 5, verse: 5)))
        #expect(beatitudes.title == "Заповеди блаженства")
        #expect(beatitudes.range.title == "Мф 5:3–12")

        let sermon = try #require(index.pericope(containing: VerseRef(book: 40, chapter: 5, verse: 1)))
        #expect(sermon.title == "Нагорная проповедь")

        let headings = index.headings(in: ChapterID(book: 40, chapter: 5))
        #expect(headings[3]?.title == "Заповеди блаженства")
        #expect(headings[2] == nil)

        // Psalms use Synodal numbering: Psalm 22 is "The Lord is my shepherd".
        let psalm = try #require(index.headings(in: ChapterID(book: 19, chapter: 22))[1])
        #expect(psalm.title == "Господь — Пастырь мой")
        #expect(psalm.range.end == VerseRef(book: 19, chapter: 22, verse: 6))
    }

    @Test func clampsRanges() throws {
        let (counts, _) = try Self.load()
        let wholeChapter = try #require(AzbykaReference.parse("Jn.3"))
        let clamped = counts.clamp(wholeChapter)
        #expect(clamped.end == VerseRef(book: 43, chapter: 3, verse: 36))
    }
}
