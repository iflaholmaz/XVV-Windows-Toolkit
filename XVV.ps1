#requires -Version 5.1
[CmdletBinding()]
param()

# XVV Control Center - designed and maintained by tv3m (@iflaholmaz).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $details = ($_ | Out-String)
    try {
        $logPath = Join-Path $PSScriptRoot 'XVV-error.log'
        [IO.File]::WriteAllText($logPath, $details, [Text.UTF8Encoding]::new($true))
    } catch { }
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("XVV baslatilamadi.`n`n$details`nAyrintilar XVV-error.log dosyasina kaydedildi.", 'XVV Baslatma Hatasi', 'OK', 'Error') | Out-Null
    } catch { }
    exit 1
}

if ($env:OS -ne 'Windows_NT') {
    throw 'XVV yalnızca Windows 10/11 üzerinde çalışır.'
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $PSScriptRoot 'src\XVV.Core.psm1') -Force

[xml]$xaml = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'src\MainWindow.xaml') -Raw -Encoding UTF8
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'NavHome','NavCleanup','NavApps','NavInstall','NavFps','NavSpecs','NavTools','PageHome','PageCleanup','PageApps','PageInstall','PageFps','PageSpecs','PageTools',
    'LanguageTrButton','LanguageEnButton','AdminBadge','HomeTitle','HomeSubtitle','OsLabel','DiskLabel','UptimeLabel','OsText','DiskText','UptimeText','HomeHeroBadge','HomeCardTitle','HomeCardSubtitle','HomeScanButton','HomeInstallButton','HomeFpsButton','HomeSpecsButton','HomeQuickTitle','HomeQuickSubtitle','HomeSafetyTitle','HomeSafetyText','HomeCatalogTitle','HomeCatalogText','HomeTweaksTitle','HomeTweaksText','CleanupTitle','CleanupSubtitle','CleanupOptions','CleanupStatus','CleanupDetail','ScanButton','CleanButton',
    'AppSearch','ClearAppSelectionButton','RefreshAppsButton','AppsList','AppsStatus','RemoveAppsButton',
    'AppsTitle','AppsSubtitle','ToolsTitle','ToolsSubtitle','SpecsTitle','SpecsSubtitle','SpecCpu','SpecGpu','SpecBoard','SpecRam','SpecDisk','SpecMonitor','SpecNetwork','SpecSystem','SpecSecurity','SpecBattery','SpecAudio','SpecUsb','SpecDetailTitle','SpecDetailText','ToolTaskManager','ToolStartup','ToolDeviceManager','ToolDiskManagement',
    'ToolStorage','ToolGraphics','ToolWindowsUpdate','ToolPrivacy','ToolControlPanel','ToolSfc','ToolRestore','ToolReliability','InstallTitle','InstallSubtitle','InstallSearch','InstallList','InstallStatus','InstallProgress','InstallProgressText','ClearInstallSelectionButton','InstallSelectedButton','InstallNote','InstallCatAll','InstallCatGames','InstallCatBrowsers','InstallCatSecurity','InstallCatCommunication','InstallCatMedia','InstallCatTools','FpsTitle','FpsSubtitle','FpsHeroBadge','FpsSelectedCount','FpsSafetyBadge','FpsQuickLabel','FpsPresetRecommended','FpsPresetCompetitive','FpsPresetLowEnd','FpsPresetPrivacy','FpsPresetWindows','FpsPresetClear','FpsPerformanceSectionTitle','FpsWindowsSectionTitle','FpsPerformanceOptions','FpsWindowsOptions','FpsStatus','FpsRestartNote','FpsProgress','FpsProgressText','RestoreFpsButton','ApplyFpsButton'
)
$ui = @{}
foreach ($name in $names) { $ui[$name] = $window.FindName($name) }

$script:cleanupTargets = @(Get-XVVCleanupTargets)
$script:cleanupChecks = @{}
$script:cleanupDetails = @{}
$script:allApps = @()
$script:language = 'tr'
$loadedInstallCatalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'data\install-apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:installCatalog = @()
foreach ($installItem in $loadedInstallCatalog) {
    $script:installCatalog += $installItem
}
$script:installItems = @()
$script:selectedInstallCategory = 'All'
$script:fpsChecks = @{}

$translations = @{
    tr = @{
        NavHome='Ana Sayfa'; NavCleanup='Temizlik'; NavApps='Uygulamalar'; NavInstall='Hızlı Kurulum'; NavFps='FPS Ayarları'; NavSpecs='PC Özellikleri'; NavTools='Hızlı Araçlar'
        HomeTitle='Merhaba.'; HomeSubtitle='Windows bakımı, kurulum ve ince ayarlar tek kontrol merkezinde.'; OsLabel='İŞLETİM SİSTEMİ'; DiskLabel='BOŞ DİSK ALANI'; UptimeLabel='ÇALIŞMA SÜRESİ'
        HomeHeroBadge='tv3m | XVV CONTROL'; HomeCardTitle='Kontrolü eline al'; HomeCardSubtitle='Başlamak istediğin bölümü seç.'; HomeScanButton='Temizliği Aç'; HomeInstallButton='Kurulumu Aç'; HomeFpsButton='Ayarları Aç'; HomeSpecsButton='Bilgileri Aç'; HomeQuickTitle='PC ÖZELLİKLERİ'; HomeQuickSubtitle='İşlemci, ekran kartı, anakart, RAM, disk ve monitör ayrıntılarını incele.'; HomeSafetyTitle='AKILLI TEMİZLİK'; HomeSafetyText='Geçici dosyaları önce tara, boyutlarını gör ve yalnız seçtiklerini temizle.'; HomeCatalogTitle='HIZLI KURULUM'; HomeCatalogText='Format sonrası uygulamaları Winget ile güncel sürümlerinden topluca kur.'; HomeTweaksTitle='WINDOWS AYARLARI'; HomeTweaksText='40 oyun, gizlilik, Explorer ve arayüz ayarını yedekleyerek uygula.'
        CleanupTitle='Akıllı Temizlik'; CleanupSubtitle='Temizlemek istediklerini seç. Önce tarama yapabilirsin.'; ScanButton='Tara'; CleanButton='Seçilenleri Temizle'
        AppsTitle='Windows Uygulamaları'; AppsSubtitle='Kutucukları işaretle ve seçtiğin uygulamaları tek işlemle kaldır.'; ClearAppSelectionButton='Seçimi Temizle'; RefreshAppsButton='Yenile'; RemoveAppsButton='Seçilenleri Kaldır'
        InstallTitle='Hızlı Kurulum'; InstallSubtitle='Format sonrası gereken uygulamaları seç; en güncel sürümleri Winget ile topluca kur.'; ClearInstallSelectionButton='Seçimi Temizle'; InstallSelectedButton='Seçilenleri Kur'; InstallCatAll='Tümü'; InstallCatGames='Oyunlar'; InstallCatBrowsers='Tarayıcılar'; InstallCatSecurity='Güvenlik'; InstallCatCommunication='İletişim'; InstallCatMedia='Video ve Medya'; InstallCatTools='Araçlar'
        FpsTitle='Oyun ve Regedit Ayarları'; FpsSubtitle='Her ayarı ayrı seç; kayıt değişikliğini gör ve güvenle geri al.'; ApplyFpsButton='Seçilenleri Uygula'; RestoreFpsButton='Son Ayarları Geri Al'; FpsPresetRecommended='Önerilen'; FpsPresetCompetitive='Rekabetçi'; FpsPresetLowEnd='Düşük Sistem'; FpsPresetPrivacy='Gizlilik'; FpsPresetWindows='Windows'; FpsPresetClear='Temizle'
        SpecsTitle='PC Özellikleri'; SpecsSubtitle='Bulması zor donanım ve sistem bilgilerini tek yerde görüntüle.'; SpecCpu='İşlemci'; SpecGpu='Ekran Kartı'; SpecBoard='Anakart ve BIOS'; SpecRam='RAM'; SpecDisk='Diskler'; SpecMonitor='Monitörler'; SpecNetwork='Ağ'; SpecSystem='Windows'; SpecSecurity='Güvenlik ve TPM'; SpecBattery='Batarya'; SpecAudio='Ses Aygıtları'; SpecUsb='USB Denetleyicileri'
        ToolsTitle='Hızlı Araçlar'; ToolsSubtitle="Windows'un kendi yönetim ekranlarına hızlı erişim."; ToolTaskManager='Görev Yöneticisi'; ToolStartup='Başlangıç Uygulamaları'; ToolDeviceManager='Aygıt Yöneticisi'; ToolDiskManagement='Disk Yönetimi'; ToolStorage='Depolama Ayarları'; ToolGraphics='Grafik Ayarları'; ToolWindowsUpdate='Windows Update'; ToolPrivacy='Gizlilik Ayarları'; ToolControlPanel='Denetim Masası'; ToolSfc='Sistem Dosyalarını Tara'; ToolRestore='Geri Yükleme Noktası'; ToolReliability='Güvenilirlik Geçmişi'
    }
    en = @{
        NavHome='Home'; NavCleanup='Cleanup'; NavApps='Applications'; NavInstall='Quick Install'; NavFps='FPS Settings'; NavSpecs='PC Specifications'; NavTools='Quick Tools'
        HomeTitle='Hello.'; HomeSubtitle='Windows maintenance, setup, and fine-tuning in one control center.'; OsLabel='OPERATING SYSTEM'; DiskLabel='FREE DISK SPACE'; UptimeLabel='UPTIME'
        HomeHeroBadge='tv3m | XVV CONTROL'; HomeCardTitle='Take control'; HomeCardSubtitle='Choose the section you want to start with.'; HomeScanButton='Open Cleanup'; HomeInstallButton='Open Installer'; HomeFpsButton='Open Settings'; HomeSpecsButton='Open Details'; HomeQuickTitle='PC SPECIFICATIONS'; HomeQuickSubtitle='Inspect processor, graphics, motherboard, memory, storage, and monitor details.'; HomeSafetyTitle='SMART CLEANUP'; HomeSafetyText='Scan temporary files, review their size, and clean only what you select.'; HomeCatalogTitle='QUICK INSTALL'; HomeCatalogText='Batch-install current post-format applications through Winget.'; HomeTweaksTitle='WINDOWS SETTINGS'; HomeTweaksText='Apply 40 gaming, privacy, Explorer, and interface settings with backups.'
        CleanupTitle='Smart Cleanup'; CleanupSubtitle='Select what you want to clean. You can scan first.'; ScanButton='Scan'; CleanButton='Clean Selected'
        AppsTitle='Windows Applications'; AppsSubtitle='Check multiple applications and remove them in one operation.'; ClearAppSelectionButton='Clear Selection'; RefreshAppsButton='Refresh'; RemoveAppsButton='Remove Selected'
        InstallTitle='Quick Install'; InstallSubtitle='Select your post-format essentials and install their latest versions together with Winget.'; ClearInstallSelectionButton='Clear Selection'; InstallSelectedButton='Install Selected'; InstallCatAll='All'; InstallCatGames='Games'; InstallCatBrowsers='Browsers'; InstallCatSecurity='Security'; InstallCatCommunication='Communication'; InstallCatMedia='Video and Media'; InstallCatTools='Tools'
        FpsTitle='Gaming & Registry Settings'; FpsSubtitle='Choose each tweak separately, inspect its registry change, and undo it safely.'; ApplyFpsButton='Apply Selected'; RestoreFpsButton='Undo Last Settings'; FpsPresetRecommended='Recommended'; FpsPresetCompetitive='Competitive'; FpsPresetLowEnd='Low-end PC'; FpsPresetPrivacy='Privacy'; FpsPresetWindows='Windows'; FpsPresetClear='Clear'
        SpecsTitle='PC Specifications'; SpecsSubtitle='View hard-to-find hardware and system information in one place.'; SpecCpu='Processor'; SpecGpu='Graphics Card'; SpecBoard='Motherboard & BIOS'; SpecRam='Memory'; SpecDisk='Drives'; SpecMonitor='Monitors'; SpecNetwork='Network'; SpecSystem='Windows'; SpecSecurity='Security & TPM'; SpecBattery='Battery'; SpecAudio='Audio Devices'; SpecUsb='USB Controllers'
        ToolsTitle='Quick Tools'; ToolsSubtitle='Quick access to built-in Windows management screens.'; ToolTaskManager='Task Manager'; ToolStartup='Startup Apps'; ToolDeviceManager='Device Manager'; ToolDiskManagement='Disk Management'; ToolStorage='Storage Settings'; ToolGraphics='Graphics Settings'; ToolWindowsUpdate='Windows Update'; ToolPrivacy='Privacy Settings'; ToolControlPanel='Control Panel'; ToolSfc='Scan System Files'; ToolRestore='Restore Point'; ToolReliability='Reliability History'
    }
}

