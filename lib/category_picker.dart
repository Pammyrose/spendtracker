import 'package:flutter/material.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'category_catalog.dart';
import 'entry_widgets.dart';

Future<int?> chooseIcon(BuildContext context, {int selected = 0}) {
  FocusScope.of(context).unfocus();
  return showDialog<int>(
    context: context,
    builder: (_) => IconPickerDialog(selected: selected),
  );
}

Future<int?> chooseCategory(
  BuildContext context,
  CategoryKind kind, {
  int? selected,
}) {
  FocusScope.of(context).unfocus();
  return showDialog<int>(
    context: context,
    builder: (_) => CategoryPickerDialog(kind: kind, selected: selected),
  );
}

class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({super.key, this.selected = 0});
  final int selected;
  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final matches = [
      for (var i = 0; i < categoryIcons.length; i++)
        if (categoryIcons[i].label.toLowerCase().contains(
          _search.trim().toLowerCase(),
        ))
          i,
    ];
    // Change the display order without changing saved icon indexes.
    final choices = [
      ...matches.where((index) => categoryIcons[index].id != 'other'),
      ...matches.where((index) => categoryIcons[index].id == 'other'),
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choose icon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close icon chooser',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                key: const Key('icon-search'),
                decoration: entryDecoration(
                  context,
                  'Search icons',
                ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Flexible(
              child: choices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No icons found.',
                        style: TextStyle(color: palette.muted),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth < 360 ? 3 : 6,
                          mainAxisExtent: 90,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: choices.length,
                        itemBuilder: (context, position) {
                          final index = choices[position],
                              choice = categoryIcons[index];
                          return Semantics(
                            selected: index == widget.selected,
                            button: true,
                            child: InkWell(
                              key: ValueKey('icon-${choice.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(context, index),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: index == widget.selected
                                      ? palette.soft
                                      : palette.surface,
                                  border: Border.all(
                                    color: index == widget.selected
                                        ? palette.accent
                                        : palette.border,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      choice.icon,
                                      color: choice.color,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      choice.label,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryPickerDialog extends StatefulWidget {
  const CategoryPickerDialog({super.key, required this.kind, this.selected});
  final CategoryKind kind;
  final int? selected;
  @override
  State<CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<CategoryPickerDialog> {
  Future<void> _add() async {
    final index = await showDialog<int>(
      context: context,
      builder: (_) => AddCategoryDialog(kind: widget.kind),
    );
    if (index != null && mounted) Navigator.pop(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context),
        categories = AppDataScope.of(context).categoriesFor(widget.kind);
    bool isOther(int index) => const [
      'other',
      'others',
    ].contains(categories[index].name.trim().toLowerCase());
    final order = [
      for (var index = 0; index < categories.length; index++)
        if (!isOther(index)) index,
      for (var index = 0; index < categories.length; index++)
        if (isOther(index)) index,
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close category chooser',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 104,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: categories.length,
                itemBuilder: (context, position) {
                  final index = order[position];
                  final category = categories[index];
                  return Semantics(
                    selected: widget.selected == index,
                    button: true,
                    child: InkWell(
                      key: ValueKey('category-${widget.kind.name}-$index'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, index),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: widget.selected == index
                              ? palette.soft
                              : palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.selected == index
                                ? palette.accent
                                : palette.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              category.icon,
                              color: category.color,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('add-category'),
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Category'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key, required this.kind});
  final CategoryKind kind;
  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  int _icon = categoryIcons.indexWhere((choice) => choice.id == 'other');
  String? _saveError;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final index = AppDataScope.of(context)
          .addCategory(widget.kind, _name.text, categoryIcons[_icon].id);
      Navigator.pop(context, index);
    } on FormatException catch (error) {
      setState(() => _saveError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = AppDataScope.of(context), icon = categoryIcons[_icon];
    return AlertDialog(
      title: const Text('Add Category'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('category-name'),
                controller: _name,
                maxLength: 40,
                decoration: entryDecoration(
                  context,
                  'e.g. Pet care',
                ).copyWith(labelText: 'Category name', counterText: ''),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter a category name';
                  if (data
                      .categoriesFor(widget.kind)
                      .any(
                        (category) =>
                            category.name.toLowerCase() == name.toLowerCase(),
                      )) {
                    return 'This category already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Icon',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                key: const Key('category-icon'),
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final index = await chooseIcon(context, selected: _icon);
                  if (index != null && mounted) setState(() => _icon = index);
                },
                child: InputDecorator(
                  decoration: entryDecoration(context, '').copyWith(
                    suffixIcon: const Icon(Icons.chevron_right_rounded),
                  ),
                  child: Row(
                    children: [
                      Icon(icon.icon, color: icon.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          icon.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-category'),
          onPressed: _save,
          child: const Text('Add Category'),
        ),
      ],
    );
  }
}

class CategoryField extends FormField<int> {
  CategoryField({
    super.key,
    required CategoryKind kind,
    required int? value,
    required ValueChanged<int> onChanged,
    bool isRequired = true,
  }) : super(
         initialValue: value,
         validator: (value) =>
             isRequired && value == null ? 'Choose a category' : null,
         builder: (field) {
           final context = field.context,
               categories = AppDataScope.of(field.context).categoriesFor(kind);
           final selected = field.value;
           final category = selected == null ? null : categories[selected];
           return InkWell(
             onTap: () async {
               final choice = await chooseCategory(
                 context,
                 kind,
                 selected: selected,
               );
               if (choice != null && context.mounted) {
                 field.didChange(choice);
                 onChanged(choice);
               }
             },
             child: InputDecorator(
               decoration: entryDecoration(context, '').copyWith(
                 errorText: field.errorText,
                 prefixIcon: Icon(
                   category?.icon ?? Icons.category_rounded,
                   color:
                       category?.color ?? Theme.of(context).colorScheme.primary,
                 ),
                 suffixIcon: const Icon(Icons.chevron_right_rounded),
               ),
               child: Text(
                 category?.name ?? 'Choose a category',
                 maxLines: 2,
                 style: TextStyle(
                   fontSize: 13,
                   color: category == null
                       ? AppPalette.of(context).muted
                       : AppPalette.of(context).ink,
                 ),
               ),
             ),
           );
         },
       );
}
