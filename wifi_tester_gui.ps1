# ============================================================================
#  WiFi Password Tester - GUI (Windows) - Fit Edition
#  FIX: chhoti screen par window lambi ho jati thi aur scroll nahi hota tha.
#  1) Window screen ke hisaab se khud chhoti hoti hai (auto-fit)
#  2) Maximize button ON - full screen karne par sab dikhega
#  3) Content scrollable panel me hai - mouse wheel se scroll hota hai
#  4) Compact layout - kam jagah me sab kuch
#
#  NOTE: Is file ko seedha chalane ke liye "WifiTesterApp.bat" use karo.
#        Sirf apne khud ke WiFi par use karein.
# ============================================================================

try {

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

$script:authMap = @{}

# ---------------------------------------------------------------------------
# Colors (theme)
# ---------------------------------------------------------------------------
$C_BG        = [System.Drawing.Color]::FromArgb(238, 242, 249)
$C_CARD      = [System.Drawing.Color]::White
$C_HEADER    = [System.Drawing.Color]::FromArgb(29, 78, 216)
$C_HEADER_TX = [System.Drawing.Color]::White
$C_HEADER_SUB= [System.Drawing.Color]::FromArgb(191, 219, 254)
$C_ACCENT    = [System.Drawing.Color]::FromArgb(29, 78, 216)
$C_GRAY      = [System.Drawing.Color]::FromArgb(100, 116, 139)
$C_PRIMARY   = [System.Drawing.Color]::FromArgb(37, 99, 235)
$C_SECONDARY = [System.Drawing.Color]::FromArgb(226, 232, 240)
$C_SECOND_TX = [System.Drawing.Color]::FromArgb(30, 41, 59)
$C_GREEN     = [System.Drawing.Color]::FromArgb(22, 163, 74)
$C_RED       = [System.Drawing.Color]::FromArgb(220, 38, 38)
$C_AMBER     = [System.Drawing.Color]::FromArgb(217, 119, 6)
$C_IDLE      = [System.Drawing.Color]::FromArgb(203, 213, 225)
$C_IDLE_TX   = [System.Drawing.Color]::FromArgb(51, 65, 85)
$C_LOG_BG    = [System.Drawing.Color]::FromArgb(248, 250, 252)

$F_TITLE  = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$F_STEP   = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$F_BTN    = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$F_BIG    = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$F_CUR    = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$F_STATUS = New-Object System.Drawing.Font("Segoe UI", 11.5, [System.Drawing.FontStyle]::Bold)

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Get-CurrentSsid {
    $lines = & netsh wlan show interfaces 2>$null
    $ssid = $null
    $state = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*SSID\s*:\s*(.+)$')   { $ssid  = $Matches[1].Trim() }
        if ($l -match '^\s*State\s*:\s*(.+)$')  { $state = $Matches[1].Trim() }
    }
    if ($state -eq "connected") { return $ssid }
    return $null
}

function Update-CurrentLabel {
    $cur = Get-CurrentSsid
    if ($cur) {
        $script:lblCurrent.Text = "O  Abhi connected: " + $cur
        $script:lblCurrent.ForeColor = $C_GREEN
    } else {
        $script:lblCurrent.Text = "X  Abhi connected: koi nahi (WiFi off hai?)"
        $script:lblCurrent.ForeColor = $C_RED
    }
}

function Escape-Xml([string]$s) {
    return [System.Security.SecurityElement]::Escape($s)
}

function Parse-Passwords([string]$text) {
    $result = @()
    $seen = @{}
    foreach ($line in ($text -split "[\r\n]+")) {
        $line = $line.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        foreach ($p in ($line -split '[,;]')) {
            $p = $p.Trim()
            if ($p -and -not $seen.ContainsKey($p)) {
                $seen[$p] = $true
                $result += $p
            }
        }
    }
    return $result
}

