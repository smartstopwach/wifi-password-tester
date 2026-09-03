# ============================================================================
#  WiFi Password Tester - GUI (Windows) - Modern Aesthetic Edition
#  Ek window me sab kuch: SSID scan, passwords, START button, result.
#
#  NOTE: Is file ko seedha chalane ke liye "WifiTesterApp.bat" use karo
#        (wo is script ko khud bana kar chala deta hai - ek hi file chahiye).
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
$C_BG        = [System.Drawing.Color]::FromArgb(238, 242, 249)   # window background
$C_CARD      = [System.Drawing.Color]::White
$C_HEADER    = [System.Drawing.Color]::FromArgb(29, 78, 216)     # deep blue
$C_HEADER_TX = [System.Drawing.Color]::White
$C_HEADER_SUB= [System.Drawing.Color]::FromArgb(191, 219, 254)
$C_ACCENT    = [System.Drawing.Color]::FromArgb(29, 78, 216)
$C_GRAY      = [System.Drawing.Color]::FromArgb(100, 116, 139)
$C_PRIMARY   = [System.Drawing.Color]::FromArgb(37, 99, 235)     # blue button
$C_SECONDARY = [System.Drawing.Color]::FromArgb(226, 232, 240)
$C_SECOND_TX = [System.Drawing.Color]::FromArgb(30, 41, 59)
$C_GREEN     = [System.Drawing.Color]::FromArgb(22, 163, 74)
$C_RED       = [System.Drawing.Color]::FromArgb(220, 38, 38)
$C_IDLE      = [System.Drawing.Color]::FromArgb(203, 213, 225)
$C_IDLE_TX   = [System.Drawing.Color]::FromArgb(51, 65, 85)
$C_LOG_BG    = [System.Drawing.Color]::FromArgb(248, 250, 252)

$F_TITLE = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$F_STEP  = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$F_BTN   = New-Object System.Drawing.Font("Segoe UI", 12.5, [System.Drawing.FontStyle]::Bold)
$F_BIG   = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$F_CUR   = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)

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
            $script:lblSec.Text = "Security: " + $auth + "   ->   NAYA type (WPA3). Checkbox apne aap ON ho gaya."
            $script:lblSec.ForeColor = $C_GREEN
            $script:chkWpa3.Checked = $true
        } elseif ($auth -match 'WPA2') {
            $script:lblSec.Text = "Security: " + $auth + "   ->   purana type. Aise hi chalega."
            $script:lblSec.ForeColor = $C_GRAY
            $script:chkWpa3.Checked = $false
        } elseif ($auth -match 'WPA') {
            $script:lblSec.Text = "Security: " + $auth + "   ->   bahut purana type."
            $script:lblSec.ForeColor = $C_GRAY
            $script:chkWpa3.Checked = $false
        } else {
            $script:lblSec.Text = "Security: " + $auth + "   ->   OPEN (password nahi lagta)."
            $script:lblSec.ForeColor = $C_RED
        }
    } else {
        $script:lblSec.Text = "Security: pata nahi. Default WPA2 chalega (purana router ho to aise hi chhodo)."
        $script:lblSec.ForeColor = $C_GRAY
    }
}

