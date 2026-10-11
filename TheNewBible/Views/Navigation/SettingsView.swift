import SwiftUI

/// Text size, typeface, sources and cache.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.serifKey) private var serif = true
    @State private var cacheCleared = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Текст") {
                    Text("В начале было Слово, и Слово было у Бога, и Слово было Бог.")
                        .font(ReaderSettings.font(size: fontSize, serif: serif))
                        .lineSpacing(fontSize * 0.3)
                        .padding(.vertical, 6)
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: $fontSize, in: 14...32, step: 1)
                        Image(systemName: "textformat.size.larger")
                    }
                    .foregroundStyle(.secondary)
                    Toggle("Шрифт с засечками", isOn: $serif)
                }

                Section {
                    sourceRow("Синодальный перевод, НРП", detail: "bolls.life", url: "https://bolls.life")
                    sourceRow("Перевод еп. Кассиана", detail: "azbyka.ru", url: "https://azbyka.ru/biblia/")
                    sourceRow("Греческий и еврейский тексты, словарь Стронга", detail: "bolls.life", url: "https://bolls.life")
                    sourceRow("Толкования", detail: "azbyka.ru", url: "https://azbyka.ru/biblia/")
                    LabeledContent("Деление на отрывки", value: "по Berean Standard Bible")
                } header: {
                    Text("Источники")
                } footer: {
                    Text("Тексты переводов и толкования загружаются с сайтов-источников и принадлежат их правообладателям.")
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await model.repository.clearCaches()
                            cacheCleared = true
                        }
                    } label: {
                        Label(cacheCleared ? "Загруженные данные удалены" : "Удалить загруженные данные",
                              systemImage: cacheCleared ? "checkmark" : "trash")
                    }
                    .disabled(cacheCleared)
                } footer: {
                    Text("Прочитанные главы, статьи словаря и толкования сохраняются на устройстве и открываются без интернета.")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func sourceRow(_ title: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            LabeledContent(title, value: detail)
        }
        .foregroundStyle(.primary)
    }
}
