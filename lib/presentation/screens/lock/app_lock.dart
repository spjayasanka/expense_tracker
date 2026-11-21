import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/app_lock_service.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';

class LockState {
  const LockState({this.config = const LockConfig(), this.locked = false, this.loaded = false});
  final LockConfig config;
  final bool locked;
  final bool loaded;

  LockState copyWith({LockConfig? config, bool? locked, bool? loaded}) => LockState(
        config: config ?? this.config,
        locked: locked ?? this.locked,
        loaded: loaded ?? this.loaded,
      );
}

class LockController extends Notifier<LockState> {
  DateTime? _backgroundedAt;
  DateTime? _suppressUntil;

  /// Call before opening a system screen (file picker, save dialog) so that
  /// returning from it does not lock the app. Expires after a minute so a
  /// stale flag can't skip a genuine lock later.
  void suppressNextLock() => _suppressUntil = DateTime.now().add(const Duration(seconds: 60));

  @override
  LockState build() {
    _load(initial: true);
    return const LockState();
  }

  AppLockService get _service => ref.read(appLockServiceProvider);

  Future<void> _load({bool initial = false}) async {
    final config = await _service.load();
    state = state.copyWith(
      config: config,
      loaded: true,
      locked: initial ? config.enabled : state.locked && config.enabled,
    );
  }

  Future<void> reload() => _load();

  void unlock() => state = state.copyWith(locked: false);

  void onBackground() {
    _backgroundedAt ??= DateTime.now();
    // "Immediately": lock before the OS takes the app-switcher snapshot, so
    // balances aren't visible there or on the first frame back. Skipped when
    // a system picker we opened is the reason for going to the background.
    final suppressed = _suppressUntil != null && DateTime.now().isBefore(_suppressUntil!);
    if (state.config.enabled && state.config.autoLockSeconds == 0 && !suppressed && !state.locked) {
      state = state.copyWith(locked: true);
    }
  }

  void onForeground() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    final suppressUntil = _suppressUntil;
    _suppressUntil = null;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) return;
    if (!state.config.enabled || since == null) return;
    if (DateTime.now().difference(since).inSeconds >= state.config.autoLockSeconds) {
      state = state.copyWith(locked: true);
    }
  }

  Future<void> enableWithPin(String pin) async {
    await _service.setPin(pin);
    await _load();
  }

  Future<void> disable() async {
    await _service.disable();
    await _load();
  }

  Future<void> setBiometrics(bool v) async {
    await _service.setBiometrics(v);
    await _load();
  }

  Future<void> setAutoLock(int seconds) async {
    await _service.setAutoLockSeconds(seconds);
    await _load();
  }
}

final lockProvider = NotifierProvider<LockController, LockState>(LockController.new);

