import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum BibleDataError: LocalizedError, Equatable, Sendable {
    /// The translation does not include the book (Kassian — New Testament only).
    case notInTranslation(Translation)
    /// The source has no such chapter in this translation (e.g. Psalm 151 in the NRT).
    case chapterMissing
    case noOriginalText
    case notFound
    case badResponse(Int)
    case unreadableResponse

    public var errorDescription: String? {
        switch self {
        case .notInTranslation(let translation):
            "\(translation.fullTitle) содержит только Новый Завет."
        case .chapterMissing:
            "В этом переводе нет такой главы."
        case .noOriginalText:
            "Для этого стиха нет текста на языке оригинала."
        case .notFound:
            "Ничего не найдено."
        case .badResponse(let status):
            "Сервер ответил ошибкой (\(status)). Попробуйте позже."
        case .unreadableResponse:
            "Не удалось разобрать ответ сервера."
        }
    }
}

public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 25)
        request.setValue("TheNewBible/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("ru-RU,ru;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw http.statusCode == 404 ? BibleDataError.notFound : BibleDataError.badResponse(http.statusCode)
        }
        return data
    }
}

/// Stores downloaded data as JSON files so that chapters already read work offline.
public struct DiskCache: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// `Library/Caches/TheNewBible`.
    public static func standard() -> DiskCache? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return DiskCache(directory: caches.appendingPathComponent("TheNewBible", isDirectory: true))
    }

    public func value<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func store<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
        return directory.appendingPathComponent(safe).appendingPathExtension("json")
    }
}

