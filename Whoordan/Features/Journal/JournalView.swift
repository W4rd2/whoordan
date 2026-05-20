import SwiftUI

struct JournalView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                WEmptyState(
                    title: "Journal",
                    message: "Habits and notes stay local unless explicit cloud sync consent is enabled. Associations require enough yes and no samples and never imply causation.",
                    systemImage: "square.and.pencil"
                )
            }
            .navigationTitle("Journal")
        }
    }
}
