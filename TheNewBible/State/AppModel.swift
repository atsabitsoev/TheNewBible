import Foundation
import Observation

/// Shared objects: the data repository, bundled indexes and the reading state.
@MainActor
@Observable
final class AppModel {
    let repository: BibleRepository
    let pericopes: PericopeIndex
    let verseCounts: VerseCounts
    let reader: ReaderState

    init() {
        let counts = VerseCounts(tsv: Self.bundledText("versecounts"))
        verseCounts = counts
        pericopes = PericopeIndex(tsv: Self.bundledText("pericopes"), verseCounts: counts)
        repository = BibleRepository()
        reader = ReaderState()
    }

    private static func bundledText(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("Missing \(name).tsv in the app bundle")
            return ""
        }
        return text
    }
}
