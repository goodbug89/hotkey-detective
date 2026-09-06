#!/usr/bin/env python3
"""소개 페이지를 15개 언어로 생성한다.  사용법: python3 Scripts/build-landing.py

  docs/index.html            영어(정본, canonical)
  docs/<locale>/index.html   나머지 14개

원본은 Scripts/landing/ 에 있다 — template.html 하나와 로케일별 JSON. 페이지를 손으로
15번 고치면 반드시 어긋나므로, 문구는 JSON에서만 고치고 페이지는 항상 생성한다.

영어 출력이 커밋된 docs/index.html과 바이트 단위로 같은지 스스로 검사한다(--check).
추출이 어긋나면 그 자리에서 드러난다.
"""
import datetime, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "Scripts" / "landing"
OUT = ROOT / "docs"
BASE = "https://goodbug89.github.io/hotkey-detective"
DEFAULT = "en"

# 로케일 -> (스위처에 보일 이름, html lang, og:locale, 방향)
LOCALES = {
    "en":      ("English",    "en",      "en_US", "ltr"),
    "ko":      ("한국어",      "ko",      "ko_KR", "ltr"),
    "ja":      ("日本語",      "ja",      "ja_JP", "ltr"),
    "zh-Hans": ("简体中文",    "zh-Hans", "zh_CN", "ltr"),
    "zh-Hant": ("繁體中文",    "zh-Hant", "zh_TW", "ltr"),
    "de":      ("Deutsch",    "de",      "de_DE", "ltr"),
    "fr":      ("Français",   "fr",      "fr_FR", "ltr"),
    "es":      ("Español",    "es",      "es_ES", "ltr"),
    "it":      ("Italiano",   "it",      "it_IT", "ltr"),
    "pt-BR":   ("Português",  "pt-BR",   "pt_BR", "ltr"),
    "ru":      ("Русский",    "ru",      "ru_RU", "ltr"),
    "ar":      ("العربية",     "ar",      "ar_AR", "rtl"),
    "th":      ("ไทย",         "th",      "th_TH", "ltr"),
    "tr":      ("Türkçe",     "tr",      "tr_TR", "ltr"),
    "vi":      ("Tiếng Việt", "vi",      "vi_VN", "ltr"),
}


def page_url(loc): return f"{BASE}/" if loc == DEFAULT else f"{BASE}/{loc}/"
def out_path(loc): return OUT / "index.html" if loc == DEFAULT else OUT / loc / "index.html"
def assets(loc):   return "" if loc == DEFAULT else "../"


def hreflang_block():
    lines = [f'<link rel="alternate" hreflang="{LOCALES[l][1]}" href="{page_url(l)}">' for l in LOCALES]
    lines.append(f'<link rel="alternate" hreflang="x-default" href="{BASE}/">')
    return "\n".join(lines)


def lang_menu(current):
    items = []
    for loc, (label, *_ ) in LOCALES.items():
        cls = ' class="active"' if loc == current else ""
        items.append(f'          <a href="{page_url(loc)}"{cls}>{label}</a>')
    return ('      <details class="lang-switcher">\n'
            f'        <summary>{LOCALES[current][0]}</summary>\n'
            '        <div class="lang-menu">\n' + "\n".join(items) + "\n"
            '        </div>\n'
            '      </details>')


def check_template(template, en_keys):
    """치환자가 엉뚱한 곳에 박히지 않았는지 확인한다.

    문자열을 순서대로 치환해 템플릿을 뽑았더니 짧은 단어가 먼저 만난 자리에 붙어버렸다.
    "System"은 BlinkMacSystemFont 한가운데에, "Install"·"Privacy"·"Verdict"는 CSS 주석에
    들어가 본문 쪽은 영어로 남았다. 영어 출력만 비교해서는 절대 보이지 않는다.
    """
    problems = []
    style = template.split("<style>")[1].split("</style>")[0]
    if "{{" in style:
        problems.append("<style> 블록 안에 치환자가 있다 — CSS가 번역돼 깨진다")
    # meta.title은 <title>과 og:title 양쪽에 의도적으로 쓴다. 그 외에는 한 번씩만.
    REUSED = {"meta.title": 2}
    for k in en_keys:
        n = template.count("{{%s}}" % k)
        if n != REUSED.get(k, 1):
            problems.append(f"{k}: 치환자가 {n}번 — 기대 {REUSED.get(k, 1)}번")
    return problems