function Set-XVVLanguage {
    param([string]$Language)
    $script:language = if ($Language -eq 'en') { 'en' } else { 'tr' }
    foreach ($entry in $translations[$script:language].GetEnumerator()) {
        if ($ui.ContainsKey($entry.Key) -and $null -ne $ui[$entry.Key] -and $ui[$entry.Key].PSObject.Properties['Content']) { $ui[$entry.Key].Content = $entry.Value }
    }
    foreach ($textName in @('HomeTitle','HomeSubtitle','OsLabel','DiskLabel','UptimeLabel','HomeHeroBadge','HomeCardTitle','HomeCardSubtitle','HomeQuickTitle','HomeQuickSubtitle','HomeSafetyTitle','HomeSafetyText','HomeCatalogTitle','HomeCatalogText','HomeTweaksTitle','HomeTweaksText','CleanupTitle','CleanupSubtitle','AppsTitle','AppsSubtitle','InstallTitle','InstallSubtitle','FpsTitle','FpsSubtitle','SpecsTitle','SpecsSubtitle','ToolsTitle','ToolsSubtitle')) {
        $ui[$textName].Text = $translations[$script:language][$textName]
    }
    $ui.AdminBadge.Text = if (Test-XVVAdministrator) { if ($script:language -eq 'en') { '● Administrator mode' } else { '● Yönetici modu' } } else { if ($script:language -eq 'en') { '○ Standard user' } else { '○ Standart kullanıcı' } }
    $ui.CleanupStatus.Text = if ($script:language -eq 'en') { 'Not scanned yet' } else { 'Henüz taranmadı' }
    $ui.AppSearch.ToolTip = if ($script:language -eq 'en') { 'Search applications' } else { 'Uygulama ara' }
    $ui.InstallSearch.ToolTip = if ($script:language -eq 'en') { 'Search install catalog' } else { 'Kurulum listesinde ara' }
    $ui.InstallNote.Text = if ($script:language -eq 'en') { 'No version is pinned; the latest version in the Winget source is downloaded.' } else { 'Sürüm sabitlenmez; Winget kaynağındaki en güncel sürüm indirilir.' }
    $ui.InstallStatus.Text = if ($script:language -eq 'en') { 'Ready to install' } else { 'Kuruluma hazır' }
    $ui.FpsStatus.Text = if ($script:language -eq 'en') { 'Ready to select settings' } else { 'Ayar seçmeye hazır' }
    $ui.FpsRestartNote.Text = if ($script:language -eq 'en') { 'Some changes take effect after signing in again.' } else { 'Bazı değişiklikler yeniden oturum açınca etkili olur.' }
    $ui.FpsHeroBadge.Text = 'XVV TWEAK LAB'
    $ui.FpsSafetyBadge.Text = if ($script:language -eq 'en') { '● Restore-point protected' } else { '● Geri yükleme korumalı' }
    $ui.FpsQuickLabel.Text = if ($script:language -eq 'en') { 'Quick selection:' } else { 'Hızlı seçim:' }
    $ui.FpsPerformanceSectionTitle.Text = if ($script:language -eq 'en') { 'Gaming, System & Explorer' } else { 'Oyun, Sistem ve Explorer' }
    $ui.FpsWindowsSectionTitle.Text = if ($script:language -eq 'en') { 'Privacy & Interface' } else { 'Gizlilik ve Arayüz' }
    $ui.LanguageTrButton.Background = if ($script:language -eq 'tr') { '#7C5CFC' } else { '#1A2030' }
    $ui.LanguageEnButton.Background = if ($script:language -eq 'en') { '#7C5CFC' } else { '#1A2030' }
    Update-XVVInstallCatalog
    Update-XVVFpsOptions
}

function Show-Page {
    param([string]$Name)
    foreach ($page in @('Home','Cleanup','Apps','Install','Fps','Specs','Tools')) { $ui["Page$page"].Visibility = 'Collapsed' }
    foreach ($nav in @('Home','Cleanup','Apps','Install','Fps','Specs','Tools')) { $ui["Nav$nav"].Background = '#1A2030' }
    $ui["Page$Name"].Visibility = 'Visible'
    $ui["Nav$Name"].Background = '#292047'
}

function Get-SelectedCleanupTargets {
    @($script:cleanupTargets | Where-Object { $script:cleanupChecks[$_.Id].IsChecked -eq $true })
}

function Show-Dialog {
    param([string]$Message, [string]$Title='XVV', [System.Windows.MessageBoxImage]$Icon='Information')
    [System.Windows.MessageBox]::Show($window, $Message, $Title, 'OK', $Icon) | Out-Null
}

function Update-XVVInstallCatalog {
    $selectedIds = @($script:installItems | Where-Object { $_.IsSelected } | ForEach-Object { $_.Id })
    $items = foreach ($app in $script:installCatalog) {
        $domain = switch -Regex ([string]$app.id) {
            '^Spotify\.' { 'spotify.com'; break } '^Discord\.' { 'discord.com'; break } '^ValdikSS\.' { 'github.com'; break } '^RiotGames\.' { 'playvalorant.com'; break }
            '^Valve\.' { 'steampowered.com'; break } '^EpicGames\.' { 'epicgames.com'; break } '^Google\.' { 'google.com'; break } '^Mozilla\.' { 'mozilla.org'; break }
            '^7zip\.' { '7-zip.org'; break } '^VideoLAN\.' { 'videolan.org'; break } '^Microsoft\.VisualStudioCode' { 'code.visualstudio.com'; break } '^Microsoft\.PowerToys' { 'microsoft.com'; break }
            '^Notepad\+\+' { 'notepad-plus-plus.org'; break } '^OBSProject\.' { 'obsproject.com'; break } '^ShareX\.' { 'getsharex.com'; break } '^voidtools\.' { 'voidtools.com'; break }
            '^qBittorrent\.' { 'qbittorrent.org'; break } '^Telegram\.' { 'telegram.org'; break } '^WhatsApp\.' { 'whatsapp.com'; break } '^OpenWhisperSystems\.' { 'signal.org'; break }
            '^Zoom\.' { 'zoom.us'; break } '^Brave\.' { 'brave.com'; break } '^Opera\.' { 'opera.com'; break } '^GitHub\.' { 'github.com'; break }
            '^Git\.' { 'git-scm.com'; break } '^OpenJS\.' { 'nodejs.org'; break } '^TheDocumentFoundation\.' { 'libreoffice.org'; break } '^Adobe\.' { 'adobe.com'; break }
            '^GIMP\.' { 'gimp.org'; break } '^Audacity\.' { 'audacityteam.org'; break } '^HandBrake\.' { 'handbrake.fr'; break } '^RustDesk\.' { 'rustdesk.com'; break }
            '^Playnite\.' { 'playnite.link'; break } '^ElectronicArts\.' { 'ea.com'; break } '^Ubisoft\.' { 'ubisoft.com'; break } '^Blizzard\.' { 'battle.net'; break }
            '^CPUID\.' { 'cpuid.com'; break } '^TechPowerUp\.' { 'techpowerup.com'; break } '^REALiX\.' { 'hwinfo.com'; break } '^CrystalDewWorld\.' { 'crystalmark.info'; break }
            '^Rufus\.' { 'rufus.ie'; break } '^Balena\.' { 'balena.io'; break } '^Bitwarden\.' { 'bitwarden.com'; break } '^KeePassXC' { 'keepassxc.org'; break }
            '^Proton\.' { 'protonvpn.com'; break } '^Mojang\.' { 'minecraft.net'; break } '^Roblox\.' { 'roblox.com'; break } '^Cfx\.re\.' { 'fivem.net'; break }
            '^ppy\.' { 'osu.ppy.sh'; break } default { 'microsoft.com' }
        }
        $group = switch -Regex ([string]$app.categoryTr) {
            '^Oyun' { 'Games'; break }
            '^Tarayıcı' { 'Browsers'; break }
            '^Güvenlik|^Ağ Aracı' { 'Security'; break }
            '^İletişim|^Görüntülü Görüşme' { 'Communication'; break }
            '^Video|^Medya|^Ses|^Yayın|^Ekran Görüntüsü' { 'Media'; break }
            default { 'Tools' }
        }
        [pscustomobject]@{
            Id = [string]$app.id
            Name = [string]$app.name
            Category = if ($script:language -eq 'en') { [string]$app.categoryEn } else { [string]$app.categoryTr }
            Description = if ($script:language -eq 'en') { [string]$app.descriptionEn } else { [string]$app.descriptionTr }
            IsSelected = ($selectedIds -contains [string]$app.id)
            Initial = ([string]$app.name).Substring(0, [Math]::Min(2, ([string]$app.name).Length)).ToUpperInvariant()
            IconUrl = "https://icons.duckduckgo.com/ip3/$domain.ico"
            Group = $group
        }
    }
    $script:installItems = @($items)
    Filter-XVVInstallCatalog
}

function Filter-XVVInstallCatalog {
    $query = $ui.InstallSearch.Text.Trim()
    $visibleItems = @($script:installItems | Where-Object {
        ($script:selectedInstallCategory -eq 'All' -or $_.Group -eq $script:selectedInstallCategory) -and
        ([string]::IsNullOrWhiteSpace($query) -or $_.Name -like "*$query*" -or $_.Category -like "*$query*" -or $_.Description -like "*$query*")
    })
    $ui.InstallList.ItemsSource = $null
    $ui.InstallList.Items.Clear()
    foreach ($item in $visibleItems) { $ui.InstallList.Items.Add($item) | Out-Null }
    $ui.InstallStatus.Text = if ($script:language -eq 'en') { "$($visibleItems.Count) applications shown" } else { "$($visibleItems.Count) uygulama gösteriliyor" }
}

function Set-XVVInstallCategory {
    param([string]$Category)
    $script:selectedInstallCategory = $Category
    $buttons = @{ All='InstallCatAll'; Games='InstallCatGames'; Browsers='InstallCatBrowsers'; Security='InstallCatSecurity'; Communication='InstallCatCommunication'; Media='InstallCatMedia'; Tools='InstallCatTools' }
    foreach ($entry in $buttons.GetEnumerator()) { $ui[$entry.Value].Background = if ($entry.Key -eq $Category) { '#7C5CFC' } else { '#1A2030' } }
    Filter-XVVInstallCatalog
}

function Set-XVVInstallProgress {
    param([int]$Value, [string]$Status)
    $value = [Math]::Max(0, [Math]::Min(100, $Value))
    $ui.InstallProgress.Value = $value
    $ui.InstallProgressText.Text = if ($value -gt 0) { "$value%" } else { '' }
    if ($Status) { $ui.InstallStatus.Text = $Status }
    $window.Dispatcher.Invoke([action]{}, 'Background')
}

function Invoke-XVVWingetInstall {
    param([pscustomobject]$App)
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw $(if ($script:language -eq 'en') { 'Winget was not found. Install or update App Installer from Microsoft Store.' } else { "Winget bulunamadı. Microsoft Store'dan Uygulama Yükleyici'yi kur veya güncelle." })
    }
    $outFile = Join-Path ([IO.Path]::GetTempPath()) ("XVV-winget-{0}-out.log" -f [guid]::NewGuid().ToString('N'))
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ("XVV-winget-{0}-err.log" -f [guid]::NewGuid().ToString('N'))
    try {
        $arguments = @('install','--id',$App.Id,'--exact','--source','winget','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
        $process = Start-Process -FilePath $winget.Source -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $output = @((Get-Content -LiteralPath $outFile -ErrorAction SilentlyContinue), (Get-Content -LiteralPath $errFile -ErrorAction SilentlyContinue)) -join [Environment]::NewLine
        if ($process.ExitCode -ne 0) {
            $lastLine = @($output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
            throw $(if ($lastLine.Count) { $lastLine[0] } else { "Winget exit code: $($process.ExitCode)" })
        }
    } finally {
        Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue
    }
}

function Load-Apps {
    $ui.AppsStatus.Text = if ($script:language -eq 'en') { 'Loading applications...' } else { 'Uygulamalar yükleniyor...' }
    $window.Dispatcher.Invoke([action]{}, 'Background')
    $script:allApps = @(Get-XVVRemovableApps)
    $ui.AppsList.ItemsSource = $script:allApps
    $ui.AppsStatus.Text = if ($script:language -eq 'en') { "$($script:allApps.Count) removable applications found" } else { "$($script:allApps.Count) kaldırılabilir uygulama bulundu" }
}

function Filter-Apps {
    $query = $ui.AppSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) { $ui.AppsList.ItemsSource = $script:allApps }
    else { $ui.AppsList.ItemsSource = @($script:allApps | Where-Object { $_.DisplayName -like "*$query*" -or $_.PackageName -like "*$query*" }) }
}

