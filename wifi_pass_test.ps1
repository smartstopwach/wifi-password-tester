# ============================================================================
#  WiFi Password Tester (Windows, PowerShell version)
#  Aapke passwords me se sahi WiFi password dhundhta hai.
#
#  Use (aasaan): double-click "wifi_pass_test.bat"
#   - ya passwords wali .txt file ko .bat ke upar drag-drop kar do!
#
#  Command line:
#      powershell -ExecutionPolicy Bypass -File wifi_pass_test.ps1 "MyWiFi" pass1 pass2 pass3
#      powershell -ExecutionPolicy Bypass -File wifi_pass_test.ps1 "MyWiFi" "C:\folder\pass.txt"
#      powershell -ExecutionPolicy Bypass -File wifi_pass_test.ps1 "MyWiFi" @pass.txt
#
#  NOTE: Sirf apne khud ke WiFi network par use karein.
# ============================================================================

param(
    [string]$Ssid      = "",
    [string[]]$Passwords = @(),
    [string]$PassFile  = "",
    [int]$Wait         = 7,
    [string]$Auth      = "WPA2PSK"
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-CurrentSsid {
    # Abhi kaunsa network connected hai -> SSID lauta hai, warna $null
    $lines = & netsh wlan show interfaces 2>$null
    $ssid  = $null
    $state = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*SSID\s*:\s*(.+)$')   { $ssid  = $Matches[1].Trim() }
        if ($l -match '^\s*State\s*:\s*(.+)$')  { $state = $Matches[1].Trim() }
    }
    if ($state -eq "connected") { return $ssid } else { return $null }
}

function Escape-Xml([string]$s) {
    return [System.Security.SecurityElement]::Escape($s)
}

function Read-PasswordsFromFile {
    # txt file se passwords nikaalta hai.
    #   - har line me ek password (comma/semicolon se multiple bhi chalega)
    #   - khaali lines ignore
    #   - '#' se shuru line = comment, ignore
    param([string]$path)
    $result = @()
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    foreach ($line in $lines) {
        $line = $line.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line -split '[,;]'
        foreach ($p in $parts) {
            $p = $p.Trim()
            if ($p) { $result += $p }
        }
    }
    return $result
}

# ---------------------------------------------------------------------------
# Ek password test karta hai. Sahi hai to $true, warna $false.
# ---------------------------------------------------------------------------
function Test-Password {
    param([string]$ssid, [string]$pw, [string]$auth)

    $pname = "wpt_" + (Get-Random -Minimum 10000 -Maximum 99999)

    $xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$pname</name>
  <SSIDConfig>
    <SSID>
      <name>$(Escape-Xml $ssid)</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>$auth</authentication>
        <encryption>AES</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>$(Escape-Xml $pw)</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
"@

    $path = Join-Path $env:TEMP ("wpt_" + (Get-Random) + ".xml")
    Set-Content -Path $path -Value $xml -Encoding ASCII

    # --- profile add ---
    & netsh wlan add profile filename="$path" user=current | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $path -ErrorAction SilentlyContinue
        return $false
    }

    # --- connect ---
    & netsh wlan connect name="$pname" ssid="$ssid" | Out-Null
    Remove-Item $path -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) {
        & netsh wlan delete profile name="$pname" | Out-Null
        return $false
    }

    # --- wait + verify ---
    Start-Sleep -Seconds $Wait
    $now = Get-CurrentSsid
    if ($now -eq $ssid) {
        # Sahi password! Profile chhod dete hain taaki connection bana rahe.
        return $true
    }

    & netsh wlan delete profile name="$pname" | Out-Null
    return $false
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  WiFi Password Tester  (Windows)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- SMART: drag-drop ya command line me koi file de di ho? ---
if ($Passwords.Count -eq 0 -and -not $PassFile -and $Ssid -and (Test-Path -LiteralPath $Ssid -PathType Leaf)) {
    $PassFile = $Ssid
    $Ssid = ""
}
if ($Passwords.Count -eq 1) {
    $first = $Passwords[0]
    if ($first.StartsWith('@')) {
        $PassFile = $first.Substring(1)
        $Passwords = @()
    } elseif (Test-Path -LiteralPath $first -PathType Leaf) {
        $PassFile = $first
        $Passwords = @()
    }
}