function Update-PwCount {
    $pws = Parse-Passwords $script:txtPass.Text
    if ($pws.Count -gt 0) {
        $script:lblStep2.Text = "STEP 2  |  PASSWORDS  (" + $pws.Count + " ready)"
        $script:lblStep2.ForeColor = $C_GREEN
    } else {
        $script:lblStep2.Text = "STEP 2  |  PASSWORDS LIKHO (har line me ek)"
        $script:lblStep2.ForeColor = $C_ACCENT
    }
}

function Test-Password {
    param([string]$ssid, [string]$pw, [string]$auth, [int]$wait)

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

    & netsh wlan add profile filename="$path" user=current | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $path -ErrorAction SilentlyContinue
        return $false
    }

    & netsh wlan connect name="$pname" ssid="$ssid" | Out-Null
    Remove-Item $path -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) {
        & netsh wlan delete profile name="$pname" | Out-Null
        return $false
    }

    Start-Sleep -Seconds $wait
    $now = Get-CurrentSsid
    if ($now -eq $ssid) { return $true }

    & netsh wlan delete profile name="$pname" | Out-Null
    return $false
}

function Get-SavedPassword {
    param([string]$ssid)
    $out = & netsh wlan show profile name="$ssid" key=clear 2>$null
    $key = $null
    $found = $false
    foreach ($l in $out) {
        if ($l -match '^\s*Key Content\s*:\s*(.+)$') { $key = $Matches[1].Trim(); $found = $true }
        if ($l -match 'Security key\s*:') { $found = $true }
    }
    if ($found) { return @{ Found = $true;  Key = $key } }
    return @{ Found = $false; Key = $null }
}

function Show-AllSavedPasswords {
    $out = & netsh wlan show profiles 2>$null
    $names = @()
    foreach ($l in $out) {
        if ($l -match ':\s*(.+)$') {
            $n = $Matches[1].Trim()
            if ($n -and $n -notin $names) { $names += $n }
        }
    }
    if ($names.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Is computer par koi WiFi profile saved nahi hai.", "WiFi Password Tester")
        return
    }
    $lines = @()
    $lines += "Is computer par ye sab WiFi SAVE hain (aur inke passwords):"
    $lines += ""
    foreach ($n in $names) {
        $r = Get-SavedPassword $n
        if ($r.Found) {
            if ($r.Key) { $lines += ($n + "  ->  " + $r.Key) }
            else { $lines += ($n + "  ->  (OPEN - password nahi lagta)") }
        } else {
            $lines += ($n + "  ->  (password nahi mila)")
        }
    }
    $text = $lines -join "`r`n"
    [System.Windows.Forms.Clipboard]::SetText($text)

    $f = New-Object System.Windows.Forms.Form
    $f.Text = "Saare Saved WiFi Passwords"
    $f.StartPosition = "CenterScreen"
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $f.ClientSize = New-Object System.Drawing.Size(560, 400)
    $f.MinimumSize = New-Object System.Drawing.Size(400, 300)
    $f.BackColor = $C_CARD
    $f.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $tb.Font = New-Object System.Drawing.Font("Consolas", 10)
    $tb.Text = $text
    $tb.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tb.Height = 340

    $pnlBtns = New-Object System.Windows.Forms.Panel
    $pnlBtns.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $pnlBtns.Height = 44

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "Copy karo"
    $btnCopy.Location = New-Object System.Drawing.Point(10, 8)
    $btnCopy.Size = New-Object System.Drawing.Size(150, 28)
    $btnCopy.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($tb.Text) })

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Band karo"
    $btnClose.Location = New-Object System.Drawing.Point(430, 8)
    $btnClose.Size = New-Object System.Drawing.Size(120, 28)
    $btnClose.Add_Click({ $f.Close() })

    $pnlBtns.Controls.Add($btnCopy)
    $pnlBtns.Controls.Add($btnClose)

    $f.Controls.Add($tb)
    $f.Controls.Add($pnlBtns)
    [void]$f.ShowDialog()
    Add-Log ("Saare saved passwords dikhaye (" + $names.Count + " networks)")
}

