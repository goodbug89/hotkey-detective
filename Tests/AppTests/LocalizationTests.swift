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

    /// contested 소유자는 셋 이상이 될 수 있다 — VerdictBuilder는 certain 소유자를 전부 싣는다
    /// (`certainOwners.count > 1`, `[certain] + rivals`). 그런데 초기 번역 10개는 "둘"을 못 박고
    /// 있었다(both / 両方とも / beide / سجّلا 같은 쌍수형). 셋이 걸리면 그 언어에서만 조용히
    /// 틀린 문장이 나오고, 한국어 화면만 보는 개발자에게는 영원히 보이지 않는다.
    func testContestedHeadlineDoesNotAssumeTwoOwners() throws {
        let dualForms = ["both", "両方", "beide", "les deux", "ambos", "entrambi",
                         "os dois", "ikisi", "ทั้งคู่", "سجّلا", "оба"]
        for lang in Self.languages {
            let line = try XCTUnwrap(strings(for: lang)["verdict.contested"], "\(lang)에 verdict.contested가 없다")
            for form in dualForms {
                XCTAssertFalse(line.lowercased().contains(form.lowercased()),
                               "\(lang): 소유자가 둘이라고 전제한다(\"\(form)\") — \(line)")
            }
        }
    }

    /// 근거 행의 뱃지 칸은 그 언어의 가장 긴 뱃지에 맞춰 늘어난다(SourceBadge.columnWidth).
    /// 번역자가 뱃지에 문장을 넣으면 칸이 설명을 밀어내 행이 무너진다. 짧게 유지시킨다.
    /// (64pt 고정이던 시절에는 반대로 러시아어 "Настройки"가 "Настро…"로 잘렸다.)
    func testSourceBadgeLabelsStayShort() throws {
        let keys = ["badge.system", "badge.parser", "badge.scan", "badge.reaction", "badge.probe"]
        for lang in Self.languages {
            let d = try strings(for: lang)
            for key in keys {
                let label = try XCTUnwrap(d[key], "\(lang)에 \(key)가 없다")
                XCTAssertLessThanOrEqual(label.count, 14,
                    "\(lang) \(key)가 너무 길다(\(label.count)자): \(label) — 뱃지는 한 단어여야 한다")
            }
        }
    }

    // MARK: 복수형 (.stringsdict)

    func plurals(for lang: String) throws -> [String: [String: Any]] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "stringsdict",
                                          subdirectory: nil, localization: lang),
              let dict = NSDictionary(contentsOf: url) as? [String: [String: Any]] else {
            throw XCTSkip("\(lang) stringsdict를 번들에서 찾지 못했다")
        }
        return dict
    }

    /// 개수가 들어가는 문구는 15개 언어 전부에 있어야 한다. 빠진 언어에서는 키 이름이
    /// 그대로 화면에 나온다 — .strings에서 이미 지웠으므로 폴백이 없다.
    func testEveryLanguageHasEveryPluralKey() throws {
        let base = Set(try plurals(for: "en").keys)
        XCTAssertEqual(base, ["verdict.evidenceCount", "signal.newWindows", "inventory.summary"])
        for lang in Self.languages where lang != "en" {
            XCTAssertEqual(Set(try plurals(for: lang).keys), base, "\(lang)의 복수형 키가 영어와 다르다")
        }
    }

    /// 모든 복수 변수에 other 범주가 있어야 한다. 없으면 그 개수에서 문구가 비어버린다.
    func testEveryPluralVariableHasOtherCategory() throws {
        for lang in Self.languages {
            for (key, entry) in try plurals(for: lang) {
                for (name, value) in entry where name != "NSStringLocalizedFormatKey" {
                    let forms = try XCTUnwrap(value as? [String: Any], "\(lang)/\(key)/\(name)이 사전이 아니다")
                    XCTAssertNotNil(forms["other"], "\(lang)/\(key)/\(name)에 other 범주가 없다")
                    XCTAssertEqual(forms["NSStringFormatSpecTypeKey"] as? String, "NSStringPluralRuleType",
                                   "\(lang)/\(key)/\(name)의 규칙 종류가 잘못됐다")
                }
            }
        }
    }

    /// 같은 키가 .strings와 .stringsdict 양쪽에 있으면 어느 쪽이 쓰이는지 흐려진다.
    /// (실제로는 stringsdict가 이기지만, 번역자가 .strings만 고치고 반영이 안 됐다고
    /// 오해하기 쉽다.) 겹치지 않게 못 박는다.
    func testPluralKeysAreNotAlsoInStrings() throws {
        let pluralKeys = Set(try plurals(for: "en").keys)
        for lang in Self.languages {
            let overlap = pluralKeys.intersection(Set(try strings(for: lang).keys))
            XCTAssertTrue(overlap.isEmpty, "\(lang): \(overlap.sorted())가 .strings에도 남아 있다")
        }
    }

    /// 괄호 복수 표기가 다시 들어오지 않게 한다 — "(s)"는 복수 규칙이 아니라 회피다.
    func testNoParentheticalPluralsRemainInStrings() throws {
        for lang in Self.languages {
            for (key, value) in try strings(for: lang) {
                XCTAssertFalse(value.contains("(s)") || value.contains("(e)") || value.contains("(es)"),
                               "\(lang) \(key): 괄호 복수 표기 — .stringsdict로 옮겨야 한다: \(value)")
            }
        }
    }
}
