import SwiftUI

/// Choose a book and chapter, or type a reference like "Ин 3:16".
/// Opening a place keeps the current one for the return button.
struct PassagePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var path: [BibleBook] = []

    private var parsed: ReferenceParser.Result? { ReferenceParser.parse(query) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                List {
                    if let parsed, parsed.chapter != nil {
                        Section {
                            Button {
                                open(parsed.verseRef)
                            } label: {
                                Label("Открыть \(parsed.title)", systemImage: "arrow.forward.circle.fill")
                                    .font(.headline)
                            }
                        }
                    }

                    if query.isEmpty, !model.reader.returnStack.isEmpty {
                        Section("Недавние места") {
                            ForEach(Array(model.reader.returnStack.reversed().prefix(5).enumerated()), id: \.offset) { _, place in
                                Button {
                                    model.reader.returnTo(place)
                                    dismiss()
                                } label: {
                                    Label(place.title, systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }
                    }

                    bookSection("Ветхий Завет", books: BibleBook.oldTestament)
                    bookSection("Новый Завет", books: BibleBook.newTestament)
                }
                .listStyle(.insetGrouped)
                .onAppear {
                    proxy.scrollTo(model.reader.chapter.book, anchor: .center)
                }
            }
            .navigationTitle("Книги Библии")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Книга или ссылка, напр. Ин 3:16")
            .onSubmit(of: .search) {
                guard let parsed else { return }
                if parsed.chapter != nil || parsed.book.chapterCount == 1 {
                    open(parsed.verseRef)
                } else {
                    path.append(parsed.book)
                }
            }
            .navigationDestination(for: BibleBook.self) { book in
                ChapterGridView(book: book, current: model.reader.chapter) { chapter in
                    open(VerseRef(book: book.id, chapter: chapter, verse: 1))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Закрыть", systemImage: "xmark")
                    }
                }
            }
        }
    }

    @ViewBuilder private func bookSection(_ title: String, books: [BibleBook]) -> some View {
        let filtered = filter(books)
        if !filtered.isEmpty {
            Section(title) {
                ForEach(filtered) { book in
                    Button {
                        if book.chapterCount == 1 {
                            open(VerseRef(book: book.id, chapter: 1, verse: 1))
                        } else {
                            path.append(book)
                        }
                    } label: {
                        BookRow(book: book, isCurrent: book.id == model.reader.chapter.book)
                    }
                    .id(book.id)
                }
            }
        }
    }

    private func filter(_ books: [BibleBook]) -> [BibleBook] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return books }
        if let parsed { return books.filter { $0 == parsed.book } }
        return books.filter { $0.name.localizedCaseInsensitiveContains(text) || $0.abbreviation.localizedCaseInsensitiveContains(text) }
    }

    private func open(_ verse: VerseRef) {
        model.reader.open(verse)
        dismiss()
    }
}

private struct BookRow: View {
    let book: BibleBook
    let isCurrent: Bool

    var body: some View {
        HStack {
            Text(book.name)
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .fontWeight(isCurrent ? .semibold : .regular)
            Spacer()
            Text(book.chapterCount == 1 ? "1 глава" : "\(book.chapterCount) гл.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if book.chapterCount > 1 {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
    }
}

/// Grid of chapter numbers.
struct ChapterGridView: View {
    let book: BibleBook
    let current: ChapterID
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    chapterButton(chapter)
                }
            }
            .padding(20)
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func chapterButton(_ chapter: Int) -> some View {
        let label = Text("\(chapter)")
            .font(.body.monospacedDigit().weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 40)
        if current.book == book.id && current.chapter == chapter {
            Button { onSelect(chapter) } label: { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
        } else {
            Button { onSelect(chapter) } label: { label }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
        }
    }
}