function Scan-Networks {
    $script:cmbSsid.Items.Clear()
    $script:authMap = @{}
    $seen = @{}
    $current = ""
    $lines = & netsh wlan show networks mode=bssid 2>$null
    foreach ($l in $lines) {
        if ($l -match 'SSID\s+\d+\s*:\s*(.+)$') {
            $current = $Matches[1].Trim()
            if ($current -and -not $seen.ContainsKey($current)) {
                $seen[$current] = $true
                [void]$script:cmbSsid.Items.Add($current)
            }
        } elseif ($l -match '^\s*Authentication\s*:\s*(.+)$' -and $current) {
            if (-not $script:authMap.ContainsKey($current)) {
                $script:authMap[$current] = $Matches[1].Trim()
            }
        }
    }
    return $script:cmbSsid.Items.Count
}

function Update-SecInfo {
    $name = $script:cmbSsid.Text.Trim()
    if ($name -and $script:authMap.ContainsKey($name)) {
        $auth = $script:authMap[$name]
        if ($auth -match 'WPA3') {
            $script:lblSec.Text = "Security: " + $auth + "  ->  NAYA type (WPA3). Checkbox apne aap ON ho gaya."
            $script:lblSec.ForeColor = $C_GREEN
            $script:chkWpa3.Checked = $true
        } elseif ($auth -match 'WPA2') {
            $script:lblSec.Text = "Security: " + $auth + "  ->  purana type. Aise hi chalega."
            $script:lblSec.ForeColor = $C_GRAY
            $script:chkWpa3.Checked = $false
        } elseif ($auth -match 'WPA') {
            $script:lblSec.Text = "Security: " + $auth + "  ->  bahut purana type."
            $script:lblSec.ForeColor = $C_GRAY
            $script:chkWpa3.Checked = $false
        } else {
            $script:lblSec.Text = "Security: " + $auth + "  ->  OPEN (password nahi lagta)."
            $script:lblSec.ForeColor = $C_RED
        }
    } else {
        $script:lblSec.Text = "Security: pata nahi. Default WPA2 chalega."
        $script:lblSec.ForeColor = $C_GRAY
    }
}

