Set-StrictMode -Version Latest

# XVV core services - iflaholmaz (@iflaholmaz), 2026.
function Test-XVVAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-XVVBytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Get-XVVCleanupTargets {
    $local = $env:LOCALAPPDATA
    $windows = $env:WINDIR
    @(
        [pscustomobject]@{ Id='UserTemp'; Name='Kullanıcı geçici dosyaları'; Detail='%TEMP%'; Paths=@($env:TEMP); Admin=$false; Default=$true }
        [pscustomobject]@{ Id='WindowsTemp'; Name='Windows geçici dosyaları'; Detail='Windows\\Temp'; Paths=@("$windows\Temp"); Admin=$true; Default=$true }
        [pscustomobject]@{ Id='Prefetch'; Name='Prefetch'; Detail='Windows yeniden oluşturur'; Paths=@("$windows\Prefetch"); Admin=$true; Default=$false }
        [pscustomobject]@{ Id='Thumbnails'; Name='Küçük resim önbelleği'; Detail='Explorer thumbnail cache'; Paths=@("$local\Microsoft\Windows\Explorer\thumbcache_*.db"); Admin=$false; Default=$true }
        [pscustomobject]@{ Id='DirectX'; Name='DirectX shader önbelleği'; Detail='D3DSCache'; Paths=@("$local\D3DSCache"); Admin=$false; Default=$true }
        [pscustomobject]@{ Id='WER'; Name='Windows hata raporları'; Detail='Yerel hata raporları'; Paths=@("$local\Microsoft\Windows\WER"); Admin=$false; Default=$true }
        [pscustomobject]@{ Id='Location'; Name='Konum önbelleği'; Detail='Yerel konum geçmişi'; Paths=@("$local\Microsoft\Windows\LocationProvider"); Admin=$false; Default=$false }
        [pscustomobject]@{ Id='RecycleBin'; Name='Çöp Kutusu'; Detail='Tüm sürücüler'; Paths=@(); Admin=$false; Default=$true }
        [pscustomobject]@{ Id='Dns'; Name='DNS önbelleği'; Detail='ipconfig /flushdns'; Paths=@(); Admin=$false; Default=$true }
    )
}

function Get-XVVPathItems {
    param([string]$Path)
    if ($Path -match '[*?]') {
        return @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)
    }
    if (Test-Path -LiteralPath $Path) {
        return @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    }
    return @()
}

function Measure-XVVCleanup {
    param([Parameter(Mandatory)][object[]]$Targets)
    [long]$bytes = 0
    [long]$files = 0
    foreach ($target in $Targets) {
        foreach ($path in $target.Paths) {
            foreach ($item in (Get-XVVPathItems -Path $path)) {
                if ($item.PSIsContainer) {
                    $children = @(Get-ChildItem -LiteralPath $item.FullName -File -Force -Recurse -ErrorAction SilentlyContinue)
                    $files += $children.Count
                    foreach ($child in $children) {
                        if ($null -ne $child.Length) {
                            $bytes += [long]$child.Length
                        }
                    }
                } else {
                    $files++
                    $bytes += [long]$item.Length
                }
            }
        }
    }
    [pscustomobject]@{ Bytes=$bytes; Files=$files; Display=(Format-XVVBytes -Bytes $bytes) }
}

