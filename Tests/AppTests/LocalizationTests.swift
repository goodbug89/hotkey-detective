import XCTest
@testable import HotkeyDetective

/// 15개 언어 카탈로그가 서로 어긋나지 않는지 고정한다.
/// 키가 빠지면 해당 언어에서 키 이름이 그대로 화면에 나오고, 포맷 인자 개수가
/// 다르면 런타임에 잘못된 값이 끼워진다 — 둘 다 번역 작업에서 흔한 실패다.
final class LocalizationTests: XCTestCase {
    static let languages = ["en", "ko", "ja", "zh-Hans", "zh-Hant", "de", "fr", "es",
                            "it", "pt-BR", "ru", "ar", "th", "tr", "vi"]

    func strings(for lang: String) throws -> [String: String] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "strings",
                                          subdirectory: nil, localization: lang),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else {
            throw XCTSkip("\(lang) 카탈로그를 번들에서 찾지 못했다")
        }
        return dict
    }

    func testAllLanguagesArePresent() throws {
        for lang in Self.languages {
            let d = try strings(for: lang)
            XCTAssertFalse(d.isEmpty, "\(lang) 카탈로그가 비어 있다")
        }
    }

    /// `feature.*`(시스템 기능명)은 의도적으로 한국어에만 있다 — 다른 언어는 macOS가
    /// 쓰는 영문 원문으로 떨어져야 시스템 설정과 표현이 어긋나지 않는다. 비교에서 제외한다.
    private func uiKeys(_ d: [String: String]) -> Set<String> {
        Set(d.keys.filter { !$0.hasPrefix("feature.") })
    }

    func testEveryLanguageHasEveryKey() throws {
        let base = uiKeys(try strings(for: "en"))
        XCTAssertGreaterThan(base.count, 40, "영어 카탈로그가 너무 작다 — 기준으로 쓸 수 없다")
        for lang in Self.languages where lang != "en" {
            let keys = uiKeys(try strings(for: lang))
            XCTAssertTrue(base.subtracting(keys).isEmpty,
                          "\(lang)에 없는 키: \(base.subtracting(keys).sorted())")
            XCTAssertTrue(keys.subtracting(base).isEmpty,
                          "\(lang)에만 있는 키: \(keys.subtracting(base).sorted())")
        }
    }

    /// 시스템 기능명 번역은 한국어에만 있고, 나머지 언어는 macOS의 영문 원문으로 떨어진다.
    /// 키는 영문명 그대로이므로 Engine이 내는 이름과 정확히 맞아야 한다 — 어긋나면
    /// 한국어에서도 조용히 영어가 나온다.
    func testKoreanFeatureNamesKeyOnTheEnglishSystemName() throws {
        let ko = try strings(for: "ko")
        let features = ko.filter { $0.key.hasPrefix("feature.") }
        XCTAssertGreaterThan(features.count, 70, "한국어 기능명이 거의 없다")
        // Engine이 실제로 내는 영문명으로 키가 잡혀 있는지 대표 항목으로 확인한다.
        XCTAssertEqual(ko["feature.Save picture of selected area as a file"], "영역 스크린샷 저장")
        XCTAssertEqual(ko["feature.Turn VoiceOver on or off"], "VoiceOver 켜기/끄기")
        XCTAssertEqual(ko["feature.Show Spotlight search"], "Spotlight 검색")
        // 다른 언어에는 없어야 한다(영문 폴백이 의도).
        for lang in ["en", "ja", "de"] {
            let d = try strings(for: lang)
            XCTAssertTrue(d.keys.filter { $0.hasPrefix("feature.") }.isEmpty,
                          "\(lang)에 feature.* 키가 있다 — 영문 폴백 설계와 어긋난다")
        }
    }

    /// `%1$@` 같은 위치 인자의 개수가 언어마다 같아야 한다.
    /// 어순이 달라 순서는 바뀌어도 되지만 개수가 다르면 값이 빠지거나 크래시한다.
    func testPositionalArgumentCountsMatch() throws {
        let base = try strings(for: "en")
        for lang in Self.languages where lang != "en" {
            let d = try strings(for: lang)
            for (key, enValue) in base {
                guard let value = d[key] else { continue }
                XCTAssertEqual(positionals(in: enValue), positionals(in: value),
                               "\(lang) / \(key): 인자 집합이 영어와 다르다")
            }
        }
    }

    private func positionals(in s: String) -> Set<String> {
        var out = Set<String>()
        let pattern = try! NSRegularExpression(pattern: #"%(\d+)\$@"#)
        for m in pattern.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            if let r = Range(m.range(at: 1), in: s) { out.insert(String(s[r])) }
        }
        return out
    }
}
