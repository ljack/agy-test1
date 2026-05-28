import SwiftUI

struct ExplorerPane: View {
    @Bindable var model: FileManagerModel
    var isFocused: FocusState<MainView.FocusablePane?>.Binding
    let paneType: MainView.FocusablePane
    
    @State private var pathInput: String = ""
    @State private var lastClickTime: Date = Date.distantPast
    @State private var lastClickedItemURL: URL? = nil
    
    private var pathFocusKey: MainView.FocusablePane {
        paneType == .leftList ? .leftPath : .rightPath
    }
    
    private var searchFocusKey: MainView.FocusablePane {
        paneType == .leftList ? .leftSearch : .rightSearch
    }
    
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
                .focused(isFocused, equals: pathFocusKey)
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
                .focused(isFocused, equals: searchFocusKey)
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
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    let fileList = List(files, selection: $model.selectedItems) { item in
                        ExplorerRow(item: item, isSelected: model.selectedItems.contains(item.url), currentDirectory: model.currentDirectory)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let now = Date()
                                if lastClickedItemURL == item.url && now.timeIntervalSince(lastClickTime) < 0.25 {
                                    model.openItem(item)
                                } else {
                                    isFocused.wrappedValue = paneType
                                }
                                lastClickTime = now
                                lastClickedItemURL = item.url
                            }
                            .contextMenu {
                                Button("Open") {
                                    model.openItem(item)
                                }
                                if item.isDirectory {
                                    Button("Open in Other Pane") {
                                        model.openInOtherPane(item)
                                    }
                                }
                                Divider()
                                Button("Copy") {
                                    model.copyToPasteboard()
                                }
                                Button("Paste") {
                                    model.pasteFromPasteboard()
                                }
                                Divider()
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
                    
                    fileList
                        .listStyle(.inset)
                        .focusable()
                        .focused(isFocused, equals: paneType)
                        .onKeyPress { press in
                            handleKeyPress(press, files: files)
                        }
                        .onChange(of: model.selectedItem) { _, newValue in
                            if let selected = newValue, !files.isEmpty {
                                proxy.scrollTo(selected.id)
                            }
                        }
                        .contextMenu {
                            Button("Paste") {
                                model.pasteFromPasteboard()
                            }
                        }
                    .overlay {
                        if files.isEmpty {
                            VStack {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No Files Found")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                        }
                    }
                }
                
                // Floating Filter Overlay
                if model.isFilterActive && !model.filterText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("Filter:")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        
                        Text(model.filterText + (model.isDeepSearching ? " (Searching...)" : ""))
                            .foregroundColor(.primary)
                            .font(.system(size: 13, weight: .bold))
                        
                        Button(action: {
                            model.filterText = ""
                            model.isFilterActive = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Text("ESC")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            pathInput = model.currentDirectory.path
            isFocused.wrappedValue = paneType
        }
        // Listen for directory changes to keep pathInput updated
        .onChange(of: model.currentDirectory) { _, newDirectory in
            pathInput = newDirectory.path
        }
        // Automatically adjust selection when filter changes
        .onChange(of: model.filterText) { _, newFilter in
            if !newFilter.isEmpty {
                let filtered = model.filteredAndSortedFiles
                if let selected = model.selectedItem {
                    if !filtered.contains(where: { $0.url == selected.url }) {
                        model.selectedItem = filtered.first
                    }
                } else {
                    model.selectedItem = filtered.first
                }
            }
        }
        // Automatically adjust selection when deep search results arrive
        .onChange(of: model.deepSearchResults) { _, _ in
            let filtered = model.filteredAndSortedFiles
            if let selected = model.selectedItem {
                if !filtered.contains(where: { $0.url == selected.url }) {
                    model.selectedItem = filtered.first
                }
            } else {
                model.selectedItem = filtered.first
            }
        }
    }
    
    private func handleKeyPress(_ press: KeyPress, files: [FileItem]) -> KeyPress.Result {
        // Command+C and Command+V take global precedence
        if press.modifiers == .command {
            if press.characters.lowercased() == "c" {
                model.copyToPasteboard()
                return .handled
            }
            if press.characters.lowercased() == "v" {
                model.pasteFromPasteboard()
                return .handled
            }
        }
        
        if model.isFilterActive {
            // 1. Handle Escape to clear and close filter
            if press.key == .escape {
                model.filterText = ""
                model.isFilterActive = false
                return .handled
            }
            
            // 2. Handle Backspace (represented by delete key or control character)
            if press.key == .delete || press.characters.first == "\u{7F}" || press.characters.first == "\u{08}" {
                if !model.filterText.isEmpty {
                    model.filterText.removeLast()
                }
                if model.filterText.isEmpty {
                    model.isFilterActive = false
                }
                return .handled
            }
            
            // 3. Handle Return to open selected file/folder
            if press.key == .return {
                if let selected = model.selectedItem {
                    model.openItem(selected)
                }
                model.filterText = ""
                model.isFilterActive = false
                return .handled
            }
            
            // 4. Handle Arrow navigation while filtering
            if press.key == .downArrow {
                selectNext(files: files)
                return .handled
            }
            if press.key == .upArrow {
                selectPrevious(files: files)
                return .handled
            }
            
            // 5. Capture other printable characters
            if press.isPrintableCharacter {
                model.filterText.append(press.characters)
                return .handled
            }
            
            return .ignored
        } else {
            // Filter is NOT active
            
            // 1. Check for '/' to activate filter (no modifier or only shift)
            if press.modifiers.subtracting(.shift).isEmpty && press.characters == "/" {
                model.isFilterActive = true
                model.filterText = ""
                return .handled
            }
            
            // 2. Normal navigation keys
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
                break
            }
            
            // 3. Vim navigation keys (no modifier or only shift)
            if press.modifiers.subtracting(.shift).isEmpty {
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
                case "v":
                    if let selected = model.selectedItem, selected.isDirectory {
                        model.openInOtherPane(selected)
                        return .handled
                    }
                    return .ignored
                case "y":
                    model.copyToPasteboard()
                    return .handled
                case "p":
                    model.pasteFromPasteboard()
                    return .handled
                default:
                    break
                }
            }
            
            // 4. Any other printable character starts the filter (smart direct filter)
            if press.isPrintableCharacter {
                model.isFilterActive = true
                model.filterText = press.characters
                return .handled
            }
            
            return .ignored
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
    var currentDirectory: URL? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if let currentDir = currentDirectory,
                       item.url.deletingLastPathComponent().standardized != currentDir.standardized {
                        let relativePath = getRelativePath(from: currentDir, to: item.url.deletingLastPathComponent())
                        if !relativePath.isEmpty {
                            Text(relativePath)
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                                .lineLimit(1)
                        }
                    }
                }
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
    
    private func getRelativePath(from base: URL, to target: URL) -> String {
        let basePath = base.standardized.path
        let targetPath = target.standardized.path
        
        if targetPath.hasPrefix(basePath) {
            let relative = String(targetPath.dropFirst(basePath.count))
            if relative.hasPrefix("/") {
                return String(relative.dropFirst())
            }
            return relative
        }
        return ""
    }
}
