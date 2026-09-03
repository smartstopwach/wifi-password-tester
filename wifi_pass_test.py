#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WiFi Password Tester
====================
Aapke 3-4 passwords me se SAHI WiFi password kaunsa hai — yeh tool khud
check karke bata deta hai. Windows, Linux (nmcli) aur macOS — teeno par chalta hai.

Usage (command line):
    python wifi_pass_test.py "MeraWiFi" pass1 pass2 pass3 pass4
    python wifi_pass_test.py "MeraWiFi" pass1 pass2 pass3 --wait 10

Interactive (bina arguments ke):
    python wifi_pass_test.py

NOTE: Sirf apne khud ke WiFi network par use karein.
"""

import argparse
import platform
import random
import re
import subprocess
import sys
import tempfile
import time
import os
from xml.sax.saxutils import escape

# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------

def run(cmd, timeout=25):
    """Run a shell command, return (returncode, stdout, stderr)."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or ""), (p.stderr or "")
    except subprocess.TimeoutExpired:
        return -1, "", "command timed out"
    except FileNotFoundError as e:
        return -1, "", "command not found: " + str(e)


def wait_seconds(n):
    """Countdown wait so the user sees what is happening."""
    for i in range(n, 0, -1):
        sys.stdout.write("\r    waiting %2ds ... " % i)
        sys.stdout.flush()
        time.sleep(1)
    sys.stdout.write("\r" + " " * 22 + "\r")
    sys.stdout.flush()


def load_passwords_from_file(path):
    """txt file se passwords nikaalta hai.
    - har line me ek password (comma/semicolon se multiple bhi chalega)
    - khaali lines ignore
    - '#' se shuru line = comment, ignore
    """
    pws = []
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                for part in re.split(r"[,;]", line):
                    part = part.strip()
                    if part:
                        pws.append(part)
    except OSError as e:
        print("File padh nahi paya: %s" % e)
        return []
    return pws


def dedupe(items):
    """Duplicate hatao, order banao."""
    seen = set()
    out = []
    for it in items:
        if it not in seen:
            seen.add(it)
            out.append(it)
    return out


OS = platform.system()          # "Windows" | "Linux" | "Darwin"
IS_WINDOWS = OS == "Windows"
IS_MACOS = OS == "Darwin"
IS_LINUX = OS == "Linux"


# ----------------------------------------------------------------------------
# "Abhi kaunsa network connected hai?"  -> returns SSID or None
# ----------------------------------------------------------------------------

def current_ssid():
    if IS_WINDOWS:
        rc, out, _ = run(["netsh", "wlan", "show", "interfaces"])
        ssid_m = re.search(r"^\s*SSID\s*:\s*(.+)$", out, re.MULTILINE)
        state_m = re.search(r"^\s*State\s*:\s*(.+)$", out, re.MULTILINE)
        if ssid_m and state_m and state_m.group(1).strip().lower() == "connected":
            return ssid_m.group(1).strip()
        return None

    if IS_LINUX:
        rc, out, _ = run(["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi"])
        for line in out.splitlines():
            parts = line.split(":", 1)
            if len(parts) == 2 and parts[0].strip().lower() == "yes":
                return parts[1].strip()
        return None

    if IS_MACOS:
        dev = macos_wifi_device()
        rc, out, _ = run(["networksetup", "-getairportnetwork", dev])
        m = re.search(r"Current Wi-Fi Network:\s*(.+)", out)
        if m and m.group(1).strip().lower() != "off":
            return m.group(1).strip()
        return None

    return None


def macos_wifi_device():
    """Find the Wi-Fi hardware device name on macOS (usually en0)."""
    rc, out, _ = run(["networksetup", "-listallhardwareports"])
    lines = out.splitlines()
    for i, line in enumerate(lines):
        if "Wi-Fi" in line:
            for j in range(i + 1, min(i + 5, len(lines))):
                if lines[j].strip().startswith("Device:"):
                    return lines[j].split("Device:", 1)[1].strip()
    return "en0"


# ----------------------------------------------------------------------------
# Connect functions (per OS). Each returns (ok: bool, message: str)
# ----------------------------------------------------------------------------

WLAN_XML = """<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>{pname}</name>
  <SSIDConfig>
    <SSID>
      <name>{ssid}</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>{auth}</authentication>
        <encryption>{enc}</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>{password}</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
"""


def windows_connect(ssid, password, auth="WPA2PSK", enc="AES"):
    """Add a temporary profile and try to connect. Returns (ok, msg, profile_name)."""
    pname = "wpt_" + str(random.randint(10000, 99999))
    xml = WLAN_XML.format(
        pname=escape(pname), ssid=escape(ssid),
        password=escape(password), auth=escape(auth), enc=escape(enc),
    )
    fd, path = tempfile.mkstemp(suffix=".xml")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(xml)

    try:
        rc, out, err = run(["netsh", "wlan", "add", "profile",
                            'filename="%s"' % path, "user=current"])
        if rc != 0:
            return False, "profile add fail: " + (err or out).strip(), pname
        rc, out, err = run(["netsh", "wlan", "connect",
                            "name=%s" % pname, 'ssid="%s"' % ssid])
        if rc != 0:
            return False, "connect fail: " + (err or out).strip(), pname
        return True, "connect command chal gaya, check ho raha hai...", pname
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def windows_delete_profile(pname):
    run(["netsh", "wlan", "delete", "profile", 'name="%s"' % pname])


