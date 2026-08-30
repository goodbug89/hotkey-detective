<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Klavye kısayolunuzu hangi uygulamanın aldığını bulun.</strong><br>
  macOS bunu sormanın bir yolunu sunmuyor. Bu araç sunuyor.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Dil:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <strong>Türkçe</strong> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

---

⇧⌘4 tuşuna basıyorsunuz ve hiçbir şey olmuyor. Bir uygulama kısayolu almış — ama hangisi? macOS'ta bunu yanıtlayan bir API yok, Sistem Ayarları'ndan da bakılamıyor.

HotkeyDetective kanıt toplar, bir karar verir ve gerekçesini de gösterir:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## Nasıl çalışır

«Bu kısayol kime ait» sorusunun tek bir doğru kaynağı yok; bu yüzden uygulama bağımsız sinyaller toplayıp ağırlıklandırır:

| Kaynak | Neyi kanıtlar | Güç |
| --- | --- | --- |
| **Sistem kısayolları** | macOS'un kendi tablosu bu kombinasyonu atamış | Kesin |
| **Uygulama ayarları** | Bilinen bir uygulamanın ayar dosyası bu kombinasyonu atamış | Yüksek (uygulama kapalıysa düşük) |
| **Ayar taraması** | Bir uygulamanın ayarları bilinen bir saklama biçimine uyuyor | Orta |
| **Tepki** | Tuşa basıldıktan hemen sonra bir uygulama pencere açtı ya da öne geldi | Yüksek |
| **Kısayol sondası** | Bir işlem Carbon kısayol kaydını elinde tutuyor | Yalnızca gözlem |

Karar `kesin`, `muhtemel`, `çakışma`, `kullanımda ama tespit edilemedi` veya `boş` olur. Her iddia dayandığı kanıtı gösterir; kara kutuya güvenmek yerine kendiniz karar verirsiniz.

Bir ayrım önemli: **tepki**, uygulamanın tuşu *aldığını* kanıtlar, *kaydettiğini* değil. Tepki bir sahibi destekleyebilir ama asla ona itiraz edemez. Bu kural olmasa ⌘Space «sistem ile Spotlight çekişiyor» gibi görünürdü, oysa ortada sorun yok.

## Kurulum

macOS 14 veya üstü gerekir.

**Homebrew** (önerilir — `brew upgrade` güncel tutar):

```bash
brew install --cask goodbug89/tap/hotkey-detective
```

**Doğrudan indirme:** [son sürümden](https://github.com/goodbug89/hotkey-detective/releases/latest) noter onaylı `.dmg` dosyasını indirin, açın ve uygulamayı Uygulamalar’a sürükleyin.

**Kaynaktan derleme:**

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

Anahtar zincirinizde Developer ID sertifikası varsa onunla, yoksa ad-hoc imzalanır. Ad-hoc derlemeler her yeniden derlemede izinlerini kaybeder — bkz. [BUILDING.md](../../BUILDING.md).

## İzinler

Sonda için hem **Erişilebilirlik** hem **Girdi İzleme** gerekir. macOS, yalnızca dinleyen bir klavye event tap'i için ikisini birden ister.

Tuş basışları gözlemlenir; asla yakalanmaz, kaydedilmez veya saklanmaz. Tap `.listenOnly` ile oluşturulur, böylece gerçek sahip tuşu almaya devam eder — tepki algılama tam olarak buna dayanır. Sondadan sonra geriye yalnızca sorduğunuz tek kombinasyon kalır. Bu depoda ağ kodu yoktur.

İzin verilmezse uygulama **sınırlı modda** çalışır: kombinasyonu elle seçersiniz, yanıt yalnızca ayar dosyalarından gelir.

## Bilinen sınırlar

- **Carbon kısayol sondası diğer işlemleri göremez.** `RegisterEventHotKey` çakışmayı yalnızca kendi işleminiz içinde bildirir; bu yüzden «kullanımda ama tespit edilemedi» kararına pratikte ulaşılamaz. Kısayol kaydeden, pencere göstermeyen ve ayarlarını tanınmayan bir biçimde saklayan bir uygulama görünmez kalır.
- **Sistem işlev adları Korece dışında İngilizcedir.** macOS kendi çevirilerini okuyamadığımız bir yerde tutuyor; kendi çevirimizi yapsak Sistem Ayarları'nda gördüğünüzden farklı olurdu.
- **Ayar taraması iki saklama biçimini tanır** (`KeyboardShortcuts` kütüphanesi ve `MASShortcut` tarzı sözlükler). Kendi biçimini kullanan uygulamalar için ayrı bir ayrıştırıcı gerekir — [katkılar memnuniyetle karşılanır](../../CONTRIBUTING.md).

## Kim geliştiriyor

HotkeyDetective, macOS için çift bölmeli dosya yöneticisi **[Unifyl](https://unifyl.app)** ekibi tarafından geliştiriliyor.

## Lisans

MIT — [LICENSE](../../LICENSE)

