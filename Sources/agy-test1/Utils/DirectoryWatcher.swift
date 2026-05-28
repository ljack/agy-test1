import Foundation

public final class DirectoryWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable () -> Void
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject? = nil
    private let queue = DispatchQueue(label: "com.agy-test1.watcher", qos: .default)
    
    public init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }
    
    public func start() {
        stop()
        
        // Open file descriptor for directory events
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open directory for watching: \(url.path)")
            return
        }
        
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )
        
        dispatchSource.setEventHandler { [weak self] in
            self?.onChange()
        }
        
        dispatchSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        
        self.source = dispatchSource
        dispatchSource.resume()
    }
    
    public func stop() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stop()
    }
}
