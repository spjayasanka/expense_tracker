import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/calculator.dart';
import '../l10n.dart';

/// Number pad with + − × ÷ for fast amount entry.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    required this.onSave,
    required this.showEquals,
    this.decimalsAllowed = true,
    this.saveColor,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<CalcOp> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final VoidCallback? onSave;
  final bool showEquals;
  final bool decimalsAllowed;
  final Color? saveColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    Widget key(
      String label, {
      required VoidCallback? onTap,
      String? semantics,
      Color? bg,
      Color? fg,
      IconData? icon,
      Key? k,
      VoidCallback? onLongPress,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Semantics(
            button: true,
            label: semantics ?? label,
            excludeSemantics: true,
            child: Material(
              color: bg ?? scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: k,
                borderRadius: BorderRadius.circular(14),
                onTap: onTap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onTap();
                      },
                onLongPress: onLongPress,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: icon != null
                        ? Icon(icon, color: fg ?? scheme.onSurface)
                        : Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: fg ?? scheme.onSurface),
                            textScaler: TextScaler.linear(
                                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4)),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget digit(String d) => key(d, onTap: () => onDigit(d), k: Key('key-$d'));
    Widget op(CalcOp o, String semantics) => key(
          o.symbol,
          onTap: () => onOperator(o),
          semantics: semantics,
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
          k: Key('key-${o.name}'),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [digit('7'), digit('8'), digit('9'), op(CalcOp.divide, l10n.keyDivide)]),
          Row(children: [digit('4'), digit('5'), digit('6'), op(CalcOp.multiply, l10n.keyMultiply)]),
          Row(children: [digit('1'), digit('2'), digit('3'), op(CalcOp.subtract, l10n.keyMinus)]),
          Row(children: [
            key(
              decimalsAllowed ? '.' : '',
              onTap: decimalsAllowed ? onDecimal : null,
              semantics: l10n.keyDecimal,
              k: const Key('key-dot'),
            ),
            digit('0'),
            key(
              '',
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              onLongPress: onClear,
              semantics: l10n.keyBackspace,
              k: const Key('key-backspace'),
            ),
            op(CalcOp.add, l10n.keyPlus),
          ]),
          Row(children: [
            if (showEquals)
              key('=', onTap: onEquals, semantics: l10n.keyEquals, k: const Key('key-equals')),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const Key('save-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: saveColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onSave,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.save),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
