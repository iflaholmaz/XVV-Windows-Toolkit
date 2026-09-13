# XVV Control Center

> A bilingual Windows 10/11 maintenance, setup, hardware-information, and tweak center by **tv3m**.

[Türkçe](#türkçe) · [English](#english)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-2F80ED)
![License](https://img.shields.io/badge/license-MIT-64D8A0)

## Türkçe

XVV; akıllı temizlik, uygulama kaldırma, toplu kurulum, Windows/Regedit ayarları, NVIDIA profilleri, ayrıntılı donanım bilgileri ve sistem araçlarını tek WPF arayüzünde birleştirir.

### Öne çıkanlar

- Silmeden önce boyut gösteren seçmeli temizlik
- Yalnız gerçek Başlat menüsü uygulamalarını gösteren, ikonlu toplu Appx kaldırma
- Winget üzerinden popüler uygulamaları seçerek toplu kurma
- Oyun, gizlilik, görünüm ve Windows ayarlarını tek ekrandan yönetme
- Her ayarın ne yaptığını gösteren açıklama ve teknik ayrıntı bölümü
- Sorun çıkarabilecek seçeneklerde açık bir `DİKKAT` uyarısı
- Değişikliklerden önce otomatik geri yükleme noktası ve ayar yedeği
- Rekabetçi, düşük sistem, gizlilik ve Windows hızlı seçimleri
- CPU, GPU, anakart, BIOS, RAM, disk, monitör, ağ, TPM, batarya, ses ve USB bilgileri
- Uygulama içinden anında Türkçe/İngilizce geçiş

### XVV nasıl başlatılır?

1. Sağdaki **Releases** bölümünden sade kullanıcı ZIP'ini indir veya geliştirme için projeyi klonla.
2. ZIP içindeki `XVV` klasörünü Masaüstüne çıkar.
3. Normal kullanım için `Start-XVV.bat` dosyasına çift tıkla.

### Yönetici olarak çalıştırma

`Start-XVV.bat` dosyasına sağ tıkla ve **Yönetici olarak çalıştır** seçeneğini seç. Uygulamanın sol alt köşesinde yeşil **Yönetici modu** yazısı görünüyorsa yetki başarıyla alınmıştır.

Yönetici modu yalnızca şu işlemler için gereklidir:

- Windows ve Regedit ayarlarını uygulama veya geri alma
- Zorunlu sistem geri yükleme noktası oluşturma
- Windows klasörlerindeki korumalı geçici dosyaları temizleme
- Sistem Dosyası Denetleyicisi'ni (`sfc /scannow`) çalıştırma

Uygulama kurma, bilgisayar özelliklerine bakma ve çoğu hızlı araç için XVV'yi normal şekilde açabilirsin.

Windows PowerShell 5.1 dışında modül kurulumu gerekmez. Hızlı Kurulum sayfası, güncel Windows 10/11 sistemlerinde App Installer ile gelen `winget` komutunu kullanır.

### Güvenlik

- XVV, Microsoft Defender veya Windows Update'i kapatmaz.
- HPET/BCD zamanlayıcı, rastgele ağ değerleri, kritik hizmet kapatma ve RAM temizleyici ayarları içermez.
- Kaynak paketinde üçüncü taraf çalıştırılabilir dosya bulunmaz.
- Ayarlar uygulanmadan önce geri yükleme noktası ve kayıt yedeği oluşturulur.
- Bir ayarın yan etkisi varsa kart üzerinde açıkça gösterilir.

## English

XVV combines smart cleanup, application removal, batch installation, Windows/Registry settings, NVIDIA profiles, detailed hardware information, and system tools in one WPF interface.

### Highlights

- Selective cleanup with size review before deletion
- Icon-aware batch Appx removal limited to real Start-menu applications
- Selection-based batch installation of popular applications through Winget
- Gaming, privacy, appearance, and Windows settings in one screen
- Plain descriptions plus optional technical details for every setting
- A visible `CAUTION` notice for settings with meaningful side effects
- An automatic restore point and settings backup before changes
- Competitive, low-end PC, privacy, and Windows quick selections
- CPU, GPU, motherboard, BIOS, memory, drive, monitor, network, TPM, battery, audio, and USB details
- Instant Turkish/English switching

### How to start XVV

1. Download the clean user ZIP from **Releases**, or clone the repository for development.
2. Extract the included `XVV` folder to your Desktop.
3. Double-click `Start-XVV.bat` for normal use.

### Run as administrator

Right-click `Start-XVV.bat` and choose **Run as administrator**. A green **Administrator mode** indicator in the lower-left corner confirms that elevation succeeded.

Administrator mode is required only for:

- Applying or restoring Windows and Registry settings
- Creating the mandatory system restore point
- Cleaning protected temporary files under Windows directories
- Running System File Checker (`sfc /scannow`)

Quick Install, PC specifications, and most quick tools can be used without administrator mode.

No module beyond Windows PowerShell 5.1 is required. Quick Install uses `winget`, supplied by App Installer on current supported Windows 10/11 systems.

### Safety

- XVV does not disable Microsoft Defender or Windows Update.
- It avoids HPET/BCD timer edits, random network values, critical service disabling, and RAM-cleaner tweaks.
- The source package contains no bundled third-party executable.
- A restore point and registry backup are created before settings are applied.
- Settings with meaningful side effects display a concrete warning on their cards.

## Project layout

```text
XVV/
├── data/install-apps.json
├── src/MainWindow.xaml
├── src/XVV.Core.psm1
├── Start-XVV.bat
├── Start-XVV.ps1
├── Start-XVV.vbs
└── XVV.ps1
```

## Contributing / Katkı

Bug reports and focused pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Security reports follow [SECURITY.md](SECURITY.md).

Hata bildirimleri ve odaklı pull request'ler kabul edilir. Önce [CONTRIBUTING.md](CONTRIBUTING.md), güvenlik bildirimleri için [SECURITY.md](SECURITY.md) dosyasını okuyun.

## Attribution

The project structure and implementation are original. Research was informed by Microsoft documentation and the open-source Windows utility ecosystem, including [Chris Titus Tech's WinUtil](https://github.com/ChrisTitusTech/winutil). No WinUtil source file is bundled.

## License

MIT © 2026 **tv3m** ([@iflaholmaz](https://github.com/iflaholmaz))
