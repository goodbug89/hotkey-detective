#!/usr/bin/env python3
"""언어별 복수 규칙을 담은 Localizable.stringsdict를 15개 .lproj에 생성한다.

.strings로는 복수를 처리할 수 없어 "%1$@ piece(s) of evidence"처럼 괄호로 때우고 있었다.
언어마다 복수 범주가 다르다 — 한국어·일본어·중국어·태국어·베트남어는 구분이 없고,
러시아어는 one/few/many, 아랍어는 zero/one/two/few/many까지 나뉜다. 괄호 표기는 그 어느
쪽도 맞지 않는다.

stringsdict는 정수 인자를 요구하므로 호출부도 String(count)가 아니라 Int를 넘긴다.
"""
import plistlib, pathlib

R = pathlib.Path("Sources/HotkeyDetective/Resources")

# lang -> key -> variable -> {category: text}
# 값이 없는 범주는 넣지 않는다. "other"는 필수다.
D = {
"en": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld piece of evidence", "other": "%ld pieces of evidence"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "opened %ld new window", "other": "opened %ld new windows"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld registered", "other": "%ld registered"},
                                              "c": {"one": "%ld conflict", "other": "%ld conflicts"}}),
},
"ko": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "근거 %ld건"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "새 창 %ld개 표시"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "등록 %ld"}, "c": {"other": "충돌 %ld"}}),
},
"ja": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "根拠 %ld 件"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "新しいウインドウを %ld 個表示"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "登録 %ld"}, "c": {"other": "競合 %ld"}}),
},
"zh-Hans": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "%ld 条依据"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "打开了 %ld 个新窗口"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "已注册 %ld"}, "c": {"other": "冲突 %ld"}}),
},
"zh-Hant": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "%ld 項依據"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "開啟了 %ld 個新視窗"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "已註冊 %ld"}, "c": {"other": "衝突 %ld"}}),
},
"de": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld Beleg", "other": "%ld Belege"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "%ld neues Fenster geöffnet", "other": "%ld neue Fenster geöffnet"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld registriert", "other": "%ld registriert"},
                                              "c": {"one": "%ld Konflikt", "other": "%ld Konflikte"}}),
},
"fr": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld élément de preuve", "other": "%ld éléments de preuve"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "%ld nouvelle fenêtre ouverte", "other": "%ld nouvelles fenêtres ouvertes"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld enregistré", "other": "%ld enregistrés"},
                                              "c": {"one": "%ld en conflit", "other": "%ld en conflit"}}),
},
"es": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld prueba", "other": "%ld pruebas"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "abrió %ld ventana nueva", "other": "abrió %ld ventanas nuevas"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld registrado", "other": "%ld registrados"},
                                              "c": {"one": "%ld en conflicto", "other": "%ld en conflicto"}}),
},
"it": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld prova", "other": "%ld prove"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "ha aperto %ld nuova finestra", "other": "ha aperto %ld nuove finestre"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld registrata", "other": "%ld registrate"},
                                              "c": {"one": "%ld in conflitto", "other": "%ld in conflitto"}}),
},
"pt-BR": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld evidência", "other": "%ld evidências"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "abriu %ld nova janela", "other": "abriu %ld novas janelas"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"one": "%ld registrado", "other": "%ld registrados"},
                                              "c": {"one": "%ld em conflito", "other": "%ld em conflito"}}),
},
"ru": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"one": "%ld свидетельство", "few": "%ld свидетельства",
                                            "many": "%ld свидетельств", "other": "%ld свидетельства"}}),
  "signal.newWindows": ("%#@n@", {"n": {"one": "открыто %ld новое окно", "few": "открыто %ld новых окна",
                                        "many": "открыто %ld новых окон", "other": "открыто %ld новых окна"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "Зарегистрировано: %ld"},
                                              "c": {"other": "Конфликтов: %ld"}}),
},
"ar": {
  "verdict.evidenceCount": ("‏%#@n@", {"n": {"zero": "لا أدلة", "one": "دليل واحد", "two": "دليلان",
                                                  "few": "%ld أدلة", "many": "%ld دليلًا", "other": "%ld دليل"}}),
  "signal.newWindows": ("%#@n@", {"n": {"zero": "لم يفتح أي نافذة", "one": "فتح نافذة جديدة", "two": "فتح نافذتين جديدتين",
                                        "few": "فتح %ld نوافذ جديدة", "many": "فتح %ld نافذة جديدة", "other": "فتح %ld نافذة جديدة"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "مسجّل %ld"}, "c": {"other": "متعارض %ld"}}),
},
"th": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "หลักฐาน %ld รายการ"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "เปิดหน้าต่างใหม่ %ld บาน"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "ลงทะเบียน %ld"}, "c": {"other": "ขัดแย้ง %ld"}}),
},
"tr": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "%ld kanıt"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "%ld yeni pencere açtı"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "%ld kayıtlı"}, "c": {"other": "%ld çakışma"}}),
},
"vi": {
  "verdict.evidenceCount": ("%#@n@", {"n": {"other": "%ld bằng chứng"}}),
  "signal.newWindows": ("%#@n@", {"n": {"other": "mở %ld cửa sổ mới"}}),
  "inventory.summary": ("%1$#@r@ · %2$#@c@", {"r": {"other": "%ld đã đăng ký"}, "c": {"other": "%ld xung đột"}}),
},
}

for lang, keys in D.items():
    out = {}
    for key, (fmt, variables) in keys.items():
        entry = {"NSStringLocalizedFormatKey": fmt}
        for name, forms in variables.items():
            assert "other" in forms, f"{lang}/{key}/{name}: other 범주는 필수"
            entry[name] = {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                           "NSStringFormatValueTypeKey": "ld", **forms}
        out[key] = entry
    path = R / f"{lang}.lproj/Localizable.stringsdict"
    path.write_bytes(plistlib.dumps(out, sort_keys=True))
    print(f"{lang:8} {len(out)}개 키")
