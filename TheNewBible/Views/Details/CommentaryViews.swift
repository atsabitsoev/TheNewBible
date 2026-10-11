import SwiftUI

/// Commentaries on a verse or passage from azbyka.ru.
struct CommentaryListSection: View {
    let range: VerseRange
    @Environment(AppModel.self) private var model
    @State private var state: Loadable<[Commentary]> = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: "Толкования", subtitle: "Святые отцы и библеисты · Азбука веры")
            LoadableView(state: state, retry: { Task { await load() } }) { items in
                if items.isEmpty {
                    ContentUnavailableView(
                        "Толкований нет",
                        systemImage: "text.book.closed",
                        description: Text("Для \(range.title) толкования не найдены.")
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink(value: SheetRoute.commentary(item)) {
                                CommentaryCard(commentary: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .task(id: range) { await load() }
    }

    private func load() async {
        state = .loading
        do {
            let items = try await model.repository.commentaries(range)
            guard !Task.isCancelled else { return }
            state = .loaded(items)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error)
        }
    }
}

struct CommentaryCard: View {
    let commentary: Commentary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(commentary.author)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let lifetime = commentary.lifetime {
                    Text(lifetime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(commentary.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            if let source = commentary.sourceTitle {
                Label(source, systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .card()
        .contentShape(.rect)
    }
}

/// The full text of one commentary. Bible references inside it open as previews.
struct CommentaryDetailView: View {
    let commentary: Commentary
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.serifKey) private var serif = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(commentary.author)
                        .font(.title2.bold())
                    if let lifetime = commentary.lifetime {
                        Text(lifetime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                RichTextView(text: commentary.text, fontSize: max(fontSize - 1, 14), serif: serif)

                VStack(alignment: .leading, spacing: 10) {
                    if let source = commentary.sourceTitle {
                        if let url = commentary.sourceURL {
                            Link(destination: url) {
                                Label(source, systemImage: "book.closed")
                            }
                        } else {
                            Label(source, systemImage: "book.closed")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let page = commentary.pageURL {
                        Link(destination: page) {
                            Label("Открыть на azbyka.ru", systemImage: "safari")
                        }
                    }
                }
                .font(.subheadline)
                .card()
            }
            .padding(20)
        }
        .navigationTitle("Толкование")
        .navigationBarTitleDisplayMode(.inline)
    }
}