function Add-Log([string]$msg) {
    $script:txtLog.AppendText($msg + "`r`n")
    $script:txtLog.SelectionStart = $script:txtLog.TextLength
    $script:txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Inputs([bool]$enabled) {
    $script:cmbSsid.Enabled   = $enabled
    $script:btnScan.Enabled   = $enabled
    $script:btnSaved.Enabled  = $enabled
    $script:btnAll.Enabled    = $enabled
    $script:txtPass.Enabled   = $enabled
    $script:btnFile.Enabled   = $enabled
    $script:btnClear.Enabled  = $enabled
    $script:numWait.Enabled   = $enabled
    $script:chkWpa3.Enabled   = $enabled
}

# ---------------------------------------------------------------------------
# Build the form
# ---------------------------------------------------------------------------

$frmMain = New-Object System.Windows.Forms.Form
$frmMain.Text = "WiFi Password Tester"
$frmMain.StartPosition = "CenterScreen"
$frmMain.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$frmMain.MaximizeBox = $true
$frmMain.MinimizeBox = $true
$frmMain.MinimumSize = New-Object System.Drawing.Size(600, 430)

# --- Auto-fit: screen se badi window kabhi nahi ---
$scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$winH = [Math]::Min(560, $scr.Height - 70)
if ($winH -lt 430) { $winH = 430 }
$frmMain.ClientSize = New-Object System.Drawing.Size(620, $winH)
$frmMain.BackColor = $C_BG
$frmMain.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# --- Header (fixed, dock top) ---
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$pnlHeader.Height = 52
$pnlHeader.BackColor = $C_HEADER

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "WiFi Password Tester"
$lblBrand.Font = $F_TITLE
$lblBrand.ForeColor = $C_HEADER_TX
$lblBrand.Location = New-Object System.Drawing.Point(20, 6)
$lblBrand.Size = New-Object System.Drawing.Size(580, 22)

$lblBrandSub = New-Object System.Windows.Forms.Label
$lblBrandSub.Text = "Apne passwords me se sahi WiFi password dhundho"
$lblBrandSub.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblBrandSub.ForeColor = $C_HEADER_SUB
$lblBrandSub.Location = New-Object System.Drawing.Point(20, 30)
$lblBrandSub.Size = New-Object System.Drawing.Size(580, 18)

$pnlHeader.Controls.Add($lblBrand)
$pnlHeader.Controls.Add($lblBrandSub)

# --- Scrollable content panel (mouse wheel se scroll hoga) ---
$pnlScroll = New-Object System.Windows.Forms.Panel
$pnlScroll.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlScroll.AutoScroll = $true
$pnlScroll.BackColor = $C_BG

# --- Card 1: WiFi chuno ---
$pnlWifi = New-Object System.Windows.Forms.Panel
$pnlWifi.Location = New-Object System.Drawing.Point(12, 8)
$pnlWifi.Size = New-Object System.Drawing.Size(584, 100)
$pnlWifi.BackColor = $C_CARD

$lblStep1 = New-Object System.Windows.Forms.Label
$lblStep1.Text = "STEP 1  |  WIFI CHUNO"
$lblStep1.Font = $F_STEP
$lblStep1.ForeColor = $C_ACCENT
$lblStep1.Location = New-Object System.Drawing.Point(10, 4)
$lblStep1.Size = New-Object System.Drawing.Size(564, 16)

$cmbSsid = New-Object System.Windows.Forms.ComboBox
$cmbSsid.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$cmbSsid.Location = New-Object System.Drawing.Point(10, 22)
$cmbSsid.Size = New-Object System.Drawing.Size(424, 24)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan Networks"
$btnScan.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnScan.FlatAppearance.BorderSize = 0
$btnScan.BackColor = $C_PRIMARY
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$btnScan.Location = New-Object System.Drawing.Point(442, 22)
$btnScan.Size = New-Object System.Drawing.Size(132, 24)

$lblCurrent = New-Object System.Windows.Forms.Label
$lblCurrent.Font = $F_CUR
$lblCurrent.Location = New-Object System.Drawing.Point(10, 50)
$lblCurrent.Size = New-Object System.Drawing.Size(564, 18)

$btnSaved = New-Object System.Windows.Forms.Button
$btnSaved.Text = "Saved Password Dikhao"
$btnSaved.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaved.FlatAppearance.BorderSize = 0
$btnSaved.BackColor = [System.Drawing.Color]::FromArgb(250, 204, 21)
$btnSaved.ForeColor = [System.Drawing.Color]::FromArgb(120, 53, 15)
$btnSaved.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$btnSaved.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSaved.Location = New-Object System.Drawing.Point(10, 72)
$btnSaved.Size = New-Object System.Drawing.Size(276, 22)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "Saare Saved Passwords"
$btnAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnAll.FlatAppearance.BorderSize = 0
$btnAll.BackColor = [System.Drawing.Color]::FromArgb(253, 224, 71)
$btnAll.ForeColor = [System.Drawing.Color]::FromArgb(120, 53, 15)
$btnAll.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$btnAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnAll.Location = New-Object System.Drawing.Point(294, 72)
$btnAll.Size = New-Object System.Drawing.Size(280, 22)

$pnlWifi.Controls.Add($lblStep1)
$pnlWifi.Controls.Add($cmbSsid)
$pnlWifi.Controls.Add($btnScan)
$pnlWifi.Controls.Add($lblCurrent)
$pnlWifi.Controls.Add($btnSaved)
$pnlWifi.Controls.Add($btnAll)

# --- Card 2: Passwords ---
$pnlPass = New-Object System.Windows.Forms.Panel
$pnlPass.Location = New-Object System.Drawing.Point(12, 114)
$pnlPass.Size = New-Object System.Drawing.Size(584, 118)
$pnlPass.BackColor = $C_CARD

$lblStep2 = New-Object System.Windows.Forms.Label
$lblStep2.Text = "STEP 2  |  PASSWORDS LIKHO (har line me ek)"
$lblStep2.Font = $F_STEP
$lblStep2.ForeColor = $C_ACCENT
$lblStep2.Location = New-Object System.Drawing.Point(10, 4)
$lblStep2.Size = New-Object System.Drawing.Size(564, 16)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Multiline = $true
$txtPass.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtPass.AllowDrop = $true
$txtPass.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtPass.Location = New-Object System.Drawing.Point(10, 22)
$txtPass.Size = New-Object System.Drawing.Size(564, 64)

$btnFile = New-Object System.Windows.Forms.Button
$btnFile.Text = "txt file kholo"
$btnFile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnFile.FlatAppearance.BorderSize = 0
$btnFile.BackColor = $C_SECONDARY
$btnFile.ForeColor = $C_SECOND_TX
$btnFile.Location = New-Object System.Drawing.Point(10, 92)
$btnFile.Size = New-Object System.Drawing.Size(110, 20)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Saaf karo"
$btnClear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnClear.FlatAppearance.BorderSize = 0
$btnClear.BackColor = $C_SECONDARY
$btnClear.ForeColor = $C_SECOND_TX
$btnClear.Location = New-Object System.Drawing.Point(126, 92)
$btnClear.Size = New-Object System.Drawing.Size(76, 20)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "ya txt file ko seedha upar drag-drop kar do"
$lblHint.ForeColor = $C_GRAY
$lblHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblHint.Location = New-Object System.Drawing.Point(208, 94)
$lblHint.Size = New-Object System.Drawing.Size(366, 16)

$pnlPass.Controls.Add($lblStep2)
$pnlPass.Controls.Add($txtPass)
$pnlPass.Controls.Add($btnFile)
$pnlPass.Controls.Add($btnClear)
$pnlPass.Controls.Add($lblHint)

# --- Card 3: Settings ---
$pnlOpt = New-Object System.Windows.Forms.Panel
$pnlOpt.Location = New-Object System.Drawing.Point(12, 238)
$pnlOpt.Size = New-Object System.Drawing.Size(584, 48)
$pnlOpt.BackColor = $C_CARD

$lblWait = New-Object System.Windows.Forms.Label
$lblWait.Text = "Wait (sec):"
$lblWait.ForeColor = $C_GRAY
$lblWait.Location = New-Object System.Drawing.Point(10, 8)
$lblWait.Size = New-Object System.Drawing.Size(66, 18)

$numWait = New-Object System.Windows.Forms.NumericUpDown
$numWait.Minimum = 1
$numWait.Maximum = 30
$numWait.Value = 7
$numWait.Location = New-Object System.Drawing.Point(78, 6)
$numWait.Size = New-Object System.Drawing.Size(58, 22)

$chkWpa3 = New-Object System.Windows.Forms.CheckBox
$chkWpa3.Text = "WPA3 (naya router)"
$chkWpa3.Location = New-Object System.Drawing.Point(146, 8)
$chkWpa3.Size = New-Object System.Drawing.Size(150, 20)

$lblSec = New-Object System.Windows.Forms.Label
$lblSec.Text = "Security: pata nahi. Default WPA2 chalega."
$lblSec.ForeColor = $C_GRAY
$lblSec.Location = New-Object System.Drawing.Point(10, 28)
$lblSec.Size = New-Object System.Drawing.Size(564, 16)

$pnlOpt.Controls.Add($lblWait)
$pnlOpt.Controls.Add($numWait)
$pnlOpt.Controls.Add($chkWpa3)
$pnlOpt.Controls.Add($lblSec)

# --- START button ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "START  -  SAHI PASSWORD DHUNDHO"
$btnStart.Font = $F_BTN
$btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.BackColor = $C_GREEN
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnStart.Location = New-Object System.Drawing.Point(12, 292)
$btnStart.Size = New-Object System.Drawing.Size(584, 40)

# --- Progress ---
$prgBar = New-Object System.Windows.Forms.ProgressBar
$prgBar.Location = New-Object System.Drawing.Point(12, 338)
$prgBar.Size = New-Object System.Drawing.Size(584, 10)

# --- STATUS (bada) ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Tayyar hai. Password likho aur START dabao."
$lblStatus.Font = $F_STATUS
$lblStatus.ForeColor = $C_ACCENT
$lblStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblStatus.Location = New-Object System.Drawing.Point(12, 352)
$lblStatus.Size = New-Object System.Drawing.Size(584, 26)

# --- Log ---
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = $C_LOG_BG
$txtLog.ForeColor = $C_SECOND_TX
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.Location = New-Object System.Drawing.Point(12, 382)
$txtLog.Size = New-Object System.Drawing.Size(584, 42)

# --- Result box ---
$pnlResult = New-Object System.Windows.Forms.Panel
$pnlResult.Location = New-Object System.Drawing.Point(12, 430)
$pnlResult.Size = New-Object System.Drawing.Size(584, 44)
$pnlResult.BackColor = $C_IDLE

$lblResult = New-Object System.Windows.Forms.Label
$lblResult.Text = "RESULT YAHAN DIKHEGA"
$lblResult.Font = $F_BIG
$lblResult.ForeColor = $C_IDLE_TX
$lblResult.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblResult.Location = New-Object System.Drawing.Point(0, 0)
$lblResult.Size = New-Object System.Drawing.Size(584, 44)

$pnlResult.Controls.Add($lblResult)

# --- sab content scroll panel me ---
$pnlScroll.Controls.Add($pnlWifi)
$pnlScroll.Controls.Add($pnlPass)
$pnlScroll.Controls.Add($pnlOpt)
$pnlScroll.Controls.Add($btnStart)
$pnlScroll.Controls.Add($prgBar)
$pnlScroll.Controls.Add($lblStatus)
$pnlScroll.Controls.Add($txtLog)
$pnlScroll.Controls.Add($pnlResult)

# --- form par header + scroll ---
$frmMain.Controls.Add($pnlScroll)
$frmMain.Controls.Add($pnlHeader)

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

$btnScan.Add_Click({
    $cnt = Scan-Networks
    if ($cnt -gt 0) { Add-Log ("Scan: " + $cnt + " networks mile") }
    else { Add-Log "Scan: koi network nahi mila - SSID khud likho" }
    Update-CurrentLabel
    Update-SecInfo
})

$cmbSsid.Add_SelectedIndexChanged({ Update-SecInfo })
$cmbSsid.Add_TextChanged({ Update-SecInfo })

$txtPass.Add_TextChanged({ Update-PwCount })

$btnSaved.Add_Click({
    $name = $script:cmbSsid.Text.Trim()
    if (-not $name) {
        [System.Windows.Forms.MessageBox]::Show("Pehle WiFi ka naam (SSID) likho ya Scan se chuno.", "WiFi Password Tester")
        return
    }
    $res = Get-SavedPassword $name
    if ($res.Found) {
        if ($res.Key) {
            [System.Windows.Forms.Clipboard]::SetText($res.Key)
            [System.Windows.Forms.MessageBox]::Show("Saved password mila (bina disconnect kiye):`n`n" + $res.Key + "`n`n(Copy bhi ho gaya)", "WiFi Password Tester")
            Add-Log ("Saved password: " + $res.Key)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ye network saved hai, lekin password store nahi hai (OPEN network ho sakta hai).", "WiFi Password Tester")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Is WiFi ka password is computer me saved NAHI hai.`nIska matlab: ye computer pehle kabhi is WiFi se connect nahi hua.`nPassword pata karne ke liye TEST karna hoga.", "WiFi Password Tester")
    }
})

$btnAll.Add_Click({ Show-AllSavedPasswords })

$btnFile.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $dlg.Title = "Passwords wali txt file chuno"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:txtPass.Text = [System.IO.File]::ReadAllText($dlg.FileName)
        Add-Log ("File load ki: " + $dlg.FileName)
    }
})

