# ofonogui

This is a very simple Gtk3 GUI written in Perl for the ofono modem manager. It allows the user to
 - make calls
 - receive calls
 - send DTMF tones for menus

This tools intention is that you can use your computer to make calls with your cell-phone. Using the
hands-free profile of Bluetooth you can pair your phone and play audio from your phone. With the
ofonogui you can make and receive calls. You don't need to touch your phone anymore.

Additional information can be found on the project's homepage (German):
https://thinksilicon.de/94/Eine-GUI-fuer-ofono.html

# Setup
Please make sure you have the following Perl packages installed:
 - Gtk3
 - Number::Phone
 - Net::DBus

First edit /etc/pulse/default.pa and find and edit this line:
```
load-module module-bluetooth-discover headset=ofono
```

If you wish to add echo cancelling the following lines can help:
```
.ifexists module-echo-cancel.so
load-module module-echo-cancel aec_method=webrtc source_name=ec_out sink_name=ec_ref
set-default-source ec_out
set-default-sink ec_ref
.endif
```


After that pair your phone via bluetoothctl:
```
pair XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
```

Finally you can run the app to make and receive calls from your computer.
