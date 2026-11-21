import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional, local-only app lock settings. Not a login: there is no account
/// and no recovery. A forgotten PIN can only be reset by clearing app data.
class LockConfig {
  const LockConfig({
    this.enabled = false,
    this.biometrics = false,
    this.autoLockSeconds = 30,
    this.pinLength = 4,
  });

  final bool enabled;
  final bool biometrics;

  /// Lock after the app has been in the background this long (0 = at once).
  final int autoLockSeconds;

  /// Number of PIN digits (4–6), so the lock screen knows when to verify.
  final int pinLength;

  LockConfig copyWith({bool? enabled, bool? biometrics, int? autoLockSeconds, int? pinLength}) =>
      LockConfig(
        enabled: enabled ?? this.enabled,
        biometrics: biometrics ?? this.biometrics,
        autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
        pinLength: pinLength ?? this.pinLength,
      );
}

/// PBKDF2-HMAC-SHA256 PIN hashing (salted, iterated).
class PinHasher {
  const PinHasher({this.iterations = 20000});
  final int iterations;

  static Uint8List randomSalt([int length = 16]) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }

  Uint8List derive(String pin, Uint8List salt, {int length = 32}) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      final blockBytes = Uint8List(4)..buffer.asByteData().setUint32(0, block);
      var u = hmac.convert([...salt, ...blockBytes]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  String hash(String pin, Uint8List salt) => base64Encode(derive(pin, salt));

  /// Constant-time comparison.
  static bool equals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class AppLockService {
  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? auth, PinHasher? hasher})
      : _storage = storage ?? const FlutterSecureStorage(),
        _auth = auth ?? LocalAuthentication(),
        _hasher = hasher ?? const PinHasher();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;
  final PinHasher _hasher;

  static const _kHash = 'lock.pinHash';
  static const _kSalt = 'lock.pinSalt';
  static const _kIter = 'lock.pinIterations';
  static const _kBio = 'lock.biometrics';
  static const _kAuto = 'lock.autoLockSeconds';
  static const _kLen = 'lock.pinLength';

  /// "iterations:saltB64:hashB64:length" in one key, so changing the PIN is a
  /// single write and can't leave a salt/hash mismatch. Older installs used
  /// the separate keys above; they're still read.
  static const _kPin = 'lock.pin';
  static const _kFailures = 'lock.failures';
  static const _kCooldown = 'lock.cooldownUntil';

  Future<LockConfig> load() async {
    final String? hash;
    try {
      final combined = await _storage.read(key: _kPin);
      hash = (combined != null && combined.isNotEmpty) ? combined : await _storage.read(key: _kHash);
    } catch (_) {
      // Fail closed: if we can't tell whether a PIN is set (e.g. the keystore
      // is broken after an OS update), stay locked rather than open the app.
      return const LockConfig(enabled: true);
    }
    try {
      return LockConfig(
        enabled: hash != null && hash.isNotEmpty,
        biometrics: (await _storage.read(key: _kBio)) == 'true',
        autoLockSeconds: int.tryParse(await _storage.read(key: _kAuto) ?? '') ?? 30,
        pinLength: int.tryParse(await _storage.read(key: _kLen) ?? '') ?? 4,
      );
    } catch (_) {
      // Secondary settings unreadable: keep the lock state, use defaults.
      return LockConfig(enabled: hash != null && hash.isNotEmpty);
    }
  }

  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{4,6}$').hasMatch(pin));
    final salt = PinHasher.randomSalt();
    final hash = await compute(_hashIsolate, (pin, salt, _hasher.iterations));
    // Single atomic write of everything needed to verify.
    await _storage.write(
      key: _kPin,
      value: '${_hasher.iterations}:${base64Encode(salt)}:$hash:${pin.length}',
    );
    await _storage.write(key: _kLen, value: '${pin.length}');
    for (final k in [_kHash, _kSalt, _kIter]) {
      await _storage.delete(key: k);
    }
    await resetFailures();
  }

  Future<bool> verifyPin(String pin) async {
    String? stored;
    String? saltB64;
    int? iterations;
    final combined = await _storage.read(key: _kPin);
    if (combined != null && combined.isNotEmpty) {
      final parts = combined.split(':');
      if (parts.length < 3) return false;
      iterations = int.tryParse(parts[0]);
      saltB64 = parts[1];
      stored = parts[2];
    } else {
      stored = await _storage.read(key: _kHash);
      saltB64 = await _storage.read(key: _kSalt);
      iterations = int.tryParse(await _storage.read(key: _kIter) ?? '');
    }
    if (stored == null || saltB64 == null) return false;
    final hash = await compute(_hashIsolate, (pin, base64Decode(saltB64), iterations ?? _hasher.iterations));
    return PinHasher.equals(hash, stored);
  }

  Future<void> disable() async {
    for (final k in [_kPin, _kHash, _kSalt, _kIter, _kBio, _kLen, _kFailures, _kCooldown]) {
      await _storage.delete(key: k);
    }
  }

  /// Failed attempts and cooldown are persisted so killing the app doesn't
  /// reset the brute-force delay.
  Future<(int failures, DateTime? cooldownUntil)> loadFailures() async {
    try {
      final f = int.tryParse(await _storage.read(key: _kFailures) ?? '') ?? 0;
      final c = int.tryParse(await _storage.read(key: _kCooldown) ?? '');
      return (f, c == null ? null : DateTime.fromMillisecondsSinceEpoch(c));
    } catch (_) {
      return (0, null);
    }
  }

  Future<void> saveFailures(int failures, DateTime? cooldownUntil) async {
    try {
      await _storage.write(key: _kFailures, value: '$failures');
      if (cooldownUntil == null) {
        await _storage.delete(key: _kCooldown);
      } else {
        await _storage.write(key: _kCooldown, value: '${cooldownUntil.millisecondsSinceEpoch}');
      }
    } catch (_) {}
  }

  Future<void> resetFailures() => saveFailures(0, null);

  Future<void> setBiometrics(bool enabled) => _storage.write(key: _kBio, value: '$enabled');

  Future<void> setAutoLockSeconds(int seconds) => _storage.write(key: _kAuto, value: '$seconds');

  Future<bool> biometricsAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

String _hashIsolate((String, Uint8List, int) args) =>
    PinHasher(iterations: args.$3).hash(args.$1, args.$2);