# --- SSID ---
if (-not $Ssid) {
    $Ssid = (Read-Host "WiFi ka naam (SSID) dalo").Trim()
}
if (-not $Ssid) { Write-Host "SSID khaali hai, exit." -ForegroundColor Red; exit 1 }

# --- Passwords (file ya direct) ---
if ($Passwords.Count -eq 0 -and -not $PassFile) {
    Write-Host "Ab passwords do (koi bhi ek tarika):"
    Write-Host "  1) txt file ka path likho,  ya" -ForegroundColor DarkGray
    Write-Host "  2) direct passwords comma se likho (jaise: abc123, xyz999)" -ForegroundColor DarkGray
    $raw = (Read-Host "> ").Trim().Trim('"')
    if ($raw -and (Test-Path -LiteralPath $raw -PathType Leaf)) {
        $PassFile = $raw
    } else {
        $Passwords = ($raw -split '[,;]') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
}

# --- File se load karo ---
if ($PassFile) {
    $loaded = Read-PasswordsFromFile $PassFile
    if ($loaded.Count -eq 0) {
        Write-Host "File me koi password nahi mila (ya file nahi mili): $PassFile" -ForegroundColor Red
        exit 1
    }
    $Passwords = $loaded
    Write-Host ("txt file se " + $Passwords.Count + " passwords load kiye: " + $PassFile) -ForegroundColor Cyan
}

# --- Duplicate hatao, order banao ---
$seen = @{}
$uniq = @()
foreach ($pw in $Passwords) {
    if (-not $seen.ContainsKey($pw)) {
        $seen[$pw] = $true
        $uniq += $pw
    }
}
$Passwords = $uniq

if ($Passwords.Count -eq 0) { Write-Host "Koi password nahi mila, exit." -ForegroundColor Red; exit 1 }

# --- WPA3? ---
if ($Auth -eq "WPA2PSK") {
    $ans = Read-Host "Naya WPA3 router hai? (y/N)"
    if ($ans -match '^(y|Y)') { $Auth = "WPA3SAE" }
}

Write-Host ""
Write-Host ("SSID      : " + $Ssid)
Write-Host ("Passwords : " + $Passwords.Count)
Write-Host ("Auth      : " + $Auth)
$estSec = $Passwords.Count * ($Wait + 4)
Write-Host ("Time (lagbhag): " + $estSec + " second") -ForegroundColor DarkGray
Write-Host "------------------------------------------------------"

$found = $null
$i = 0
foreach ($pw in $Passwords) {
    $i++
    Write-Host ""
    Write-Host ("[" + $i + "/" + $Passwords.Count + "] Try ho raha hai: '" + $pw + "'")

    $ok = Test-Password -ssid $Ssid -pw $pw -auth $Auth

    if ($ok) {
        Write-Host "    SAHI PASSWORD MIL GAYA: " -NoNewline
        Write-Host $pw -ForegroundColor Green
        $found = $pw
        break
    } else {
        $now = Get-CurrentSsid
        if (-not $now) { $now = "koi nahi" }
        Write-Host ("    X Ye password sahi nahi tha. (abhi connected: " + $now + ")") -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
if ($found) {
    Write-Host "  RESULT: Sahi password = " -NoNewline
    Write-Host $found -ForegroundColor Green
} else {
    Write-Host "  RESULT: Koi bhi password sahi nahi nikla." -ForegroundColor Red
    Write-Host "  Check karo: SSID spelling, ya WPA3 hai to dobara chala kar 'y' dabao."
}
Write-Host "======================================================" -ForegroundColor Cyan
