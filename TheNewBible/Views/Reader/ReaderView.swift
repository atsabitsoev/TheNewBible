import SwiftUI

/// Sheets presented over the reader.
enum ReaderSheet: Identifiable {
    case picker
    case settings
    case detail(SheetRoute)

    var id: String {
        switch self {
        case .picker: "picker"
        case .settings: "settings"
        case .detail(let route): "detail-\(route.id)"
        }
    }
}

/// The main screen: one chapter of the current translation.
struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.serifKey) private var serif = true

    @State private var sheet: ReaderSheet?
    @State private var selectedVerse: VerseRef?
    @State private var chapterState: Loadable<ChapterText> = .loading
    @Namespace private var transitionNamespace

    private struct ChapterKey: Hashable {
        var chapter: ChapterID
        var translation: Translation
    }

    private var reader: ReaderState { model.reader }
    private var chapterKey: ChapterKey { ChapterKey(chapter: reader.chapter, translation: reader.translation) }

    var body: some View {
        NavigationStack {
            content
                .toolbar { toolbarContent }
                .toolbarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom, spacing: 0) { returnBar }
                .animation(.snappy, value: reader.returnStack)
        }
        .task(id: chapterKey) { await loadChapter() }
        .onChange(of: reader.navigationID) { sheet = nil }
        .sheet(item: $sheet, onDismiss: { selectedVerse = nil }) { sheet in
            sheetContent(sheet)
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch chapterState {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            failureView(error)
        case .loaded(let text):
            ChapterScrollView(
                text: text,
                headings: model.pericopes.headings(in: text.chapter),
                continuing: continuingPericope(for: text.chapter),
                fontSize: fontSize,
                serif: serif,
                selectedVerse: selectedVerse?.chapterID == text.chapter ? selectedVerse?.verse : nil,
                highlightedVerse: reader.highlightedVerse?.chapterID == text.chapter ? reader.highlightedVerse?.verse : nil,
                scrollRequest: reader.scrollRequest,
                visibleVerse: Binding(
                    get: { reader.visibleVerse },
                    set: { reader.visibleVerse = $0 }
                ),
                onSelectVerse: { number in
                    let verse = VerseRef(book: text.chapter.book, chapter: text.chapter.chapter, verse: number)
                    selectedVerse = verse
                    sheet = .detail(.verse(verse))
                },
                onSelectPericope: { pericope in
                    sheet = .detail(.pericope(pericope))
                },
                onNextChapter: { reader.showNextChapter() }
            )
            .id(ChapterKey(chapter: text.chapter, translation: text.translation))
        }
    }

    /// The pericope that started in an earlier chapter and continues into this one.
    private func continuingPericope(for chapter: ChapterID) -> Pericope? {
        let first = VerseRef(book: chapter.book, chapter: chapter.chapter, verse: 1)
        guard let pericope = model.pericopes.pericope(containing: first), pericope.start < first else { return nil }
        return pericope
    }

    @ViewBuilder private func failureView(_ error: Error) -> some View {
        let dataError = error as? BibleDataError
        ContentUnavailableView {
            Label(failureTitle(dataError), systemImage: dataError == nil ? "wifi.exclamationmark" : "book.closed")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            switch dataError {
            case .some(.notInTranslation), .some(.chapterMissing):
                Button("Читать в Синодальном переводе") { reader.setTranslation(.synodal) }
                    .buttonStyle(.glassProminent)
            default:
                Button("Повторить") { Task { await loadChapter() } }
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureTitle(_ error: BibleDataError?) -> String {
        switch error {
        case .some(.notInTranslation), .some(.chapterMissing): "Нет в этом переводе"
        default: "Не удалось загрузить главу"
        }
    }

    private func loadChapter() async {
        let key = chapterKey
        if let current = chapterState.value, current.chapter != key.chapter || current.translation != key.translation {
            chapterState = .loading
        } else if case .failed = chapterState {
            chapterState = .loading
        }
        do {
            let text = try await model.repository.chapter(key.chapter, translation: key.translation)
            guard !Task.isCancelled else { return }
            chapterState = .loaded(text)
        } catch {
            guard !Task.isCancelled else { return }
            chapterState = .failed(error)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                sheet = .settings
            } label: {
                Label("Оформление", systemImage: "textformat.size")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            translationMenu
        }

        ToolbarItem(placement: .bottomBar) {
            Button {
                reader.showPreviousChapter()
            } label: {
                Label("Предыдущая глава", systemImage: "chevron.left")
            }
            .disabled(reader.chapter.previous == nil)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                sheet = .picker
            } label: {
                HStack(spacing: 6) {
                    Text("\(reader.book.name) \(reader.chapter.chapter)")
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .accessibilityLabel("Выбрать книгу и главу")
            .accessibilityValue("\(reader.book.name), глава \(reader.chapter.chapter)")
        }
        .matchedTransitionSource(id: "picker", in: transitionNamespace)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                reader.showNextChapter()
            } label: {
                Label("Следующая глава", systemImage: "chevron.right")
            }
            .disabled(reader.chapter.next == nil)
        }
    }

    private var translationMenu: some View {
        Menu {
            Picker("Перевод", selection: Binding(
                get: { reader.translation },
                set: { reader.setTranslation($0) }
            )) {
                ForEach(Translation.allCases) { translation in
                    if translation == .kassian {
                        Text("\(translation.fullTitle) — только НЗ").tag(translation)
                    } else {
                        Text(translation.fullTitle).tag(translation)
                    }
                }
            }
        } label: {
            Text(reader.translation.shortTitle)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
        }
        .accessibilityLabel("Перевод: \(reader.translation.fullTitle)")
    }

    // MARK: Return to the saved place

    @ViewBuilder private var returnBar: some View {
        if let target = reader.returnStack.last {
            ReturnBar(
                target: target,
                history: reader.returnStack,
                onReturn: { reader.returnBack() },
                onSelect: { reader.returnTo($0) },
                onClear: { reader.clearReturnStack() }
            )
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Sheets

    @ViewBuilder private func sheetContent(_ sheet: ReaderSheet) -> some View {
        switch sheet {
        case .picker:
            PassagePickerView()
                .environment(model)
                .navigationTransition(.zoom(sourceID: "picker", in: transitionNamespace))
        case .settings:
            SettingsView()
                .environment(model)
                .presentationDetents([.medium, .large])
        case .detail(let route):
            DetailSheet(root: route)
                .environment(model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
