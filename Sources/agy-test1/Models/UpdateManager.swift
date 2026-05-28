import Foundation
import Observation
import AppKit

@Observable
@MainActor
public final class UpdateManager: Sendable {
    public enum UpdateStatus: Sendable, Equatable {
        case idle
        case checking
        case updateAvailable(version: String, downloadURL: URL)
        case upToDate
        case downloading(progress: Double)
        case extracting
        case readyToRestart(version: String)
        case failed(error: String)
    }
    
    public private(set) var status: UpdateStatus = .idle
    public let currentVersion: String
    
    public init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version.hasPrefix("v") ? version : "v\(version)"
        } else {
            self.currentVersion = "v1.0.0" // Dev mode version
        }
    }
    
    @MainActor
    public func checkForUpdates() {
        guard status == .idle || status == .upToDate || isFailedStatus else { return }
        status = .checking
        
        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/ljack/agy-test1/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("AgyFinder-Updater", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NSError(domain: "UpdateManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to query GitHub Releases API"])
                }
                
                struct GitHubRelease: Decodable {
                    let tag_name: String
                    let assets: [GitHubAsset]
                }
                struct GitHubAsset: Decodable {
                    let name: String
                    let browser_download_url: URL
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                
                let latestVer = release.tag_name
                let currentVer = self.currentVersion
                
                let cleanLatest = latestVer.replacingOccurrences(of: "v", with: "")
                let cleanCurrent = currentVer.replacingOccurrences(of: "v", with: "")
                
                let isNewer = cleanLatest.localizedStandardCompare(cleanCurrent) == .orderedDescending
                
                if isNewer {
                    if let zipAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) {
                        self.status = .updateAvailable(version: latestVer, downloadURL: zipAsset.browser_download_url)
                    } else {
                        throw NSError(domain: "UpdateManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No compatible AgyFinder.zip asset found in the latest release."])
                    }
                } else {
                    self.status = .upToDate
                }
            } catch {
                self.status = .failed(error: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    public func downloadAndInstall() {
        guard case let .updateAvailable(latestVersion, downloadURL) = status else { return }
        status = .downloading(progress: 0.0)
        
        Task {
            do {
                // 1. Download the ZIP file
                let (tempZipURL, _) = try await URLSession.shared.download(from: downloadURL)
                
                self.status = .extracting
                
                // 2. Unzip using standard /usr/bin/unzip process
                let fileManager = FileManager.default
                let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-o", tempZipURL.path, "-d", tempDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                
                guard unzipProcess.terminationStatus == 0 else {
                    throw NSError(domain: "UpdateManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unzip operation failed with status \(unzipProcess.terminationStatus)"])
                }
                
                // 3. Find the app bundle inside extracted files
                let items = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                guard let newAppURL = items.first(where: { $0.pathExtension == "app" }) else {
                    throw NSError(domain: "UpdateManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not find AgyFinder.app inside the downloaded release archive."])
                }
                
                // 4. Locate current running bundle
                let currentBundleURL = Bundle.main.bundleURL
                guard currentBundleURL.pathExtension == "app" else {
                    throw NSError(domain: "UpdateManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot update: App is not running as a packaged macOS App Bundle."])
                }
                
                // 5. Replace current bundle URL atomically
                _ = try fileManager.replaceItemAt(currentBundleURL, withItemAt: newAppURL, backupItemName: nil, options: [])
                
                // Clean up tempDir
                try? fileManager.removeItem(at: tempDir)
                
                self.status = .readyToRestart(version: latestVersion)
            } catch {
                self.status = .failed(error: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    public func relaunch() {
        guard case .readyToRestart = status else { return }
        
        let currentBundleURL = Bundle.main.bundleURL
        let openProcess = Process()
        openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProcess.arguments = [currentBundleURL.path]
        
        do {
            try openProcess.run()
            NSApplication.shared.terminate(nil)
        } catch {
            status = .failed(error: "Failed to relaunch app: \(error.localizedDescription)")
        }
    }
    
    private var isFailedStatus: Bool {
        if case .failed = status { return true }
        return false
    }
}
