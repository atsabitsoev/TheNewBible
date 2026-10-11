import SwiftUI

/// "О стихе": the verse, its pericope, the original words with Strong's numbers,
/// commentaries and the other translations.
struct VerseDetailView: View {
    let verse: VerseRef

    enum Tab: String, CaseIterable, Identifiable {
        case words = "Слова"
        case commentaries = "Толкования"
        case translations = "Переводы"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @AppStorage("detail.verseTab") private var tab: Tab = .words

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VerseQuoteCard(verse: verse)

                if let pericope = model.pericopes.pericope(containing: verse) {
                    NavigationLink(value: SheetRoute.pericope(pericope)) {
                        PericopeLinkRow(pericope: pericope)
                    }
                    .buttonStyle(.plain)
                }

                Picker("Раздел", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .words:
                    OriginalWordsSection(verse: verse)
                case .commentaries:
                    CommentaryListSection(range: VerseRange(verse))
                case .translations:
                    TranslationsSection(verse: verse)
                }
            }
            .padding(20)
        }
        .navigationTitle("Стих \(verse.title)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The verse in the reader's translation.
struct VerseQuoteCard: View {
    let verse: VerseRef
    @Environment(AppModel.self) private var model
    @AppStorage(ReaderSettings.serifKey) private var serif = true
    @State private var text: String?
    @State private var translation: Translation = .synodal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text ?? "Загрузка текста стиха…")
                .font(ReaderSettings.font(size: 20, serif: serif))
                .lineSpacing(5)
                .redacted(reason: text == nil ? .placeholder : [])
                .textSelection(.enabled)
            HStack {
                Text("\(verse.title) · \(translation.shortTitle)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let text {
                    ShareLink(item: "«\(text)» (\(verse.title), \(translation.fullTitle))") {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .card()
        .task(id: verse) { await load() }
    }

    private func load() async {
        var translation = model.reader.translation
        if let book = verse.bibleBook, !translation.contains(book) { translation = .synodal }
        self.translation = translation
        if let chapter = try? await model.repository.chapter(verse.chapterID, translation: translation) {
            text = chapter.verse(verse.verse)?.text
        }
    }
}

struct PericopeLinkRow: View {
    let pericope: Pericope

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Отрывок")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pericope.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Text(pericope.range.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .card()
        .contentShape(.rect)
    }
}

/// The verse in all three translations.
struct TranslationsSection: View {
    let verse: VerseRef

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Translation.allCases) { translation in
                TranslationVerseCard(translation: translation, verse: verse)
            }
        }
    }
}

private struct TranslationVerseCard: View {
    let translation: Translation
    let verse: VerseRef
    @Environment(AppModel.self) private var model
    @AppStorage(ReaderSettings.serifKey) private var serif = true
    @State private var state: Loadable<String> = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(translation.fullTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            switch state {
            case .loading:
                Text("Загрузка стиха из перевода")
                    .redacted(reason: .placeholder)
            case .loaded(let text):
                Text(text)
                    .font(ReaderSettings.font(size: 18, serif: serif))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            case .failed(let error):
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .card()
        .task(id: verse) { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let chapter = try await model.repository.chapter(verse.chapterID, translation: translation)
            if let text = chapter.verse(verse.verse)?.text {
                state = .loaded(text)
            } else {
                state = .failed(BibleDataError.notFound)
            }
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        }
    }
}