function Select-Preset {
    param([string]$Id)
    $script:selectedPreset = $script:presets | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $script:selectedPreset) {
        throw "NVIDIA profili bulunamadi: $Id"
    }
    $englishPresetNames = @{ competitive='Competitive FPS'; balanced='Maximum Performance'; quality='Story Game' }
    $englishPresetSubtitles = @{ competitive='Low latency and high performance without conflicting with Reflex'; balanced='More aggressive global settings for the highest FPS'; quality='Image quality and a smooth single-player experience' }
    $ui.PresetTitle.Text = if ($script:language -eq 'en') { $englishPresetNames[$Id] } else { $script:selectedPreset.name }
    $ui.PresetSubtitle.Text = if ($script:language -eq 'en') { $englishPresetSubtitles[$Id] } else { $script:selectedPreset.subtitle }
    $englishNames = @{
        'Güç yönetimi modu'='Power management mode'; 'Düşük gecikme modu'='Low Latency Mode'; 'Dikey senkronizasyon'='Vertical Sync'
        'Doku filtreleme - Kalite'='Texture filtering - Quality'; 'Doku filtreleme - Negatif LOD tercihi'='Texture filtering - Negative LOD bias'
        'Anizotropik örnek optimizasyonu'='Anisotropic sample optimization'; 'Anizotropik filtre optimizasyonu'='Anisotropic filter optimization'
        'Kenar yumuşatma modu'='Antialiasing mode'; 'Üçlü arabelleğe alma'='Triple buffering'; 'Tercih edilen yenileme hızı'='Preferred refresh rate'
        'Shader önbelleği'='Shader cache'; 'Maksimum kare hızı'='Max frame rate'; 'İş parçacıklı optimizasyon'='Threaded optimization'
    }
    $englishValues = @{
        'Maksimum performansı tercih et'='Prefer maximum performance'; 'Açık (Reflex ile güvenli)'='On (Reflex-safe)'; 'Uygulama denetimli'='Application-controlled'
        'Performans'='Performance'; 'Kapalı'='Off'; 'En yüksek kullanılabilir'='Highest available'; 'Sınırsız'='Unlimited'; 'Kapalı (oyun içinden sınırla)'='Off (limit in game)'
        'Ultra'='Ultra'; 'Yüksek performans'='High performance'; 'Açık'='On'; 'Normal'='Normal'; 'Kalite'='Quality'; 'Kısıtla'='Clamp'
    }
    $cards = @()
    foreach ($setting in $script:selectedPreset.settings) {
        $parts = @([string]$setting -split ': ', 2)
        $settingName = $parts[0]
        $settingValue = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $descriptionTr = switch -Regex ($settingName) {
            '^Güç yönetimi' { 'Ekran kartının saat hızını yük altında nasıl yöneteceğini belirler. Maksimum performans, oyun sırasında gereksiz hız düşüşlerini azaltır.'; break }
            '^Düşük gecikme' { 'CPU tarafından önceden hazırlanan kare sayısını azaltır. Giriş gecikmesini düşürür; NVIDIA Reflex bulunan oyunlarda oyun içindeki Reflex ayarı önceliklidir.'; break }
            '^Dikey senkronizasyon' { 'Ekran kartının kareleri monitörün yenileme zamanıyla eşleştirmesini yönetir. Yırtılmayı azaltabilir fakat zorlandığında gecikme ekleyebilir.'; break }
            '^Doku filtreleme - Kalite' { 'Doku filtrelemede görüntü kalitesi ile performans arasındaki dengeyi belirler. Kalite seçeneği düşük maliyetle daha temiz dokular sunar.'; break }
            '^Doku filtreleme - Negatif' { 'Uzak dokulardaki parıldama ve titreşimi azaltmak için negatif LOD kullanımını sınırlar.'; break }
            '^Anizotropik' { 'Doku filtrelemesindeki bazı hesaplamaları sadeleştirerek küçük bir performans kazancı sağlar.'; break }
            '^Kenar yumuşatma' { 'Kenar yumuşatma kararını oyuna bırakır. Böylece uyumsuzluk ve gereksiz FPS kaybı önlenir.'; break }
            '^Üçlü arabelleğe' { 'OpenGL uygulamalarında V-Sync ile ek tampon kullanır. Kapalı olması bellek kullanımını ve olası gecikmeyi azaltır.'; break }
            '^Tercih edilen yenileme' { 'Oyunun desteklediği durumlarda monitörün en yüksek kullanılabilir yenileme hızını tercih eder.'; break }
            '^Shader önbelleği' { 'Derlenmiş gölgelendiricileri diskte saklayarak tekrar derleme kaynaklı takılmaları azaltmaya yardımcı olur.'; break }
            '^Maksimum kare hızı' { 'Sürücü düzeyinde FPS sınırı koyar. Kapalıyken sınırlandırma oyun içinden veya Reflex üzerinden yapılabilir.'; break }
            '^İş parçacıklı' { 'OpenGL sürücüsünün çok çekirdekli işlemeyi kullanmasına izin verir.'; break }
            default { 'Bu ayar seçilen profil için NVIDIA global sürücü profiline uygulanır.' }
        }
        $descriptionEn = switch -Regex ($settingName) {
            '^Güç yönetimi' { 'Controls how the GPU manages clock speeds under load. Prefer maximum performance reduces unnecessary clock drops while gaming.'; break }
            '^Düşük gecikme' { 'Reduces the number of frames prepared ahead by the CPU. This can lower input latency; in games with NVIDIA Reflex, use the in-game Reflex option.'; break }
            '^Dikey senkronizasyon' { 'Controls whether GPU frames are synchronized with the monitor refresh cycle. It can reduce tearing but may add latency when forced.'; break }
            '^Doku filtreleme - Kalite' { 'Sets the balance between texture quality and performance. Quality provides cleaner textures at a generally low performance cost.'; break }
            '^Doku filtreleme - Negatif' { 'Limits negative LOD usage to reduce shimmering and flickering in distant textures.'; break }
            '^Anizotropik' { 'Simplifies selected texture-filtering calculations for a small performance improvement.'; break }
            '^Kenar yumuşatma' { 'Leaves antialiasing control to the game, avoiding compatibility problems and unnecessary FPS loss.'; break }
            '^Üçlü arabelleğe' { 'Adds another buffer for OpenGL applications using V-Sync. Keeping it off can reduce memory use and potential latency.'; break }
            '^Tercih edilen yenileme' { 'Prefers the monitor highest available refresh rate whenever the game supports it.'; break }
            '^Shader önbelleği' { 'Stores compiled shaders on disk to help reduce stutter caused by repeated shader compilation.'; break }
            '^Maksimum kare hızı' { 'Sets a driver-level FPS limit. When off, frame limiting can be configured inside the game or through Reflex.'; break }
            '^İş parçacıklı' { 'Allows the OpenGL driver to use multithreaded processing.'; break }
            default { 'This setting is applied to the NVIDIA global driver profile.' }
        }
        $cardName = if ($script:language -eq 'en' -and $englishNames.ContainsKey($settingName)) { $englishNames[$settingName] } else { $settingName }
        $cardValue = if ($script:language -eq 'en' -and $englishValues.ContainsKey($settingValue)) { $englishValues[$settingValue] } else { $settingValue }
        $cards += [pscustomobject]@{ Name=$cardName; Value=$cardValue; Description=$(if ($script:language -eq 'en') { $descriptionEn } else { $descriptionTr }) }
    }
    $ui.PresetSettingsList.ItemsSource = $cards
}

function Set-NvidiaProgress {
    param([int]$Value, [string]$Status)
    $value = [Math]::Max(0, [Math]::Min(100, $Value))
    $ui.NvidiaProgress.Value = $value
    $ui.NvidiaProgressText.Text = if ($value -gt 0) { "$value%" } else { '' }
    if ($Status) { $ui.NvidiaStatus.Text = $Status }
    $window.Dispatcher.Invoke([action]{}, 'Background')
}

function Start-XVVTrackedProcess {
    param([string]$FilePath, [string]$Arguments, [int]$From, [int]$To, [string]$Status)
    $process = Start-Process -FilePath $FilePath -WorkingDirectory (Split-Path $FilePath) -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    $progress = $From
    while (-not $process.HasExited) {
        Set-NvidiaProgress -Value $progress -Status $Status
        if ($progress -lt ($To - 1)) { $progress++ }
        Start-Sleep -Milliseconds 70
        $process.Refresh()
    }
    Set-NvidiaProgress -Value $To -Status $Status
    return $process
}

function Show-PresetDetails {
    param([string]$Id)
    Select-Preset -Id $Id
    $ui.PresetDetailsPanel.Visibility = 'Visible'
}

function New-XVVNvidiaBackup {
    param([string]$InspectorPath)
    $toolDirectory = Split-Path $InspectorPath
    $started = Get-Date
    $process = Start-XVVTrackedProcess -FilePath $InspectorPath -Arguments '-exportCustomized' -From 3 -To 25 -Status 'Mevcut NVIDIA ayarları yedekleniyor...'
    if ($process.ExitCode -ne 0) { throw 'Mevcut NVIDIA ayarlarının yedeği alınamadı.' }
    $export = Get-ChildItem -LiteralPath $toolDirectory -Filter 'CustomProfiles_*.nip' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $started.AddSeconds(-2) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $export) { throw 'NVIDIA yedek dosyası oluşturulamadı.' }
    $backupDirectory = Join-Path $PSScriptRoot 'backups'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $backupPath = Join-Path $backupDirectory 'LastNvidiaBackup.nip'
    $backupText = Get-Content -LiteralPath $export.FullName -Raw
    if ($backupText -notmatch '<ProfileName>Base Profile</ProfileName>') {
        $emptyBase = '<Profile><ProfileName>Base Profile</ProfileName><Executeables/><Settings/><ExecutableFindFiles/></Profile>'
        $backupText = $backupText -replace '</ArrayOfProfile>', "$emptyBase</ArrayOfProfile>"
    }
    [IO.File]::WriteAllText($backupPath, $backupText, [Text.UnicodeEncoding]::new($false, $true))
    Remove-Item -LiteralPath $export.FullName -Force -ErrorAction SilentlyContinue
    return $backupPath
}

function Invoke-NvidiaPreset {
    param([string]$Id)
    Select-Preset -Id $Id
    $npiPath = Join-Path $PSScriptRoot 'tools\NVIDIAProfileInspector\nvidiaProfileInspector.exe'
    $profilePath = Join-Path $PSScriptRoot "profiles\$Id.nip"
    if (-not (Test-Path -LiteralPath $npiPath)) {
        Show-Dialog 'NVIDIA Profile Inspector bileşeni bulunamadı.' 'XVV' 'Warning'
        return
    }
    if (-not (Test-Path -LiteralPath $profilePath)) {
        Show-Dialog "Profil dosyası bulunamadı: $Id" 'XVV' 'Warning'
        return
    }
    if (-not (Test-XVVAdministrator)) {
        Show-Dialog 'NVIDIA ayarlarını uygulamak için XVV uygulamasını yönetici olarak çalıştır.' 'XVV' 'Warning'
        return
    }
    $nvidiaDriver = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*NVIDIA*' } | Select-Object -First 1
    if (-not $nvidiaDriver) {
        Show-Dialog 'Etkin bir NVIDIA ekran kartı veya sürücüsü bulunamadı.' 'XVV' 'Warning'
        return
    }
    $ui.NvidiaStatus.Text = "$($script:selectedPreset.name) uygulanıyor..."
    Set-NvidiaProgress -Value 1 -Status "$($script:selectedPreset.name) hazırlanıyor..."
    $window.Dispatcher.Invoke([action]{}, 'Background')
    try {
        $runningInspector = @(Get-Process -Name 'nvidiaProfileInspector' -ErrorAction SilentlyContinue)
        if ($runningInspector.Count -gt 0) {
            throw 'NVIDIA Profile Inspector açık. Önce onu kapatıp tekrar dene.'
        }
        $null = New-XVVNvidiaBackup -InspectorPath $npiPath
        # Replace modu önce eski global özel ayarları temizler; profiller birbirine karışmaz.
        $arguments = '-silentImport -replaceImport "{0}"' -f $profilePath
        $process = Start-XVVTrackedProcess -FilePath $npiPath -Arguments $arguments -From 26 -To 70 -Status "$($script:selectedPreset.name) uygulanıyor..."
        if ($process.ExitCode -ne 0) { throw "NVIDIA Profile Inspector çıkış kodu: $($process.ExitCode)" }
        $exportStart = Get-Date
        $exportProcess = Start-XVVTrackedProcess -FilePath $npiPath -Arguments '-exportCustomized' -From 71 -To 94 -Status 'Uygulanan ayarlar doğrulanıyor...'
        if ($exportProcess.ExitCode -ne 0) { throw 'NVIDIA ayarları doğrulanamadı.' }
        $exportFile = Get-ChildItem -LiteralPath (Split-Path $npiPath) -Filter 'CustomProfiles_*.nip' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $exportStart.AddSeconds(-2) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $exportFile) { throw 'NVIDIA profili dışa aktarılamadı; ayarlar uygulanmamış olabilir.' }
        [xml]$expectedXml = Get-Content -LiteralPath $profilePath -Raw
        [xml]$actualXml = Get-Content -LiteralPath $exportFile.FullName -Raw
        $actualProfile = @($actualXml.ArrayOfProfile.Profile | Where-Object { $_.ProfileName -eq 'Base Profile' }) | Select-Object -First 1
        if (-not $actualProfile) { throw 'NVIDIA global profili doğrulama dosyasında bulunamadı.' }
        $actualSettings = @{}
        foreach ($setting in @($actualProfile.Settings.ProfileSetting)) { $actualSettings[[string]$setting.SettingID] = [string]$setting.SettingValue }
        $mismatches = @($expectedXml.ArrayOfProfile.Profile.Settings.ProfileSetting | Where-Object { $actualSettings[[string]$_.SettingID] -ne [string]$_.SettingValue })
        Remove-Item -LiteralPath $exportFile.FullName -Force -ErrorAction SilentlyContinue
        if ($mismatches.Count -gt 0) { throw "$($mismatches.Count) NVIDIA ayarı doğrulanamadı. Profil uygulanmadı." }
        Set-NvidiaProgress -Value 100 -Status "✓ $($script:selectedPreset.name) uygulandı"
        $ui.NvidiaStatus.Text = "✓ $($script:selectedPreset.name) uygulandı"
        Show-Dialog "$($script:selectedPreset.name) NVIDIA global profiline uygulandı."
    } catch {
        $ui.NvidiaProgress.Value = 0
        $ui.NvidiaProgressText.Text = ''
        $ui.NvidiaStatus.Text = 'Profil uygulanamadı'
        Show-Dialog $_.Exception.Message 'NVIDIA Profil Hatası' 'Warning'
    }
}

function Convert-XVVWmiText {
    param($Value)
    if ($null -eq $Value) { return '-' }
    $characters = @($Value | Where-Object { [int]$_ -gt 0 } | ForEach-Object { [char][int]$_ })
    $text = (-join $characters).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return '-' }
    return $text
}

