import Foundation
import Observation

/// Where the reader is and how they got there.
///
/// Moving to another place with ``open(_:remember:)`` puts the current position
/// on ``returnStack``, so the reader can always come back with ``returnBack()``.
/// Turning pages (previous/next chapter) does not touch the stack.
@MainActor
@Observable
final class ReaderState {
    /// A request for the chapter view to scroll to a verse. A new value is
    /// created for every request so that repeating the same verse still scrolls.
    struct ScrollRequest: Equatable {
        var chapter: ChapterID
        var verse: Int
        var id = UUID()
    }

    private(set) var chapter: ChapterID
    private(set) var translation: Translation
    /// Top-most visible verse, kept up to date by the chapter view.
    var visibleVerse: Int? {
        didSet { if visibleVerse != oldValue { scheduleSave() } }
    }
    /// Places to come back to, the most recent last.
    private(set) var returnStack: [VerseRef]
    private(set) var scrollRequest: ScrollRequest?
    /// A verse briefly highlighted after a jump.
    private(set) var highlightedVerse: VerseRef?
    /// Changes whenever the reader is sent to another place; sheets close on it.
    private(set) var navigationID = UUID()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var highlightTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: Keys.position).flatMap { try? JSONDecoder().decode(VerseRef.self, from: $0) }
        let start = saved ?? VerseRef(book: 43, chapter: 1, verse: 1)
        chapter = start.chapterID
        visibleVerse = start.verse > 1 ? start.verse : nil
        translation = defaults.string(forKey: Keys.translation).flatMap(Translation.init(rawValue:)) ?? .synodal
        returnStack = defaults.data(forKey: Keys.returnStack)
            .flatMap { try? JSONDecoder().decode([VerseRef].self, from: $0) } ?? []
        if start.verse > 1 {
            scrollRequest = ScrollRequest(chapter: chapter, verse: start.verse)
        }
    }

    var currentPosition: VerseRef {
        VerseRef(book: chapter.book, chapter: chapter.chapter, verse: visibleVerse ?? 1)
    }

    var book: BibleBook { chapter.bibleBook ?? BibleBook.all[0] }

    // MARK: Navigation

    /// Opens another place. With `remember`, the current position is saved so the
    /// reader can return to it.
    func open(_ verse: VerseRef, remember: Bool = true) {
        let here = currentPosition
        if remember, here.chapterID != verse.chapterID || abs(here.verse - verse.verse) > 2 {
            returnStack.removeAll { $0 == here }
            returnStack.append(here)
            if returnStack.count > 30 { returnStack.removeFirst(returnStack.count - 30) }
        }
        move(to: verse, highlight: verse.verse > 1)
    }

    /// Goes back to the most recently saved position.
    func returnBack() {
        guard let last = returnStack.popLast() else { return }
        move(to: last, highlight: true)
    }

    /// Goes back to a specific saved position, dropping the ones after it.
    func returnTo(_ position: VerseRef) {
        guard let index = returnStack.lastIndex(of: position) else { return }
        returnStack.removeSubrange(index...)
        move(to: position, highlight: true)
    }

    func clearReturnStack() {
        returnStack.removeAll()
        save()
    }

    func showNextChapter() {
        guard let next = chapter.next else { return }
        turn(to: next)
    }

    func showPreviousChapter() {
        guard let previous = chapter.previous else { return }
        turn(to: previous)
    }

    /// Switches the translation and keeps the reader at the same verse.
    func setTranslation(_ newValue: Translation) {
        guard newValue != translation else { return }
        translation = newValue
        if let verse = visibleVerse, verse > 1 {
            scrollRequest = ScrollRequest(chapter: chapter, verse: verse)
        }
        save()
    }

    private func turn(to chapter: ChapterID) {
        self.chapter = chapter
        visibleVerse = nil
        scrollRequest = nil
        navigationID = UUID()
        save()
    }

    private func move(to verse: VerseRef, highlight: Bool) {
        chapter = verse.chapterID
        visibleVerse = verse.verse
        scrollRequest = ScrollRequest(chapter: verse.chapterID, verse: verse.verse)
        navigationID = UUID()
        if highlight { flash(verse) }
        save()
    }

    private func flash(_ verse: VerseRef) {
        highlightTask?.cancel()
        highlightedVerse = verse
        highlightTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.highlightedVerse = nil
        }
    }

    // MARK: Persistence

    private enum Keys {
        static let position = "reader.position"
        static let translation = "reader.translation"
        static let returnStack = "reader.returnStack"
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(currentPosition), forKey: Keys.position)
        defaults.set(translation.rawValue, forKey: Keys.translation)
        defaults.set(try? encoder.encode(returnStack), forKey: Keys.returnStack)
    }
}
