ip = tasmota.wifi()["ip"]
qr = lv.qrcode(scr, 200, lv.color(0x000000), lv.color(0xffffff))
qr.set_pos(280, 280)
text = "http://" + ip
qr.update(text, size(text))

qr = lv.qrcode(scr, 200, lv.color(0x000000), lv.color(0xffffff))
qr.set_pos(280, 280)
ssid="ssid"
pass="pass"
wifi_text="WIFI:T:WPA;S:"+ssid+";P:"+pass+";H:;;"
qr.update(wifi_text, size(wifi_text))
