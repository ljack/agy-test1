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
        .frame(minWidth: 150, idealWidth: 200, maxWidth: 300)
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
