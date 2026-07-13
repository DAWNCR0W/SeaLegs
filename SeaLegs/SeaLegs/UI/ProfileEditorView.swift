import SwiftUI

struct ProfileEditorView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    @State private var pendingDeleteProfile: GameProfile?

    var body: some View {
        HSplitView {
            List(selection: profileSelection) {
                ForEach(state.profiles) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                }
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            profileDetail
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if state.selectedProfileID == nil, let firstProfile = state.profiles.first {
                coordinator.selectProfile(firstProfile)
            }
        }
        .confirmationDialog(
            state.t("Delete this profile?"),
            isPresented: Binding(
                get: { pendingDeleteProfile != nil },
                set: { if !$0 { pendingDeleteProfile = nil } }
            )
        ) {
            Button(role: .destructive) {
                if let pendingDeleteProfile {
                    coordinator.deleteProfile(pendingDeleteProfile)
                    self.pendingDeleteProfile = nil
                }
            } label: {
                Label(state.t("Delete Profile"), systemImage: "trash")
            }
            Button(role: .cancel) {
                pendingDeleteProfile = nil
            } label: {
                Label(state.t("Cancel"), systemImage: "xmark")
            }
        } message: {
            Text(pendingDeleteProfile?.displayName ?? "")
        }
        .sheet(isPresented: Binding(
            get: { state.pendingProfileImport != nil },
            set: { if !$0 { coordinator.resolvePendingProfileImport(.cancel) } }
        )) {
            if let preview = state.pendingProfileImport {
                ProfileImportPreviewView(coordinator: coordinator, state: state, preview: preview)
            }
        }
    }

    private var profileSelection: Binding<UUID?> {
        Binding(
            get: { state.selectedProfileID },
            set: { profileID in
                guard let profileID,
                      let profile = state.profiles.first(where: { $0.id == profileID }) else {
                    return
                }
                coordinator.selectProfile(profile)
            }
        )
    }

    @ViewBuilder
    private var profileDetail: some View {
        if let profile = state.selectedProfile {
            Form {
                Section(state.t("Profile")) {
                    LabeledContent(state.t("Profile Type")) {
                        profileTypeLabel(profile)
                    }
                    TextField(state.t("Display Name"), text: Binding(
                        get: { profile.displayName },
                        set: { value in
                            coordinator.mutateSelectedProfile({ $0.displayName = value }, preview: false)
                        }
                    ))
                    .disabled(profile.isTemplate)
                    Picker(state.t("Category"), selection: Binding(
                        get: { profile.category },
                        set: { value in
                            coordinator.mutateSelectedProfile({ selected in
                                selected.category = value
                                selected.settingsChecklist = DefaultGameSettingRecommendations.recommendations(for: value)
                            }, preview: false)
                        }
                    )) {
                        ForEach(GameCategory.allCases) { category in
                            Text(state.localizer.category(category)).tag(category)
                        }
                    }
                    .disabled(profile.isTemplate)
                }
                Section(state.t("Match")) {
                    if profile.isTemplate {
                        Label(
                            state.t("Template profile names and categories are fixed, but their visual settings can be adjusted."),
                            systemImage: "lock"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        LabeledContent(state.t("Bundle ID"), value: profile.bundleIdentifier ?? "-")
                        LabeledContent(state.t("Executable"), value: profile.executableName ?? "-")
                        Text(state.t(
                            profile.hasApplicationMatch
                                ? "Registered profiles are linked to an app and can be deleted."
                                : "Unlinked custom profiles can be previewed or linked to the current app."
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section(state.t("Actions")) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Button {
                            coordinator.previewProfile(profile)
                        } label: {
                            Label(state.t("Preview Profile"), systemImage: "play.rectangle")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                        }
                        .accessibilityLabel(Text("\(state.t("Preview Profile")): \(profile.displayName)"))

                        Button {
                            coordinator.exportSelectedProfile()
                        } label: {
                            Label(state.t("Export Selected Profile..."), systemImage: "square.and.arrow.up")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                        }

                        Button {
                            coordinator.importProfiles()
                        } label: {
                            Label(state.t("Import Profiles..."), systemImage: "square.and.arrow.down")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                        }

                        Button {
                            coordinator.exportCustomProfiles()
                        } label: {
                            Label(state.t("Export Custom Profiles..."), systemImage: "archivebox")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                        }

                        if !profile.isTemplate, !profile.hasApplicationMatch {
                            Button {
                                coordinator.linkSelectedProfileToCurrentApp()
                            } label: {
                                Label(state.t("Link to Current App"), systemImage: "link.badge.plus")
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                            }
                        }

                        if !profile.isTemplate {
                            Button(role: .destructive) {
                                pendingDeleteProfile = profile
                            } label: {
                                Label(state.t("Delete Profile"), systemImage: "trash")
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                            }
                            .accessibilityLabel(Text("\(state.t("Delete Profile")): \(profile.displayName)"))
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.leading, 12)
        } else {
            ContentUnavailableView(
                state.t("Select a profile."),
                systemImage: "gamecontroller"
            )
        }
    }

    private func profileRow(_ profile: GameProfile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: profile.isTemplate ? "doc.on.doc" : "app.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                profileTypeLabel(profile)
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if state.activeProfile?.id == profile.id {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(Color.accentColor)
                    .help(state.t("Active Profile"))
                    .accessibilityLabel(Text(state.t("Active Profile")))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func profileTypeLabel(_ profile: GameProfile) -> some View {
        let label = profile.isTemplate
            ? "Template profile"
            : (profile.hasApplicationMatch ? "Registered profile" : "Custom profile")
        return Label(
            state.t(label),
            systemImage: profile.isTemplate ? "doc.on.doc" : "checkmark.circle.fill"
        )
        .foregroundStyle(.secondary)
    }

}

private struct ProfileImportPreviewView: View {
    let coordinator: AppCoordinator
    @ObservedObject var state: AppState
    let preview: ProfileImportPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.t("Profile Import Preview"))
                    .font(.title2.weight(.semibold))
                Text(String(format: state.t("%d profile(s) ready to import."), preview.archive.profiles.count))
                    .foregroundStyle(.secondary)
            }

            List {
                Section(state.t("Profiles")) {
                    ForEach(preview.archive.profiles) { profile in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.displayName)
                                .font(.headline)
                            Text(state.localizer.category(profile.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let bundleIdentifier = profile.bundleIdentifier {
                                LabeledContent(state.t("Bundle ID"), value: bundleIdentifier)
                                    .font(.caption.monospaced())
                            }
                            if let executableName = profile.executableName {
                                LabeledContent(state.t("Executable"), value: executableName)
                                    .font(.caption.monospaced())
                            }
                            if profile.bundleIdentifier == nil, profile.executableName == nil {
                                LabeledContent(state.t("Match"), value: state.t("Unlinked"))
                                    .font(.caption)
                            }
                            LabeledContent(
                                state.t("Mode"),
                                value: state.localizer.mode(profile.overlay.mode)
                            )
                            .font(.caption)
                        }
                    }
                }
                if preview.canReplaceAll {
                    Section(state.t("Conflicts")) {
                        ForEach(preview.conflicts) { conflict in
                            Text(conflict.existingName)
                        }
                    }
                }
                if !preview.warnings.isEmpty {
                    Section(state.t("Warnings")) {
                        ForEach(preview.warnings, id: \.self) { warning in
                            Label(state.t(warning), systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            HStack {
                Button(state.t("Cancel"), role: .cancel) {
                    coordinator.resolvePendingProfileImport(.cancel)
                }
                Spacer()
                if preview.canReplaceAll {
                    Button(state.t("Replace Existing")) {
                        coordinator.resolvePendingProfileImport(.replace)
                    }
                }
                Button(state.t(preview.conflicts.isEmpty ? "Import Profiles" : "Keep Both")) {
                    coordinator.resolvePendingProfileImport(.keepBoth)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 440)
    }
}
