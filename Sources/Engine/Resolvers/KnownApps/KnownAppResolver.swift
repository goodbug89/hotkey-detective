import Foundation
import os

public protocol RunningAppChecker {
    func isRunning(bundleID: String) -> Bool
}

public struct KnownAppDescriptor {
    public let bundleID: String
    public let name: String
    /// 설정 파일 후보. 앞에서부터 존재하는 첫 파일을 쓴다 (샌드박스 컨테이너 경로 → 일반 경로 순).
    public let candidateFileURLs: [URL]
    /// plist 루트 딕셔너리 → (액션명, 조합) 목록
    public let parse: ([String: Any]) -> [(action: String, combo: KeyCombo)]

    public init(bundleID: String, name: String, candidateFileURLs: [URL],
                parse: @escaping ([String: Any]) -> [(action: String, combo: KeyCombo)]) {
        self.bundleID = bundleID
        self.name = name
        self.candidateFileURLs = candidateFileURLs
        self.parse = parse
    }

    public init(bundleID: String, name: String, defaultFileURL: URL,
                parse: @escaping ([String: Any]) -> [(action: String, combo: KeyCombo)]) {
        self.init(bundleID: bundleID, name: name, candidateFileURLs: [defaultFileURL], parse: parse)
    }

    /// 존재하는 첫 후보. 없으면 첫 후보(로그용).
    public var resolvedFileURL: URL {
        candidateFileURLs.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidateFileURLs[0]
    }
}

public struct KnownAppResolver: Resolver, Enumerable {
        let descriptor: KnownAppDescriptor
    let fileURL: URL
    let running: RunningAppChecker
    private static let log = Logger(subsystem: "HotkeyDetective", category: "knownapp")

    public init(descriptor: KnownAppDescriptor, fileURL: URL? = nil, running: RunningAppChecker) {
        self.descriptor = descriptor
        self.fileURL = fileURL ?? descriptor.resolvedFileURL
        self.running = running
    }

    public func resolve(_ combo: KeyCombo, probe: ProbeSnapshot?) -> [Evidence] {
        allPairs().filter { $0.0 == combo }.map { $0.1 }
    }

    public func allPairs() -> [(KeyCombo, Evidence)] {
        guard let data = try? Data(contentsOf: fileURL),
              let root = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            Self.log.debug("\(descriptor.name): 설정 파일 없음/파싱 실패 \(fileURL.path)")
            return []
        }
        let isRunning = running.isRunning(bundleID: descriptor.bundleID)
        return descriptor.parse(root).map { hit in
            (hit.combo, Evidence(source: .knownAppParser(appName: descriptor.name),
                owner: .app(bundleID: descriptor.bundleID, name: descriptor.name, action: hit.action),
                confidence: isRunning ? .high : .low,
                reason: .knownApp(app: descriptor.name, action: hit.action,
                                  combo: hit.combo.display, isRunning: isRunning)))
        }
    }
}

public enum KnownApps {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let prefs = home.appendingPathComponent("Library/Preferences")
    /// 샌드박스 앱의 설정 경로
    static func containerPrefs(_ bundleID: String) -> URL {
        home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
    }

    public static let parserBundleIDs: Set<String> = ["com.knollsoft.Rectangle", "org.p0deje.Maccy", "com.raycast.macos"]

    public static func all(running: RunningAppChecker) -> [Resolver] {
        [rectangle, maccy, raycast].map { KnownAppResolver(descriptor: $0, running: running) }
    }
}
