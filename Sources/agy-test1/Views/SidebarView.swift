import SwiftUI

struct SidebarItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let iconName: String
    let url: URL
}

struct SidebarView: View {
    var model: FileManagerModel
    
    private var favorites: [SidebarItem] {
        model.favoriteDirectories.map { item in
            let iconName: String
            let path = item.url.path
            if path == NSHomeDirectory() {
                iconName = "house"
            } else if path == NSHomeDirectory() + "/Desktop" {
                iconName = "desktopcomputer"
            } else if path == NSHomeDirectory() + "/Documents" {
                iconName = "doc"
            } else if path == NSHomeDirectory() + "/Downloads" {
                iconName = "arrow.down.circle"
            } else if path == "/Users/jarkko/_dev" {
                iconName = "hammer"
            } else {
                iconName = "folder"
            }
            return SidebarItem(
                name: item.name.isEmpty ? "/" : item.name,
                iconName: iconName,
                url: item.url
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Favorites") {
                    ForEach(favorites) { item in
                        SidebarRow(item: item, isSelected: model.currentDirectory.path == item.url.path) {
                            model.navigateTo(url: item.url)
                        }
                        .contextMenu {
                            Button("Remove from Favorites") {
                                model.removeFromFavorites(item.url)
                            }
                        }
                    }
                }
                
                if !model.recentDirectories.isEmpty {
                    Section("Recent History") {
                        ForEach(model.recentDirectories, id: \.self) { url in
                            SidebarRow(
                                item: SidebarItem(
                                    name: url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent,
                                    iconName: "folder.badge.clock",
                                    url: url
                                ),
                                isSelected: model.currentDirectory.path == url.path
                            ) {
                                model.navigateTo(url: url)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            SidebarFooterView()
        }
        .frame(minWidth: 150, idealWidth: 200, maxWidth: 300)
    }
}

struct SidebarFooterView: View {
    @State private var updater = UpdateManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agy Finder")
                        .font(.headline)
                    Text(updater.currentVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                switch updater.status {
                case .checking:
                    ProgressView()
                        .controlSize(.small)
                case .downloading, .extracting:
                    ProgressView()
                        .controlSize(.small)
                default:
                    Button(action: {
                        updater.checkForUpdates()
                    }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Check for Updates")
                }
            }
            
            if case let .updateAvailable(version, _) = updater.status {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New version \(version) is available!")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    
                    Button(action: {
                        updater.downloadAndInstall()
                    }) {
                        Text("Download & Install")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } else if case .downloading = updater.status {
                Text("Downloading update...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if case .extracting = updater.status {
                Text("Extracting update...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if case let .readyToRestart(version) = updater.status {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Version \(version) ready.")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Button(action: {
                        updater.relaunch()
                    }) {
                        Text("Relaunch App")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } else if case let .failed(error) = updater.status {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Update failed:")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(2)
                    Button("Try Again") {
                        updater.checkForUpdates()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            } else if case .upToDate = updater.status {
                Text("App is up to date")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .padding(10)
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: item.iconName)
                    .font(.body)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 18, alignment: .center)
                
                Text(item.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