function Get-SavedPassword {
    # Agar is computer ne pehle ye WiFi use kiya hai, to password Windows me
    # save hota hai. Ye bina disconnect kiye, bina test kiye seedha dikha deta hai.
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

function Add-Log([string]$msg) {
    $script:txtLog.AppendText($msg + "`r`n")
    $script:txtLog.SelectionStart = $script:txtLog.TextLength
    $script:txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Inputs([bool]$enabled) {
    $script:cmbSsid.Enabled   = $enabled
    $script:btnScan.Enabled   = $enabled
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
$frmMain.FormBorderStyle = "FixedSingle"
$frmMain.MaximizeBox = $false
$frmMain.ClientSize = New-Object System.Drawing.Size(640, 732)
$frmMain.BackColor = $C_BG
$frmMain.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# --- Header banner ---
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
$pnlHeader.Size = New-Object System.Drawing.Size(640, 92)
$pnlHeader.BackColor = $C_HEADER

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "WiFi Password Tester"
$lblBrand.Font = $F_TITLE
$lblBrand.ForeColor = $C_HEADER_TX
$lblBrand.Location = New-Object System.Drawing.Point(24, 14)
$lblBrand.Size = New-Object System.Drawing.Size(500, 32)

$lblBrandSub = New-Object System.Windows.Forms.Label
$lblBrandSub.Text = "Apne passwords me se sahi WiFi password dhundho - ek click me"
$lblBrandSub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblBrandSub.ForeColor = $C_HEADER_SUB
$lblBrandSub.Location = New-Object System.Drawing.Point(24, 50)
$lblBrandSub.Size = New-Object System.Drawing.Size(580, 28)

$pnlHeader.Controls.Add($lblBrand)
$pnlHeader.Controls.Add($lblBrandSub)

# --- Card 1: WiFi chuno ---
$pnlWifi = New-Object System.Windows.Forms.Panel
$pnlWifi.Location = New-Object System.Drawing.Point(16, 100)
$pnlWifi.Size = New-Object System.Drawing.Size(608, 160)
$pnlWifi.BackColor = $C_CARD

$lblStep1 = New-Object System.Windows.Forms.Label
$lblStep1.Text = "STEP 1  |  WIFI CHUNO"
$lblStep1.Font = $F_STEP
$lblStep1.ForeColor = $C_ACCENT
$lblStep1.Location = New-Object System.Drawing.Point(14, 10)
$lblStep1.Size = New-Object System.Drawing.Size(580, 20)

$lblSsid = New-Object System.Windows.Forms.Label
$lblSsid.Text = "WiFi ka naam (SSID) - jisko connect karna hai:"
$lblSsid.ForeColor = $C_GRAY
$lblSsid.Location = New-Object System.Drawing.Point(14, 36)
$lblSsid.Size = New-Object System.Drawing.Size(580, 16)

$cmbSsid = New-Object System.Windows.Forms.ComboBox
$cmbSsid.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$cmbSsid.Location = New-Object System.Drawing.Point(14, 58)
$cmbSsid.Size = New-Object System.Drawing.Size(428, 28)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan Networks"
$btnScan.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnScan.FlatAppearance.BorderSize = 0
$btnScan.BackColor = $C_PRIMARY
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnScan.Location = New-Object System.Drawing.Point(452, 58)
$btnScan.Size = New-Object System.Drawing.Size(142, 28)

$lblCurrent = New-Object System.Windows.Forms.Label
$lblCurrent.Font = $F_CUR
$lblCurrent.Location = New-Object System.Drawing.Point(14, 92)
$lblCurrent.Size = New-Object System.Drawing.Size(580, 24)

$btnSaved = New-Object System.Windows.Forms.Button
$btnSaved.Text = "KEY: Saved Password Dikhao (bina disconnect)"
$btnSaved.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSaved.FlatAppearance.BorderSize = 0
$btnSaved.BackColor = [System.Drawing.Color]::FromArgb(250, 204, 21)
$btnSaved.ForeColor = [System.Drawing.Color]::FromArgb(120, 53, 15)
$btnSaved.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnSaved.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSaved.Location = New-Object System.Drawing.Point(14, 122)
$btnSaved.Size = New-Object System.Drawing.Size(580, 30)

$pnlWifi.Controls.Add($lblStep1)
$pnlWifi.Controls.Add($lblSsid)
$pnlWifi.Controls.Add($cmbSsid)
$pnlWifi.Controls.Add($btnScan)
$pnlWifi.Controls.Add($lblCurrent)
$pnlWifi.Controls.Add($btnSaved)

# --- Card 2: Passwords ---
$pnlPass = New-Object System.Windows.Forms.Panel
$pnlPass.Location = New-Object System.Drawing.Point(16, 268)
$pnlPass.Size = New-Object System.Drawing.Size(608, 176)
$pnlPass.BackColor = $C_CARD

$lblStep2 = New-Object System.Windows.Forms.Label
$lblStep2.Text = "STEP 2  |  PASSWORDS LIKHO  (har line me ek)"
$lblStep2.Font = $F_STEP
$lblStep2.ForeColor = $C_ACCENT
$lblStep2.Location = New-Object System.Drawing.Point(14, 10)
$lblStep2.Size = New-Object System.Drawing.Size(580, 20)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Multiline = $true
$txtPass.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtPass.AllowDrop = $true
$txtPass.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtPass.Location = New-Object System.Drawing.Point(14, 32)
$txtPass.Size = New-Object System.Drawing.Size(580, 106)

$btnFile = New-Object System.Windows.Forms.Button
$btnFile.Text = "txt file kholo..."
$btnFile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnFile.FlatAppearance.BorderSize = 0
$btnFile.BackColor = $C_SECONDARY
$btnFile.ForeColor = $C_SECOND_TX
$btnFile.Location = New-Object System.Drawing.Point(14, 144)
$btnFile.Size = New-Object System.Drawing.Size(150, 26)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Saaf karo"
$btnClear.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnClear.FlatAppearance.BorderSize = 0
$btnClear.BackColor = $C_SECONDARY
$btnClear.ForeColor = $C_SECOND_TX
$btnClear.Location = New-Object System.Drawing.Point(172, 144)
$btnClear.Size = New-Object System.Drawing.Size(90, 26)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "ya txt file ko seedha upar drag-drop kar do"
$lblHint.ForeColor = $C_GRAY
$lblHint.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblHint.Location = New-Object System.Drawing.Point(270, 148)
$lblHint.Size = New-Object System.Drawing.Size(320, 20)

$pnlPass.Controls.Add($lblStep2)
$pnlPass.Controls.Add($txtPass)
$pnlPass.Controls.Add($btnFile)
$pnlPass.Controls.Add($btnClear)
$pnlPass.Controls.Add($lblHint)

# --- Card 3: Settings ---
$pnlOpt = New-Object System.Windows.Forms.Panel
$pnlOpt.Location = New-Object System.Drawing.Point(16, 452)
$pnlOpt.Size = New-Object System.Drawing.Size(608, 84)
$pnlOpt.BackColor = $C_CARD

$lblStep3 = New-Object System.Windows.Forms.Label
$lblStep3.Text = "STEP 3  |  SETTINGS"
$lblStep3.Font = $F_STEP
$lblStep3.ForeColor = $C_ACCENT
$lblStep3.Location = New-Object System.Drawing.Point(14, 10)
$lblStep3.Size = New-Object System.Drawing.Size(580, 20)

$lblWait = New-Object System.Windows.Forms.Label
$lblWait.Text = "Wait (sec):"
$lblWait.ForeColor = $C_GRAY
$lblWait.Location = New-Object System.Drawing.Point(14, 38)
$lblWait.Size = New-Object System.Drawing.Size(76, 20)

$numWait = New-Object System.Windows.Forms.NumericUpDown
$numWait.Minimum = 1
$numWait.Maximum = 30
$numWait.Value = 7
$numWait.Location = New-Object System.Drawing.Point(92, 36)
$numWait.Size = New-Object System.Drawing.Size(64, 24)

$chkWpa3 = New-Object System.Windows.Forms.CheckBox
$chkWpa3.Text = "WPA3 (naya router)"
$chkWpa3.Location = New-Object System.Drawing.Point(168, 38)
$chkWpa3.Size = New-Object System.Drawing.Size(170, 24)

$lblSec = New-Object System.Windows.Forms.Label
$lblSec.Text = "Security: pata nahi. Default WPA2 chalega."
$lblSec.ForeColor = $C_GRAY
$lblSec.Location = New-Object System.Drawing.Point(14, 60)
$lblSec.Size = New-Object System.Drawing.Size(580, 20)

$pnlOpt.Controls.Add($lblStep3)
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
$btnStart.Location = New-Object System.Drawing.Point(16, 544)
$btnStart.Size = New-Object System.Drawing.Size(608, 54)

# --- Progress ---
$prgBar = New-Object System.Windows.Forms.ProgressBar
$prgBar.Location = New-Object System.Drawing.Point(16, 606)
$prgBar.Size = New-Object System.Drawing.Size(608, 14)

# --- Result box ---
$pnlResult = New-Object System.Windows.Forms.Panel
$pnlResult.Location = New-Object System.Drawing.Point(16, 628)
$pnlResult.Size = New-Object System.Drawing.Size(608, 46)
$pnlResult.BackColor = $C_IDLE

$lblResult = New-Object System.Windows.Forms.Label
$lblResult.Text = "RESULT YAHAN DIKHEGA"
$lblResult.Font = $F_BIG
$lblResult.ForeColor = $C_IDLE_TX
$lblResult.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblResult.Location = New-Object System.Drawing.Point(0, 0)
$lblResult.Size = New-Object System.Drawing.Size(608, 46)

$pnlResult.Controls.Add($lblResult)

# --- Log ---
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = $C_LOG_BG
$txtLog.ForeColor = $C_SECOND_TX
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.Location = New-Object System.Drawing.Point(16, 682)
$txtLog.Size = New-Object System.Drawing.Size(608, 40)

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
            [System.Windows.Forms.MessageBox]::Show("Saved password mila (bina disconnect kiye):`n`n" + $res.Key + "`n`n(Copy bhi ho gaya - kahin bhi paste kar sakte ho)", "WiFi Password Tester")
            Add-Log ("Saved password: " + $res.Key)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Ye network is computer me saved hai, lekin iska password store nahi hai (OPEN network ho sakta hai).", "WiFi Password Tester")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Is WiFi ka password is computer me saved NAHI hai.`n`nIska matlab: ye computer pehle kabhi is WiFi se connect nahi hua.`nIsliye password pata karne ke liye TEST karna hi padega (jo connect karke check karta hai).", "WiFi Password Tester")
    }
})

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

    Add-Log ("Start: SSID = " + $ssid + ", passwords = " + $pws.Count)

    $found = $null
    $i = 0
    foreach ($pw in $pws) {
        $i++
        $script:prgBar.Value = $i
        Add-Log ("[" + $i + "/" + $pws.Count + "] Try: " + $pw)
        $ok = Test-Password $ssid $pw $auth $wait
        Update-CurrentLabel
        if ($ok) {
            $found = $pw
            Add-Log ("SAHI password: " + $pw + "  ->  abhi connected: " + $ssid)
            break
        } else {
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
        # purane WiFi se wapas connect karo (agar koi tha)
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

$cnt = Scan-Networks
if ($cnt -gt 0) { Add-Log ("Scan: " + $cnt + " networks mile - dropdown se chuno") }
else { Add-Log "Scan: koi network nahi mila - SSID khud type karo" }
Update-SecInfo

$frmMain.Controls.Add($pnlHeader)
$frmMain.Controls.Add($pnlWifi)
$frmMain.Controls.Add($pnlPass)
$frmMain.Controls.Add($pnlOpt)
$frmMain.Controls.Add($btnStart)
$frmMain.Controls.Add($prgBar)
$frmMain.Controls.Add($pnlResult)
$frmMain.Controls.Add($txtLog)

[void]$frmMain.ShowDialog()

}
catch {
    try {
        [System.Windows.Forms.MessageBox]::Show("Kuch galat ho gaya: " + $_.Exception.Message, "WiFi Password Tester")
    } catch { }
}
