import SwiftUI

struct ExplorerPane: View {
    var model: FileManagerModel
    
    @State private var pathInput: String = ""
    @FocusState private var isListFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar Area
            HStack(spacing: 8) {
                // Navigation buttons
                HStack(spacing: 4) {
                    Button(action: { model.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!model.canGoBack)
                    .buttonStyle(.bordered)
                    
                    Button(action: { model.goForward() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!model.canGoForward)
                    .buttonStyle(.bordered)
                    
                    Button(action: { model.goUp() }) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(!model.canGoUp)
                    .buttonStyle(.bordered)
                }
                
                // Address Bar / Path Input
                TextField("Path", text: $pathInput, onCommit: {
                    let newURL = URL(fileURLWithPath: pathInput)
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        model.navigateTo(url: newURL)
                    } else {
                        // Reset if path is invalid
                        pathInput = model.currentDirectory.path
                    }
                })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .font(.system(.body, design: .monospaced))
                
                // Sorting & Visibility Options
                HStack(spacing: 8) {
                    // Hidden files toggle
                    Button(action: { model.showHiddenFiles.toggle() }) {
                        Image(systemName: model.showHiddenFiles ? "eye" : "eye.slash")
                    }
                    .buttonStyle(.bordered)
                    .help(model.showHiddenFiles ? "Hide Hidden Files" : "Show Hidden Files")
                    
                    // Sort options
                    Menu {
                        Picker("Sort By", selection: Binding(
                            get: { model.sortBy },
                            set: { model.sortBy = $0; model.reload() }
                        )) {
                            ForEach(FileManagerModel.SortField.allCases) { field in
                                Text(field.rawValue).tag(field)
                            }
                        }
                        
                        Divider()
                        
                        Toggle("Ascending", isOn: Binding(
                            get: { model.sortAscending },
                            set: { model.sortAscending = $0; model.reload() }
                        ))
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .menuStyle(.button)
                    .frame(width: 80)
                }
                
                // Search Box
                TextField("Search...", text: Binding(
                    get: { model.searchQuery },
                    set: { model.searchQuery = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .transition(.move(edge: .trailing))
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Header for columns
            HStack(spacing: 0) {
                Text("Name")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 32)
                
                Text("Date Modified")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
                
                Text("Size")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)
                    .padding(.trailing, 10)
            }
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // File List
            let files = model.filteredAndSortedFiles
            if files.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Files Found")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List(files) { item in
                        ExplorerRow(item: item, isSelected: model.selectedItem?.url == item.url)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                model.openItem(item)
                            }
                            .onTapGesture(count: 1) {
                                model.selectedItem = item
                                isListFocused = true
                            }
                            .contextMenu {
                                Button("Open") {
                                    model.openItem(item)
                                }
                                Button("Reveal in Finder") {
                                    model.revealInFinder(item)
                                }
                                Button("Open in Terminal") {
                                    model.openInTerminal(item.isDirectory ? item.url : item.url.deletingLastPathComponent())
                                }
                                if item.isDirectory {
                                    Button("Add to Favorites") {
                                        model.addToFavorites(item)
                                    }
                                }
                                Divider()
                                Button("Move to Trash", role: .destructive) {
                                    model.moveToTrash(item)
                                }
                            }
                    }
                    .listStyle(.inset)
                    .focusable()
                    .focused($isListFocused)
                    .onKeyPress { press in
                        switch press.key {
                        case .downArrow:
                            selectNext(files: files)
                            return .handled
                        case .upArrow:
                            selectPrevious(files: files)
                            return .handled
                        case .rightArrow:
                            if let selected = model.selectedItem, selected.isDirectory {
                                model.navigateTo(url: selected.url)
                                return .handled
                            }
                            return .ignored
                        case .leftArrow:
                            if model.canGoUp {
                                model.goUp()
                                return .handled
                            }
                            return .ignored
                        case .return:
                            if let selected = model.selectedItem {
                                model.openItem(selected)
                                return .handled
                            }
                            return .ignored
                        default:
                            // Vim-style keybindings
                            switch press.characters {
                            case "j":
                                selectNext(files: files)
                                return .handled
                            case "k":
                                selectPrevious(files: files)
                                return .handled
                            case "h":
                                if model.canGoUp {
                                    model.goUp()
                                    return .handled
                                }
                                return .ignored
                            case "l":
                                if let selected = model.selectedItem, selected.isDirectory {
                                    model.navigateTo(url: selected.url)
                                    return .handled
                                }
                                return .ignored
                            case "o":
                                if let selected = model.selectedItem {
                                    model.openItem(selected)
                                    return .handled
                                }
                                return .ignored
                            default:
                                break
                            }
                            return .ignored
                        }
                    }
                    .onChange(of: model.selectedItem) { _, newValue in
                        if let selected = newValue {
                            proxy.scrollTo(selected.id)
                        }
                    }
                }
            }
        }
        .onAppear {
            pathInput = model.currentDirectory.path
            isListFocused = true
        }
        // Listen for directory changes to keep pathInput updated
        .onChange(of: model.currentDirectory) { _, newDirectory in
            pathInput = newDirectory.path
        }
    }
    
    private func selectNext(files: [FileItem]) {
        if let selected = model.selectedItem,
           let index = files.firstIndex(where: { $0.url == selected.url }) {
            if index < files.count - 1 {
                model.selectedItem = files[index + 1]
            }
        } else if let first = files.first {
            model.selectedItem = first
        }
    }
    
    private func selectPrevious(files: [FileItem]) {
        if let selected = model.selectedItem,
           let index = files.firstIndex(where: { $0.url == selected.url }) {
            if index > 0 {
                model.selectedItem = files[index - 1]
            }
        } else if let last = files.last {
            model.selectedItem = last
        }
    }
}

struct ExplorerRow: View {
    let item: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .frame(width: 16)
                
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(item.formattedDate)
                .font(.body)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(item.formattedSize)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .frame(width: 90, alignment: .trailing)
                .padding(.trailing, 10)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}
