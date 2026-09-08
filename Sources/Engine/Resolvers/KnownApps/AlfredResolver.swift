import Foundation

extension KnownApps {
    /// Alfred — 런처. 메인 단축키를 설정 번들 안 `hotkey/prefs.plist`에 둔다:
    ///
    ///     { "default" = { key = 38; mod = 1835008; string = "J" } }
    ///
    /// 실측(2026-09-09, Alfred 5.7.3): `key`는 가상 키코드(38 = J), `mod`는 CG 수정자
    /// 비트(1835008 = ⌃262144 + ⌥524288 + ⌘1048576)다. `string`은 표시용이라 쓰지 않는다.
    ///
    /// 경로가 고정이 아니다. `~/Library/Application Support/Alfred/prefs.json`이 활성 설정
    /// 번들의 위치(`current`, 동기화 폴더를 가리킬 수 있다)와 머신별 `localhash`를 담고,
    /// 단축키 파일은 그 둘을 합쳐야 나온다. 그래서 이 서술자만 계산 프로퍼티다 —
    /// 매번 다시 읽어 사용자가 설정 폴더를 옮겨도 따라간다.
    public static var alfred: KnownAppDescriptor {
        KnownAppDescriptor(
            bundleID: "com.runningwithcrayons.Alfred", name: "Alfred",
            candidateFileURLs: alfredHotkeyURLs
        ) { root in
            root.compactMap { key, value -> (action: String, combo: KeyCombo)? in
                guard let entry = value as? [String: Any],
                      let code = (entry["key"] as? NSNumber)?.uint16Value,
                      let mod = (entry["mod"] as? NSNumber)?.uint64Value else { return nil }
                return (action: key, combo: KeyCombo(keyCode: code, modifiers: Modifiers(cgFlags: mod)))
            }
            .sorted { $0.action < $1.action }   // plist 딕셔너리 순서는 비결정적
        }
    }

    /// prefs.json에서 단축키 파일 경로를 만든다. 읽지 못하면 표준 위치를 돌려준다 —
    /// 후보가 비면 resolvedFileURL이 첫 원소를 꺼내다 죽는다.
    static var alfredHotkeyURLs: [URL] {
        let support = home.appendingPathComponent("Library/Application Support/Alfred")
        let standard = support.appendingPathComponent("Alfred.alfredpreferences")
        func hotkeyFile(bundle: URL, hash: String) -> URL {
            bundle.appendingPathComponent("preferences/local/\(hash)/hotkey/prefs.plist")
        }
        guard let data = try? Data(contentsOf: support.appendingPathComponent("prefs.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hash = json["localhash"] as? String, !hash.isEmpty else {
            return [hotkeyFile(bundle: standard, hash: "")]
        }
        let bundle = (json["current"] as? String).map { URL(fileURLWithPath: $0) } ?? standard
        return [hotkeyFile(bundle: bundle, hash: hash)]
    }
}
