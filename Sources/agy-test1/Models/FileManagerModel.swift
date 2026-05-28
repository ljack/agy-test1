import Foundation
import Observation
import AppKit

@Observable
@MainActor
public final class FileManagerModel: Sendable {
    public private(set) var currentDirectory: URL
    public private(set) var files: [FileItem] = []
    public var selectedItem: FileItem? = nil
    public private(set) var recentDirectories: [URL] = []
    public private(set) var favoriteDirectories: [FileItem] = []
    
    public var searchQuery: String = ""
    public var showHiddenFiles: Bool = false {
        didSet { reload() }
    }
    
    public var sortBy: SortField = .name
    public var sortAscending: Bool = true
    
    private var backHistory: [URL] = []
    private var forwardHistory: [URL] = []
    
    // File watcher reference
    private var directoryWatcher: DirectoryWatcher? = nil
    
    public enum SortField: String, CaseIterable, Identifiable, Sendable {
        case name = "Name"
        case date = "Date Modified"
        case size = "Size"
        case `extension` = "Kind"
        
        public var id: String { rawValue }
    }
    
    public init(startDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.currentDirectory = startDirectory.standardized
        loadFavorites()
        reload()
        setupWatcher()
    }
    
    public func reload() {
        let path = currentDirectory
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            do {
                let urls = try fileManager.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                    options: options
                )
                
                let loadedFiles = urls.map { FileItem(url: $0) }
                
                await MainActor.run {
                    guard self.currentDirectory == path else { return }
                    self.files = loadedFiles
                    if let selected = self.selectedItem, !loadedFiles.contains(where: { $0.url == selected.url }) {
                        self.selectedItem = nil
                    }
                    self.addToRecents(path)
                }
            } catch {
                print("Error loading directory \(path.path): \(error)")
                await MainActor.run {
                    guard self.currentDirectory == path else { return }
                    self.files = []
                    self.selectedItem = nil
                }
            }
        }
    }
    
    private func addToRecents(_ url: URL) {
        var recents = recentDirectories
        recents.removeAll { $0 == url }
        recents.insert(url, at: 0)
        if recents.count > 8 {
            recents = Array(recents.prefix(8))
        }
        self.recentDirectories = recents
    }
    
    private func setupWatcher() {
        directoryWatcher?.stop()
        directoryWatcher = DirectoryWatcher(url: currentDirectory) { [weak self] in
            Task { @MainActor in
                self?.reload()
            }
        }
        directoryWatcher?.start()
    }
    
    public var filteredAndSortedFiles: [FileItem] {
        var result = files
        
        if !searchQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
        
        result.sort { (item1, item2) -> Bool in
            // Folders always go first
            if item1.isDirectory != item2.isDirectory {
                return item1.isDirectory && !item2.isDirectory
            }
            
            let ascending: Bool
            switch sortBy {
            case .name:
                ascending = item1.name.localizedStandardCompare(item2.name) == .orderedAscending
            case .date:
                let date1 = item1.modificationDate ?? Date.distantPast
                let date2 = item2.modificationDate ?? Date.distantPast
                ascending = date1 < date2
            case .size:
                ascending = item1.size < item2.size
            case .extension:
                ascending = item1.fileExtension.localizedStandardCompare(item2.fileExtension) == .orderedAscending
            }
            
            return sortAscending ? ascending : !ascending
        }
        
        return result
    }
    
    // Navigation actions
    
    public func navigateTo(url: URL) {
        let target = url.standardized
        guard target != currentDirectory else { return }
        
        backHistory.append(currentDirectory)
        forwardHistory.removeAll()
        
        currentDirectory = target
        selectedItem = nil
        reload()
        setupWatcher()
    }
    
    public func goBack() {
        guard let previous = backHistory.popLast() else { return }
        forwardHistory.append(currentDirectory)
        currentDirectory = previous
        selectedItem = nil
        reload()
        setupWatcher()
    }
    
    public func goForward() {
        guard let next = forwardHistory.popLast() else { return }
        backHistory.append(currentDirectory)
        currentDirectory = next
        selectedItem = nil
        reload()
        setupWatcher()
    }
    
    public func goUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        // Prevent going past root
        if parent != currentDirectory {
            navigateTo(url: parent)
        }
    }
    
    public var canGoBack: Bool {
        !backHistory.isEmpty
    }
    
    public var canGoForward: Bool {
        !forwardHistory.isEmpty
    }
    
    public var canGoUp: Bool {
        currentDirectory.path != "/"
    }
    
    // File operations
    
    public func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(url: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    public func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    public func openInTerminal(_ url: URL) {
        let script = "tell application \"Terminal\" to do script \"cd '\(url.path)'\""
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                print("AppleScript error opening terminal: \(error)")
            }
        }
    }
    
    public func moveToTrash(_ item: FileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            // Watcher will trigger reload, but let's proactively refresh list
            reload()
        } catch {
            print("Failed to move \(item.name) to trash: \(error)")
        }
    }
    
    // Favorites Management
    
    public func addToFavorites(_ item: FileItem) {
        guard item.isDirectory else { return }
        if !favoriteDirectories.contains(where: { $0.url == item.url }) {
            favoriteDirectories.append(item)
            saveFavorites()
        }
    }
    
    public func removeFromFavorites(_ url: URL) {
        favoriteDirectories.removeAll { $0.url == url }
        saveFavorites()
    }
    
    private func saveFavorites() {
        let paths = favoriteDirectories.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: "FavoriteDirectoriesPaths")
    }
    
    private func loadFavorites() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let defaultPaths = [
            home.path,
            home.appendingPathComponent("Desktop").path,
            home.appendingPathComponent("Documents").path,
            home.appendingPathComponent("Downloads").path,
            "/Users/jarkko/_dev"
        ]
        
        let paths = UserDefaults.standard.stringArray(forKey: "FavoriteDirectoriesPaths") ?? defaultPaths
        self.favoriteDirectories = paths.map { path in
            FileItem(url: URL(fileURLWithPath: path))
        }
    }
}