$btnClear.Add_Click({ $script:txtPass.Clear() })

$txtPass.Add_DragEnter({
    if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    }
})

$txtPass.Add_DragDrop({
    $files = $_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($files -and $files.Length -gt 0) {
        $script:txtPass.Text = [System.IO.File]::ReadAllText($files[0])
        Add-Log ("File load ki: " + $files[0])
    }
})

$btnStart.Add_Click({
    $ssid = $script:cmbSsid.Text.Trim()
    if (-not $ssid) {
        [System.Windows.Forms.MessageBox]::Show("Pehle WiFi ka naam (SSID) likho, ya Scan dabao.", "WiFi Password Tester")
        return
    }

    $pws = Parse-Passwords $script:txtPass.Text
    if ($pws.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Koi password nahi likha. Pehle passwords likho ya txt file kholo.", "WiFi Password Tester")
        return
    }

    $auth = "WPA2PSK"
    if ($script:chkWpa3.Checked) { $auth = "WPA3SAE" }
    $wait = [int]$script:numWait.Value

    $origSsid = Get-CurrentSsid

    Set-Inputs $false
    $script:btnStart.Enabled = $false
    $script:btnStart.Text = "CHAL RAHA HAI..."
    $script:prgBar.Maximum = $pws.Count
    $script:prgBar.Value = 0
    $script:pnlResult.BackColor = $C_IDLE
    $script:lblResult.ForeColor = $C_IDLE_TX
    $script:lblResult.Text = "CHECK HO RAHA HAI..."
    $script:lblStatus.ForeColor = $C_AMBER
    $script:lblStatus.Text = "Shuru... (" + $pws.Count + " passwords hain)"

    Add-Log ("Start: SSID = " + $ssid + ", passwords = " + $pws.Count)

    $found = $null
    $i = 0
    foreach ($pw in $pws) {
        $i++
        $script:prgBar.Value = $i
        $script:lblStatus.Text = "[" + $i + "/" + $pws.Count + "] Try ho raha hai: " + $pw
        Add-Log ("[" + $i + "/" + $pws.Count + "] Try: " + $pw)
        $ok = Test-Password $ssid $pw $auth $wait
        Update-CurrentLabel
        if ($ok) {
            $found = $pw
            $script:lblStatus.ForeColor = $C_GREEN
            $script:lblStatus.Text = "SAHI MIL GAYA: " + $pw + "  (" + $i + "/" + $pws.Count + ")"
            Add-Log ("SAHI password: " + $pw + "  ->  abhi connected: " + $ssid)
            break
        } else {
            $script:lblStatus.ForeColor = $C_RED
            $script:lblStatus.Text = "[" + $i + "/" + $pws.Count + "] Galat: " + $pw
            Add-Log ("X  galat: " + $pw)
        }
    }

    if ($found) {
        $script:pnlResult.BackColor = $C_GREEN
        $script:lblResult.ForeColor = [System.Drawing.Color]::White
        $script:lblResult.Text = "SAHI PASSWORD:  " + $found
    } else {
        $script:pnlResult.BackColor = $C_RED
        $script:lblResult.ForeColor = [System.Drawing.Color]::White
        $script:lblResult.Text = "KOI BHI PASSWORD SAHI NAHI MILA"
        $script:lblStatus.ForeColor = $C_RED
        $script:lblStatus.Text = "Koi bhi password sahi nahi tha. List check karo."
        if ($origSsid -and $origSsid -ne $ssid) {
            Add-Log ("Wapas connect ho rahe hain: " + $origSsid)
            & netsh wlan connect name="$origSsid" | Out-Null
            Start-Sleep -Seconds 3
            Update-CurrentLabel
            Add-Log ("Wapas connect ho gaye: " + $origSsid)
        }
    }

    Set-Inputs $true
    $script:btnStart.Enabled = $true
    $script:btnStart.Text = "START  -  SAHI PASSWORD DHUNDHO"
})

# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

Update-CurrentLabel
Update-PwCount

$cnt = Scan-Networks
if ($cnt -gt 0) { Add-Log ("Scan: " + $cnt + " networks mile - dropdown se chuno") }
else { Add-Log "Scan: koi network nahi mila - SSID khud type karo" }
Update-SecInfo

[void]$frmMain.ShowDialog()

}
catch {
    try {
        [System.Windows.Forms.MessageBox]::Show("Kuch galat ho gaya: " + $_.Exception.Message, "WiFi Password Tester")
    } catch { }
}
