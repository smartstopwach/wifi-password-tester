# ============================================================================
#  WiFi Password Tester - GUI version (Windows)
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
    $seen = @{}
    $lines = & netsh wlan show networks mode=bssid 2>$null
    foreach ($l in $lines) {
        if ($l -match 'SSID\s+\d+\s*:\s*(.+)$') {
            $s = $Matches[1].Trim()
            if ($s -and -not $seen.ContainsKey($s)) {
                $seen[$s] = $true
                [void]$script:cmbSsid.Items.Add($s)
            }
        }
    }
    return $script:cmbSsid.Items.Count
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
$frmMain.ClientSize = New-Object System.Drawing.Size(620, 622)
$frmMain.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# --- Title ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "WiFi Password Tester"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(30, 90, 180)
$lblTitle.Location = New-Object System.Drawing.Point(15, 12)
$lblTitle.Size = New-Object System.Drawing.Size(590, 32)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Apne passwords me se sahi WiFi password dhundho - ek click me"
$lblSub.ForeColor = [System.Drawing.Color]::Gray
$lblSub.Location = New-Object System.Drawing.Point(15, 46)
$lblSub.Size = New-Object System.Drawing.Size(590, 20)

# --- SSID row ---
$lblSsid = New-Object System.Windows.Forms.Label
$lblSsid.Text = "WiFi ka naam (SSID):"
$lblSsid.Location = New-Object System.Drawing.Point(15, 74)
$lblSsid.Size = New-Object System.Drawing.Size(590, 18)

$cmbSsid = New-Object System.Windows.Forms.ComboBox
$cmbSsid.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$cmbSsid.Location = New-Object System.Drawing.Point(15, 96)
$cmbSsid.Size = New-Object System.Drawing.Size(470, 28)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan Networks"
$btnScan.Location = New-Object System.Drawing.Point(495, 96)
$btnScan.Size = New-Object System.Drawing.Size(110, 28)

$lblCurrent = New-Object System.Windows.Forms.Label
$lblCurrent.ForeColor = [System.Drawing.Color]::Gray
$lblCurrent.Location = New-Object System.Drawing.Point(15, 128)
$lblCurrent.Size = New-Object System.Drawing.Size(590, 18)

# --- Passwords ---
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "Passwords (har line me ek) - ya txt file yahan drag-drop karo:"
$lblPass.Location = New-Object System.Drawing.Point(15, 152)
$lblPass.Size = New-Object System.Drawing.Size(590, 18)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Multiline = $true
$txtPass.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtPass.AllowDrop = $true
$txtPass.Location = New-Object System.Drawing.Point(15, 174)
$txtPass.Size = New-Object System.Drawing.Size(590, 160)

$btnFile = New-Object System.Windows.Forms.Button
$btnFile.Text = "txt file kholo..."
$btnFile.Location = New-Object System.Drawing.Point(15, 340)
$btnFile.Size = New-Object System.Drawing.Size(150, 30)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Saaf karo"
$btnClear.Location = New-Object System.Drawing.Point(175, 340)
$btnClear.Size = New-Object System.Drawing.Size(90, 30)

# --- Options ---
$lblWait = New-Object System.Windows.Forms.Label
$lblWait.Text = "Wait (sec):"
$lblWait.Location = New-Object System.Drawing.Point(15, 382)
$lblWait.Size = New-Object System.Drawing.Size(80, 20)

$numWait = New-Object System.Windows.Forms.NumericUpDown
$numWait.Minimum = 1
$numWait.Maximum = 30
$numWait.Value = 7
$numWait.Location = New-Object System.Drawing.Point(90, 378)
$numWait.Size = New-Object System.Drawing.Size(60, 26)

$chkWpa3 = New-Object System.Windows.Forms.CheckBox
$chkWpa3.Text = "WPA3 (naya router)"
$chkWpa3.Location = New-Object System.Drawing.Point(170, 380)
$chkWpa3.Size = New-Object System.Drawing.Size(180, 24)

# --- START ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "START - Sahi Password Dhundho"
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(40, 150, 80)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Location = New-Object System.Drawing.Point(15, 414)
$btnStart.Size = New-Object System.Drawing.Size(590, 52)

$prgBar = New-Object System.Windows.Forms.ProgressBar
$prgBar.Location = New-Object System.Drawing.Point(15, 476)
$prgBar.Size = New-Object System.Drawing.Size(590, 16)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.BackColor = [System.Drawing.Color]::White
$txtLog.Location = New-Object System.Drawing.Point(15, 498)
$txtLog.Size = New-Object System.Drawing.Size(590, 70)

$lblResult = New-Object System.Windows.Forms.Label
$lblResult.Text = ""
$lblResult.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblResult.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblResult.Location = New-Object System.Drawing.Point(15, 574)
$lblResult.Size = New-Object System.Drawing.Size(590, 30)

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

$btnScan.Add_Click({
    $cnt = Scan-Networks
    if ($cnt -gt 0) { Add-Log ("Scan: " + $cnt + " networks mile") }
    else { Add-Log "Scan: koi network nahi mila - SSID khud likho" }
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

    Set-Inputs $false
    $script:btnStart.Enabled = $false
    $script:prgBar.Maximum = $pws.Count
    $script:prgBar.Value = 0
    $script:lblResult.Text = "Check ho raha hai..."
    $script:lblResult.ForeColor = [System.Drawing.Color]::Black

    Add-Log ("Start: SSID = " + $ssid + ", passwords = " + $pws.Count)

    $found = $null
    $i = 0
    foreach ($pw in $pws) {
        $i++
        $script:prgBar.Value = $i
        Add-Log ("[" + $i + "/" + $pws.Count + "] Try: " + $pw)
        $ok = Test-Password $ssid $pw $auth $wait
        if ($ok) {
            $found = $pw
            Add-Log ("SAHI password: " + $pw)
            break
        } else {
            Add-Log ("X galat: " + $pw)
        }
    }

    if ($found) {
        $script:lblResult.Text = "SAHI PASSWORD: " + $found
        $script:lblResult.ForeColor = [System.Drawing.Color]::Green
    } else {
        $script:lblResult.Text = "Koi bhi password sahi nahi mila."
        $script:lblResult.ForeColor = [System.Drawing.Color]::Red
    }

    Set-Inputs $true
    $script:btnStart.Enabled = $true
})

# ---------------------------------------------------------------------------
# Startup: auto-scan + show current connection
# ---------------------------------------------------------------------------

$cur = Get-CurrentSsid
if ($cur) { $lblCurrent.Text = "Abhi connected: " + $cur } else { $lblCurrent.Text = "Abhi connected: koi nahi" }

$cnt = Scan-Networks
if ($cnt -gt 0) { Add-Log ("Scan: " + $cnt + " networks mile - dropdown se chuno") }
else { Add-Log "Scan: koi network nahi mila - SSID khud type karo" }

$frmMain.Controls.AddRange(@(
    $lblTitle, $lblSub,
    $lblSsid, $cmbSsid, $btnScan, $lblCurrent,
    $lblPass, $txtPass, $btnFile, $btnClear,
    $lblWait, $numWait, $chkWpa3,
    $btnStart, $prgBar, $txtLog, $lblResult
))

[void]$frmMain.ShowDialog()

}
catch {
    try {
        [System.Windows.Forms.MessageBox]::Show("Kuch galat ho gaya: " + $_.Exception.Message, "WiFi Password Tester")
    } catch { }
}