def linux_connect(ssid, password):
    rc, out, err = run(["nmcli", "device", "wifi", "connect", ssid,
                        "password", password])
    if rc == 0:
        return True, "connect command chal gaya, check ho raha hai..."
    msg = (err or out).strip()
    if "nmcli" in (msg.lower()):
        msg += "\n    (Lagta hai nmcli install nahi hai. Ubuntu/Debian: sudo apt install network-manager)"
    return False, msg


def macos_connect(ssid, password, dev):
    rc, out, err = run(["networksetup", "-setairportnetwork", dev, ssid, password])
    if rc == 0:
        return True, "connect command chal gaya, check ho raha hai..."
    return False, (err or out).strip()


# ----------------------------------------------------------------------------
# Main flow
# ----------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="3-4 passwords me se sahi WiFi password dhundhta hai.")
    ap.add_argument("ssid", nargs="?", help="WiFi ka naam (SSID)")
    ap.add_argument("passwords", nargs="*", help="Test karne wale passwords")
    ap.add_argument("--file", help="Passwords wali txt file ka path")
    ap.add_argument("--wait", type=int, default=7,
                    help="connect ke baad kitne second wait karein (default 7)")
    ap.add_argument("--auth", default="WPA2PSK",
                    help="Windows par auth type (WPA2PSK / WPA3SAE / WPAPSK), default WPA2PSK")
    ap.add_argument("--dry-run", action="store_true",
                    help="Bina connect kiye sirf process dikhata hai")
    args = ap.parse_args()

    print("=" * 56)
    print("  WiFi Password Tester  (OS: %s)" % OS)
    print("=" * 56)

    # --- SSID ---
    ssid = args.ssid
    # SMART: agar pehla argument koi file hai (drag-drop / path) to use pass-file maano
    if ssid and not args.file and not args.passwords and os.path.isfile(ssid):
        args.file = ssid
        ssid = ""
    if not ssid:
        ssid = input("WiFi ka naam (SSID) dalo: ").strip()
    if not ssid:
        print("SSID khaali hai, exit.")
        sys.exit(1)

    # --- Passwords ---
    passwords = args.passwords
    passfile = args.file
    # SMART: single positional argument jo @file ya existing file hai
    if not passfile and len(passwords) == 1:
        p = passwords[0]
        if p.startswith("@"):
            passfile = p[1:]
            passwords = []
        elif os.path.isfile(p):
            passfile = p
            passwords = []
    if passfile:
        loaded = load_passwords_from_file(passfile)
        if not loaded:
            print("File se koi password nahi mila: %s" % passfile)
            sys.exit(1)
        passwords = loaded
        print("txt file se %d passwords load kiye: %s" % (len(passwords), passfile))
    if not passwords:
        raw = input("Passwords txt file ka path dalo, ya direct passwords comma se alag karke:\n  (jaise: abc123, xyz999) -> ")
        raw = raw.strip().strip('"')
        if raw and os.path.isfile(raw):
            passwords = load_passwords_from_file(raw)
        else:
            passwords = [p.strip() for p in raw.split(",") if p.strip()]
    passwords = dedupe(passwords)
    if not passwords:
        print("Koi password nahi mila, exit.")
        sys.exit(1)

    # Already connected?
    cur = None if args.dry_run else current_ssid()
    if cur == ssid:
        print("Pehle se '%s' se connected ho." % ssid)
        print("Phir bhi test karna hai to aage badhte hain...")
    elif cur:
        print("Abhi connected ho: '%s'" % cur)

    print()
    print("SSID        : %s" % ssid)
    print("Passwords   : %d" % len(passwords))
    if not args.dry_run:
        print("Time (lagbhag): ~%d second" % (len(passwords) * (args.wait + 3)))
    print("-" * 56)

    found = None
    for i, pw in enumerate(passwords, 1):
        print("\n[%d/%d] Try ho raha hai: %r" % (i, len(passwords), pw))

        if args.dry_run:
            print("    (dry-run) yahan '%s' connect hota..." % ssid)
            continue

        # ---- connect ----
        if IS_WINDOWS:
            ok, msg, pname = windows_connect(ssid, pw, auth=args.auth)
        elif IS_LINUX:
            ok, msg = linux_connect(ssid, pw)
            pname = None
        elif IS_MACOS:
            dev = macos_wifi_device()
            ok, msg = macos_connect(ssid, pw, dev)
            pname = None
        else:
            print("    Ye OS (%s) support nahi karta." % OS)
            sys.exit(1)

        if not ok:
            print("    ✗ Connect fail: %s" % msg)
            if pname:
                windows_delete_profile(pname)
            continue

        # ---- wait + verify ----
        wait_seconds(args.wait)
        now = current_ssid()
        if now == ssid:
            print("    ✓✓ SAHI PASSWORD MIL GAYA:  %s" % pw)
            found = pw
            # Success par temporary profile ko chhod dete hain taaki
            # connection bana rahe (Windows).
            break
        else:
            print("    ✗ Ye password sahi nahi tha. (abhi connected: %s)" % (now or "koi nahi"))
            if pname:
                windows_delete_profile(pname)

    # ---- Result ----
    print()
    print("=" * 56)
    if args.dry_run:
        print("  (Dry-run khatam — koi real connect nahi hua.)")
    elif found:
        print("  RESULT: Sahi password =  %s" % found)
    else:
        print("  RESULT: Koi bhi password sahi nahi nikla.")
        print("  Check karo: SSID spelling, ya security type")
        print("  (Windows WPA3 hai to --auth WPA3SAE try karo).")
    print("=" * 56)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nRuk gaya. Bye!")