def render(loc, template, keys):
    label, lang, oglocale, direction = LOCALES[loc]
    out = template
    for k, v in keys.items():
        out = out.replace("{{%s}}" % k, v)
    # og:title은 meta.title을 그대로 쓴다 — 따로 번역하지 않는다.
    out = out.replace("{{_lang}}", lang).replace("{{_dir}}", direction)
    out = out.replace("{{_canonical}}", page_url(loc)).replace("{{_hreflang}}", hreflang_block())
    out = out.replace("{{_assets}}", assets(loc)).replace("{{_langmenu}}", lang_menu(loc))
    out = out.replace("{{_oglocale}}", oglocale)
    left = [s for s in out.split("{{")[1:]]
    assert not left, f"{loc}: 치환되지 않은 자리 {[x.split('}}')[0] for x in left][:5]}"
    return out


def write_sitemap():
    """15개 로케일을 hreflang 대체 링크와 함께 담은 sitemap을 만든다.

    다국어 사이트에서 sitemap의 xhtml:link는 hreflang 태그와 같은 정보를 검색엔진에
    한 번 더, 더 확실하게 준다. 페이지가 15개로 늘어난 이상 손으로 유지할 대상이 아니다.
    """
    day = datetime.date.today().isoformat()
    alts = "".join(
        f'\n      <xhtml:link rel="alternate" hreflang="{LOCALES[l][1]}" href="{page_url(l)}"/>'
        for l in LOCALES
    ) + f'\n      <xhtml:link rel="alternate" hreflang="x-default" href="{BASE}/"/>'
    urls = "".join(
        f"""  <url>
    <loc>{page_url(l)}</loc>
    <lastmod>{day}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>{"1.0" if l == DEFAULT else "0.8"}</priority>{alts}
  </url>
"""
        for l in LOCALES
    )
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n'
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + urls + "</urlset>\n")
    (OUT / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {BASE}/sitemap.xml\n")
    return len(LOCALES)


def main():
    check = "--check" in sys.argv
    template = (SRC / "template.html").read_text()
    en_keys = json.loads((SRC / "en.json").read_text())
    problems = 0
    for msg in check_template(template, en_keys):
        print(f"  템플릿: {msg}"); problems += 1
    if problems:
        return 1
    for loc in LOCALES:
        path = SRC / f"{loc}.json"
        if not path.exists():
            print(f"  건너뜀: {loc}.json 없음"); continue
        keys = json.loads(path.read_text())
        missing = set(en_keys) - set(keys)
        extra = set(keys) - set(en_keys)
        if missing or extra:
            print(f"  {loc}: 키 불일치 — 누락 {sorted(missing)[:4]} 초과 {sorted(extra)[:4]}")
            problems += 1; continue
        html = render(loc, template, keys)
        # 치환자가 엉뚱한 자리에 붙으면 원래 자리는 영어 원문 그대로 남는다. 영어 출력끼리
        # 비교해서는 절대 드러나지 않는다(영어에서는 결과가 같다) — 실제로 og:title이
        # h1과 같은 단어를 담고 있어 h1이 영어로 남는 사고가 있었다. 번역본에 영어 원문이
        # 통째로 남아 있으면 그 자리에서 실패시킨다.
        if loc != DEFAULT:
            # <style>은 제외한다. CSS 주석과 BlinkMacSystemFont 같은 식별자에 영어 단어가
            # 들어 있는 것은 정상이고, 오히려 그 자리에 치환자가 들어가면 안 된다
            # (그 경우는 check_template이 잡는다).
            body = html.split("</style>", 1)[-1]
            # 단어 경계를 본다. 부분 문자열로 보면 독일어 "Installation"이 영어 "Install"을,
            # 프랑스어 "Sources"가 "Source"를 품고 있어 멀쩡한 번역이 오탐된다.
            leaked = [k for k, v in en_keys.items()
                      if len(v) > 4 and v != keys[k]
                      and re.search(r"(?<![A-Za-z])" + re.escape(v) + r"(?![A-Za-z])", body)]
            if leaked:
                print(f"  {loc}: 영어 원문이 남아 있다 → {leaked[:3]}")
                problems += 1
                continue
        target = out_path(loc)
        if check and loc == DEFAULT:
            current = target.read_text()
            if current != html:
                print("  영어 출력이 커밋된 docs/index.html과 다르다 — 추출이 어긋났다")
                problems += 1
            else:
                print("  영어 출력 바이트 일치 확인")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(html)
        print(f"  {loc:8} → {target.relative_to(ROOT)}  ({len(html):,} bytes)")
    if not problems and not check:
        n = write_sitemap()
        print(f"  sitemap.xml ({n}개 URL) · robots.txt")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