function Get-XVVSpecText {
    param([string]$Category)
    $lines = [System.Collections.Generic.List[string]]::new()
    switch ($Category) {
        'Cpu' {
            foreach ($item in @(Get-CimInstance Win32_Processor)) {
                $lines.Add("Model             : $($item.Name.Trim())")
                $lines.Add("Üretici            : $($item.Manufacturer)")
                $lines.Add("Çekirdek / İş parç.: $($item.NumberOfCores) / $($item.NumberOfLogicalProcessors)")
                $lines.Add("Azami hız          : $($item.MaxClockSpeed) MHz")
                $lines.Add("Soket              : $($item.SocketDesignation)")
                $lines.Add("İşlemci kimliği    : $($item.ProcessorId)")
                $lines.Add('')
            }
        }
        'Gpu' {
            foreach ($item in @(Get-CimInstance Win32_VideoController)) {
                $lines.Add("Model              : $($item.Name)")
                $lines.Add("Sürücü sürümü      : $($item.DriverVersion)")
                $lines.Add("Sürücü tarihi      : $($item.DriverDate)")
                $lines.Add("Video modu         : $($item.VideoModeDescription)")
                $lines.Add("Çözünürlük         : $($item.CurrentHorizontalResolution) x $($item.CurrentVerticalResolution) @ $($item.CurrentRefreshRate) Hz")
                if ($item.AdapterRAM) { $lines.Add("Bildirilen VRAM    : $(Format-XVVBytes ([long]$item.AdapterRAM))") }
                $lines.Add('')
            }
        }
        'Board' {
            $system = Get-CimInstance Win32_ComputerSystem
            $board = Get-CimInstance Win32_BaseBoard
            $bios = Get-CimInstance Win32_BIOS
            $lines.Add("Sistem üreticisi   : $($system.Manufacturer)")
            $lines.Add("Sistem modeli      : $($system.Model)")
            $lines.Add("Anakart üreticisi  : $($board.Manufacturer)")
            $lines.Add("Anakart modeli     : $($board.Product)")
            $lines.Add("Anakart sürümü     : $($board.Version)")
            $lines.Add("Anakart seri no    : $($board.SerialNumber)")
            $lines.Add("BIOS üreticisi     : $($bios.Manufacturer)")
            $lines.Add("BIOS sürümü        : $($bios.SMBIOSBIOSVersion)")
            $lines.Add("BIOS seri no       : $($bios.SerialNumber)")
            $lines.Add("SMBIOS sürümü      : $($bios.SMBIOSMajorVersion).$($bios.SMBIOSMinorVersion)")
        }
        'Ram' {
            $array = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($array) {
                $lines.Add("Toplam RAM yuvası  : $($array.MemoryDevices)")
                $maxCapacityEx = if ($array.PSObject.Properties['MaxCapacityEx']) { [long]$array.MaxCapacityEx } else { 0 }
                if ($maxCapacityEx -gt 0) { $lines.Add("Azami destek       : $(Format-XVVBytes ($maxCapacityEx * 1KB))") }
                elseif ([long]$array.MaxCapacity -gt 0) { $lines.Add("Azami destek       : $(Format-XVVBytes ([long]$array.MaxCapacity * 1KB))") }
                $lines.Add('')
            }
            $index = 0
            foreach ($item in @(Get-CimInstance Win32_PhysicalMemory)) {
                $index++
                $lines.Add("RAM modülü $index")
                $lines.Add("  Yuva             : $($item.DeviceLocator) / $($item.BankLabel)")
                $lines.Add("  Kapasite         : $(Format-XVVBytes ([long]$item.Capacity))")
                $lines.Add("  Üretici          : $($item.Manufacturer)")
                $lines.Add("  Parça numarası   : $(([string]$item.PartNumber).Trim())")
                $lines.Add("  Seri numarası    : $(([string]$item.SerialNumber).Trim())")
                $lines.Add("  Hız / Ayarlı hız : $($item.Speed) / $($item.ConfiguredClockSpeed) MHz")
                $lines.Add('')
            }
        }
        'Disk' {
            $physicalDisks = @(Get-CimInstance -Namespace root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk -ErrorAction SilentlyContinue)
            foreach ($item in @(Get-CimInstance Win32_DiskDrive)) {
                $lines.Add("Model              : $($item.Model)")
                $lines.Add("Boyut              : $(Format-XVVBytes ([long]$item.Size))")
                $lines.Add("Arabirim           : $($item.InterfaceType)")
                $lines.Add("Medya türü         : $($item.MediaType)")
                $lines.Add("Firmware           : $($item.FirmwareRevision)")
                $lines.Add("Seri numarası      : $(([string]$item.SerialNumber).Trim())")
                $health = $physicalDisks | Where-Object { $_.FriendlyName -eq $item.Model -or $_.Model -eq $item.Model } | Select-Object -First 1
                if ($health) {
                    $lines.Add("Sağlık durumu      : $($health.HealthStatus)")
                    $lines.Add("Çalışma durumu     : $(@($health.OperationalStatus) -join ', ')")
                    $lines.Add("Veri yolu / Tür    : $($health.BusType) / $($health.MediaType)")
                }
                $lines.Add('')
            }
        }
        'Monitor' {
            $monitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue)
            if ($monitors.Count -eq 0) { $lines.Add('Monitör, model bilgisini Windows sistemine bildirmedi.') }
            $index = 0
            foreach ($item in $monitors) {
                $index++
                $lines.Add("Monitör $index")
                $lines.Add("  Üretici          : $(Convert-XVVWmiText $item.ManufacturerName)")
                $lines.Add("  Model            : $(Convert-XVVWmiText $item.UserFriendlyName)")
                $lines.Add("  Ürün kodu        : $(Convert-XVVWmiText $item.ProductCodeID)")
                $lines.Add("  Seri numarası    : $(Convert-XVVWmiText $item.SerialNumberID)")
                $lines.Add("  Üretim yılı      : $($item.YearOfManufacture)")
                $lines.Add("  Etkin            : $($item.Active)")
                $lines.Add('')
            }
        }
        'Network' {
            foreach ($item in @(Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object IPEnabled)) {
                $lines.Add("Bağdaştırıcı       : $($item.Description)")
                $lines.Add("MAC adresi         : $($item.MACAddress)")
                $lines.Add("IP adresleri       : $(@($item.IPAddress) -join ', ')")
                $lines.Add("Ağ geçidi          : $(@($item.DefaultIPGateway) -join ', ')")
                $lines.Add("DNS sunucuları     : $(@($item.DNSServerSearchOrder) -join ', ')")
                $lines.Add("DHCP               : $($item.DHCPEnabled)")
                $lines.Add('')
            }
        }
        'System' {
            $osInfo = Get-CimInstance Win32_OperatingSystem
            $computer = Get-CimInstance Win32_ComputerSystem
            $lines.Add("Windows            : $($osInfo.Caption)")
            $lines.Add("Sürüm              : $($osInfo.Version)")
            $lines.Add("Derleme            : $($osInfo.BuildNumber)")
            $lines.Add("Mimari             : $($osInfo.OSArchitecture)")
            $lines.Add("Bilgisayar adı     : $env:COMPUTERNAME")
            $lines.Add("Kullanıcı          : $env:USERNAME")
            $lines.Add("Toplam RAM         : $(Format-XVVBytes ([long]$computer.TotalPhysicalMemory))")
            $lines.Add("Son açılış         : $($osInfo.LastBootUpTime)")
            $lines.Add("Windows dizini     : $($osInfo.WindowsDirectory)")
        }
        'Security' {
            $computer = Get-CimInstance Win32_ComputerSystem
            $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
            $lines.Add("Hipervizör mevcut  : $($computer.HypervisorPresent)")
            $lines.Add("Firmware sanallaş. : $($processor.VirtualizationFirmwareEnabled)")
            $lines.Add("SLAT desteği       : $($processor.SecondLevelAddressTranslationExtensions)")
            try {
                $tpm = Get-Tpm -ErrorAction Stop
                $lines.Add("TPM mevcut         : $($tpm.TpmPresent)")
                $lines.Add("TPM hazır          : $($tpm.TpmReady)")
                $lines.Add("TPM etkin          : $($tpm.TpmEnabled)")
                $lines.Add("TPM üretici sürümü : $($tpm.ManufacturerVersion)")
            } catch { $lines.Add('TPM bilgisi        : Okunamadı veya TPM bulunmuyor') }
            try { $lines.Add("Güvenli Önyükleme : $(Confirm-SecureBootUEFI -ErrorAction Stop)") }
            catch { $lines.Add('Güvenli Önyükleme : Desteklenmiyor veya BIOS Legacy modunda') }
            try {
                foreach ($volume in @(Get-BitLockerVolume -ErrorAction Stop)) {
                    $lines.Add("BitLocker $($volume.MountPoint)       : $($volume.ProtectionStatus) / $($volume.VolumeStatus)")
                }
            } catch { $lines.Add('BitLocker          : Bilgi alınamadı') }
        }
        'Battery' {
            $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
            if ($batteries.Count -eq 0) { $lines.Add('Bu sistemde Windows tarafından bildirilen batarya bulunmuyor.') }
            foreach ($item in $batteries) {
                $lines.Add("Model              : $($item.Name)")
                $lines.Add("Üretici            : $($item.Manufacturer)")
                $lines.Add("Kalan şarj         : $($item.EstimatedChargeRemaining)%")
                $lines.Add("Durum kodu         : $($item.BatteryStatus)")
                if ($item.DesignCapacity) { $lines.Add("Tasarım kapasitesi : $($item.DesignCapacity) mWh") }
                if ($item.FullChargeCapacity) { $lines.Add("Tam dolum kapasite : $($item.FullChargeCapacity) mWh") }
                if ($item.DesignVoltage) { $lines.Add("Tasarım voltajı    : $($item.DesignVoltage) mV") }
                $lines.Add("Kimlik             : $($item.DeviceID)")
                $lines.Add('')
            }
        }
        'Audio' {
            $devices = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue)
            if ($devices.Count -eq 0) { $lines.Add('Ses aygıtı bulunamadı.') }
            foreach ($item in $devices) {
                $lines.Add("Aygıt              : $($item.Name)")
                $lines.Add("Üretici            : $($item.Manufacturer)")
                $lines.Add("Durum              : $($item.Status)")
                $lines.Add("Aygıt kimliği      : $($item.PNPDeviceID)")
                $lines.Add('')
            }
        }
        'Usb' {
            foreach ($item in @(Get-CimInstance Win32_USBController -ErrorAction SilentlyContinue)) {
                $lines.Add("USB denetleyici    : $($item.Name)")
                $lines.Add("Üretici            : $($item.Manufacturer)")
                $lines.Add("Durum              : $($item.Status)")
                $lines.Add("Aygıt kimliği      : $($item.PNPDeviceID)")
                $lines.Add('')
            }
            $hubs = @(Get-CimInstance Win32_USBHub -ErrorAction SilentlyContinue)
            $lines.Add("Algılanan USB hub  : $($hubs.Count)")
        }
    }
    if ($lines.Count -eq 0) { return 'Bilgi bulunamadı.' }
    return ($lines -join [Environment]::NewLine).Trim()
}

