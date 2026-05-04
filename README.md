# adb_wifi_plus

[![pub package](https://img.shields.io/pub/v/adb_wifi_plus.svg)](https://pub.dev/packages/adb_wifi_plus)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

A Windows-friendly CLI for attaching `adb` over Wi-Fi using a QR code.

This is a fork of [`adb_wifi`](https://pub.dev/packages/adb_wifi) by
jkoenig134 with the following additions:

- **Windows compatibility fixes** for QR code rendering (switches the console
  code page to UTF-8 / 65001) and for `multicast_dns` (`socket.joinMulticast`
  errno 10042 caused by virtual / loopback adapters).
- An **automatic `adb connect` step** after pairing, so you no longer have to
  copy the IP/port from the phone manually. The tool discovers the
  `_adb-tls-connect._tcp.local` mDNS service and runs
  `adb connect <ip>:<port>` for you.
- Robust pair-success detection (does not rely solely on `adb pair`'s exit
  code, which is unreliable on Windows).
- A 60-second timeout on connect-service discovery with a clear fallback
  message that tells you exactly what to do manually.

## Requirements

- Dart SDK
- `adb` available on your `PATH` (Android Platform Tools).
- A phone with **Wireless debugging** enabled (Developer options).
- The phone and the PC must be on the **same Wi-Fi network**, and the network
  must allow mDNS / multicast traffic between clients (many guest / "AP
  isolation" networks block this).

## Install

```powershell
dart pub global activate adb_wifi_plus
```

Make sure `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) or `$HOME/.pub-cache/bin`
(macOS/Linux) is on your `PATH`.

## Usage

```powershell
adb_wifi_plus
```

A QR code is displayed in the terminal:

1. On your phone open **Settings → Developer options → Wireless debugging →
   Pair device with QR code**.
2. Scan the QR code shown in the terminal.
3. The tool prints `Successfully paired to <ip>:<port>`.
4. The tool then auto-discovers the connect endpoint and prints
   `connected to <ip>:<port>`.

Expected output:

```text
[QR code]
Successfully paired to 192.168.1.42:41015 [guid=adb-XXXXXXXX-XXXXXX]

[adb_wifi_plus] Pair step finished (success=true).
[adb_wifi_plus] Waiting for device to advertise the connect service ...
[adb_wifi_plus] Discovered connect endpoint 192.168.1.42:41923
connected to 192.168.1.42:41923
```

## Troubleshooting

### "Timed out waiting for the connect mDNS announcement"

mDNS for `_adb-tls-connect._tcp.local` did not reach the PC within 60 s.
Common causes:

- **AP / client isolation** is enabled on your Wi-Fi (very common on guest
  networks and many ISP routers). Switch to a network that allows
  client-to-client traffic, or use a hotspot.
- **Windows Firewall** is blocking inbound UDP port 5353 for `dart.exe` /
  `adb_wifi_plus.exe`. Allow it through the firewall (Private network).
- The phone closed the Wireless-debugging screen too early — keep it open
  until the connect step succeeds.

In all cases you can fall back to the manual flow: open the phone's
**Wireless debugging** screen, read the **IP address & Port**, and run:

```powershell
adb connect <ip>:<port>
```

### QR code looks garbled in the terminal

This fork already switches the active code page to UTF-8 (`chcp 65001`) on
Windows. If you still see garbled output, use a modern terminal that supports
UTF-8 block characters (Windows Terminal, PowerShell 7+, or the integrated
terminal in VS Code).

### `adb` is not recognized

Install the Android Platform Tools and add the install directory to your
`PATH`. Verify with:

```powershell
adb version
```

## Shoutout

This package is heavily inspired by the npm CLI
[adb-wifi](https://www.npmjs.com/package/adb-wifi). The goal is to provide a
similar experience for Dart and Flutter developers without switching
ecosystems.
