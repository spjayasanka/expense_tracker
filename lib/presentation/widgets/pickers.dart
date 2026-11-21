import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_library.dart';
import '../../core/money/currencies.dart';
import '../../domain/entities/entities.dart';
import '../l10n.dart';
import '../providers/providers.dart';
import 'common.dart';
import 'formatters.dart';

/// Bottom sheet listing accounts with balances.
Future<Account?> pickAccount(
  BuildContext context, {
  int? selectedId,
  int? excludeId,
  String? title,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _AccountPickerSheet(selectedId: selectedId, excludeId: excludeId, title: title),
  );
}

class _AccountPickerSheet extends ConsumerWidget {
  const _AccountPickerSheet({this.selectedId, this.excludeId, this.title});
  final int? selectedId;
  final int? excludeId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref
        .watch(balancesProvider)
        .where((b) => !b.account.isArchived && b.account.id != excludeId)
        .toList();
    final fmt = ref.fmt(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title ?? context.l10n.chooseAccount,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in balances)
                    ListTile(
                      leading: ColorIcon(icon: b.account.icon, color: b.account.color),
                      title: Text(b.account.name),
                      subtitle: Text(b.account.currency),
                      trailing: Text(fmt.money(b.balance, b.account.currency)),
                      selected: b.account.id == selectedId,
                      onTap: () => Navigator.pop(context, b.account),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of categories of [type]; returns the chosen category.
Future<Category?> pickCategory(BuildContext context, {required CategoryType type, int? selectedId}) {
  return showModalBottomSheet<Category>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CategoryPickerSheet(type: type, selectedId: selectedId),
  );
}

class _CategoryPickerSheet extends ConsumerWidget {
  const _CategoryPickerSheet({required this.type, this.selectedId});
  final CategoryType type;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref
        .watch(categoriesProvider)
        .where((c) => c.type == type && (!c.isHidden || c.id == selectedId))
        .toList();
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.chooseCategory, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  childAspectRatio: 0.8,
                ),
                itemCount: cats.length,
                itemBuilder: (ctx, i) {
                  final c = cats[i];
                  final selected = c.id == selectedId;
                  return InkWell(
                    key: Key('pick-category-${c.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      decoration: selected
                          ? BoxDecoration(
                              border: Border.all(color: theme.colorScheme.primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ColorIcon(icon: c.icon, color: c.color, size: 44),
                          const SizedBox(height: 6),
                          Text(
                            c.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable list of all bundled ISO currencies.
Future<Currency?> pickCurrency(BuildContext context, {String? selected}) {
  return showModalBottomSheet<Currency>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CurrencyPickerSheet(selected: selected),
  );
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({this.selected});
  final String? selected;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = kCurrencies
        .where((c) => q.isEmpty || c.code.toLowerCase().contains(q) || c.name.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + MediaQuery.viewInsetsOf(context).bottom * 0),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.searchCurrency,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  return ListTile(
                    key: Key('currency-${c.code}'),
                    leading: SizedBox(
                      width: 48,
                      child: Text(c.symbol, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    title: Text(c.code),
                    subtitle: Text(c.name),
                    selected: c.code == widget.selected,
                    trailing: c.code == widget.selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon library grid grouped by theme.
Future<String?> pickIcon(BuildContext context, {String? selected, int color = 0xFF2E7D4F}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.8,
        child: CustomScrollView(
          slivers: [
            for (final g in kIconGroups) ...[
              SliverToBoxAdapter(child: SectionHeader(g.name)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 60),
                  delegate: SliverChildListDelegate([
                    for (final e in g.icons.entries)
                      Semantics(
                        button: true,
                        selected: e.key == selected,
                        label: e.key.replaceAll('_', ' '),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => Navigator.pop(ctx, e.key),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: e.key == selected
                                ? ColorIcon(icon: e.key, color: color)
                                : Icon(e.value, size: 28),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Palette plus a custom hue/brightness picker.
Future<int?> pickColor(BuildContext context, {required int selected}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ColorPickerSheet(initial: selected),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});
  final int initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSLColor _hsl = HSLColor.fromColor(Color(widget.initial));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = _hsl.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final c in kPaletteColors)
                  Semantics(
                    button: true,
                    selected: c == widget.initial,
                    label: l10n.colorSwatch,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context, c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: c == widget.initial
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.customColor, style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _hsl.hue,
              max: 360,
              label: l10n.hue,
              semanticFormatterCallback: (v) => '${l10n.hue} ${v.round()}',
              onChanged: (v) => setState(() => _hsl = _hsl.withHue(v)),
            ),
            Slider(
              value: _hsl.lightness.clamp(0.15, 0.85),
              min: 0.15,
              max: 0.85,
              semanticFormatterCallback: (v) => '${l10n.lightness} ${(v * 100).round()}%',
              onChanged: (v) => setState(() => _hsl = _hsl.withLightness(v).withSaturation(0.65)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: custom),
              onPressed: () => Navigator.pop(context, custom.toARGB32()),
              icon: Icon(Icons.check,
                  color: ThemeData.estimateBrightnessForColor(custom) == Brightness.dark
                      ? Colors.white
                      : Colors.black),
              label: Text(
                l10n.useThisColor,
                style: TextStyle(
                    color: ThemeData.estimateBrightnessForColor(custom) == Brightness.dark
                        ? Colors.white
                        : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