$script:fpsTweaks = @(
    [pscustomobject]@{ Id='GameMode'; Default=$true; CategoryTr='OYUN'; CategoryEn='GAMING'; NameTr='Windows Oyun Modunu Aç'; NameEn='Enable Windows Game Mode'; DescTr='Oyun açıkken Windows kaynak önceliğini oyuna verir.'; DescEn='Lets Windows prioritize game resources while playing.'; DetailTr='GameBar içindeki Oyun Modu değerlerini açar. Oyun dosyalarını ve grafik kalitesini değiştirmez.'; DetailEn='Enables the Game Mode values under GameBar. It does not alter game files or image quality.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AllowAutoGameMode'; Value=1; Type='DWord' },
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AutoGameModeEnabled'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='GameDvr'; Default=$true; Caution=$true; WarningTr='Xbox Game Bar ile geriye dönük oyun kaydı çalışmaz.'; WarningEn='Retrospective recording with Xbox Game Bar will not work.'; CategoryTr='KAYIT'; CategoryEn='CAPTURE'; NameTr='Game DVR Arka Plan Kaydını Kapat'; NameEn='Disable Game DVR Background Recording'; DescTr='Game DVR hizmetinin oyun görüntüsünü arka planda tutmasını engeller.'; DescEn='Stops Game DVR from retaining gameplay footage in the background.'; DetailTr='GameConfigStore içindeki GameDVR_Enabled değerini kapatır. Xbox Game Bar ile geriye dönük kayıt kullanıyorsan seçme.'; DetailEn='Disables GameDVR_Enabled in GameConfigStore. Leave it unchecked if you use retrospective Xbox Game Bar recording.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='AppCapture'; Default=$true; Caution=$true; WarningTr='Windows yerleşik ekran ve oyun yakalama özelliği kapanır.'; WarningEn='Windows built-in screen and game capture will be disabled.'; CategoryTr='KAYIT'; CategoryEn='CAPTURE'; NameTr='Windows Uygulama Yakalamayı Kapat'; NameEn='Disable Windows App Capture'; DescTr='Windows uygulama ve oyun yakalama özelliğini kapatır.'; DescEn='Disables Windows application and game capture.'; DetailTr='GameDVR içindeki AppCaptureEnabled değerini kapatır. OBS ve ShareX gibi ayrı programların kaydını etkilemez.'; DetailEn='Disables AppCaptureEnabled under GameDVR. Separate programs such as OBS and ShareX are unaffected.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='Hags'; Default=$false; Caution=$true; WarningTr='Her sistemde fayda sağlamaz; bazı sürücülerde takılma olabilir ve yeniden başlatma gerekir.'; WarningEn='It does not benefit every system; some drivers may stutter and a restart is required.'; CategoryTr='GPU'; CategoryEn='GPU'; NameTr='Donanım Hızlandırmalı GPU Zamanlaması'; NameEn='Hardware-Accelerated GPU Scheduling'; DescTr='Desteklenen ekran kartlarında GPU zamanlama işini donanıma aktarır.'; DescEn='Moves GPU scheduling work to supported graphics hardware.'; DetailTr='Her sistemde FPS artırmaz ve yeniden başlatma gerekir. Desteklenmeyen sürücüler ayarı yok sayabilir.'; DetailEn='It does not improve FPS on every system and requires a restart. Unsupported drivers may ignore it.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name='HwSchMode'; Value=2; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='PowerThrottling'; Default=$false; Caution=$true; WarningTr='Dizüstünde pil tüketimini, sıcaklığı ve fan sesini artırabilir.'; WarningEn='May increase battery use, temperature, and fan noise on laptops.'; CategoryTr='GÜÇ'; CategoryEn='POWER'; NameTr='Windows Güç Kısıtlamasını Kapat'; NameEn='Disable Windows Power Throttling'; DescTr='Windows güç kısıtlamasının işlemci süreçlerini yavaşlatmasını engeller.'; DescEn='Prevents Windows power throttling from slowing processor tasks.'; DetailTr='Masaüstünde daha tutarlı performans sağlayabilir. Dizüstünde pil tüketimi ve sıcaklık artabileceği için varsayılan kapalıdır.'; DetailEn='May provide steadier desktop performance. It is off by default because laptop battery use and temperatures can increase.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'; Name='PowerThrottlingOff'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='StartupDelay'; Default=$false; CategoryTr='TEPKİ'; CategoryEn='RESPONSE'; NameTr='Başlangıç Uygulaması Gecikmesini Kapat'; NameEn='Disable Startup Application Delay'; DescTr='Oturum açıldıktan sonra başlangıç uygulamalarının bekleme süresini kaldırır.'; DescEn='Removes the delay before startup applications launch after sign-in.'; DetailTr='Bilgisayarın açılış süresini değil, masaüstü geldikten sonraki uygulama başlatma gecikmesini etkiler.'; DetailEn='Affects application launch delay after the desktop appears, not the Windows boot time itself.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Name='StartupDelayInMSec'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='Transparency'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Windows Saydamlık Efektini Kapat'; NameEn='Disable Windows Transparency'; DescTr='Başlat menüsü ve görev çubuğundaki saydamlık işlemini kapatır.'; DescEn='Disables transparency rendering in Start and the taskbar.'; DetailTr='Düşük donanımlı sistemlerde masaüstü GPU kullanımını az miktarda azaltabilir; oyun içi FPS etkisi beklenmemelidir.'; DetailEn='May slightly reduce desktop GPU work on low-end systems; an in-game FPS gain should not be expected.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='ToastNotifications'; Default=$false; Caution=$true; WarningTr='Discord, güvenlik ve diğer uygulamaların önemli bildirimlerini kaçırabilirsin.'; WarningEn='You may miss important Discord, security, and other app notifications.'; CategoryTr='ODAK'; CategoryEn='FOCUS'; NameTr='Bildirim Açılır Pencerelerini Kapat'; NameEn='Disable Notification Toasts'; DescTr='Oyun sırasında sağ altta çıkan Windows bildirimlerini kapatır.'; DescEn='Disables Windows notification popups while gaming.'; DetailTr='Tüm uygulamaların bildirim afişlerini etkiler; önemli mesajları kaçırabileceğin için varsayılan olarak seçili değildir.'; DetailEn='Affects notification banners from every application, so it is not selected by default.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name='ToastEnabled'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='BingSearch'; Default=$false; Caution=$true; WarningTr='Bazı yeni Windows sürümleri bu eski kayıt değerini yok sayabilir.'; WarningEn='Some newer Windows builds may ignore this legacy registry value.'; CategoryTr='TEPKİ'; CategoryEn='RESPONSE'; NameTr='Başlat Menüsü Web Aramasını Kapat'; NameEn='Disable Start Menu Web Search'; DescTr='Başlat aramasının Bing web sonuçlarını istemesini engeller.'; DescEn='Stops Start search from requesting Bing web results.'; DetailTr='Yerel uygulama ve dosya araması çalışmaya devam eder. Bazı yeni Windows sürümleri bu eski kullanıcı değerini yok sayabilir.'; DetailEn='Local app and file search continues to work. Some newer Windows builds may ignore this legacy per-user value.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name='BingSearchEnabled'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='GameBarStartup'; Default=$false; CategoryTr='OYUN'; CategoryEn='GAMING'; NameTr='Game Bar Başlangıç Panelini Kapat'; NameEn='Disable Game Bar Startup Panel'; DescTr='Game Bar başlangıç bilgilendirme panelinin kendiliğinden açılmasını engeller.'; DescEn='Prevents the Game Bar startup information panel from opening automatically.'; DetailTr='Game Bar uygulamasını kaldırmaz; Win+G kullanımı ve manuel açma korunur.'; DetailEn='Does not uninstall Game Bar; Win+G and manual launch remain available.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\GameBar'; Name='ShowStartupPanel'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='GameModeNotices'; Default=$false; CategoryTr='ODAK'; CategoryEn='FOCUS'; NameTr='Oyun Modu Bildirimlerini Kapat'; NameEn='Disable Game Mode Notifications'; DescTr='Oyun Modunun açılıp kapandığını bildiren mesajları gizler.'; DescEn='Hides messages reporting that Game Mode was enabled or disabled.'; DetailTr='Oyun Modunun kendisini kapatmaz; yalnızca Game Bar bildirim değerini değiştirir.'; DetailEn='Does not disable Game Mode itself; it only changes the related Game Bar notification value.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\GameBar'; Name='ShowGameModeNotifications'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='MouseAccel'; Default=$true; CategoryTr='GİRDİ'; CategoryEn='INPUT'; NameTr='Fare İvmesini Kapat'; NameEn='Disable Mouse Acceleration'; DescTr='Nişan hareketinin fiziksel fare hareketiyle daha tutarlı olmasını sağlar.'; DescEn='Makes aiming movement more consistent with physical mouse movement.'; DetailTr='MouseSpeed ve eşik değerlerini sıfırlar. DPI veya oyun içi hassasiyeti değiştirmez; yeniden oturum açmak gerekebilir.'; DetailEn='Sets MouseSpeed and acceleration thresholds to zero. It does not change DPI or in-game sensitivity; signing in again may be required.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Control Panel\Mouse'; Name='MouseSpeed'; Value='0'; Type='String' },
        [pscustomobject]@{ Path='HKCU:\Control Panel\Mouse'; Name='MouseThreshold1'; Value='0'; Type='String' },
        [pscustomobject]@{ Path='HKCU:\Control Panel\Mouse'; Name='MouseThreshold2'; Value='0'; Type='String' }
    ) },
    [pscustomobject]@{ Id='BackgroundApps'; Default=$false; Caution=$true; WarningTr='Posta, Telefon Bağlantısı ve benzeri uygulamalarda bildirim/eşitleme durabilir.'; WarningEn='Notifications or sync may stop in Mail, Phone Link, and similar apps.'; CategoryTr='ARKA PLAN'; CategoryEn='BACKGROUND'; NameTr='Mağaza Uygulamalarını Arka Planda Kapat'; NameEn='Disable Store Apps in Background'; DescTr='Microsoft Store uygulamalarının arka planda çalışmasını sınırlar.'; DescEn='Restricts Microsoft Store applications from running in the background.'; DetailTr='GlobalUserDisabled değerini açar. Bildirim veya arka plan eşitlemesi gereken uygulamaları etkileyebilir; bu yüzden varsayılan olarak seçili değildir.'; DetailEn='Enables GlobalUserDisabled. It may affect notifications or background sync, so it is not selected by default.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name='GlobalUserDisabled'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='WindowAnimation'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Pencere Animasyonunu Kapat'; NameEn='Disable Window Animation'; DescTr='Pencerelerin küçülüp büyürken yaptığı animasyonu kaldırır.'; DescEn='Removes the minimize and maximize window animation.'; DetailTr='WindowMetrics içindeki MinAnimate değerini kapatır. Oyun içi FPS yerine masaüstü tepkisini hızlandırır.'; DetailEn='Disables MinAnimate under WindowMetrics. This improves desktop response rather than in-game FPS.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Control Panel\Desktop\WindowMetrics'; Name='MinAnimate'; Value='0'; Type='String' }
    ) },
    [pscustomobject]@{ Id='TaskbarAnimation'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Görev Çubuğu Animasyonunu Kapat'; NameEn='Disable Taskbar Animation'; DescTr='Görev çubuğu geçiş ve açılış animasyonlarını azaltır.'; DescEn='Reduces taskbar transition and opening animations.'; DetailTr='Explorer Advanced içindeki TaskbarAnimations değerini kapatır. Etkisi yeniden oturum açınca görülebilir.'; DetailEn='Disables TaskbarAnimations under Explorer Advanced. The change may appear after signing in again.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAnimations'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='AeroPeek'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Aero Peek Efektini Kapat'; NameEn='Disable Aero Peek'; DescTr='Görev çubuğunda masaüstü önizleme efektini kapatır.'; DescEn='Disables the desktop preview effect on the taskbar.'; DetailTr='DWM içindeki EnableAeroPeek değerini kapatır. GPU yükü kazancı küçüktür; amaç masaüstünü sadeleştirmektir.'; DetailEn='Disables EnableAeroPeek under DWM. GPU savings are minor; the purpose is a simpler desktop.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\DWM'; Name='EnableAeroPeek'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='WindowContents'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Sürüklerken Pencere İçeriğini Gizle'; NameEn='Hide Window Contents While Dragging'; DescTr='Pencere taşırken yalnız çerçevesini gösterir.'; DescEn='Shows only the window outline while dragging.'; DetailTr='DragFullWindows değerini kapatır. Eski veya düşük donanımlı sistemlerde masaüstü çizim yükünü azaltabilir.'; DetailEn='Disables DragFullWindows. It can reduce desktop rendering work on older or low-end hardware.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Control Panel\Desktop'; Name='DragFullWindows'; Value='0'; Type='String' }
    ) },
    [pscustomobject]@{ Id='MenuDelay'; Default=$false; CategoryTr='TEPKİ'; CategoryEn='RESPONSE'; NameTr='Menü Açılış Gecikmesini Azalt'; NameEn='Reduce Menu Opening Delay'; DescTr='Windows menülerinin bekleme süresini 200 ms yapar.'; DescEn='Sets the Windows menu opening delay to 200 ms.'; DetailTr='MenuShowDelay değerini 200 yapar. FPS artırmaz; arayüzün daha seri hissettirmesini sağlar.'; DetailEn='Sets MenuShowDelay to 200. It does not increase FPS; it makes the interface feel quicker.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Control Panel\Desktop'; Name='MenuShowDelay'; Value='200'; Type='String' }
    ) },
    [pscustomobject]@{ Id='IconShadows'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Masaüstü Simge Gölgelerini Kapat'; NameEn='Disable Desktop Icon Shadows'; DescTr='Masaüstü simge yazılarının gölge efektini kaldırır.'; DescEn='Removes the shadow effect from desktop icon labels.'; DetailTr='ListviewShadow değerini kapatır. Performans farkı küçük olabilir; görsel sadeleştirme seçeneğidir.'; DetailEn='Disables ListviewShadow. The performance difference may be small; this is a visual simplification.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ListviewShadow'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='SelectionFade'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Seçim Solma Efektini Kapat'; NameEn='Disable Selection Fade Effect'; DescTr='Dosya seçimlerinin yumuşak geçiş efektini kapatır.'; DescEn='Disables the fade effect used for file selections.'; DetailTr='ListviewAlphaSelect değerini kapatır. FPS yerine Explorer görsel efektini azaltır.'; DetailEn='Disables ListviewAlphaSelect. This reduces an Explorer effect rather than increasing game FPS.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ListviewAlphaSelect'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='KeyboardDelay'; Default=$false; CategoryTr='GİRDİ'; CategoryEn='INPUT'; NameTr='Klavye Tekrar Gecikmesini Azalt'; NameEn='Reduce Keyboard Repeat Delay'; DescTr='Bir tuş basılı tutulduğunda tekrarın daha erken başlamasını sağlar.'; DescEn='Makes key repeat start sooner when a key is held.'; DetailTr='KeyboardDelay değerini sıfırlar. Tek basış gecikmesini veya oyun FPS değerini değiştirmez.'; DetailEn='Sets KeyboardDelay to zero. It does not change single-key input latency or game FPS.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Control Panel\Keyboard'; Name='KeyboardDelay'; Value='0'; Type='String' }
    ) },
    [pscustomobject]@{ Id='LongPaths'; Default=$false; CategoryTr='SİSTEM'; CategoryEn='SYSTEM'; NameTr='Uzun Dosya Yollarını Aç'; NameEn='Enable Long File Paths'; DescTr='Uyumlu uygulamalarda 260 karakterden uzun dosya yollarına izin verir.'; DescEn='Allows paths longer than 260 characters in compatible applications.'; DetailTr='Microsoft tarafından belgelenen LongPathsEnabled değerini açar. Eski uygulamalar kendi desteğini sunmuyorsa etkilenmez.'; DetailEn='Enables the Microsoft-documented LongPathsEnabled value. Legacy applications still need their own long-path support.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name='LongPathsEnabled'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='FileExtensions'; Default=$false; CategoryTr='EXPLORER'; CategoryEn='EXPLORER'; NameTr='Dosya Uzantılarını Göster'; NameEn='Show File Extensions'; DescTr='Dosya adlarında .exe, .jpg ve .zip gibi gerçek uzantıları gösterir.'; DescEn='Shows real extensions such as .exe, .jpg, and .zip in file names.'; DetailTr='HideFileExt değerini kapatır. Dosya türlerini ayırt etmeyi kolaylaştırır ve Explorer yeniden başlatması gerekebilir.'; DetailEn='Disables HideFileExt. It makes file types easier to identify and Explorer may need to restart.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='HiddenFiles'; Default=$false; Caution=$true; WarningTr='Gizli sistem öğeleri görünür olur; ne olduğunu bilmediğin dosyaları silme.'; WarningEn='Hidden system items become visible; do not delete files you do not recognize.'; CategoryTr='EXPLORER'; CategoryEn='EXPLORER'; NameTr='Gizli Dosyaları Göster'; NameEn='Show Hidden Files'; DescTr='Explorer içinde gizli olarak işaretlenen dosya ve klasörleri gösterir.'; DescEn='Shows files and folders marked as hidden in Explorer.'; DetailTr='Explorer Advanced içindeki Hidden değerini 1 yapar. Korunan işletim sistemi dosyalarını ayrıca açmaz.'; DetailEn='Sets Hidden to 1 under Explorer Advanced. It does not separately expose protected operating-system files.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Hidden'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='LaunchThisPc'; Default=$false; CategoryTr='EXPLORER'; CategoryEn='EXPLORER'; NameTr='Explorer Bu Bilgisayar ile Açılsın'; NameEn='Open Explorer to This PC'; DescTr='Dosya Gezgini başlangıç sayfasını Ana Sayfa yerine Bu Bilgisayar yapar.'; DescEn='Makes File Explorer open This PC instead of Home.'; DetailTr='Explorer Advanced içindeki LaunchTo değerini 1 yapar. Dosyalarına veya sabitlenmiş klasörlere dokunmaz.'; DetailEn='Sets LaunchTo to 1 under Explorer Advanced. It does not alter files or pinned folders.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='LaunchTo'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='CompactExplorer'; Default=$false; CategoryTr='EXPLORER'; CategoryEn='EXPLORER'; NameTr='Explorer Kompakt Görünümü Aç'; NameEn='Enable Explorer Compact View'; DescTr='Dosya Gezgini satır aralıklarını daraltarak ekrana daha fazla öğe sığdırır.'; DescEn='Reduces File Explorer row spacing so more items fit on screen.'; DetailTr='Explorer Advanced içindeki UseCompactMode değerini 1 yapar. Dosyalara dokunmaz; yalnız görünüm yoğunluğunu değiştirir ve Explorer yeniden başlatması gerekebilir.'; DetailEn='Sets UseCompactMode to 1 under Explorer Advanced. It does not alter files; it only changes visual density and Explorer may need to restart.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='UseCompactMode'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='SeparateExplorer'; Default=$false; Caution=$true; WarningTr='Her Explorer penceresi ek bellek kullanabilir; düşük RAM bulunan sistemlerde seçme.'; WarningEn='Each Explorer window may use additional memory; avoid this on systems with limited RAM.'; CategoryTr='EXPLORER'; CategoryEn='EXPLORER'; NameTr='Explorer Pencerelerini Ayrı Süreçte Aç'; NameEn='Launch Explorer Windows Separately'; DescTr='Klasör pencerelerini ayrı explorer.exe süreçlerinde çalıştırarak bir çökmede diğerlerini koruyabilir.'; DescEn='Runs folder windows in separate explorer.exe processes so one crash may not close the others.'; DetailTr='Explorer Advanced içindeki SeparateProcess değerini 1 yapar. Kararlılığı artırabilir ancak açık pencere başına daha fazla RAM kullanabilir.'; DetailEn='Sets SeparateProcess to 1 under Explorer Advanced. It may improve isolation but can use more memory per open window.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='SeparateProcess'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='TaskbarEndTask'; Default=$false; Caution=$true; WarningTr='Görevi Sonlandır uygulamayı kaydetmeden kapatabilir; yalnız yanıt vermeyen uygulamalarda kullan.'; WarningEn='End Task can close an app without saving; use it only for unresponsive apps.'; CategoryTr='GÖREV ÇUBUĞU'; CategoryEn='TASKBAR'; NameTr='Sağ Tıkla Görevi Sonlandır'; NameEn='Enable Taskbar End Task'; DescTr='Görev çubuğu uygulama menüsüne Görevi Sonlandır seçeneği ekler.'; DescEn='Adds End Task to application menus on the taskbar.'; DetailTr='Windows 11 destekli sürümlerde TaskbarEndTask değerini açar. Bu düğme normal Kapat işleminden daha zorlayıcıdır.'; DetailEn='Enables TaskbarEndTask on supported Windows 11 builds. This action is more forceful than normal Close.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name='TaskbarEndTask'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='DarkTheme'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Windows Koyu Temayı Aç'; NameEn='Enable Windows Dark Theme'; DescTr='Windows ve desteklenen uygulamalarda koyu renk modunu etkinleştirir.'; DescEn='Enables dark mode in Windows and supported applications.'; DetailTr='SystemUsesLightTheme ve AppsUseLightTheme değerlerini kapatır. Yalnız görünümü değiştirir.'; DetailEn='Disables SystemUsesLightTheme and AppsUseLightTheme. This changes appearance only.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='SystemUsesLightTheme'; Value=0; Type='DWord' },
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='AppsUseLightTheme'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='AdvertisingId'; Default=$false; Caution=$true; WarningTr='Bazı uygulamalardaki kişiselleştirilmiş içerik ve reklamlar daha az ilgili olabilir.'; WarningEn='Personalized content and ads in some applications may become less relevant.'; CategoryTr='GİZLİLİK'; CategoryEn='PRIVACY'; NameTr='Windows Reklam Kimliğini Kapat'; NameEn='Disable Windows Advertising ID'; DescTr='Uygulamaların ortak reklam kimliğini kullanmasını engeller.'; DescEn='Prevents applications from using the shared advertising identifier.'; DetailTr='Belgelenmiş DisabledByGroupPolicy değerini açar. Uygulamaların normal internet erişimini engellemez.'; DetailEn='Enables the documented DisabledByGroupPolicy value. It does not block normal application internet access.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\Software\Policies\Microsoft\Windows\AdvertisingInfo'; Name='DisabledByGroupPolicy'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='ActivityFeed'; Default=$false; Caution=$true; WarningTr='Cihazlar arası etkinlik geçmişi ve devam etme deneyimleri çalışmayabilir.'; WarningEn='Cross-device activity history and resume experiences may stop working.'; CategoryTr='GİZLİLİK'; CategoryEn='PRIVACY'; NameTr='Etkinlik Akışını Kapat'; NameEn='Disable Activity Feed'; DescTr='Windows etkinliklerinin yayımlanmasını ve bulut eşitlemesini kapatır.'; DescEn='Disables publishing and cloud synchronization of Windows activities.'; DetailTr='Microsoft OS Policy içindeki EnableActivityFeed değerini 0 yapar. Yerel dosyaları silmez.'; DetailEn='Sets EnableActivityFeed to 0 under Microsoft OS Policy. It does not delete local files.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\Software\Policies\Microsoft\Windows\System'; Name='EnableActivityFeed'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='CloudSearch'; Default=$false; Caution=$true; WarningTr='Windows aramasında OneDrive ve kurumsal SharePoint sonuçları görünmez.'; WarningEn='OneDrive and organizational SharePoint results will not appear in Windows Search.'; CategoryTr='GİZLİLİK'; CategoryEn='PRIVACY'; NameTr='Windows Bulut Aramasını Kapat'; NameEn='Disable Windows Cloud Search'; DescTr='Windows aramasının bulut kaynaklarında sonuç aramasını engeller.'; DescEn='Stops Windows Search from querying cloud sources.'; DetailTr='Belgelenmiş AllowCloudSearch politikasını 0 yapar. Yerel uygulama ve dosya araması korunur.'; DetailEn='Sets the documented AllowCloudSearch policy to 0. Local application and file search remains available.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCloudSearch'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='DeliveryOptimization'; Default=$false; Caution=$true; WarningTr='Yerel ağdaki diğer bilgisayarlardan güncelleme alma hız avantajı kaybolabilir.'; WarningEn='You may lose faster update delivery from other PCs on the local network.'; CategoryTr='AĞ'; CategoryEn='NETWORK'; NameTr='Güncelleme Eş Paylaşımını Kapat'; NameEn='Disable Update Peer Sharing'; DescTr='Windows Update indirmelerinde bilgisayarlar arası P2P paylaşımını kapatır.'; DescEn='Disables peer-to-peer sharing for Windows Update downloads.'; DetailTr='DODownloadMode değerini Microsoft tarafından önerilen HTTP Only değerine, yani 0 olarak ayarlar. Windows Update ve normal HTTP indirmeleri çalışmaya devam eder.'; DetailEn='Sets DODownloadMode to the Microsoft-documented HTTP Only value 0. Windows Update and normal HTTP downloads continue to work.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name='DODownloadMode'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='HideRecommended'; Default=$false; Caution=$true; WarningTr='Yalnız desteklenen Windows 11 sürüm ve edition seçeneklerinde tam olarak uygulanır.'; WarningEn='It is fully enforced only on supported Windows 11 builds and editions.'; CategoryTr='BAŞLAT'; CategoryEn='START'; NameTr='Başlat Önerilerini Gizle'; NameEn='Hide Start Recommendations'; DescTr='Başlat menüsündeki önerilen uygulama ve dosya bölümünü gizler.'; DescEn='Hides the recommended applications and files section in Start.'; DetailTr='Microsoft tarafından belgelenen HideRecommendedSection politikasını açar. Windows 11 22H2 ve sonrası için tasarlanmıştır.'; DetailEn='Enables the Microsoft-documented HideRecommendedSection policy. It is designed for Windows 11 22H2 and later.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\Software\Policies\Microsoft\Windows\Explorer'; Name='HideRecommendedSection'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='CrossDeviceClipboard'; Default=$false; Caution=$true; WarningTr='Microsoft hesabına bağlı cihazlar arasında pano eşitlemesi kapanır.'; WarningEn='Clipboard synchronization between devices using your Microsoft account will stop.'; CategoryTr='GİZLİLİK'; CategoryEn='PRIVACY'; NameTr='Cihazlar Arası Panoyu Kapat'; NameEn='Disable Cross-Device Clipboard'; DescTr='Pano içeriğinin diğer Windows cihazlarıyla eşitlenmesini engeller.'; DescEn='Prevents clipboard contents from synchronizing with other Windows devices.'; DetailTr='Belgelenmiş AllowCrossDeviceClipboard politikasını 0 yapar. Bu bilgisayardaki normal kopyala ve yapıştır çalışmaya devam eder.'; DetailEn='Sets the documented AllowCrossDeviceClipboard policy to 0. Normal local copy and paste continues to work.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\Software\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='TaskbarSearch'; Default=$false; CategoryTr='GÖREV ÇUBUĞU'; CategoryEn='TASKBAR'; NameTr='Görev Çubuğu Aramasını Gizle'; NameEn='Hide Taskbar Search'; DescTr='Görev çubuğundaki arama kutusu veya simgesini gizler.'; DescEn='Hides the search box or icon from the taskbar.'; DetailTr='SearchboxTaskbarMode değerini 0 yapar. Başlat menüsüne yazıp arama yapmaya devam edebilirsin.'; DetailEn='Sets SearchboxTaskbarMode to 0. You can still search by typing in Start.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name='SearchboxTaskbarMode'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='TaskViewButton'; Default=$false; CategoryTr='GÖREV ÇUBUĞU'; CategoryEn='TASKBAR'; NameTr='Görev Görünümü Düğmesini Gizle'; NameEn='Hide Task View Button'; DescTr='Görev çubuğundaki Görev Görünümü simgesini kaldırır.'; DescEn='Removes the Task View icon from the taskbar.'; DetailTr='ShowTaskViewButton değerini 0 yapar. Win+Tab klavye kısayolu çalışmaya devam eder.'; DetailEn='Sets ShowTaskViewButton to 0. The Win+Tab keyboard shortcut remains available.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='TaskbarLeft'; Default=$false; CategoryTr='GÖREV ÇUBUĞU'; CategoryEn='TASKBAR'; NameTr='Görev Çubuğu Simgelerini Sola Al'; NameEn='Align Taskbar Icons Left'; DescTr='Windows 11 görev çubuğu simgelerini sola hizalar.'; DescEn='Aligns Windows 11 taskbar icons to the left.'; DetailTr='TaskbarAl değerini 0 yapar. Bu yalnızca kişisel görünüm tercihidir ve FPS etkisi yoktur.'; DetailEn='Sets TaskbarAl to 0. This is a personal appearance preference with no FPS effect.'; Settings=@(
        [pscustomobject]@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAl'; Value=0; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='DisableLoginBlur'; Default=$false; CategoryTr='GÖRSEL'; CategoryEn='VISUAL'; NameTr='Giriş Ekranı Bulanıklığını Kapat'; NameEn='Disable Sign-In Screen Blur'; DescTr='Windows giriş ekranındaki akrilik bulanıklık efektini kaldırır.'; DescEn='Removes the acrylic blur effect from the Windows sign-in screen.'; DetailTr='DisableAcrylicBackgroundOnLogon politikasını 1 yapar. Güvenlik veya oturum açma yöntemlerini değiştirmez.'; DetailEn='Sets DisableAcrylicBackgroundOnLogon to 1. It does not change security or sign-in methods.'; Settings=@(
        [pscustomobject]@{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='DisableAcrylicBackgroundOnLogon'; Value=1; Type='DWord' }
    ) },
    [pscustomobject]@{ Id='PowerPlan'; Default=$false; Caution=$true; WarningTr='Dizüstünde pil daha hızlı bitebilir; sıcaklık ve fan sesi artabilir.'; WarningEn='Laptop battery may drain faster; temperature and fan noise may increase.'; CategoryTr='GÜÇ'; CategoryEn='POWER'; NameTr='Yüksek Performans Güç Planı'; NameEn='High Performance Power Plan'; DescTr='Windows Yüksek Performans güç planını etkinleştirir.'; DescEn='Activates the Windows High Performance power plan.'; DetailTr='İşlemci güç tasarrufu gecikmelerini azaltabilir. Dizüstünde pil tüketimi ve sıcaklık artabilir; mevcut plan yedeklenir.'; DetailEn='May reduce CPU power-saving delays. Battery use and temperature can rise on laptops; the current plan is backed up.'; Settings=@() }
)

