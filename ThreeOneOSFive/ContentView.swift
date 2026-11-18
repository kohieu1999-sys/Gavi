import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var licenseStore: GaviStoreLicense
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showPatchLibrary = false

    var body: some View {
        TabView(selection: $selectedTab) {
            GaviHomeView(
                onOpenSettings: { showSettings = true },
                onOpenPatchLibrary: { showPatchLibrary = true }
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            GaviFunctionsView(
                onOpenSettings: { showSettings = true },
                onOpenPatchLibrary: { showPatchLibrary = true }
            )
            .tabItem {
                Label("Chức năng", systemImage: "slider.horizontal.3")
            }
            .tag(1)
        }
        .tint(.orange)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { showPatchLibrary = true }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { showPatchLibrary = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showLogs) {
            LogView()
        }
        .sheet(isPresented: $showPatchLibrary) {
            PatchProjectsView(
                onOpenSettings: { showSettings = true },
                onOpenLogs: { showLogs = true }
            )
        }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }
}
