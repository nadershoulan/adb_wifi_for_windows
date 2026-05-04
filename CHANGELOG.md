## 1.0.0

First release of `adb_wifi_plus`, a Windows-friendly fork of
[`adb_wifi`](https://pub.dev/packages/adb_wifi) by jkoenig134.

- Feat: Automatic `adb connect` step after a successful pair, by discovering
  the `_adb-tls-connect._tcp.local` mDNS service.
- Feat: Robust pair-success detection from command output (does not rely on
  `adb pair`'s exit code, which is unreliable on Windows).
- Feat: 60-second timeout on connect-service discovery with a clear manual
  fallback message.
- Fix: QR code rendered as garbled characters in the Windows terminal
  (switch console code page to UTF-8 / 65001).
- Fix: `adb pair` not found on Windows when run from a global activation
  (use `runInShell` so `PATH` resolution finds `adb.exe`).
- Fix: Windows `joinMulticast` failure (errno 10042 / WSAENOPROTOOPT) during
  mDNS discovery by filtering the network interface list to real,
  multicast-capable IPv4 adapters.
- Fix: Resolve IPv4 address before running `adb pair`.

---

History of the upstream `adb_wifi` package this fork is based on:



## 1.0.3

- Fix: resolve IPv4 address before running adb pair command.

## 1.0.2

- Update docs, add example.

## 1.0.1

- Remove an unused dependency.

## 1.0.0

- Initial version.
