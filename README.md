# WiFi Password Tester

Ye ek chhota sa tool hai jo aapke **passwords me se sahi WiFi password** khud
try karke bata deta hai — koi guessing nahi, khud test karta hai.

> ⚠️ **Sirf apne khud ke WiFi par use karein** (jiske passwords aapke paas pehle se
> saved hain ya jo aapka apna network hai). Kisi aur ke network par use karna
> galat / illegal ho sakta hai.

---

# 📱 SABSE AASAAN TARIKA — "APP" (ek hi file)

**Sirf `WifiTesterApp.bat` download karo — bas yehi ek file chahiye.**

- Koi folder nahi, koi dusri file nahi, koi Python/PowerShell samajhne ki zaroorat nahi.
- Is par **double-click** karo → ek **window khulegi** (jaise normal app).

### Window me ye sab milega:
| Chiz | Kya kare |
|------|----------|
| **Scan Networks** button | Aas-paas ke saare WiFi ki list le aayega → dropdown me se apna WiFi chuno (typing ki galati nahi hogi) |
| **"Abhi connected" (green)** | SSID box ke neeche **live** dikhta hai ki abhi kaunsa WiFi connected hai — isse sure ho jaoge ki sahi WiFi ka hi test ho raha hai |
| **Security auto-detect** ⭐ | Network chunte hi app **khud pata laga leta hai** ki purana (WPA2) hai ya naya (WPA3) — WPA3 checkbox **apne aap** ON ho jayega, kuch sochna nahi |
| **Passwords box** | Har line me ek password likho, **ya txt file ko seedha us box me drag-drop** karo, ya "txt file kholo" button se chuno |
| **START button** | Dabao → ye khud test karega |
| **Progress + log** | Kaunsa password try ho raha hai, live dikhta hai |
| **Result** | Sahi password **bade green letters** me dikhega |

### Steps:
1. `WifiTesterApp.bat` download karo (koi bhi folder — bas 1 file).
2. Double-click karo.
3. **Scan Networks** dabao → apna WiFi chuno (ya naam likho).
4. Passwords likho / txt file drag-drop karo.
5. **START** dabao → result aa jayega. ✅

> Pehli baar Windows SmartScreen bole to **More info → Run anyway**. Ye isliye
> hota hai kyunki file internet se download hui hai; script me sirf `netsh`
> (Windows ka apna WiFi command) use hota hai, kuch bhi install nahi hota.

> 🛠️ Ye "app" asal me ek .bat file hai jo apne andar chhupa hua code (PowerShell
> GUI) nikaal kar chalati hai. Source code `wifi_tester_gui.ps1` me hai agar
> koi dekhna chahe.

---

## 🪟 WINDOWS — command line wala tarika (bat/ps1, bina Python)

Ye do files download karo aur **dono ek hi folder me** rakho:

| File | Kaam |
|------|------|
| `wifi_pass_test.bat` | **Is par double-click karo** (ya is par txt file drag-drop karo) |
| `wifi_pass_test.ps1` | Asli script (bat ise khud chala deta hai) |

**Steps:**

1. Dono files download karke ek folder me daalo (jaise `Desktop\WifiTool`).
2. `wifi_pass_test.bat` par **double-click** karo.
3. Ye puchhega, bas jawab do:
   - `WiFi ka naam (SSID) dalo:` → jaise `MeraGharWiFi`
   - Phir passwords — **koi bhi ek tarika** (niche dekho) 👇
   - `Naya WPA3 router hai? (y/N)` → purana/normal router hai to bas **Enter**;
     naya router (WPA3) hai to `y` likh kar Enter.
4. Bas — ye ek-ek karke try karega aur **sahi password green me dikha dega**. ✅

> Agar pehli baar blue PowerShell window khule to "Allow" kar dena (ya Windows
> SmartScreen bole to "More info" → "Run anyway").

---

## 📄 Passwords DENE KE 3 TARIKE (smart!)

### Tarika 1 — txt file drag-drop karo (sabse aasaan)
- Ek `.txt` file banao jisme **har line pe ek password** ho (format niche hai).
- Us file ko **seedha `wifi_pass_test.bat` ke upar drag-drop** kar do.
- Bas SSID puchhega, baaki file khud padh lega.

### Tarika 2 — txt file ka path type karo
Tool jab passwords mange, to txt file ka **poora path** likh do, jaise:
```
> C:\Users\AapkaNaam\Desktop\passwords.txt
```

### Tarika 3 — direct passwords likho
Comma se alag karke seedha likh do:
```
> abc123, xyz999, pass@2024, raju123
```

### txt file ka format (aisa banao)

```
# har line me ek password
abc123
xyz999
pass@2024
raju123
MyWifi@2023
```

- `#` se shuru wali line ignore hoti hai (comments).
- Khaali lines ignore hoti hain.
- Ek line me comma se multiple passwords bhi likh sakte ho.
- **Duplicate passwords khud hat jaate hain** — repeat karne ki zaroorat nahi.

> Sample file `passwords_example.txt` bhi di hai — use dekh kar apni file banao.

---

## 🐍 PYTHON WALA TARIKA (Windows / Linux / macOS)