/// Shows the lock screen above the app when locked; tracks background time.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final c = ref.read(lockProvider.notifier);
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) c.onBackground();
    if (s == AppLifecycleState.resumed) c.onForeground();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    if (!lock.loaded) return const ColoredBox(color: Colors.black);
    return Stack(
      children: [
        // Keep the app mounted underneath so state survives locking.
        ExcludeSemantics(excluding: lock.locked, child: widget.child),
        // Own Overlay so tooltips on the PIN pad work above the Navigator.
        if (lock.locked)
          Positioned.fill(
            child: Overlay(initialEntries: [OverlayEntry(builder: (_) => const LockScreen())]),
          ),
      ],
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  int _failures = 0;
  DateTime? _cooldownUntil;
  bool _checking = false;
  bool _showForgot = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _restoreFailures();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _restoreFailures() async {
    final (failures, until) = await ref.read(appLockServiceProvider).loadFailures();
    if (!mounted) return;
    setState(() {
      _failures = failures;
      _cooldownUntil = until;
    });
    if (_coolingDown) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_coolingDown) t.cancel();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    final config = ref.read(lockProvider).config;
    if (!config.biometrics || !mounted) return;
    final ok = await ref.read(appLockServiceProvider).authenticateWithBiometrics(context.l10n.unlockReason);
    if (ok) ref.read(lockProvider.notifier).unlock();
  }

  bool get _coolingDown => _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  Future<void> _digit(String d) async {
    if (_checking || _coolingDown) return;
    final len = ref.read(lockProvider).config.pinLength;
    if (_pin.length >= len) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == len) {
      setState(() => _checking = true);
      bool ok;
      try {
        ok = await ref.read(appLockServiceProvider).verifyPin(_pin);
      } catch (_) {
        ok = false;
      }
      if (!mounted) return;
      final service = ref.read(appLockServiceProvider);
      if (ok) {
        await service.resetFailures();
        ref.read(lockProvider.notifier).unlock();
      } else {
        HapticFeedback.heavyImpact();
        _failures++;
        setState(() {
          _pin = '';
          _error = context.l10n.wrongPin;
          if (_failures % 5 == 0) {
            _cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
            _startTick();
          }
        });
        await service.saveFailures(_failures, _cooldownUntil);
      }
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final config = ref.watch(lockProvider).config;
    final remaining = _coolingDown ? _cooldownUntil!.difference(DateTime.now()).inSeconds + 1 : 0;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(l10n.enterPin, style: theme.textTheme.titleLarge),
                const SizedBox(height: 20),
                PinDots(length: config.pinLength, filled: _pin.length),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      _coolingDown ? l10n.tryAgainIn(remaining) : (_error ?? ''),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                PinPad(
                  onDigit: _digit,
                  onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
                  extra: config.biometrics
                      ? IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.fingerprint),
                          tooltip: l10n.useBiometrics,
                          onPressed: _tryBiometrics,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                // The lock screen sits above the Navigator (MaterialApp.builder),
                // so dialogs can't be shown here; reveal the help inline.
                TextButton(
                  onPressed: () => setState(() => _showForgot = !_showForgot),
                  child: Text(l10n.forgotPin),
                ),
                if (_showForgot)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.forgotPinMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled});
  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.pinProgress(filled, length),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? scheme.primary : Colors.transparent,
                border: Border.all(color: scheme.primary, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.extra});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget key(String d) => SizedBox(
          width: 80,
          height: 72,
          child: TextButton(
            key: Key('pin-$d'),
            style: TextButton.styleFrom(shape: const CircleBorder()),
            onPressed: () => onDigit(d),
            child: Text(d, style: Theme.of(context).textTheme.headlineSmall),
          ),
        );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisSize: MainAxisSize.min, children: row.map(key).toList()),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 80, height: 72, child: Center(child: extra)),
            key('0'),
            SizedBox(
              width: 80,
              height: 72,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                tooltip: l10n.keyBackspace,
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks for a new PIN twice. Returns the PIN or null if cancelled.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  String? _error;

  void _digit(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _next() {
    final l10n = context.l10n;
    if (_pin.length < 4) {
      setState(() => _error = l10n.pinTooShort);
      return;
    }
    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
    } else if (_pin == _first) {
      Navigator.pop(context, _pin);
    } else {
      setState(() {
        _error = l10n.pinMismatch;
        _pin = '';
        _first = '';
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setPin)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_confirming ? l10n.confirmPin : l10n.chooseNewPin, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l10n.pinRules, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                PinDots(length: _pin.length < 4 ? 4 : (_pin.length == 6 ? 6 : _pin.length + 1), filled: _pin.length),
                SizedBox(
                  height: 32,
                  child: Center(child: Text(_error ?? '', style: TextStyle(color: theme.colorScheme.error))),
                ),
                PinPad(
                  onDigit: _digit,
                  onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
                ),
                const SizedBox(height: 16),
                FilledButton(key: const Key('pin-next'), onPressed: _next, child: Text(_confirming ? l10n.confirm : l10n.next)),
                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.pinWarning, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the current PIN before sensitive lock changes (turning the lock
/// off, changing the PIN), so someone holding the unlocked phone can't simply
/// disable it. Shares the persisted failure counter/cooldown with the lock
/// screen. Returns true when the PIN was entered correctly.
Future<bool> confirmCurrentPin(BuildContext context, WidgetRef ref) async {
  final service = ref.read(appLockServiceProvider);
  final l10n = context.l10n;
  var (failures, cooldownUntil) = await service.loadFailures();
  if (!context.mounted) return false;
  final controller = TextEditingController();
  String? error;
  var checking = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> submit() async {
          if (checking) return;
          final now = DateTime.now();
          if (cooldownUntil != null && now.isBefore(cooldownUntil!)) {
            setState(() => error = l10n.tryAgainIn(cooldownUntil!.difference(now).inSeconds + 1));
            return;
          }
          setState(() => checking = true);
          bool ok;
          try {
            ok = await service.verifyPin(controller.text);
          } catch (_) {
            ok = false;
          }
          if (ok) {
            await service.resetFailures();
            if (ctx.mounted) Navigator.pop(ctx, true);
            return;
          }
          failures++;
          if (failures % 5 == 0) cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
          await service.saveFailures(failures, cooldownUntil);
          controller.clear();
          if (ctx.mounted) {
            setState(() {
              checking = false;
              error = l10n.wrongPin;
            });
          }
        }

        return AlertDialog(
          title: Text(l10n.enterPin),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(errorText: error, counterText: ''),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            TextButton(onPressed: checking ? null : submit, child: Text(l10n.ok)),
          ],
        );
      },
    ),
  );
  // Not disposed here: the TextField may still be animating out. It's
  // garbage-collected with the dialog.
  return result ?? false;
}