function Update-XVVFpsSelectedCount {
    if (-not $ui.FpsSelectedCount) { return }
    $count = @($script:fpsTweaks | Where-Object { $script:fpsChecks.ContainsKey($_.Id) -and $script:fpsChecks[$_.Id].IsChecked -eq $true }).Count
    $ui.FpsSelectedCount.Text = if ($script:language -eq 'en') { "$count selected" } else { "$count seçili" }
}

function Update-XVVFpsOptions {
    if (-not $ui.FpsPerformanceOptions -or -not $ui.FpsWindowsOptions) { return }
    $selectedIds = @($script:fpsTweaks | Where-Object { $script:fpsChecks.ContainsKey($_.Id) -and $script:fpsChecks[$_.Id].IsChecked -eq $true } | ForEach-Object { $_.Id })
    $firstBuild = ($script:fpsChecks.Count -eq 0)
    $ui.FpsPerformanceOptions.Children.Clear()
    $ui.FpsWindowsOptions.Children.Clear()
    $script:fpsChecks = @{}
    foreach ($tweak in $script:fpsTweaks) {
        $card = [Windows.Controls.Border]::new()
        $card.MinHeight = 108; $card.Background = '#151B2A'; $card.BorderBrush = '#273149'; $card.BorderThickness = '1'; $card.CornerRadius = '11'; $card.Padding = '13,11'; $card.Margin = '0,0,0,8'
        $panel = [Windows.Controls.StackPanel]::new()
        $top = [Windows.Controls.Grid]::new()
        $top.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
        $toggleColumn = [Windows.Controls.ColumnDefinition]::new(); $toggleColumn.Width = 'Auto'; $top.ColumnDefinitions.Add($toggleColumn)
        $badges = [Windows.Controls.WrapPanel]::new()
        $category = [Windows.Controls.Border]::new()
        $category.Background = '#2B2350'; $category.CornerRadius = '7'; $category.Padding = '8,3'; $category.HorizontalAlignment = 'Left'
        $categoryText = [Windows.Controls.TextBlock]::new()
        $categoryText.Text = if ($script:language -eq 'en') { $tweak.CategoryEn } else { $tweak.CategoryTr }
        $categoryText.Foreground = '#B9AAFF'; $categoryText.FontSize = 10; $categoryText.FontWeight = 'Bold'; $category.Child = $categoryText
        $typeBadge = [Windows.Controls.Border]::new()
        $typeBadge.Background = '#123A39'; $typeBadge.CornerRadius = '7'; $typeBadge.Padding = '8,3'; $typeBadge.Margin = '6,0,0,0'
        $typeText = [Windows.Controls.TextBlock]::new()
        $typeText.Text = if (@($tweak.Settings).Count -gt 0) { 'REGEDIT' } else { if ($script:language -eq 'en') { 'POWER PLAN' } else { 'GÜÇ PLANI' } }
        $typeText.Foreground = '#70E0C0'; $typeText.FontSize = 10; $typeText.FontWeight = 'Bold'; $typeBadge.Child = $typeText
        $badges.Children.Add($category) | Out-Null; $badges.Children.Add($typeBadge) | Out-Null
        if ($tweak.PSObject.Properties['Caution'] -and $tweak.Caution) {
            $warningBadge = [Windows.Controls.Border]::new()
            $warningBadge.Background = '#4A2D16'; $warningBadge.BorderBrush = '#B96A24'; $warningBadge.BorderThickness = '1'; $warningBadge.CornerRadius = '7'; $warningBadge.Padding = '8,3'; $warningBadge.Margin = '6,0,0,0'
            $warningBadgeText = [Windows.Controls.TextBlock]::new()
            $warningBadgeText.Text = if ($script:language -eq 'en') { 'CAUTION' } else { 'DİKKAT' }
            $warningBadgeText.Foreground = '#FFB86B'; $warningBadgeText.FontSize = 10; $warningBadgeText.FontWeight = 'Bold'; $warningBadge.Child = $warningBadgeText
            $badges.Children.Add($warningBadge) | Out-Null
        }
        $check = [Windows.Controls.Primitives.ToggleButton]::new()
        $check.Style = $window.FindResource('TweakToggle')
        $check.SetValue([Windows.Controls.Grid]::ColumnProperty, 1); $check.VerticalAlignment = 'Center'; $check.ToolTip = if ($script:language -eq 'en') { 'Include this setting' } else { 'Bu ayarı seç' }
        $check.IsChecked = if ($firstBuild) { [bool]$tweak.Default } else { $selectedIds -contains $tweak.Id }
        $top.Children.Add($badges) | Out-Null; $top.Children.Add($check) | Out-Null
        $title = [Windows.Controls.TextBlock]::new()
        $title.Text = if ($script:language -eq 'en') { $tweak.NameEn } else { $tweak.NameTr }
        $title.FontSize = 14; $title.FontWeight = 'SemiBold'; $title.Margin = '0,8,0,0'; $title.TextWrapping = 'Wrap'
        $summary = [Windows.Controls.TextBlock]::new()
        $summary.Text = if ($script:language -eq 'en') { $tweak.DescEn } else { $tweak.DescTr }
        $summary.Foreground = '#9DA8BE'; $summary.FontSize = 11; $summary.TextWrapping = 'Wrap'; $summary.LineHeight = 17; $summary.Margin = '0,5,0,0'
        $warningPanel = $null
        if ($tweak.PSObject.Properties['Caution'] -and $tweak.Caution) {
            $warningPanel = [Windows.Controls.Border]::new()
            $warningPanel.Background = '#241B16'; $warningPanel.BorderBrush = '#6E4524'; $warningPanel.BorderThickness = '1'; $warningPanel.CornerRadius = '7'; $warningPanel.Padding = '9,6'; $warningPanel.Margin = '0,8,0,0'
            $warningText = [Windows.Controls.TextBlock]::new()
            $warningReason = if ($script:language -eq 'en') { $tweak.WarningEn } else { $tweak.WarningTr }
            $warningText.Text = $(if ($script:language -eq 'en') { "Why caution: $warningReason" } else { "Neden dikkat: $warningReason" })
            $warningText.Foreground = '#F1B873'; $warningText.FontSize = 10.5; $warningText.FontWeight = 'SemiBold'; $warningText.TextWrapping = 'Wrap'; $warningText.LineHeight = 16
            $warningPanel.Child = $warningText
        }
        $details = [Windows.Controls.Expander]::new()
        $details.Header = if ($script:language -eq 'en') { 'Technical details' } else { 'Teknik ayrıntı' }
        $details.Margin = '0,9,0,0'
        $description = [Windows.Controls.TextBlock]::new()
        $detailText = if ($script:language -eq 'en') { $tweak.DetailEn } else { $tweak.DetailTr }
        if (@($tweak.Settings).Count -gt 0) {
            $registryText = @($tweak.Settings | ForEach-Object { "$($_.Path)  →  $($_.Name) = $($_.Value) [$($_.Type)]" }) -join [Environment]::NewLine
            $detailText += [Environment]::NewLine + [Environment]::NewLine + $registryText
        } else {
            $detailText += [Environment]::NewLine + [Environment]::NewLine + $(if ($script:language -eq 'en') { 'Command: powercfg.exe /setactive SCHEME_MIN' } else { 'Komut: powercfg.exe /setactive SCHEME_MIN' })
        }
        $description.Text = $detailText
        $description.Foreground = '#AAB2C3'; $description.FontSize = 11; $description.TextWrapping = 'Wrap'; $description.LineHeight = 17; $description.Margin = '0,7,6,3'
        $details.Content = $description
        $panel.Children.Add($top) | Out-Null; $panel.Children.Add($title) | Out-Null; $panel.Children.Add($summary) | Out-Null
        if ($null -ne $warningPanel) { $panel.Children.Add($warningPanel) | Out-Null }
        $panel.Children.Add($details) | Out-Null
        $card.Child = $panel
        # tv3m: iki panel bilinçli olarak 20/20 dengede tutulur.
        $performanceIds = @('GameMode','GameDvr','AppCapture','Hags','PowerThrottling','GameBarStartup','GameModeNotices','MouseAccel','KeyboardDelay','PowerPlan','LongPaths','FileExtensions','LaunchThisPc','CompactExplorer','SeparateExplorer','TaskbarEndTask','HideRecommended','TaskbarSearch','TaskViewButton','TaskbarLeft')
        if ($performanceIds -contains $tweak.Id) { $ui.FpsPerformanceOptions.Children.Add($card) | Out-Null }
        else { $ui.FpsWindowsOptions.Children.Add($card) | Out-Null }
        $script:fpsChecks[$tweak.Id] = $check
        $check.Add_Checked({ Update-XVVFpsSelectedCount })
        $check.Add_Unchecked({ Update-XVVFpsSelectedCount })
    }
    Update-XVVFpsSelectedCount
}

