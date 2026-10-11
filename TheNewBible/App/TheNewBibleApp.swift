import SwiftUI

@main
struct TheNewBibleApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ReaderView()
                .environment(model)
        }
    }
}
