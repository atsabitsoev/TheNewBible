import Foundation

/// Number of verses in every Synodal chapter, loaded from `versecounts.tsv`.
public struct VerseCounts: Sendable {
    private var counts: [ChapterID: Int]

    public init(tsv: String) {
        var counts: [ChapterID: Int] = [:]
        for line in tsv.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t")
            guard fields.count == 3,
                  let book = Int(fields[0]), let chapter = Int(fields[1]), let count = Int(fields[2])
            else { continue }
            counts[ChapterID(book: book, chapter: chapter)] = count
        }
        self.counts = counts
    }

    public func count(_ chapter: ChapterID) -> Int? {
        counts[chapter]
    }

    /// Keeps the range inside existing chapters and verses.
    public func clamp(_ range: VerseRange) -> VerseRange {
        func clamp(_ ref: VerseRef) -> VerseRef {
            var ref = ref
            if let book = ref.bibleBook { ref.chapter = min(max(ref.chapter, 1), book.chapterCount) }
            let last = counts[ref.chapterID] ?? ref.verse
            ref.verse = min(max(ref.verse, 1), last)
            return ref
        }
        return VerseRange(start: clamp(range.start), end: clamp(range.end))
    }
}

/// A passage that opens with a section heading and runs up to the next heading.
public struct Pericope: Identifiable, Hashable, Sendable {
    /// Position in the whole-Bible list of pericopes.
    public let id: Int
    public let title: String
    /// Larger headings printed above this one (e.g. "Нагорная проповедь").
    public let sectionTitles: [String]
    public let range: VerseRange

    public var start: VerseRef { range.start }
}

/// All pericopes of the Bible, loaded from `pericopes.tsv`.
public struct PericopeIndex: Sendable {
    public let pericopes: [Pericope]
    private let byChapter: [ChapterID: [Pericope]]

    public init(tsv: String, verseCounts: VerseCounts) {
        struct Heading {
            var position: VerseRef
            var titles: [String]
        }

        var headings: [Heading] = []
        for line in tsv.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", maxSplits: 3).map(String.init)
            guard fields.count == 4,
                  let book = Int(fields[0]), let chapter = Int(fields[1]), let verse = Int(fields[2])
            else { continue }
            let position = VerseRef(book: book, chapter: chapter, verse: verse)
            if headings.last?.position == position {
                headings[headings.count - 1].titles.append(fields[3])
            } else {
                headings.append(Heading(position: position, titles: [fields[3]]))
            }
        }
        headings.sort { $0.position < $1.position }

        var pericopes: [Pericope] = []
        for (index, heading) in headings.enumerated() {
            let start = heading.position
            let end: VerseRef
            let next = index + 1 < headings.count ? headings[index + 1].position : nil
            if let next, next.book == start.book {
                if next.verse > 1 {
                    end = VerseRef(book: next.book, chapter: next.chapter, verse: next.verse - 1)
                } else {
                    let chapter = next.chapter - 1
                    let last = verseCounts.count(ChapterID(book: start.book, chapter: chapter)) ?? 1
                    end = VerseRef(book: start.book, chapter: chapter, verse: last)
                }
            } else {
                // The last pericope of a book runs to the end of the book.
                let lastChapter = start.bibleBook?.chapterCount ?? start.chapter
                let last = verseCounts.count(ChapterID(book: start.book, chapter: lastChapter)) ?? start.verse
                end = VerseRef(book: start.book, chapter: lastChapter, verse: last)
            }
            pericopes.append(Pericope(
                id: index,
                title: heading.titles.last ?? "",
                sectionTitles: Array(heading.titles.dropLast()),
                range: VerseRange(start: start, end: end)
            ))
        }

        var byChapter: [ChapterID: [Pericope]] = [:]
        for pericope in pericopes {
            for chapter in pericope.range.chapters {
                byChapter[chapter, default: []].append(pericope)
            }
        }
        self.pericopes = pericopes
        self.byChapter = byChapter
    }

    /// Pericopes that overlap the chapter, in order.
    public func pericopes(in chapter: ChapterID) -> [Pericope] {
        byChapter[chapter] ?? []
    }

    /// Pericopes whose heading is printed inside the chapter, keyed by verse number.
    public func headings(in chapter: ChapterID) -> [Int: Pericope] {
        var result: [Int: Pericope] = [:]
        for pericope in pericopes(in: chapter) where pericope.start.chapterID == chapter {
            result[pericope.start.verse] = pericope
        }
        return result
    }

    /// The pericope that contains the verse.
    public func pericope(containing verse: VerseRef) -> Pericope? {
        pericopes(in: verse.chapterID).last { $0.range.contains(verse) }
    }
}