function Set-XVVFpsQuickSelection {
    param([string]$Mode)
    $ids = switch ($Mode) {
        'Recommended' { @('GameMode','GameDvr','AppCapture','MouseAccel') }
        'Competitive' { @('GameMode','GameDvr','AppCapture','MouseAccel','GameBarStartup','GameModeNotices','PowerPlan') }
        'LowEnd' { @('GameMode','GameDvr','AppCapture','MouseAccel','BackgroundApps','WindowAnimation','TaskbarAnimation','AeroPeek','WindowContents','MenuDelay','IconShadows','SelectionFade','Transparency') }
        'Privacy' { @('AdvertisingId','ActivityFeed','CloudSearch','DeliveryOptimization','CrossDeviceClipboard') }
        'Windows' { @('LongPaths','FileExtensions','LaunchThisPc','TaskbarEndTask','DarkTheme','HideRecommended','TaskbarSearch','TaskViewButton','TaskbarLeft','DisableLoginBlur') }
        default { @() }
    }
    foreach ($tweak in $script:fpsTweaks) { $script:fpsChecks[$tweak.Id].IsChecked = ($ids -contains $tweak.Id) }
    Update-XVVFpsSelectedCount
}

function Set-XVVFpsProgress {
    param([int]$Value, [string]$Status)
    $ui.FpsProgress.Value = [Math]::Max(0, [Math]::Min(100, $Value))
    $ui.FpsProgressText.Text = "$($ui.FpsProgress.Value)%"
    $ui.FpsStatus.Text = $Status
    $window.Dispatcher.Invoke([action]{}, 'Background')
}

function Get-XVVRegistryBackup {
    param($Setting)
    $exists = $false; $value = $null; $kind = $null
    if (Test-Path -LiteralPath $Setting.Path) {
        try {
            $key = Get-Item -LiteralPath $Setting.Path
            $value = $key.GetValue($Setting.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $exists = ($null -ne $value)
            if ($exists) { $kind = $key.GetValueKind($Setting.Name).ToString() }
        } catch { }
    }
    [pscustomobject]@{ Path=$Setting.Path; Name=$Setting.Name; Exists=$exists; Value=$value; Kind=$kind }
}

function New-XVVFpsRestorePoint {
    $frequencyPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $frequencySetting = [pscustomobject]@{ Path=$frequencyPath; Name='SystemRestorePointCreationFrequency' }
    $oldFrequency = Get-XVVRegistryBackup -Setting $frequencySetting
    try {
        New-Item -Path $frequencyPath -Force | Out-Null
        New-ItemProperty -Path $frequencyPath -Name $frequencySetting.Name -Value 0 -PropertyType DWord -Force | Out-Null
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'XVV FPS Ayarlari Oncesi' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    } finally {
        if ($oldFrequency.Exists) { New-ItemProperty -Path $frequencyPath -Name $frequencySetting.Name -Value $oldFrequency.Value -PropertyType $oldFrequency.Kind -Force | Out-Null }
        else { Remove-ItemProperty -Path $frequencyPath -Name $frequencySetting.Name -ErrorAction SilentlyContinue }
    }
}

function Save-XVVFpsBackup {
    param([array]$Tweaks)
    $settings = @($Tweaks | ForEach-Object { $_.Settings } | ForEach-Object { $_ })
    $registry = @($settings | ForEach-Object { Get-XVVRegistryBackup -Setting $_ })
    $activeText = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
    $activeGuid = if ($activeText -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $matches[1] } else { $null }
    $backup = [pscustomobject]@{ Created=(Get-Date).ToString('o'); Registry=$registry; ActivePowerScheme=$activeGuid }
    $backupDir = Join-Path $PSScriptRoot 'backups'; New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $backup | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $backupDir 'LastFpsBackup.json') -Encoding UTF8
}

function Restore-XVVFpsBackup {
    $path = Join-Path $PSScriptRoot 'backups\LastFpsBackup.json'
    if (-not (Test-Path -LiteralPath $path)) { throw $(if ($script:language -eq 'en') { 'No FPS settings backup was found.' } else { 'Geri alınacak FPS ayarı yedeği bulunamadı.' }) }
    $backup = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in @($backup.Registry)) {
        if ($item.Exists) {
            New-Item -Path $item.Path -Force | Out-Null
            New-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -PropertyType $item.Kind -Force | Out-Null
        } elseif (Test-Path -LiteralPath $item.Path) { Remove-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction SilentlyContinue }
    }
    if ($backup.ActivePowerScheme) { & powercfg.exe /setactive ([string]$backup.ActivePowerScheme) | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'Power plan could not be restored.' } }
}

function Show-XVVSpec {
    param([string]$Category, [string]$Title)
    $ui.SpecDetailTitle.Text = $Title
    $ui.SpecDetailText.Text = 'Bilgiler okunuyor...'
    $window.Dispatcher.Invoke([action]{}, 'Background')
    try { $ui.SpecDetailText.Text = Get-XVVSpecText -Category $Category }
    catch { $ui.SpecDetailText.Text = "Bilgiler okunamadı:`n$($_.Exception.Message)" }
}

foreach ($target in $script:cleanupTargets) {
    $panel = [Windows.Controls.StackPanel]::new()
    $check = [Windows.Controls.CheckBox]::new()
    $check.Content = $target.Name
    $check.IsChecked = $target.Default
    $detail = [Windows.Controls.TextBlock]::new()
    $detail.Text = $target.Detail + $(if ($target.Admin) { '  •  Yönetici izni gerekir' } else { '' })
    $detail.Foreground = '#8E96A8'
    $detail.FontSize = 11
    $detail.Margin = '24,-3,0,7'
    $panel.Children.Add($check) | Out-Null
    $panel.Children.Add($detail) | Out-Null
    $ui.CleanupOptions.Children.Add($panel) | Out-Null
    $script:cleanupChecks[$target.Id] = $check
    $script:cleanupDetails[$target.Id] = $detail
}

$ui.AdminBadge.Text = if (Test-XVVAdministrator) { '● Yönetici modu' } else { '○ Standart kullanıcı' }
$ui.AdminBadge.Foreground = if (Test-XVVAdministrator) { '#64D8A0' } else { '#F2B45B' }
$os = Get-CimInstance Win32_OperatingSystem
$ui.OsText.Text = $os.Caption -replace 'Microsoft ', ''
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$ui.DiskText.Text = "$(Format-XVVBytes $drive.FreeSpace) boş"
$uptime = (Get-Date) - $os.LastBootUpTime
$ui.UptimeText.Text = "$([int]$uptime.TotalHours) saat $($uptime.Minutes) dakika"
Set-XVVLanguage -Language 'tr'
function Update-XVVLanguage {
    param([string]$Language)
    Set-XVVLanguage -Language $Language
    $ui.UptimeText.Text = if ($script:language -eq 'en') { "$([int]$uptime.TotalHours) hours $($uptime.Minutes) minutes" } else { "$([int]$uptime.TotalHours) saat $($uptime.Minutes) dakika" }
}
$ui.LanguageTrButton.Add_Click({ Update-XVVLanguage -Language 'tr' })
$ui.LanguageEnButton.Add_Click({ Update-XVVLanguage -Language 'en' })

$ui.NavHome.Add_Click({ Show-Page Home })
$ui.NavCleanup.Add_Click({ Show-Page Cleanup })
$ui.NavApps.Add_Click({ Show-Page Apps; if ($script:allApps.Count -eq 0) { Load-Apps } })
$ui.NavInstall.Add_Click({ Show-Page Install })
$ui.NavFps.Add_Click({ Show-Page Fps })
$ui.NavSpecs.Add_Click({ Show-Page Specs })
$ui.NavTools.Add_Click({ Show-Page Tools })
$ui.HomeScanButton.Add_Click({ Show-Page Cleanup; $ui.ScanButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) })
$ui.HomeInstallButton.Add_Click({ Show-Page Install })
$ui.HomeFpsButton.Add_Click({ Show-Page Fps })
$ui.HomeSpecsButton.Add_Click({ Show-Page Specs })
$ui.FpsPresetRecommended.Add_Click({ Set-XVVFpsQuickSelection Recommended })
$ui.FpsPresetCompetitive.Add_Click({ Set-XVVFpsQuickSelection Competitive })
$ui.FpsPresetLowEnd.Add_Click({ Set-XVVFpsQuickSelection LowEnd })
$ui.FpsPresetPrivacy.Add_Click({ Set-XVVFpsQuickSelection Privacy })
$ui.FpsPresetWindows.Add_Click({ Set-XVVFpsQuickSelection Windows })
$ui.FpsPresetClear.Add_Click({ Set-XVVFpsQuickSelection Clear })

