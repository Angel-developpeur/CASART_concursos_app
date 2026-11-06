import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

String _normalizeSpanish(String text) {
  return text
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
}

/// Campo de texto de formulario con sugerencias de autocompletado desplegables
/// basadas en valores escritos con anterioridad (estilo input web).
class AutocompleteTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final int maxSuggestions;

  const AutocompleteTextFormField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.decoration = const InputDecoration(),
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.maxSuggestions = 8,
  });

  @override
  State<AutocompleteTextFormField> createState() =>
      _AutocompleteTextFormFieldState();
}

class _AutocompleteTextFormFieldState extends State<AutocompleteTextFormField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _buildOptions(TextEditingValue textEditingValue) {
    if (widget.readOnly || !widget.enabled || widget.suggestions.isEmpty) {
      return const Iterable<String>.empty();
    }

    final rawQuery = textEditingValue.text.trim();
    if (rawQuery.isEmpty) {
      return const Iterable<String>.empty();
    }

    final normQuery = _normalizeSpanish(rawQuery);
    if (normQuery.isEmpty) {
      return const Iterable<String>.empty();
    }

    final matches = <String>[];
    for (final item in widget.suggestions) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final normItem = _normalizeSpanish(trimmed);
      if (normItem.contains(normQuery)) {
        matches.add(trimmed);
      }
    }

    if (matches.isEmpty) {
      return const Iterable<String>.empty();
    }

    // Si la única coincidencia ya es exactamente igual a lo escrito, ocultar el menú
    if (matches.length == 1 &&
        _normalizeSpanish(matches.first) == normQuery) {
      return const Iterable<String>.empty();
    }

    matches.sort((a, b) {
      final normA = _normalizeSpanish(a);
      final normB = _normalizeSpanish(b);

      final startsA = normA.startsWith(normQuery);
      final startsB = normB.startsWith(normQuery);
      if (startsA && !startsB) return -1;
      if (startsB && !startsA) return 1;

      final wordStartsA =
          normA.split(RegExp(r'\s+')).any((w) => w.startsWith(normQuery));
      final wordStartsB =
          normB.split(RegExp(r'\s+')).any((w) => w.startsWith(normQuery));
      if (wordStartsA && !wordStartsB) return -1;
      if (wordStartsB && !wordStartsA) return 1;

      return 0; // Conservar orden de frecuencia/recencia de la BD
    });

    return matches.take(widget.maxSuggestions);
  }

  Widget _buildHighlightedSuggestion(
    BuildContext context,
    String option,
    String query,
    bool isHighlighted,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : Colors.black87;
    final queryTrim = query.trim();

    if (queryTrim.isEmpty) {
      return Text(
        option,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          color: defaultColor,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    final normOption = _normalizeSpanish(option);
    final normQuery = _normalizeSpanish(queryTrim);
    final matchIdx = normOption.indexOf(normQuery);

    if (matchIdx < 0 || matchIdx + normQuery.length > option.length) {
      return Text(
        option,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          color: defaultColor,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    final before = option.substring(0, matchIdx);
    final match = option.substring(matchIdx, matchIdx + normQuery.length);
    final after = option.substring(matchIdx + normQuery.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          color: defaultColor,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.casart200 : AppTheme.casart800,
              backgroundColor: isDark
                  ? AppTheme.casart800.withValues(alpha: 0.35)
                  : AppTheme.casart100,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;

        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: _buildOptions,
          onSelected: (String selection) {
            widget.controller.value = TextEditingValue(
              text: selection,
              selection: TextSelection.collapsed(offset: selection.length),
            );
            widget.onChanged?.call(selection);
            _focusNode.requestFocus();
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _focusNode.requestFocus();
                widget.controller.selection = TextSelection.collapsed(
                  offset: widget.controller.text.length,
                );
              }
            });
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              decoration: widget.decoration,
              validator: widget.validator,
              onChanged: widget.onChanged,
              onEditingComplete: () {
                // Evita que EditableText haga unfocus() automáticamente al presionar Enter
              },
              onFieldSubmitted: (_) {
                onFieldSubmitted();
                focusNode.requestFocus();
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    focusNode.requestFocus();
                  }
                });
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final optionsList = options.toList(growable: false);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Material(
                  elevation: 6,
                  color: isDark ? const Color(0xFF26262E) : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade700
                          : AppTheme.casart200,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: fieldWidth > 0 ? fieldWidth : 300,
                      maxHeight: 220,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: optionsList.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = optionsList[index];
                        return Builder(
                          builder: (BuildContext context) {
                            final bool isHighlighted =
                                AutocompleteHighlightedOption.of(context) ==
                                    index;
                            if (isHighlighted) {
                              SchedulerBinding.instance
                                  .addPostFrameCallback((_) {
                                if (context.mounted) {
                                  Scrollable.ensureVisible(
                                    context,
                                    alignment: 0.5,
                                  );
                                }
                              });
                            }

                            return InkWell(
                              canRequestFocus: false,
                              onTap: () => onSelected(option),
                              child: Container(
                                color: isHighlighted
                                    ? (isDark
                                        ? AppTheme.casart800
                                            .withValues(alpha: 0.25)
                                        : AppTheme.casart50)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 16,
                                      color: isHighlighted
                                          ? (isDark
                                              ? AppTheme.casart200
                                              : AppTheme.casart800)
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildHighlightedSuggestion(
                                        context,
                                        option,
                                        widget.controller.text,
                                        isHighlighted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
