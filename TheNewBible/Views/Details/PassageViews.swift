import SwiftUI

struct PassageVerse: Identifiable, Hashable {
    let ref: VerseRef
    let text: String
    var id: VerseRef { ref }
}

/// "Об отрывке": title, range, commentaries on the whole passage and its text
/// in any of the translations.
struct PericopeDetailView: View {
    let pericope: Pericope

    enum Tab: String, CaseIterable, Identifiable {
        case commentaries = "Толкования"
        case text = "Текст"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @AppStorage("detail.pericopeTab") private var tab: Tab = .commentaries

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(pericope.sectionTitles, id: \.self) { section in
                        Text(section.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                    }
                    Text(pericope.title)
                        .font(.title2.bold())
                    Text(passageDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if model.reader.chapter != pericope.start.chapterID {
                    Button {
                        model.reader.open(pericope.start)
                    } label: {
                        Label("Читать этот отрывок", systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }

                Picker("Раздел", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .commentaries:
                    CommentaryListSection(range: pericope.range)
                case .text:
                    PassageTextSection(range: pericope.range)
                }
            }
            .padding(20)
        }
        .navigationTitle("Об отрывке")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var passageDescription: String {
        let range = pericope.range
        var count = 0
        for chapter in range.chapters {
            let first = chapter == range.start.chapterID ? range.start.verse : 1
            let last = chapter == range.end.chapterID ? range.end.verse : (model.verseCounts.count(chapter) ?? 0)
            count += max(last - first + 1, 0)
        }
        return "\(range.title) · \(versesWord(count))"
    }

    private func versesWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "\(count) стихов" }
        switch last {
        case 1: return "\(count) стих"
        case 2...4: return "\(count) стиха"
        default: return "\(count) стихов"
        }
    }
}

/// The verses of a passage, with a switch between translations.
struct PassageTextSection: View {
    let range: VerseRange
    var highlighted: VerseRange?

    @Environment(AppModel.self) private var model
    @AppStorage(ReaderSettings.serifKey) private var serif = true
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @State private var translation: Translation?
    @State private var state: Loadable<[PassageVerse]> = .loading

    private var current: Translation { translation ?? model.reader.translation }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Перевод", selection: Binding(get: { current }, set: { translation = $0 })) {
                ForEach(Translation.allCases) { translation in
                    Text(translation.shortTitle).tag(translation)
                }
            }
            .pickerStyle(.segmented)

            LoadableView(state: state, retry: { Task { await load() } }) { verses in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(verses) { verse in
                        verseText(verse)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background {
                                if let highlighted, highlighted.contains(verse.ref), highlighted != range {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.14))
                                }
                            }
                            .padding(.horizontal, -6)
                    }
                    Text(current.fullTitle)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .textSelection(.enabled)
            }
        }
        .task(id: "\(range.azbykaQuery)-\(current.rawValue)") { await load() }
    }

    private func verseText(_ verse: PassageVerse) -> some View {
        var number = AttributedString(verse.ref.chapter == range.start.chapter
                                      ? "\(verse.ref.verse)\u{2009}"
                                      : "\(verse.ref.chapter):\(verse.ref.verse)\u{2009}")
        number.font = .system(size: fontSize * 0.6, weight: .semibold, design: .rounded)
        number.foregroundColor = Color.accentColor
        number[AttributeScopes.SwiftUIAttributes.BaselineOffsetAttribute.self] = fontSize * 0.32
        return Text(number + AttributedString(verse.text))
            .font(ReaderSettings.font(size: fontSize - 1, serif: serif))
            .lineSpacing(fontSize * 0.25)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        state = .loading
        do {
            let verses = try await model.repository.verses(range, translation: current)
            guard !Task.isCancelled else { return }
            state = .loaded(verses.map { PassageVerse(ref: $0.0, text: $0.1) })
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        }
    }
}

/// A look at another place of the Bible (e.g. a reference from a commentary)
/// without leaving the reader's place. "Перейти" moves the reader there and
/// remembers the old place for the return button.
struct PassagePreviewView: View {
    let range: VerseRange
    @Environment(AppModel.self) private var model
    @State private var showWholeChapter = false

    private var clamped: VerseRange { model.verseCounts.clamp(range) }

    private var shownRange: VerseRange {
        guard showWholeChapter else { return clamped }
        let chapter = clamped.start.chapterID
        let last = model.verseCounts.count(chapter) ?? clamped.end.verse
        return VerseRange(
            start: VerseRef(book: chapter.book, chapter: chapter.chapter, verse: 1),
            end: VerseRef(book: chapter.book, chapter: chapter.chapter, verse: last)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clamped.title)
                        .font(.title2.bold())
                    if let pericope = model.pericopes.pericope(containing: clamped.start) {
                        NavigationLink(value: SheetRoute.pericope(pericope)) {
                            HStack(spacing: 4) {
                                Text(pericope.title)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .font(.subheadline)
                        }
                    }
                }

                PassageTextSection(range: shownRange, highlighted: clamped)

                Button {
                    withAnimation(.snappy) { showWholeChapter.toggle() }
                } label: {
                    Label(showWholeChapter ? "Только этот отрывок" : "Показать всю главу",
                          systemImage: showWholeChapter ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.glass)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Button {
                    model.reader.open(clamped.start)
                } label: {
                    Label("Перейти сюда", systemImage: "arrow.forward.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                Text("Текущее место сохранится — вернуться можно одной кнопкой.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .navigationTitle("Другое место")
        .navigationBarTitleDisplayMode(.inline)
    }
}
