import Foundation
import UniformTypeIdentifiers

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let size: Int64
    public let modificationDate: Date?
    
    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        var isDir = false
        var isSymLink = false
        var fileSize: Int64 = 0
        var modDate: Date? = nil
        
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) {
            isDir = values.isDirectory ?? false
            isSymLink = values.isSymbolicLink ?? false
            fileSize = Int64(values.fileSize ?? 0)
            modDate = values.contentModificationDate
        } else {
            // Fallback
            var isDirectoryValue: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryValue) {
                isDir = isDirectoryValue.boolValue
            }
        }
        
        self.isDirectory = isDir
        self.isSymbolicLink = isSymLink
        self.size = fileSize
        self.modificationDate = modDate
    }
    
    public var fileExtension: String {
        url.pathExtension
    }
    
    public var utType: UTType? {
        UTType(filenameExtension: fileExtension)
    }
    
    public var formattedSize: String {
        if isDirectory {
            return "--"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    public var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    public var iconName: String {
        if isDirectory {
            return "folder"
        }
        if isSymbolicLink {
            return "link"
        }
        
        // Simple SF Symbols mapping based on extension
        let ext = fileExtension.lowercased()
        switch ext {
        case "txt", "md", "rtf", "json", "yaml", "yml", "xml", "csv":
            return "doc.text"
        case "swift", "py", "js", "ts", "html", "css", "rs", "c", "cpp", "h", "go", "sh":
            return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "svg":
            return "doc.richtext" // or "photo"
        case "pdf":
            return "doc.viewfinder"
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        case "mp3", "m4a", "wav", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "video"
        case "app":
            return "app"
        default:
            return "doc"
        }
    }
}