$ui.ScanButton.Add_Click({
    $selected = @(Get-SelectedCleanupTargets)
    if ($selected.Count -eq 0) { Show-Dialog 'En az bir temizlik alanı seç.' 'XVV'; return }
    $ui.CleanupStatus.Text = 'Taranıyor...'
    $window.Dispatcher.Invoke([action]{}, 'Background')
    $result = Measure-XVVCleanup -Targets $selected
    $ui.CleanupStatus.Text = "$($result.Display) temizlenebilir"
    $ui.CleanupDetail.Text = "$($result.Files) dosya • $($selected.Count) işlem seçildi"
})

$ui.CleanButton.Add_Click({
    $selected = @(Get-SelectedCleanupTargets)
    if ($selected.Count -eq 0) { Show-Dialog 'En az bir temizlik alanı seç.'; return }
    $answer = [System.Windows.MessageBox]::Show($window, "$($selected.Count) seçili işlem çalıştırılacak. Devam edilsin mi?", 'XVV Temizlik', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    $ui.CleanupStatus.Text = 'Temizlik yapılıyor...'
    $window.Dispatcher.Invoke([action]{}, 'Background')
    $result = Invoke-XVVCleanup -Targets $selected
    $ui.CleanupStatus.Text = "$($result.Completed.Count) işlem tamamlandı"
    $ui.CleanupDetail.Text = if ($result.Errors.Count) { "$($result.Errors.Count) işlem tamamlanamadı" } else { 'Temizlik başarıyla tamamlandı' }
    if ($result.Errors.Count) { Show-Dialog ($result.Errors -join [Environment]::NewLine) 'Tamamlanamayan işlemler' 'Warning' }
})

$ui.RefreshAppsButton.Add_Click({ Load-Apps })
$ui.ClearAppSelectionButton.Add_Click({
    $ui.AppsList.UnselectAll()
    $ui.AppsStatus.Text = if ($script:language -eq 'en') { 'Selection cleared' } else { 'Seçim temizlendi' }
})
$ui.AppSearch.Add_TextChanged({ Filter-Apps })
$ui.RemoveAppsButton.Add_Click({
    $selected = @($ui.AppsList.SelectedItems)
    if ($selected.Count -eq 0) { Show-Dialog 'Kaldırmak için en az bir uygulama seç.'; return }
    $names = ($selected.DisplayName -join ', ')
    $answer = [System.Windows.MessageBox]::Show($window, "Şu uygulamalar kaldırılacak:`n$names", 'XVV Uygulama Kaldırma', 'YesNo', 'Warning')
    if ($answer -ne 'Yes') { return }
    $ui.AppsStatus.Text = "$($selected.Count) uygulama kaldırılıyor..."
    $window.Dispatcher.Invoke([action]{}, 'Background')
    $result = Remove-XVVApps -Apps $selected
    $message = "$($result.Removed.Count) uygulama kaldırıldı."
    if ($result.Errors.Count -gt 0) { $message += "`n$($result.Errors.Count) uygulama kaldırılamadı." }
    Show-Dialog $message
    Load-Apps
})

$ui.ClearInstallSelectionButton.Add_Click({
    foreach ($app in $script:installItems) { $app.IsSelected = $false }
    Filter-XVVInstallCatalog
    $ui.InstallStatus.Text = if ($script:language -eq 'en') { 'Selection cleared' } else { 'Seçim temizlendi' }
})
$ui.InstallSearch.Add_TextChanged({ Filter-XVVInstallCatalog })
$ui.InstallCatAll.Add_Click({ Set-XVVInstallCategory All })
$ui.InstallCatGames.Add_Click({ Set-XVVInstallCategory Games })
$ui.InstallCatBrowsers.Add_Click({ Set-XVVInstallCategory Browsers })
$ui.InstallCatSecurity.Add_Click({ Set-XVVInstallCategory Security })
$ui.InstallCatCommunication.Add_Click({ Set-XVVInstallCategory Communication })
$ui.InstallCatMedia.Add_Click({ Set-XVVInstallCategory Media })
$ui.InstallCatTools.Add_Click({ Set-XVVInstallCategory Tools })
$ui.InstallSelectedButton.Add_Click({
    $selected = @($script:installItems | Where-Object { $_.IsSelected })
    if ($selected.Count -eq 0) {
        Show-Dialog $(if ($script:language -eq 'en') { 'Select at least one application to install.' } else { 'Kurmak için en az bir uygulama seç.' })
        return
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Show-Dialog $(if ($script:language -eq 'en') { 'Winget was not found. Install or update App Installer from Microsoft Store, then try again.' } else { "Winget bulunamadı. Microsoft Store'dan Uygulama Yükleyici'yi kur veya güncelle, ardından tekrar dene." }) 'XVV' 'Warning'
        return
    }
    $namesToInstall = $selected.Name -join ', '
    $prompt = if ($script:language -eq 'en') { "The latest available versions will be installed:`n$namesToInstall`n`nContinue?" } else { "En güncel sürümler kurulacak:`n$namesToInstall`n`nDevam edilsin mi?" }
    $answer = [System.Windows.MessageBox]::Show($window, $prompt, 'XVV', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    $ui.InstallSelectedButton.IsEnabled = $false
    $ui.ClearInstallSelectionButton.IsEnabled = $false
    $completed = [Collections.Generic.List[string]]::new()
    $failed = [Collections.Generic.List[string]]::new()
    try {
        for ($index = 0; $index -lt $selected.Count; $index++) {
            $app = $selected[$index]
            $from = [int](($index / $selected.Count) * 100)
            $status = if ($script:language -eq 'en') { "Installing $($app.Name)..." } else { "$($app.Name) kuruluyor..." }
            Set-XVVInstallProgress -Value $from -Status $status
            try {
                Invoke-XVVWingetInstall -App $app
                $completed.Add($app.Name)
            } catch {
                $failed.Add("$($app.Name): $($_.Exception.Message)")
            }
            Set-XVVInstallProgress -Value ([int]((($index + 1) / $selected.Count) * 100)) -Status $status
        }
        $summary = if ($script:language -eq 'en') { "$($completed.Count) application(s) installed or already current." } else { "$($completed.Count) uygulama kuruldu veya zaten günceldi." }
        if ($failed.Count -gt 0) {
            $summary += if ($script:language -eq 'en') { "`n`n$($failed.Count) application(s) failed:`n$($failed -join [Environment]::NewLine)" } else { "`n`n$($failed.Count) uygulama tamamlanamadı:`n$($failed -join [Environment]::NewLine)" }
        }
        $ui.InstallStatus.Text = if ($failed.Count -gt 0) { if ($script:language -eq 'en') { 'Completed with some errors' } else { 'Bazı hatalarla tamamlandı' } } else { if ($script:language -eq 'en') { 'Installation complete' } else { 'Kurulum tamamlandı' } }
        Show-Dialog $summary 'XVV' $(if ($failed.Count -gt 0) { 'Warning' } else { 'Information' })
    } finally {
        $ui.InstallSelectedButton.IsEnabled = $true
        $ui.ClearInstallSelectionButton.IsEnabled = $true
    }
})

$ui.ApplyFpsButton.Add_Click({
    $selected = @($script:fpsTweaks | Where-Object { $script:fpsChecks[$_.Id].IsChecked -eq $true })
    if ($selected.Count -eq 0) { Show-Dialog $(if ($script:language -eq 'en') { 'Select at least one setting.' } else { 'En az bir ayar seç.' }); return }
    if (-not (Test-XVVAdministrator)) { Show-Dialog $(if ($script:language -eq 'en') { 'Run XVV as administrator to create the mandatory restore point.' } else { 'Zorunlu geri yükleme noktasını oluşturmak için XVV uygulamasını yönetici olarak çalıştır.' }) 'XVV' 'Warning'; return }
    $prompt = if ($script:language -eq 'en') { "A system restore point will be created first, then $($selected.Count) selected setting(s) will be applied. Continue?" } else { "Önce sistem geri yükleme noktası oluşturulacak, ardından $($selected.Count) seçili ayar uygulanacak. Devam edilsin mi?" }
    if ([System.Windows.MessageBox]::Show($window, $prompt, 'XVV FPS', 'YesNo', 'Question') -ne 'Yes') { return }
    $ui.ApplyFpsButton.IsEnabled = $false; $ui.RestoreFpsButton.IsEnabled = $false
    $changesStarted = $false
    try {
        Set-XVVFpsProgress 5 $(if ($script:language -eq 'en') { 'Backing up current settings...' } else { 'Mevcut ayarlar yedekleniyor...' })
        Save-XVVFpsBackup -Tweaks $selected
        Set-XVVFpsProgress 18 $(if ($script:language -eq 'en') { 'Creating mandatory restore point...' } else { 'Zorunlu geri yükleme noktası oluşturuluyor...' })
        try { New-XVVFpsRestorePoint }
        catch { throw $(if ($script:language -eq 'en') { "Restore point could not be created. No FPS setting was applied. $($_.Exception.Message)" } else { "Geri yükleme noktası oluşturulamadı. Hiçbir FPS ayarı uygulanmadı. $($_.Exception.Message)" }) }
        $changesStarted = $true
        for ($index = 0; $index -lt $selected.Count; $index++) {
            $tweak = $selected[$index]
            $name = if ($script:language -eq 'en') { $tweak.NameEn } else { $tweak.NameTr }
            Set-XVVFpsProgress (25 + [int](65 * $index / $selected.Count)) $(if ($script:language -eq 'en') { "Applying $name..." } else { "$name uygulanıyor..." })
            foreach ($setting in @($tweak.Settings)) {
                New-Item -Path $setting.Path -Force | Out-Null
                New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType $setting.Type -Force | Out-Null
                $actual = (Get-ItemProperty -LiteralPath $setting.Path -Name $setting.Name).($setting.Name)
                if ([string]$actual -ne [string]$setting.Value) { throw "$($setting.Path)\$($setting.Name) doğrulanamadı." }
            }
            if ($tweak.Id -eq 'PowerPlan') { & powercfg.exe /setactive SCHEME_MIN | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'Yüksek Performans güç planı etkinleştirilemedi.' } }
        }
        Set-XVVFpsProgress 100 $(if ($script:language -eq 'en') { 'Selected settings applied and verified' } else { 'Seçili ayarlar uygulandı ve doğrulandı' })
        Show-Dialog $(if ($script:language -eq 'en') { 'Selected settings were applied. Sign out or restart Windows for all changes to take effect.' } else { 'Seçili ayarlar uygulandı. Tüm değişikliklerin etkili olması için Windows oturumunu veya bilgisayarı yeniden başlat.' })
    } catch {
        $applyError = $_.Exception.Message
        if ($changesStarted) { try { Restore-XVVFpsBackup } catch { } }
        $ui.FpsStatus.Text = if ($script:language -eq 'en') { 'Settings were not completed' } else { 'Ayarlar tamamlanamadı' }
        Show-Dialog $applyError 'XVV FPS' 'Warning'
    } finally { $ui.ApplyFpsButton.IsEnabled = $true; $ui.RestoreFpsButton.IsEnabled = $true }
})

$ui.RestoreFpsButton.Add_Click({
    if (-not (Test-XVVAdministrator)) { Show-Dialog $(if ($script:language -eq 'en') { 'Run XVV as administrator to restore settings.' } else { 'Ayarları geri almak için XVV uygulamasını yönetici olarak çalıştır.' }) 'XVV' 'Warning'; return }
    try {
        Restore-XVVFpsBackup
        Set-XVVFpsProgress 100 $(if ($script:language -eq 'en') { 'Previous settings restored' } else { 'Önceki ayarlar geri yüklendi' })
        Show-Dialog $(if ($script:language -eq 'en') { 'Previous FPS settings and power plan were restored.' } else { 'Önceki FPS ayarları ve güç planı geri yüklendi.' })
    } catch { Show-Dialog $_.Exception.Message 'XVV FPS' 'Warning' }
})

$specButtons = @{
    SpecCpu=@('Cpu','İşlemci'); SpecGpu=@('Gpu','Ekran Kartı'); SpecBoard=@('Board','Anakart ve BIOS'); SpecRam=@('Ram','RAM Modülleri')
    SpecDisk=@('Disk','Depolama Diskleri'); SpecMonitor=@('Monitor','Monitörler'); SpecNetwork=@('Network','Ağ Bağlantıları'); SpecSystem=@('System','Windows ve Sistem')
    SpecSecurity=@('Security','Güvenlik, TPM ve Sanallaştırma'); SpecBattery=@('Battery','Batarya Bilgileri'); SpecAudio=@('Audio','Ses Aygıtları'); SpecUsb=@('Usb','USB Denetleyicileri')
}
foreach ($entry in $specButtons.GetEnumerator()) {
    $button = $ui[$entry.Key]
    $category = $entry.Value[0]
    $title = $entry.Value[1]
    $button.Add_Click({ Show-XVVSpec -Category $category -Title $title }.GetNewClosure())
}

$tools = @{
    ToolTaskManager=@('taskmgr.exe',$null); ToolStartup=@('ms-settings:startupapps',$null); ToolDeviceManager=@('devmgmt.msc',$null)
    ToolDiskManagement=@('diskmgmt.msc',$null); ToolStorage=@('ms-settings:storagesense',$null); ToolGraphics=@('ms-settings:display-advancedgraphics',$null)
    ToolWindowsUpdate=@('ms-settings:windowsupdate',$null); ToolPrivacy=@('ms-settings:privacy',$null); ToolControlPanel=@('control.exe',$null)
    ToolRestore=@('SystemPropertiesProtection.exe',$null); ToolReliability=@('perfmon.exe','/rel')
}
foreach ($entry in $tools.GetEnumerator()) {
    $button = $ui[$entry.Key]
    $command = $entry.Value[0]
    $arguments = $entry.Value[1]
    $button.Add_Click({ if ($arguments) { Start-Process $command -ArgumentList $arguments } else { Start-Process $command } }.GetNewClosure())
}
$ui.ToolSfc.Add_Click({
    if (-not (Test-XVVAdministrator)) { Show-Dialog 'Sistem taraması için XVV uygulamasını yönetici olarak çalıştır.' 'XVV' 'Warning'; return }
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','sfc /scannow'
})

Show-Page Home
$window.ShowDialog() | Out-Null
