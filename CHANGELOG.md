## 1.0.6

- Fix: Windows `joinMulticast` failure (errno 10042 / WSAENOPROTOOPT) during mDNS discovery by filtering the network interface list to real, multicast-capable IPv4 adapters.

## 1.0.5

- Fix: QR code rendered as garbled characters in the Windows terminal (switch console code page to UTF-8 / 65001).
- Fix: `adb pair` not found on Windows when run from a global activation (use `runInShell` so the `PATH` resolution finds `adb.exe`).

## 1.0.4

- Fix: Startup on windows is not possible (https://github.com/jkoenig134/adb_wifi/issues/1)

## 1.0.3

- Fix: resolve IPv4 address before running adb pair command.

## 1.0.2

- Update docs, add example.

## 1.0.1

- Remove an unused dependency.

## 1.0.0

- Initial version.
