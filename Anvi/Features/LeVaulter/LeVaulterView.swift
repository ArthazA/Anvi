import SwiftData
import SwiftUI

struct LeVaulterView: View {
    @ObservedObject var preferences: AnviPreferences
    let goBack: () -> Void

    @EnvironmentObject private var anviMode: AnviModeController
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordEntry.trayOrder) private var allWords: [WordEntry]
    @Query(sort: \WordCategory.sortOrder) private var categories: [WordCategory]

    @State private var isCreatingCategory = false
    @State private var isCreatingWord = false
    @State private var categoryName = ""
    @State private var wordText = ""
    @State private var openedCategory: WordCategory?
    @State private var categoryPendingDeletion: WordCategory?
    @State private var highlightedWordID: UUID?
    @State private var highlightedCategoryIndex: Int?

    private var trayWords: [WordEntry] { allWords.filter { $0.category == nil } }

    var body: some View {
        ZStack {
            AnviTheme.canvas.ignoresSafeArea()
            mainContent

            if let openedCategory {
                CategoryDetailView(
                    category: openedCategory,
                    close: { withAnimation(.easeOut(duration: 0.2)) { self.openedCategory = nil } },
                    requestDelete: { categoryPendingDeletion = openedCategory }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { registerAnviMode() }
        .onChange(of: categories.count) { _, _ in registerAnviMode() }
        .alert("New category", isPresented: $isCreatingCategory) {
            TextField("Category name", text: $categoryName)
            Button("Cancel", role: .cancel) { categoryName = "" }
            Button("Create") { createCategory() }
        } message: {
            Text("Create a home for related words.")
        }
        .alert("New word", isPresented: $isCreatingWord) {
            TextField("Word", text: $wordText)
            Button("Cancel", role: .cancel) { wordText = "" }
            Button("Add") { createWord() }
        } message: {
            Text("The word will appear in your library tray.")
        }
        .alert(
            "Delete category?",
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { if !$0 { categoryPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { categoryPendingDeletion = nil }
            Button("Delete", role: .destructive) { deletePendingCategory() }
        } message: {
            Text("Its words will return to the library tray.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    libraryTray
                    categorySection
                }
                .padding(.top, 20)
                .padding(.bottom, 110)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(AnviTheme.vault)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Return to canvas")

            VStack(alignment: .leading, spacing: 2) {
                Text("LE VAUL-TTER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(AnviTheme.vault)
                Text("Your word library")
                    .font(.system(size: 22, weight: .bold, design: .serif))
            }
            .foregroundStyle(AnviTheme.ink)

            Spacer()

            HStack(spacing: 8) {
                Button { isCreatingWord = true } label: {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AnviTheme.vault)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Create word")

                Button { isCreatingCategory = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .background(AnviTheme.vault, in: Circle())
                }
                .accessibilityLabel("Create category")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var libraryTray: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("WORD TRAY", systemImage: "tray.full.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(AnviTheme.vault)
                Spacer()
                Text("\(trayWords.count)")
                    .font(.caption.bold())
                    .foregroundStyle(AnviTheme.mutedInk)
            }
            .padding(.horizontal, 22)

            if trayWords.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray")
                    Text("Words saved from That’s Word will wait here.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AnviTheme.mutedInk)
                .padding(.horizontal, 22)
                .frame(height: 88)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(trayWords) { word in
                            VaultWordCard(
                                word: word,
                                isHighlighted: anviMode.isButtonHeld && highlightedWordID == word.id
                            )
                            .draggable(word.id.uuidString)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 5)
                }
                .frame(height: 104)
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Categories")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    isCreatingCategory = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(AnviTheme.ink)
            .padding(.horizontal, 22)

            if categories.isEmpty {
                ContentUnavailableView(
                    "No categories yet",
                    systemImage: "square.grid.2x2",
                    description: Text("Create one, then drag a word onto it.")
                )
                .frame(minHeight: 190)
            } else {
                ScrollViewReader { reader in
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 148), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            VaultCategoryCard(
                                category: category,
                                isHighlighted: anviMode.isButtonHeld && highlightedCategoryIndex == index,
                                open: { withAnimation(.easeOut(duration: 0.2)) { openedCategory = category } },
                                assignDroppedWord: { assignWord(with: $0, to: category) }
                            )
                            .id(category.id)
                        }
                    }
                    .padding(.horizontal, 18)
                    .onChange(of: highlightedCategoryIndex) { _, newIndex in
                        guard let newIndex, categories.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.24)) {
                            reader.scrollTo(categories[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func registerAnviMode() {
        anviMode.register(
            context: .leVaulter,
            showsSlider: true,
            onBegin: beginAnviSelection,
            onCommit: commitAnviSelection,
            onCancel: clearAnviSelection,
            onSliderChanged: selectCategory
        )
    }

    private func beginAnviSelection() {
        highlightedWordID = trayWords.first?.id
        highlightedCategoryIndex = categories.isEmpty ? nil : 0
    }

    private func selectCategory(with sliderValue: CGFloat) {
        guard !categories.isEmpty else {
            highlightedCategoryIndex = nil
            return
        }
        highlightedCategoryIndex = min(
            categories.count - 1,
            Int((sliderValue * CGFloat(categories.count - 1)).rounded())
        )
    }

    private func commitAnviSelection() {
        defer { clearAnviSelection() }
        guard
            let highlightedWordID,
            let word = trayWords.first(where: { $0.id == highlightedWordID }),
            let highlightedCategoryIndex,
            categories.indices.contains(highlightedCategoryIndex)
        else {
            AnviHaptics.warning(enabled: preferences.hapticsEnabled)
            return
        }
        assign(word, to: categories[highlightedCategoryIndex])
    }

    private func clearAnviSelection() {
        highlightedWordID = nil
        highlightedCategoryIndex = nil
    }

    private func createCategory() {
        let created = VaultRepository.createCategory(named: categoryName, in: modelContext)
        categoryName = ""
        if created == nil {
            AnviHaptics.warning(enabled: preferences.hapticsEnabled)
        } else {
            AnviHaptics.success(enabled: preferences.hapticsEnabled)
        }
    }

    private func createWord() {
        let created = VaultRepository.addWords([wordText], to: modelContext)
        wordText = ""
        if created.isEmpty {
            AnviHaptics.warning(enabled: preferences.hapticsEnabled)
        } else {
            AnviHaptics.success(enabled: preferences.hapticsEnabled)
        }
    }

    private func assignWord(with identifier: String, to category: WordCategory) -> Bool {
        guard let id = UUID(uuidString: identifier), let word = allWords.first(where: { $0.id == id }) else {
            return false
        }
        assign(word, to: category)
        return true
    }

    private func assign(_ word: WordEntry, to category: WordCategory) {
        withAnimation(.spring(duration: 0.3, bounce: preferences.bounciness)) {
            VaultRepository.assign(word, to: category, in: modelContext)
        }
        AnviHaptics.success(enabled: preferences.hapticsEnabled)
    }

    private func deletePendingCategory() {
        guard let categoryPendingDeletion else { return }
        openedCategory = nil
        VaultRepository.delete(categoryPendingDeletion, from: modelContext)
        self.categoryPendingDeletion = nil
        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
    }
}

private struct VaultWordCard: View {
    let word: WordEntry
    let isHighlighted: Bool

    var body: some View {
        Text(word.text)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(AnviTheme.ink)
            .frame(width: AnviCustomization.Developer.vaultWordCardWidth, height: 78)
            .background(AnviTheme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isHighlighted ? AnviTheme.clay : Color.white.opacity(0.8), lineWidth: isHighlighted ? 3 : 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.08), radius: 12, y: 6)
            .scaleEffect(isHighlighted ? 1.05 : 1)
            .animation(.easeOut(duration: 0.18), value: isHighlighted)
    }
}

private struct VaultCategoryCard: View {
    let category: WordCategory
    let isHighlighted: Bool
    let open: () -> Void
    let assignDroppedWord: (String) -> Bool
    @State private var isDropTarget = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 26))
                    Spacer()
                    Text("\(category.words.count)")
                        .font(.caption.bold())
                }
                Text(category.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(AnviTheme.vault)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 128)
            .background(
                isDropTarget ? AnviTheme.lavender.opacity(0.24) : AnviTheme.paper,
                in: RoundedRectangle(
                    cornerRadius: AnviCustomization.Developer.vaultCategoryCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AnviCustomization.Developer.vaultCategoryCornerRadius,
                    style: .continuous
                )
                .stroke(isHighlighted ? AnviTheme.clay : Color.white.opacity(0.8), lineWidth: isHighlighted ? 3 : 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.07), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { identifiers, _ in
            guard let identifier = identifiers.first else { return false }
            return assignDroppedWord(identifier)
        } isTargeted: { isDropTarget = $0 }
    }
}

private struct CategoryDetailView: View {
    let category: WordCategory
    let close: () -> Void
    let requestDelete: () -> Void

    var body: some View {
        ZStack {
            AnviTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: close) {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text("\(category.words.count) \(category.words.count == 1 ? "word" : "words")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnviTheme.mutedInk)
                    }
                    Spacer()
                    Button(role: .destructive, action: requestDelete) {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(AnviTheme.vault)
                .padding(.horizontal, 18)
                .padding(.top, 10)

                if category.words.isEmpty {
                    ContentUnavailableView(
                        "This category is empty",
                        systemImage: "text.badge.plus",
                        description: Text("Drag a word here from the library tray.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                            ForEach(category.words.sorted(by: { $0.createdAt < $1.createdAt })) { word in
                                VaultWordCard(word: word, isHighlighted: false)
                            }
                        }
                        .padding(18)
                        .padding(.bottom, 90)
                    }
                }
            }
        }
    }
}
