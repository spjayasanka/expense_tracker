import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../startup.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.categories),
            bottom: TabBar(tabs: [Tab(text: l10n.expense), Tab(text: l10n.income)]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: Text(l10n.newCategory),
            onPressed: () {
              final idx = DefaultTabController.of(context).index;
              openCategoryEditor(context, type: idx == 0 ? CategoryType.expense : CategoryType.income);
            },
          ),
          body: const TabBarView(
            children: [
              _CategoryList(type: CategoryType.expense),
              _CategoryList(type: CategoryType.income),
            ],
          ),
        );
      }),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});
  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cats = ref.watch(categoriesProvider).where((c) => c.type == type).toList();
    if (cats.isEmpty) {
      return EmptyState(icon: Icons.category_outlined, title: l10n.noCategories);
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: cats.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = cats.map((c) => c.id).toList();
        ids.insert(newIndex, ids.removeAt(oldIndex));
        ref.read(categoryRepoProvider).reorder(ids);
      },
      itemBuilder: (ctx, i) {
        final c = cats[i];
        return ListTile(
          key: ValueKey(c.id),
          leading: Opacity(
            opacity: c.isHidden ? 0.4 : 1,
            child: ColorIcon(icon: c.icon, color: c.color),
          ),
          title: Text(c.name),
          subtitle: c.isHidden ? Text(l10n.hidden) : null,
          onTap: () => openCategoryEditor(context, existing: c, type: c.type),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(c.isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                tooltip: c.isHidden ? l10n.show : l10n.hide,
                onPressed: () => ref.read(categoryRepoProvider).update(c.copyWith(isHidden: !c.isHidden)),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.moreOptions,
                onSelected: (v) {
                  if (v == 'merge') mergeCategoryFlow(context, ref, c);
                  if (v == 'delete') deleteCategoryFlow(context, ref, c);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'merge', child: Text(l10n.mergeInto)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, semanticLabel: l10n.reorder),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> mergeCategoryFlow(BuildContext context, WidgetRef ref, Category from) async {
  final l10n = context.l10n;
  final others = ref.read(categoriesProvider).where((c) => c.type == from.type && c.id != from.id).toList();
  if (others.isEmpty) return;
  final into = await showDialog<Category>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.mergeCategoryTitle(from.name)),
      children: [
        for (final c in others)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: Row(children: [
              ColorIcon(icon: c.icon, color: c.color, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(c.name)),
            ]),
          ),
      ],
    ),
  );
  if (into == null || !context.mounted) return;
  final count = await ref.read(categoryRepoProvider).transactionCount(from.id);
  if (!context.mounted) return;
  final ok = await confirmDialog(
    context,
    title: l10n.mergeCategoryTitle(from.name),
    message: l10n.mergeCategoryMessage(count, from.name, into.name),
    confirmLabel: l10n.merge,
  );
  if (!ok) return;
  await ref.read(categoryRepoProvider).merge(fromId: from.id, intoId: into.id);
  if (context.mounted) showSnack(context, l10n.categoriesMerged);
}

Future<void> deleteCategoryFlow(BuildContext context, WidgetRef ref, Category c) async {
  final l10n = context.l10n;
  final repo = ref.read(categoryRepoProvider);
  final count = await repo.transactionCount(c.id);
  if (!context.mounted) return;
  if (count == 0) {
    final ok = await confirmDialog(
      context,
      title: l10n.deleteCategoryTitle(c.name),
      message: l10n.deleteCategoryEmpty,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (ok) {
      await repo.deleteWithTransactions(c.id);
      await refreshRecurringState(ref, l10n);
    }
    return;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteCategoryTitle(c.name)),
      content: Text(l10n.deleteCategoryWithTxns(count)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: Text(l10n.moveTransactions)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, 'delete'),
          child: Text(l10n.deleteAll),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 'merge') await mergeCategoryFlow(context, ref, c);
  if (choice == 'delete') {
    await repo.deleteWithTransactions(c.id);
    await refreshRecurringState(ref, l10n);
  }
}

Future<void> openCategoryEditor(BuildContext context, {Category? existing, required CategoryType type}) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryEditorScreen(existing: existing, type: type)),
    );

class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen({super.key, this.existing, required this.type});
  final Category? existing;
  final CategoryType type;

  @override
  ConsumerState<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? 'category';
  late int _color = widget.existing?.color ?? 0xFF1E88E5;
  late CategoryType _type = widget.existing?.type ?? widget.type;
  late bool _hidden = widget.existing?.isHidden ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(categoryRepoProvider);
    final cat = Category(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      type: _type,
      icon: _icon,
      color: _color,
      sortOrder: widget.existing?.sortOrder ?? 0,
      isHidden: _hidden,
    );
    if (widget.existing == null) {
      await repo.add(cat);
    } else {
      await repo.update(cat);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final existing = widget.existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? l10n.newCategory : l10n.editCategory),
        actions: [
          if (existing != null)
            PopupMenuButton<String>(
              tooltip: l10n.moreOptions,
              onSelected: (v) async {
                if (v == 'merge') {
                  await mergeCategoryFlow(context, ref, existing);
                } else if (v == 'delete') {
                  await deleteCategoryFlow(context, ref, existing);
                }
                // Read straight from the database: the stream may lag a frame.
                final stillExists =
                    (await ref.read(categoryRepoProvider).getAll()).any((c) => c.id == existing.id);
                if (!stillExists && context.mounted) Navigator.pop(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'merge', child: Text(l10n.mergeInto)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: ColorIcon(icon: _icon, color: _color, size: 72, semanticLabel: _name.text)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.name),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 16),
            if (existing == null)
              SegmentedButton<CategoryType>(
                segments: [
                  ButtonSegment(value: CategoryType.expense, label: Text(l10n.expense)),
                  ButtonSegment(value: CategoryType.income, label: Text(l10n.income)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_symbols),
              title: Text(l10n.icon),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final i = await pickIcon(context, selected: _icon, color: _color);
                if (i != null) setState(() => _icon = i);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.color),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Color(_color), shape: BoxShape.circle),
              ),
              onTap: () async {
                final c = await pickColor(context, selected: _color);
                if (c != null) setState(() => _color = c);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.hidden),
              subtitle: Text(l10n.hiddenHelp),
              value: _hidden,
              onChanged: (v) => setState(() => _hidden = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
