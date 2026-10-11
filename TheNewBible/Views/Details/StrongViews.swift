import SwiftUI

/// Greek or Hebrew words of a verse with Strong's numbers and short meanings.
struct OriginalWordsSection: View {
    let verse: VerseRef

    @Environment(AppModel.self) private var model
    /// Manual correction when the original numbering differs from the Synodal one.
    @State private var offset = 0
    @State private var state: Loadable<[OriginalWord]> = .loading

    private var isNewTestament: Bool { verse.book >= 40 }

    private var position: VerseRef? {
        guard var position = Versification.originalPosition(for: verse) else { return nil }
        position.verse += offset
        return position.verse >= 1 ? position : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(
                title: isNewTestament ? "Греческий текст" : "Еврейский текст",
                subtitle: isNewTestament
                    ? "Тишендорф, 8-е изд. · номера Стронга"
                    : "Ленинградский кодекс · номера Стронга"
            )

            if let position {
                positionControl(position)
                LoadableView(state: state, retry: { Task { await load() } }) { words in
                    wordsView(words)
                }
            } else {
                ContentUnavailableView(
                    "Нет текста оригинала",
                    systemImage: "character.book.closed",
                    description: Text("Этого стиха нет в еврейском тексте: он сохранился только в греческом переводе (Септуагинте).")
                )
            }
        }
        .task(id: position) { await load() }
    }

    private func positionControl(_ position: VerseRef) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("В оригинале: \(position.title)")
                    .font(.subheadline.weight(.medium))
                Text("Если нумерация не совпала, сдвиньте стих")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ControlGroup {
                Button {
                    offset -= 1
                } label: {
                    Label("Предыдущий стих", systemImage: "chevron.left")
                }
                .disabled(position.verse <= 1)
                Button {
                    offset += 1
                } label: {
                    Label("Следующий стих", systemImage: "chevron.right")
                }
            }
            .controlGroupStyle(.navigation)
            .fixedSize()
        }
    }

    @ViewBuilder private func wordsView(_ words: [OriginalWord]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // The verse as a line of tappable words.
            FlowLayout(spacing: 6, lineSpacing: 8, rightToLeft: !isNewTestament) {
                ForEach(words) { word in
                    if let number = word.numbers.first {
                        NavigationLink(value: SheetRoute.strong(number)) {
                            Text(word.text)
                                .font(.system(size: 22, design: .serif))
                                .padding(.horizontal, 2)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(word.text)
                            .font(.system(size: 22, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isNewTestament ? .leading : .trailing)
            .card()

            VStack(spacing: 0) {
                let tagged = words.filter { !$0.numbers.isEmpty }
                ForEach(tagged) { word in
                    NavigationLink(value: SheetRoute.strong(word.numbers[0])) {
                        StrongWordRow(word: word, number: word.numbers[0])
                    }
                    .buttonStyle(.plain)
                    if word.id != tagged.last?.id {
                        Divider()
                    }
                }
            }
            .card()

            Text("Нажмите на слово, чтобы открыть статью словаря. Словарь: «Полный лексикон по Стронгу и Дворецкому».")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        guard let position else { return }
        state = .loading
        do {
            let words = try await model.repository.originalWords(at: position)
            guard !Task.isCancelled else { return }
            state = .loaded(words)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        }
    }
}

/// A word with its transliteration and short meaning, loaded lazily.
struct StrongWordRow: View {
    let word: OriginalWord
    let number: StrongNumber
    @Environment(AppModel.self) private var model
    @State private var entry: StrongEntry?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(word.bareText)
                .font(.system(size: 21, design: .serif))
                .frame(minWidth: 84, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.map { $0.shortDefinition.isEmpty ? $0.lexeme : $0.shortDefinition } ?? "значение слова")
                    .font(.body)
                    .lineLimit(2)
                    .redacted(reason: entry == nil ? .placeholder : [])
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .task(id: number) {
            entry = try? await model.repository.strongEntry(number)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let entry, !entry.transliteration.isEmpty { parts.append(entry.transliteration) }
        parts.append(word.numbers.map(\.description).joined(separator: ", "))
        return parts.joined(separator: " · ")
    }
}

/// An article of the Strong's lexicon.
struct StrongEntryView: View {
    let number: StrongNumber
    @Environment(AppModel.self) private var model
    @State private var state: Loadable<StrongEntry> = .loading

    var body: some View {
        ScrollView {
            LoadableView(state: state, retry: { Task { await load() } }) { entry in
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.lexeme)
                            .font(.system(size: 40, design: .serif))
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            if !entry.transliteration.isEmpty {
                                Text(entry.transliteration).italic()
                            }
                            if !entry.pronunciation.isEmpty {
                                Text("[\(entry.pronunciation)]")
                            }
                            Text(number.language == .greek ? "греч." : "евр.")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }

                    if !entry.shortDefinition.isEmpty {
                        Text(entry.shortDefinition)
                            .font(.title3.weight(.semibold))
                    }

                    RichTextView(text: entry.definition, fontSize: 17, serif: false)
                        .card()

                    Text("«Полный лексикон по Стронгу и Дворецкому» · bolls.life")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .navigationTitle("Стронг \(number.description)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: number) { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let entry = try await model.repository.strongEntry(number)
            guard !Task.isCancelled else { return }
            state = .loaded(entry)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        }
    }
}
