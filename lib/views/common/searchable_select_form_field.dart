import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Normaliza texto para búsqueda: minúsculas, sin acentos/diacríticos y sin 'ñ'.
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

/// Muestra un modal de diálogo de selección con búsqueda en tiempo real.
Future<String?> showSearchableSelectDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<String> items,
  String? initialValue,
  String searchHint = 'Escribe una letra o nombre para buscar...',
  bool allowCustomValue = false,
  String customValueLabel = 'opción',
  String emptyText = 'No se encontraron resultados',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SearchableSelectDialog(
      title: title,
      subtitle: subtitle,
      items: items,
      initialValue: initialValue,
      searchHint: searchHint,
      allowCustomValue: allowCustomValue,
      customValueLabel: customValueLabel,
      emptyText: emptyText,
    ),
  );
}

/// Diálogo de búsqueda y selección optimizado para escritorio.
class SearchableSelectDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> items;
  final String? initialValue;
  final String searchHint;
  final bool allowCustomValue;
  final String customValueLabel;
  final String emptyText;

  const SearchableSelectDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.initialValue,
    this.searchHint = 'Escribe una letra o nombre para buscar...',
    this.allowCustomValue = false,
    this.customValueLabel = 'opción',
    this.emptyText = 'No se encontraron resultados',
  });

  @override
  State<SearchableSelectDialog> createState() => _SearchableSelectDialogState();
}