/// Loads texts, Strong's articles and commentaries, with memory and disk caching.
///
/// Sources:
/// - Synodal and NRT texts, Greek (Tischendorf) and Hebrew (WLC) texts with Strong's
///   numbers and the Russian Strong's lexicon — bolls.life;
/// - the Kassian translation and the commentaries — azbyka.ru.
public actor BibleRepository {
    private let client: HTTPClient
    private let disk: DiskCache?

    private var chapters: [String: ChapterText] = [:]
    private var originals: [String: [Int: String]] = [:]
    private var strongEntries: [StrongNumber: StrongEntry] = [:]
    private var commentaryPages: [String: [Commentary]] = [:]
    private var inFlight: [String: Task<ChapterText, Error>] = [:]

    public init(client: HTTPClient = URLSessionHTTPClient(), disk: DiskCache? = DiskCache.standard()) {
        self.client = client
        self.disk = disk
    }

    // MARK: Texts

    public func chapter(_ id: ChapterID, translation: Translation) async throws -> ChapterText {
        guard let book = id.bibleBook else { throw BibleDataError.notFound }
        guard translation.contains(book) else { throw BibleDataError.notInTranslation(translation) }
        let key = "chapter-\(translation.rawValue)-\(id.book)-\(id.chapter)"
        if let cached = chapters[key] { return cached }
        if let cached = disk?.value(ChapterText.self, for: key) {
            chapters[key] = cached
            return cached
        }
        if let running = inFlight[key] { return try await running.value }

        let client = self.client
        let task = Task<ChapterText, Error> {
            let verses: [Verse]
            switch translation {
            case .synodal:
                verses = try await Self.bollsChapter("SYNOD", id, client: client)
            case .nrt:
                verses = try await Self.bollsChapter("NRT", id, client: client)
            case .kassian:
                guard let url = Azbyka.kassianURL(id) else { throw BibleDataError.notFound }
                let html = try await Self.string(from: url, client: client)
                verses = Azbyka.parseVerses(html: html, chapter: id.chapter)
            }
            guard !verses.isEmpty else { throw BibleDataError.chapterMissing }
            return ChapterText(translation: translation, chapter: id, verses: verses)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let text = try await task.value
        chapters[key] = text
        disk?.store(text, for: key)
        return text
    }

    /// Verses of a range in one translation; chapters that fail to load are skipped.
    public func verses(_ range: VerseRange, translation: Translation) async throws -> [(VerseRef, String)] {
        var result: [(VerseRef, String)] = []
        var firstError: Error?
        for chapterID in range.chapters {
            do {
                let text = try await chapter(chapterID, translation: translation)
                for verse in text.verses {
                    let ref = VerseRef(book: chapterID.book, chapter: chapterID.chapter, verse: verse.number)
                    if range.contains(ref) { result.append((ref, verse.text)) }
                }
            } catch {
                firstError = firstError ?? error
            }
        }
        if result.isEmpty, let firstError { throw firstError }
        return result
    }

    // MARK: Original text and Strong's lexicon

    /// Greek or Hebrew words of the verse at `position` in the original numbering
    /// (see ``Versification``).
    public func originalWords(at position: VerseRef) async throws -> [OriginalWord] {
        let isNewTestament = position.book >= 40
        let source = isNewTestament ? "TISCH" : "WLCa"
        let key = "original-\(source)-\(position.book)-\(position.chapter)"
        var verses = originals[key] ?? disk?.value([Int: String].self, for: key)
        if verses == nil {
            let url = URL(string: "https://bolls.life/get-text/\(source)/\(position.book)/\(position.chapter)/")!
            let items = try await Self.decodeBolls(from: url, client: client)
            let loaded = Dictionary(items.map { ($0.verse, $0.text) }, uniquingKeysWith: { first, _ in first })
            disk?.store(loaded, for: key)
            verses = loaded
        }
        originals[key] = verses
        guard let tagged = verses?[position.verse] else { throw BibleDataError.noOriginalText }
        let words = OriginalText.words(fromTagged: tagged, language: isNewTestament ? .greek : .hebrew)
        guard !words.isEmpty else { throw BibleDataError.noOriginalText }
        return words
    }

    /// Number of verses in a chapter of the original-language text, once loaded.
    public func originalVerseCount(book: Int, chapter: Int) -> Int? {
        let source = book >= 40 ? "TISCH" : "WLCa"
        return originals["original-\(source)-\(book)-\(chapter)"]?.keys.max()
    }

    public func strongEntry(_ number: StrongNumber) async throws -> StrongEntry {
        if let cached = strongEntries[number] { return cached }
        let key = "strong-\(number)"
        if let cached = disk?.value(StrongEntry.self, for: key) {
            strongEntries[number] = cached
            return cached
        }
        let url = URL(string: "https://bolls.life/dictionary-definition/RUSD/\(number)/")!
        let data = try await client.data(from: url)
        let entries: [BollsDictionaryEntry]
        do {
            entries = try JSONDecoder().decode([BollsDictionaryEntry].self, from: data)
        } catch {
            throw BibleDataError.unreadableResponse
        }
        let match = entries.first { $0.topic.uppercased() == number.description } ?? entries.first
        guard let match else { throw BibleDataError.notFound }
        let entry = StrongEntry(
            number: number,
            lexeme: match.lexeme ?? "",
            transliteration: match.transliteration ?? "",
            pronunciation: match.pronunciation ?? "",
            shortDefinition: HTMLText.plain(match.shortDefinition ?? ""),
            definition: HTMLText.parse(match.definition ?? "")
        )
        strongEntries[number] = entry
        disk?.store(entry, for: key)
        return entry
    }

    // MARK: Commentaries

    public func commentaries(_ range: VerseRange) async throws -> [Commentary] {
        let key = "commentary-\(range.azbykaQuery)"
        if let cached = commentaryPages[key] { return cached }
        if let cached = disk?.value([Commentary].self, for: key) {
            commentaryPages[key] = cached
            return cached
        }
        guard let url = Azbyka.commentaryURL(range) else { throw BibleDataError.notFound }
        let html = try await Self.string(from: url, client: client)
        let result = Azbyka.parseCommentaries(html: html, pageURL: url)
        commentaryPages[key] = result
        disk?.store(result, for: key)
        return result
    }

    public func clearCaches() {
        chapters.removeAll()
        originals.removeAll()
        strongEntries.removeAll()
        commentaryPages.removeAll()
        disk?.removeAll()
    }

    // MARK: Helpers

    struct BollsVerse: Decodable {
        var verse: Int
        var text: String
    }

    struct BollsDictionaryEntry: Decodable {
        var topic: String
        var definition: String?
        var lexeme: String?
        var transliteration: String?
        var pronunciation: String?
        var shortDefinition: String?

        enum CodingKeys: String, CodingKey {
            case topic, definition, lexeme, transliteration, pronunciation
            case shortDefinition = "short_definition"
        }
    }

    static func decodeBolls(from url: URL, client: HTTPClient) async throws -> [BollsVerse] {
        let data = try await client.data(from: url)
        do {
            return try JSONDecoder().decode([BollsVerse].self, from: data)
        } catch {
            throw BibleDataError.unreadableResponse
        }
    }

    static func bollsChapter(_ code: String, _ id: ChapterID, client: HTTPClient) async throws -> [Verse] {
        let url = URL(string: "https://bolls.life/get-text/\(code)/\(id.book)/\(id.chapter)/")!
        return try await decodeBolls(from: url, client: client).compactMap { item in
            let text = HTMLText.plain(item.text).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : Verse(number: item.verse, text: text)
        }
    }

    static func string(from url: URL, client: HTTPClient) async throws -> String {
        let data = try await client.data(from: url)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
            throw BibleDataError.unreadableResponse
        }
        return html
    }
}
