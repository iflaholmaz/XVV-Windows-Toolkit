# Contributing / Katkı Rehberi

## Türkçe

Katkı göndermeden önce bir issue açarak değişikliğin kapsamını anlatın. Pull request'ler küçük, tek amaçlı ve geri alınabilir olmalıdır.

- Windows PowerShell 5.1 uyumluluğunu koruyun.
- `.ps1` ve `.psm1` dosyalarını UTF-8 BOM olarak kaydedin.
- Kullanıcıya görünen bütün metinleri Türkçe ve İngilizce ekleyin.
- Yeni kayıt ayarında tam yol, değer adı, tür, geri alma davranışı ve somut açıklama bulunmalıdır.
- Yan etkisi olan ayarlara `DİKKAT / CAUTION` bilgisi ekleyin.
- Defender, Windows Update, kritik hizmetler, HPET/BCD zamanlayıcıları veya kanıtsız ağ ayarları eklemeyin.
- Kaynak paketine çalıştırılabilir üçüncü taraf dosya koymayın.

## English

Open an issue describing the scope before contributing. Pull requests should be small, focused, and reversible.

- Preserve Windows PowerShell 5.1 compatibility.
- Save `.ps1` and `.psm1` files with a UTF-8 BOM.
- Add every user-facing string in both Turkish and English.
- New registry settings must include the exact path, value name, type, rollback behavior, and a concrete explanation.
- Add a `DİKKAT / CAUTION` notice for meaningful side effects.
- Do not add Defender, Windows Update, critical-service, HPET/BCD timer, or unverified network tweaks.
- Do not bundle third-party executables in the source package.

## Validation / Doğrulama

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-XVV.ps1` on Windows before opening a pull request.
