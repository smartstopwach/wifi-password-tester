#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wifi_qr_decoder.html me jsQR library inject karta hai (gallery se QR padhne ke liye).
Input: wifi_qr_decoder.html (placeholder /*__JSQR_CODE__*/ ke saath)
Output: wifi_qr_decoder.html (jsQR inlined)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
HTML = os.path.join(HERE, "wifi_qr_decoder.html")
JSQR = os.path.join(HERE, "jsqr.min.js")
PLACEHOLDER = "/*__JSQR_CODE__*/"

with open(JSQR, "r", encoding="utf-8") as f:
    jsqr = f.read()

with open(HTML, "r", encoding="utf-8") as f:
    html = f.read()

if PLACEHOLDER not in html:
    print("WARNING: placeholder nahi mila - already injected?")
else:
    html = html.replace(PLACEHOLDER, jsqr)
    with open(HTML, "w", encoding="utf-8") as f:
        f.write(html)
    print("Injected jsQR (%d bytes) -> wifi_qr_decoder.html (%d bytes total)" % (len(jsqr), len(html)))