### Kya chahiye (requirement)

- **Python 3** aapke PC/laptop par hona chahiye.
  - Windows: [python.org](https://www.python.org/downloads/) se install karo (install karte waqt "Add Python to PATH" ka checkbox ✔ karna mat bhoolna).
  - Linux: zyada tar pehle se hota hai. Check karo: `python3 --version`
  - macOS: `brew install python3` ya python.org se.
- **Linux par** `nmcli` (NetworkManager) hona chahiye.
- Ye tool aapke **apne computer par** chalega — kyunki WiFi aapke device se hi
  connect hota hai.

---

## Kaise chalayein

### Tarika 1 — command line (recommended)

Terminal / Command Prompt kholo aur type karo:

```
python wifi_pass_test.py "ApnaWifiNaam" pass1 pass2 pass3 pass4
```

Example:
```
python wifi_pass_test.py "MeraGharWiFi" abc123 xyz999 pass@2024 raju123
```

txt file ke saath (Python):
```
python wifi_pass_test.py "MeraGharWiFi" @passwords.txt
# ya
python wifi_pass_test.py "MeraGharWiFi" --file C:\Users\Aap\passwords.txt
```

Ye 4 passwords ek-ek karke try karega aur jo sahi hoga use bata dega.

### Tarika 2 — interactive (bina arguments ke)

```
python wifi_pass_test.py
```

Phir ye khud puchhega:
1. WiFi ka naam (SSID) — type karo, Enter.
2. Passwords — comma se alag karke ek line me likho, Enter.

```
WiFi ka naam (SSID) dalo: MeraGharWiFi
Passwords comma se alag karke dalo
  (jaise: abc123, xyz999, pass@2024): abc123, xyz999, pass@2024
```

---

## Extra options

| Option | Kaam |
|--------|------|
| `--file pass.txt` | Passwords wali txt file ka path do. |
| `@pass.txt` | Shortcut — password wali jagah `@file.txt` likh do. |
| `--wait 10` | connect ke baad kitne second wait kare (default 7). Slow router ho to badha do. |
| `--auth WPA3SAE` | Windows par agar aapka WiFi **WPA3** hai (naya router), to ye lagao. Default WPA2PSK hai. |
| `--dry-run` | Bina connect kiye sirf ye dikhata hai ki kya hoga (testing ke liye). |

---

## Output kaisa dikhta hai

```
========================================================
  WiFi Password Tester  (OS: Windows)
========================================================
SSID        : MeraGharWiFi
Passwords   : 4
--------------------------------------------------------

[1/4] Try ho raha hai: 'abc123'
    ✗ Ye password sahi nahi tha. (abhi connected: koi nahi)

[2/4] Try ho raha hai: 'xyz999'
    ✗ Ye password sahi nahi tha. (abhi connected: koi nahi)

[3/4] Try ho raha hai: 'pass@2024'
    ✓✓ SAHI PASSWORD MIL GAYA:  pass@2024

========================================================
  RESULT: Sahi password =  pass@2024
========================================================
```

---

## OS-wise note

- **Windows**: tool ek temporary profile bana kar connect karta hai. Sahi password
  milne par connection bana rehta hai. Agar aap chahen to WiFi settings me ja kar
  is password se connection save kar lein.
- **Linux**: `nmcli` use hota hai. Agar permission error aaye to `sudo` ke saath try karo.
- **macOS**: `networksetup` use hota hai, kabhi-kabhi admin (sudo) password maang sakta hai.

---

## 🔐 NAYA WIFI vs PURANA WIFI — kya scene hai?

WiFi ka password "lock" system 2 tarah ka hota hai. Router ke hisaab se:

| Type | Kaun | Scene |
|------|------|-------|
| **WPA2** (purana) | 2018 tak ke + zyada tar saste router | Sabse common. 8 character se chhota password bhi chalta hai. |
| **WPA3** (naya) | Naye router (Jio AirFiber, Airtel Xstream, TP-Link new, etc.) | Zyada secure. Naya WiFi connection jo 2020+ me set hua ho. |
| **WPA** (bahut purana) | 2003-2008 wale router | Ab mushkil se milta hai. |

**Aapko kuch sochna nahi padta** — app me **Scan Networks** dabate hi, jab aap apna
WiFi chunte ho, app khud batayega:
- 🟢 `Security: WPA3-Personal -> NAYA type` → checkbox **apne aap ON**
- ⚪ `Security: WPA2-Personal -> purana type` → checkbox **apne aap OFF**

Matlab app khud sahi setting laga deta hai. ✅

> **Tip (agar Scan me nahi dikh raha):** Purana router = WPA2 (checkbox khaali chhodo).
> Naya router (2020+ ya Jio/Airtel fiber) = WPA3 (checkbox tick karo).
> Galat laga diya to sirf result "koi sahi nahi" aayega — dobara dusra try kar lena, koi nuksaan nahi.

---

## Agar koi password sahi nahi mila

- SSID ka spelling check karo (capital/small letters matter karte hain).
- Windows + naya router = WPA3 ho sakta hai → `--auth WPA3SAE` lagao.
- Password me space hai to command line par quotes ke andar likho: `"my pass word"`.
