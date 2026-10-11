import SwiftUI

/// Scrollable text of one chapter with pericope headings.
struct ChapterScrollView: View {
    let text: ChapterText
    let headings: [Int: Pericope]
    let continuing: Pericope?
    let fontSize: Double
    let serif: Bool
    let selectedVerse: Int?
    let highlightedVerse: Int?
    let scrollRequest: ReaderState.ScrollRequest?
    @Binding var visibleVerse: Int?
    var onSelectVerse: (Int) -> Void
    var onSelectPericope: (Pericope) -> Void
    var onNextChapter: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    ForEach(text.verses) { verse in
                        VStack(alignment: .leading, spacing: 0) {
                            if let pericope = headings[verse.number] {
                                PericopeHeading(pericope: pericope, fontSize: fontSize) {
                                    onSelectPericope(pericope)
                                }
                            } else if verse.number == text.verses.first?.number, let continuing {
                                PericopeHeading(pericope: continuing, isContinuation: true, fontSize: fontSize) {
                                    onSelectPericope(continuing)
                                }
                            }
                            VerseRow(
                                verse: verse,
                                fontSize: fontSize,
                                serif: serif,
                                isSelected: selectedVerse == verse.number,
                                isHighlighted: highlightedVerse == verse.number
                            ) {
                                onSelectVerse(verse.number)
                            }
                        }
                        .id(verse.number)
                    }
                    footer
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollPosition(id: $visibleVerse, anchor: .top)
            .onAppear { scroll(proxy, to: scrollRequest) }
            .onChange(of: scrollRequest) { _, request in scroll(proxy, to: request) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to request: ReaderState.ScrollRequest?) {
        guard let request, request.chapter == text.chapter, request.verse > 1 else { return }
        // Let the lazy stack lay out first.
        DispatchQueue.main.async {
            withAnimation(.snappy) {
                proxy.scrollTo(request.verse, anchor: .top)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text.chapter.bibleBook?.name ?? "")
                .font(.system(.largeTitle, design: serif ? .serif : .default, weight: .bold))
            Text(text.chapter.bibleBook?.id == 19 ? "Псалом \(text.chapter.chapter)" : "Глава \(text.chapter.chapter)")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if let next = text.chapter.next, let book = next.bibleBook {
                Button(action: onNextChapter) {
                    HStack(spacing: 8) {
                        Text("Дальше: \(book.abbreviation) \(next.chapter)")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
            Text("\(text.translation.fullTitle) · \(text.translation.sourceName)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, 28)
    }
}

/// A verse: superscript number and text. Tapping it opens the verse details.
struct VerseRow: View {
    let verse: Verse
    let fontSize: Double
    let serif: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Text(attributedText)
            .font(ReaderSettings.font(size: fontSize, serif: serif))
            .lineSpacing(fontSize * 0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.18 : (isHighlighted ? 0.12 : 0)))
            }
            .padding(.horizontal, -8)
            .contentShape(.rect)
            .onTapGesture(perform: action)
            .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Открыть сведения о стихе")
    }

    private var attributedText: AttributedString {
        var number = AttributedString("\(verse.number)\u{2009}")
        number.font = .system(size: fontSize * 0.6, weight: .semibold, design: .rounded)
        number.foregroundColor = Color.accentColor
        number[AttributeScopes.SwiftUIAttributes.BaselineOffsetAttribute.self] = fontSize * 0.32
        return number + AttributedString(verse.text)
    }
}

/// Heading of a pericope inside the text. Tapping it opens the pericope details.
struct PericopeHeading: View {
    let pericope: Pericope
    var isContinuation = false
    let fontSize: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                if !isContinuation {
                    ForEach(pericope.sectionTitles, id: \.self) { section in
                        Text(section.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(isContinuation ? "\(pericope.title) (продолжение)" : pericope.title)
                        .font(.system(size: fontSize * (isContinuation ? 0.8 : 0.95), weight: .semibold))
                        .foregroundStyle(isContinuation ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "info.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.tint)
                }
                if !isContinuation {
                    Text(pericope.range.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, isContinuation ? 12 : 24)
        .padding(.bottom, 8)
        .accessibilityHint("Открыть сведения об отрывке")
    }
}

/// Floating glass button that brings the reader back to the saved place.
struct ReturnBar: View {
    let target: VerseRef
    let history: [VerseRef]
    var onReturn: () -> Void
    var onSelect: (VerseRef) -> Void
    var onClear: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Section("Вернуться к месту") {
                        ForEach(Array(history.reversed().enumerated()), id: \.offset) { _, place in
                            Button(place.title) { onSelect(place) }
                        }
                    }
                    Button("Забыть сохранённые места", systemImage: "trash", role: .destructive, action: onClear)
                } label: {
                    Label {
                        Text("Вернуться к \(target.title)")
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                } primaryAction: {
                    onReturn()
                }
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.3)).interactive(), in: .capsule)
                .accessibilityHint("Удерживайте, чтобы выбрать из истории")

                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Не возвращаться")
            }
        }
    }
}
