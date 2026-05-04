import 'dart:convert';
import 'dart:io';

import 'package:adb_wifi_plus/generate_qr_code.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:nanoid/nanoid.dart';

/// Run the adb wifi pairing process.
Future<void> run() async {
  // On Windows the default console code page (cp850/cp1252) cannot render the
  // unicode block characters used to draw the QR code, which results in a
  // garbled output that cannot be scanned. Switch the active code page of the
  // current console to UTF-8 (65001) before printing.
  if (Platform.isWindows) {
    try {
      await Process.run('chcp', ['65001'], runInShell: true);
      stdout.encoding = const SystemEncoding();
    } catch (_) {
      // Ignore – we tried our best to enable UTF-8 output.
    }
  }

  final name = 'ADB_WIFI_${nanoid()}';
  final password = nanoid();

  _showQrCode(name: name, password: password);

  final discovered = await _discover();

  final ipv4Address = await _lookupAddress(discovered.address);
  if (ipv4Address == null) return;

  final pairOk = await _runAdbPair(
    address: ipv4Address,
    port: discovered.port,
    password: password,
  );

  print('');
  print('[adb_wifi_plus] Pair step finished (success=$pairOk).');
  print('[adb_wifi_plus] Waiting for device to advertise the connect service '
      '(_adb-tls-connect._tcp.local) ...');

  final connectService = await _discoverConnect().timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      print(
        '[adb_wifi_plus] Timed out waiting for the connect mDNS announcement.\n'
        'Open your phone, go to Developer Options > Wireless debugging, and\n'
        'note the "IP address & Port" shown there, then run:\n'
        '   adb connect <ip>:<port>',
      );
      return (address: '', port: 0);
    },
  );

  if (connectService.port == 0) return;

  print('[adb_wifi_plus] Discovered connect endpoint '
      '${connectService.address}:${connectService.port}');

  final connectIp = await _lookupAddress(connectService.address) ?? ipv4Address;
  await _runAdbConnect(address: connectIp, port: connectService.port);
}

void _showQrCode({required String name, required String password}) {
  final text = 'WIFI:T:ADB;S:$name;P:$password;;';
  final qrCode = generateQrCode(text);
  print(qrCode);
}

Future<({String address, int port})> _discover() async {
  return _discoverService('_adb-tls-pairing._tcp.local');
}

Future<({String address, int port})> _discoverConnect() async {
  return _discoverService('_adb-tls-connect._tcp.local');
}

Future<({String address, int port})> _discoverService(String name) async {
  final client = MDnsClient(
    rawDatagramSocketFactory: (
      dynamic host,
      int port, {
      bool reuseAddress = true,
      bool reusePort = true,
      int ttl = 10000,
    }) =>
        RawDatagramSocket.bind(
      host,
      port,
      reusePort: !Platform.isWindows && reusePort,
      ttl: ttl,
    ),
  );

  // On Windows, `socket.joinMulticast` fails (errno 10042) when the OS lists
  // virtual / loopback / non multicast-capable adapters. Filter the interface
  // list to only the real, multicast-capable IPv4 interfaces.
  Future<Iterable<NetworkInterface>> interfacesFactory(
    InternetAddressType type,
  ) async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: type,
    );
    return interfaces.where(
      (i) => i.addresses.any((a) => a.type == InternetAddressType.IPv4),
    );
  }

  await client.start(
    interfacesFactory: Platform.isWindows ? interfacesFactory : null,
  );

  while (true) {
    final ptrs = client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(name),
    );

    await for (final PtrResourceRecord ptr in ptrs) {
      final srvs = client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      );

      await for (final SrvResourceRecord srv in srvs) {
        client.stop();

        return (address: srv.target, port: srv.port);
      }
    }
  }
}

Future<String?> _lookupAddress(String address) async {
  // IPv4 address doesn't need to be resolved
  final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
  if (ipRegex.hasMatch(address)) return address;

  // IPv6 address doesn't need to be resolved
  final ipv6Regex = RegExp(
    r'^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
  );
  if (ipv6Regex.hasMatch(address)) return address;

  final lookup = await InternetAddress.lookup(address);
  final ipv4 = lookup.where(
    (address) => address.type == InternetAddressType.IPv4,
  );

  if (ipv4.isEmpty) {
    print('Error: Could not resolve address $address');
    return null;
  }

  final ipv4Address = ipv4.first.address;
  return ipv4Address;
}

Future<bool> _runAdbPair({
  required String address,
  required int port,
  required String password,
}) async {
  final process = await Process.start(
    'adb',
    ['pair', '$address:$port', password],
    runInShell: Platform.isWindows,
  );

  // Tee stdout/stderr so the user sees the output AND we can detect success
  // from the text (adb pair may exit with a non-zero code on some setups even
  // when pairing actually succeeded). Buffer raw bytes and decode at the end
  // with a tolerant decoder so partial multi-byte sequences don't throw.
  final stdoutBytes = <int>[];
  final stderrBytes = <int>[];

  final stdoutDone = process.stdout.listen((data) {
    stdout.add(data);
    stdoutBytes.addAll(data);
  }).asFuture<void>();

  final stderrDone = process.stderr.listen((data) {
    stderr.add(data);
    stderrBytes.addAll(data);
  }).asFuture<void>();

  await Future.wait([stdoutDone, stderrDone]);
  await process.exitCode;

  String safeDecode(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  final combined =
      '${safeDecode(stdoutBytes)}\n${safeDecode(stderrBytes)}'.toLowerCase();
  return combined.contains('successfully paired');
}

Future<void> _runAdbConnect({
  required String address,
  required int port,
}) async {
  final process = await Process.start(
    'adb',
    ['connect', '$address:$port'],
    runInShell: Platform.isWindows,
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  await process.exitCode;
}