function Invoke-XVVCleanup {
    param([Parameter(Mandatory)][object[]]$Targets)
    $errors = [System.Collections.Generic.List[string]]::new()
    $completed = [System.Collections.Generic.List[string]]::new()
    foreach ($target in $Targets) {
        try {
            switch ($target.Id) {
                'Dns' {
                    $null = & ipconfig.exe /flushdns 2>&1
                }
                'RecycleBin' {
                    Clear-RecycleBin -Force -ErrorAction Stop
                }
                default {
                    foreach ($path in $target.Paths) {
                        foreach ($item in (Get-XVVPathItems -Path $path)) {
                            Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
            $completed.Add($target.Name)
        } catch {
            $errors.Add("$($target.Name): $($_.Exception.Message)")
        }
    }
    [pscustomobject]@{ Completed=$completed; Errors=$errors }
}

function Find-XVVAppIcon {
    param($Package)
    try {
        $manifestPath = Join-Path $Package.InstallLocation 'AppxManifest.xml'
        if (-not (Test-Path -LiteralPath $manifestPath)) { return $null }
        [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop
        $visualNodes = @($manifest.SelectNodes("//*[local-name()='VisualElements']"))
        $propertiesLogo = @($manifest.SelectNodes("//*[local-name()='Properties']/*[local-name()='Logo']"))
        $logos = [System.Collections.Generic.List[string]]::new()

        foreach ($node in $visualNodes) {
            foreach ($attributeName in @('Square44x44Logo','Square30x30Logo','Square150x150Logo','Logo')) {
                $attribute = $node.Attributes[$attributeName]
                if ($null -ne $attribute -and -not [string]::IsNullOrWhiteSpace($attribute.Value)) { $logos.Add($attribute.Value) }
            }
        }
        foreach ($node in $propertiesLogo) {
            if (-not [string]::IsNullOrWhiteSpace($node.InnerText)) { $logos.Add($node.InnerText) }
        }

        foreach ($logo in $logos) {
            if ($logo.StartsWith('ms-resource:')) { continue }
            $candidate = Join-Path $Package.InstallLocation ($logo -replace '/', '\')
            if (Test-Path -LiteralPath $candidate) { return $candidate }
            $directory = Split-Path $candidate
            $stem = [IO.Path]::GetFileNameWithoutExtension($candidate)
            if (-not (Test-Path -LiteralPath $directory)) { continue }
            $best = Get-ChildItem -LiteralPath $directory -Filter "$stem*.png" -File -ErrorAction SilentlyContinue |
                Sort-Object @{ Expression = {
                    if ($_.Name -match 'targetsize-44') { 0 } elseif ($_.Name -match 'targetsize-48') { 1 }
                    elseif ($_.Name -match 'scale-200') { 2 } elseif ($_.Name -match 'scale-100') { 3 } else { 4 }
                }} | Select-Object -First 1
            if ($best) { return $best.FullName }
        }
        # Bazı paketler manifestte kaynak anahtarı kullanır. Assets içindeki en uygun gerçek PNG'yi dene.
        $fallback = Get-ChildItem -LiteralPath $Package.InstallLocation -Filter '*.png' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(Square44x44|targetsize-44|AppList|Logo)' -and $_.Name -notmatch '(Splash|Wide|StoreLogo)' } |
            Sort-Object @{ Expression = { if ($_.Name -match 'targetsize-44') { 0 } elseif ($_.Name -match 'Square44x44') { 1 } else { 2 } } }, Length |
            Select-Object -First 1
        if ($fallback) { return $fallback.FullName }
    } catch { }
    return $null
}

function Get-XVVNvidiaControlPanel {
    $candidates = @(
        "$env:ProgramFiles\NVIDIA Corporation\Control Panel Client\nvcplui.exe",
        "${env:ProgramFiles(x86)}\NVIDIA Corporation\Control Panel Client\nvcplui.exe",
        "$env:WINDIR\System32\nvcplui.exe"
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    $appPath = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\nvcplui.exe' -ErrorAction SilentlyContinue
    if ($appPath -and (Test-Path -LiteralPath $appPath.'(default)')) { return $appPath.'(default)' }
    return $null
}

function Get-XVVRemovableApps {
    $protected = @(
        'Microsoft.WindowsStore','Microsoft.DesktopAppInstaller','Microsoft.SecHealthUI',
        'Microsoft.Windows.ShellExperienceHost','Microsoft.Windows.StartMenuExperienceHost',
        'Microsoft.AAD.BrokerPlugin','Microsoft.AccountsControl','Microsoft.LockApp'
    )
    # Yalnızca Başlat menüsünde gerçek bir uygulama girişi bulunan paketleri göster.
    # Bu filtre WinAppRuntime, framework, DLC ve kaynak paketlerini kullanıcı listesinden çıkarır.
    $startAppsByFamily = @{}
    foreach ($startApp in @(Get-StartApps -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($startApp.AppID) -or $startApp.AppID -notlike '*!*') { continue }
        $family = ($startApp.AppID -split '!', 2)[0]
        if (-not $startAppsByFamily.ContainsKey($family)) { $startAppsByFamily[$family] = @() }
        $startAppsByFamily[$family] += $startApp
    }

    Get-AppxPackage -ErrorAction SilentlyContinue |
        Where-Object {
            -not $_.IsFramework -and -not $_.IsResourcePackage -and -not $_.NonRemovable -and
            $_.Name -notin $protected -and $startAppsByFamily.ContainsKey($_.PackageFamilyName)
        } |
        ForEach-Object {
            $launchEntry = @($startAppsByFamily[$_.PackageFamilyName] | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }) | Select-Object -First 1
            $display = if ($launchEntry) { [string]$launchEntry.Name } elseif ($_.Name -match '\.') { ($_.Name -split '\.')[-1] } else { $_.Name }
            $iconPath = Find-XVVAppIcon -Package $_
            [pscustomobject]@{
                DisplayName = $display
                PackageName = $_.Name
                FullName = $_.PackageFullName
                Publisher = $_.PublisherId
                IconPath = $iconPath
                AppId = if ($launchEntry) { [string]$launchEntry.AppID } else { $null }
            }
        } | Sort-Object DisplayName
}

function Remove-XVVApps {
    param([Parameter(Mandatory)][object[]]$Apps)
    $removed = [System.Collections.Generic.List[string]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($app in $Apps) {
        try {
            Remove-AppxPackage -Package $app.FullName -ErrorAction Stop
            $removed.Add($app.DisplayName)
        } catch {
            $errors.Add("$($app.DisplayName): $($_.Exception.Message)")
        }
    }
    [pscustomobject]@{ Removed=$removed; Errors=$errors }
}

Export-ModuleMember -Function *-XVV*