class _SearchableSelectDialogState extends State<SearchableSelectDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final FocusNode _searchFocusNode;
  final ScrollController _scrollController = ScrollController();

  late List<String> _filteredItems;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);

    _searchFocusNode = FocusNode(onKeyEvent: (node, event) {
      return _handleKeyEvent(event);
    });

    // Si hay un valor inicial seleccionado, posicionar resaltado sobre él
    if (widget.initialValue != null) {
      final initialIndex = _filteredItems.indexOf(widget.initialValue!);
      if (initialIndex >= 0) {
        _highlightedIndex = initialIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && initialIndex > 4) {
            _scrollController.jumpTo((initialIndex - 2) * 48.0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final normQuery = _normalizeSpanish(query);
    setState(() {
      if (normQuery.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        final tokens = normQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

        final matches = widget.items.where((item) {
          final normItem = _normalizeSpanish(item);
          return tokens.every((tok) => normItem.contains(tok));
        }).toList();

        // Ordenar con prioridad:
        // 1. Coincidencia exacta
        // 2. Empieza con la búsqueda
        // 3. Alguna palabra empieza con la búsqueda
        // 4. Contiene la búsqueda
        matches.sort((a, b) {
          final normA = _normalizeSpanish(a);
          final normB = _normalizeSpanish(b);

          if (normA == normQuery && normB != normQuery) return -1;
          if (normB == normQuery && normA != normQuery) return 1;

          final startsA = normA.startsWith(normQuery);
          final startsB = normB.startsWith(normQuery);
          if (startsA && !startsB) return -1;
          if (startsB && !startsA) return 1;

          final wordsAStarts = normA.split(' ').any((w) => w.startsWith(normQuery));
          final wordsBStarts = normB.split(' ').any((w) => w.startsWith(normQuery));
          if (wordsAStarts && !wordsBStarts) return -1;
          if (wordsBStarts && !wordsAStarts) return 1;

          return a.compareTo(b);
        });

        _filteredItems = matches;
      }

      _highlightedIndex = 0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _selectItem(String value) {
    Navigator.of(context).pop(value);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_filteredItems.isNotEmpty) {
        setState(() {
          _highlightedIndex = (_highlightedIndex + 1).clamp(0, _filteredItems.length - 1);
        });
        _scrollToIndex(_highlightedIndex);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_filteredItems.isNotEmpty) {
        setState(() {
          _highlightedIndex = (_highlightedIndex - 1).clamp(0, _filteredItems.length - 1);
        });
        _scrollToIndex(_highlightedIndex);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_filteredItems.isNotEmpty && _highlightedIndex >= 0 && _highlightedIndex < _filteredItems.length) {
        _selectItem(_filteredItems[_highlightedIndex]);
        return KeyEventResult.handled;
      } else if (widget.allowCustomValue && _searchCtrl.text.trim().isNotEmpty) {
        _selectItem(_searchCtrl.text.trim());
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 48.0;
    final targetOffset = index * itemHeight;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
        targetOffset + itemHeight - viewportHeight,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildHighlightedText(String text, String query, bool isSelected) {
    final queryTrim = query.trim();
    if (queryTrim.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.casart800 : Colors.black87,
        ),
      );
    }

    final normText = _normalizeSpanish(text);
    final normQuery = _normalizeSpanish(queryTrim);

    final matchIndex = normText.indexOf(normQuery);
    if (matchIndex < 0) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.casart800 : Colors.black87,
        ),
      );
    }

    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + normQuery.length);
    final after = text.substring(matchIndex + normQuery.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? AppTheme.casart800 : Colors.black87,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.casart800,
              backgroundColor: AppTheme.casart100,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearchText = _searchCtrl.text.trim().isNotEmpty;
    final exactMatch = widget.items.any(
      (it) => _normalizeSpanish(it) == _normalizeSpanish(_searchCtrl.text),
    );
    final canAddCustom = widget.allowCustomValue && hasSearchText && !exactMatch;

    final mediaSize = MediaQuery.of(context).size;
    final dialogWidth = (mediaSize.width * 0.9).clamp(320.0, 580.0);
    final dialogHeight = (mediaSize.height * 0.85).clamp(380.0, 600.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ENCABEZADO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.casart50,
                border: Border(bottom: BorderSide(color: AppTheme.casart200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.casart100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.casart800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.casart950,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    tooltip: 'Cerrar (Esc)',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // CAMPO DE BÚSQUEDA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search, color: AppTheme.casart800),
                  suffixIcon: hasSearchText
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          tooltip: 'Borrar búsqueda',
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDFC9D7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.casart800, width: 1.8),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // BARRA DE ESTADO / CONTADOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasSearchText
                          ? '${_filteredItems.length} coincidencia(s)'
                          : '${widget.items.length} opciones en total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Usa ↑ ↓ y Enter',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 12, thickness: 1),

              // LISTADO DE RESULTADOS
              Expanded(
                child: _filteredItems.isEmpty && !canAddCustom
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.emptyText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Prueba escribiendo otra letra o verifica el nombre.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredItems.length + (canAddCustom ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Opción personalizada al final si no se encontró en catálogo
                            if (canAddCustom && index == _filteredItems.length) {
                              final customVal = _searchCtrl.text.trim();
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Material(
                                  color: AppTheme.casart50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: AppTheme.casart300),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _selectItem(customVal),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.add_circle_outline,
                                            color: AppTheme.casart800,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Usar "$customVal" como ${widget.customValueLabel}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.casart800,
                                                  ),
                                                ),
                                                Text(
                                                  'Esta opción no se encuentra en el listado oficial',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: AppTheme.casart800,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = _filteredItems[index];
                            final isSelected = item == widget.initialValue;
                            final isHighlighted = index == _highlightedIndex;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: Material(
                                color: isSelected
                                    ? AppTheme.casart50
                                    : (isHighlighted ? Colors.grey.shade100 : Colors.transparent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppTheme.casart300
                                        : (isHighlighted ? Colors.grey.shade300 : Colors.transparent),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _selectItem(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked,
                                          size: 18,
                                          color: isSelected
                                              ? AppTheme.casart800
                                              : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildHighlightedText(
                                            item,
                                            _searchCtrl.text,
                                            isSelected,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const Divider(height: 1, thickness: 1),

              // PIE DE ACCIONES
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    if (widget.initialValue != null && widget.initialValue!.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Limpiar selección'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: () => Navigator.of(context).pop('__CLEAR__'),
                      ),
                    const Spacer(),
                    TextButton(
                      style: AppTheme.cancelButtonStyle,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
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

/// Selector de formulario tipo dropdown con búsqueda integrada por letra o nombre completo.
class SearchableSelectFormField extends StatefulWidget {
  final String? value;
  final List<String> items;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final IconData? prefixIcon;
  final bool enabled;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String?>? validator;
  final String searchTitle;
  final String? searchSubtitle;
  final String searchHint;
  final bool allowCustomValue;
  final String customValueLabel;

  const SearchableSelectFormField({
    super.key,
    this.value,
    required this.items,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.searchTitle = 'Buscar',
    this.searchSubtitle,
    this.searchHint = 'Escribe una letra o nombre para buscar...',
    this.allowCustomValue = false,
    this.customValueLabel = 'opción',
  });

  @override
  State<SearchableSelectFormField> createState() => _SearchableSelectFormFieldState();
}

class _SearchableSelectFormFieldState extends State<SearchableSelectFormField> {
  late final FocusNode _focusNode;
  FormFieldState<String?>? _fieldState;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: (node, event) {
      if (_fieldState != null) {
        return _handleKey(event, _fieldState!);
      }
      return KeyEventResult.ignored;
    });
  }

  @override
  void didUpdateWidget(covariant SearchableSelectFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _fieldState != null) {
      if (_fieldState!.value != widget.value) {
        _fieldState!.didChange(widget.value);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openSearch(BuildContext context, FormFieldState<String?> state) async {
    if (!widget.enabled) return;

    final selected = await showSearchableSelectDialog(
      context: context,
      title: widget.searchTitle,
      subtitle: widget.searchSubtitle,
      items: widget.items,
      initialValue: state.value,
      searchHint: widget.searchHint,
      allowCustomValue: widget.allowCustomValue,
      customValueLabel: widget.customValueLabel,
    );

    if (selected == '__CLEAR__') {
      state.didChange(null);
      widget.onChanged?.call(null);
    } else if (selected != null) {
      state.didChange(selected);
      widget.onChanged?.call(selected);
    }
  }

  KeyEventResult _handleKey(KeyEvent event, FormFieldState<String?> state) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _openSearch(context, state);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        if (state.value != null) {
          state.didChange(null);
          widget.onChanged?.call(null);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String?>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        _fieldState = state;

        final currentValue = state.value ?? widget.value;
        final hasValue = currentValue != null && currentValue.trim().isNotEmpty;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return InkWell(
          focusNode: _focusNode,
          onTap: widget.enabled ? () => _openSearch(context, state) : null,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            isEmpty: !hasValue,
            isFocused: _focusNode.hasFocus,
            decoration: InputDecoration(
                labelText: widget.labelText,
                helperText: widget.helperText,
                errorText: state.errorText,
                enabled: widget.enabled,
                prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
                fillColor: !widget.enabled
                    ? (isDark ? Colors.grey.shade900 : const Color(0xFFF3F3F5))
                    : (isDark ? AppTheme.cardDark : Colors.white),
                filled: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enabled && hasValue)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpiar selección',
                        splashRadius: 16,
                        onPressed: () {
                          state.didChange(null);
                          widget.onChanged?.call(null);
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: widget.enabled ? AppTheme.casart800 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              child: Text(
                hasValue
                    ? currentValue
                    : (widget.hintText ?? ''),
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue
                      ? (widget.enabled
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey.shade500)
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      );
    }
  }
