import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Normaliza texto en español: minúsculas, sin acentos y 'ñ' -> 'n'.
String _normalizeForKeyMatch(String text) {
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

/// Extrae el carácter imprimible de un evento de teclado.
String? _extractPrintableChar(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  if (HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isAltPressed ||
      HardwareKeyboard.instance.isMetaPressed) {
    return null;
  }

  final ch = event.character;
  if (ch != null && ch.trim().isNotEmpty) {
    final trimmed = ch.trim();
    final code = trimmed.codeUnitAt(0);
    if (code >= 32 && code != 127) {
      return trimmed;
    }
  }

  final label = event.logicalKey.keyLabel;
  if (label.length == 1) {
    final code = label.codeUnitAt(0);
    if (code >= 32 && code != 127) {
      return label;
    }
  }

  return null;
}

/// Buscador por letra inicial estilo `<select>` web.
/// Soporta:
/// - Oprimir una letra para saltar a la primera opción que empiece con esa letra.
/// - Oprimir repetidamente la misma letra para ciclar entre todas las opciones con esa inicial.
/// - Escribir rápido varias letras (ej. "ca") para coincidir con el prefijo.
class _WebSelectTypeaheadMatcher {
  String _typedBuffer = '';
  DateTime? _lastKeyTime;

  int? findMatch({
    required List<String> normalizedLabels,
    required List<String> normalizedValueCodes,
    required List<bool> isSelectable,
    required int currentIndex,
    required String char,
  }) {
    final normChar = _normalizeForKeyMatch(char);
    if (normChar.isEmpty) return null;

    final now = DateTime.now();
    final isWithinTimeout = _lastKeyTime != null &&
        now.difference(_lastKeyTime!) <= const Duration(milliseconds: 750);
    _lastKeyTime = now;

    if (isWithinTimeout) {
      _typedBuffer += normChar;
    } else {
      _typedBuffer = normChar;
    }

    final count = normalizedLabels.length;
    if (count == 0) return null;

    final allSameChar = _typedBuffer.split('').every((c) => c == normChar);

    // 1. Si el usuario tecleó rápido un prefijo de varias letras distintas (ej. "se")
    if (_typedBuffer.length > 1 && !allSameChar) {
      final startIdx = currentIndex >= 0 ? currentIndex : 0;
      for (int i = 0; i < count; i++) {
        final idx = (startIdx + i) % count;
        if (isSelectable[idx] &&
            normalizedLabels[idx].startsWith(_typedBuffer)) {
          return idx;
        }
      }
      // Si ninguna opción coincide con el prefijo compuesto, hacer fallback a la letra actual
      _typedBuffer = normChar;
    }

    // 2. Búsqueda por letra inicial del texto visible (ciclando a la siguiente si la actual ya empieza con esa letra)
    final currentStartsWithChar = currentIndex >= 0 &&
        currentIndex < count &&
        isSelectable[currentIndex] &&
        normalizedLabels[currentIndex].startsWith(normChar);

    final startIdx = currentStartsWithChar ? (currentIndex + 1) % count : 0;
    for (int i = 0; i < count; i++) {
      final idx = (startIdx + i) % count;
      if (isSelectable[idx] && normalizedLabels[idx].startsWith(normChar)) {
        return idx;
      }
    }

    // 3. Fallback por código de valor (ej. 'F' para Femenino/Mujer en Género)
    for (int i = 0; i < count; i++) {
      final idx = (startIdx + i) % count;
      if (isSelectable[idx] &&
          normalizedValueCodes[idx].isNotEmpty &&
          normalizedValueCodes[idx].startsWith(normChar)) {
        return idx;
      }
    }

    return null;
  }
}

/// Selector desplegable de formulario que permite seleccionar opciones al oprimir
/// la letra con la que empieza la opción (tanto con el menú cerrado como abierto),
/// replicando el comportamiento nativo de los `<select>` en páginas web.
class KeySelectableDropdownFormField<T> extends FormField<T> {
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final Widget? hint;

  KeySelectableDropdownFormField({
    super.key,
    super.initialValue,
    required this.items,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.hint,
    super.validator,
  }) : super(
          enabled: onChanged != null,
          builder: (FormFieldState<T> field) {
            final state = field as _KeySelectableDropdownFormFieldState<T>;
            return state._buildField(field.context);
          },
        );

  @override
  FormFieldState<T> createState() => _KeySelectableDropdownFormFieldState<T>();
}

class _KeySelectableDropdownFormFieldState<T> extends FormFieldState<T> {
  late final FocusNode _focusNode;
  final GlobalKey _boxKey = GlobalKey();
  final _WebSelectTypeaheadMatcher _matcher = _WebSelectTypeaheadMatcher();
  bool _isMenuOpen = false;

  KeySelectableDropdownFormField<T> get _dropdownWidget =>
      widget as KeySelectableDropdownFormField<T>;

  bool get _isEnabled => _dropdownWidget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) => _handleClosedKeyEvent(event),
    );
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant KeySelectableDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dropdownWidget.initialValue != oldWidget.initialValue) {
      setValue(_dropdownWidget.initialValue);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  String _extractLabel(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) {
      return child.data ?? '';
    }
    return '';
  }

  bool _isPlaceholderItem(DropdownMenuItem<T> item) {
    if (item.value != null) return false;
    final norm = _normalizeForKeyMatch(_extractLabel(item));
    return norm.startsWith('selecciona');
  }

  int _findCurrentIndex() {
    final items = _dropdownWidget.items;
    for (int i = 0; i < items.length; i++) {
      if (items[i].value == value) {
        return i;
      }
    }
    return -1;
  }

  void _applySelection(T? newValue) {
    didChange(newValue);
    if (hasError) {
      validate();
    }
    _dropdownWidget.onChanged?.call(newValue);
  }

  KeyEventResult _handleClosedKeyEvent(KeyEvent event) {
    if (!_isEnabled || _isMenuOpen) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final items = _dropdownWidget.items;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _openDropdownMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final curr = _findCurrentIndex();
      for (int step = 1; step <= items.length; step++) {
        final next = (curr + step).clamp(0, items.length - 1);
        if (!_isPlaceholderItem(items[next])) {
          if (next != curr) {
            _applySelection(items[next].value);
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final curr = _findCurrentIndex();
      final start = curr <= 0 ? 0 : curr;
      for (int next = start - 1; next >= 0; next--) {
        if (!_isPlaceholderItem(items[next])) {
          _applySelection(items[next].value);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    final char = _extractPrintableChar(event);
    if (char != null) {
      final normLabels =
          items.map((it) => _normalizeForKeyMatch(_extractLabel(it))).toList();
      final normCodes = items
          .map((it) =>
              it.value is String ? _normalizeForKeyMatch(it.value as String) : '')
          .toList();
      final selectable =
          items.map((it) => it.enabled && !_isPlaceholderItem(it)).toList();

      final matchIdx = _matcher.findMatch(
        normalizedLabels: normLabels,
        normalizedValueCodes: normCodes,
        isSelectable: selectable,
        currentIndex: _findCurrentIndex(),
        char: char,
      );

      if (matchIdx != null) {
        _applySelection(items[matchIdx].value);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openDropdownMenu() async {
    if (!_isEnabled || _isMenuOpen || _dropdownWidget.items.isEmpty) return;

    final renderBox =
        _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    _focusNode.requestFocus();

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    setState(() => _isMenuOpen = true);

    await Navigator.of(context).push(
      _KeySelectableDropdownRoute<T>(
        targetOffset: offset,
        targetSize: size,
        items: _dropdownWidget.items,
        initialIndex: _findCurrentIndex(),
        extractLabel: _extractLabel,
        isPlaceholder: _isPlaceholderItem,
        onSelect: (selectedValue) {
          _applySelection(selectedValue);
        },
      ),
    );

    if (mounted) {
      setState(() => _isMenuOpen = false);
      _focusNode.requestFocus();
    }
  }

  Widget _buildField(BuildContext context) {
    final items = _dropdownWidget.items;
    final currIdx = _findCurrentIndex();
    final selectedItem = currIdx >= 0 ? items[currIdx] : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveDecoration = _dropdownWidget.decoration
        .applyDefaults(Theme.of(context).inputDecorationTheme)
        .copyWith(
          errorText: errorText,
          enabled: _isEnabled,
        );

    final isEmpty = selectedItem == null;

    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        key: _boxKey,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(8),
        onTap: _isEnabled ? _openDropdownMenu : null,
        child: InputDecorator(
          isEmpty: isEmpty,
          isFocused: _focusNode.hasFocus || _isMenuOpen,
          decoration: effectiveDecoration,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: selectedItem != null
                      ? DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 14,
                            color: _isEnabled
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: selectedItem.child,
                        )
                      : (_dropdownWidget.hint ?? const SizedBox.shrink()),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isMenuOpen
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 22,
                  color: _isEnabled
                      ? (_focusNode.hasFocus || _isMenuOpen
                          ? AppTheme.casart800
                          : (isDark ? Colors.white70 : Colors.grey.shade700))
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeySelectableDropdownRoute<T> extends PopupRoute<void> {
  final Offset targetOffset;
  final Size targetSize;
  final List<DropdownMenuItem<T>> items;
  final int initialIndex;
  final String Function(DropdownMenuItem<T>) extractLabel;
  final bool Function(DropdownMenuItem<T>) isPlaceholder;
  final ValueChanged<T?> onSelect;

  _KeySelectableDropdownRoute({
    required this.targetOffset,
    required this.targetSize,
    required this.items,
    required this.initialIndex,
    required this.extractLabel,
    required this.isPlaceholder,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Cerrar menú';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _KeySelectableDropdownMenu<T>(
      targetOffset: targetOffset,
      targetSize: targetSize,
      items: items,
      initialIndex: initialIndex,
      extractLabel: extractLabel,
      isPlaceholder: isPlaceholder,
      onSelect: onSelect,
      animation: animation,
    );
  }
}

class _KeySelectableDropdownMenu<T> extends StatefulWidget {
  final Offset targetOffset;
  final Size targetSize;
  final List<DropdownMenuItem<T>> items;
  final int initialIndex;
  final String Function(DropdownMenuItem<T>) extractLabel;
  final bool Function(DropdownMenuItem<T>) isPlaceholder;
  final ValueChanged<T?> onSelect;
  final Animation<double> animation;

  const _KeySelectableDropdownMenu({
    required this.targetOffset,
    required this.targetSize,
    required this.items,
    required this.initialIndex,
    required this.extractLabel,
    required this.isPlaceholder,
    required this.onSelect,
    required this.animation,
  });

  @override
  State<_KeySelectableDropdownMenu<T>> createState() =>
      _KeySelectableDropdownMenuState<T>();
}

class _KeySelectableDropdownMenuState<T>
    extends State<_KeySelectableDropdownMenu<T>> {
  static const double _itemHeight = 42.0;

  late final FocusNode _menuFocusNode;
  late final ScrollController _scrollController;
  final _WebSelectTypeaheadMatcher _matcher = _WebSelectTypeaheadMatcher();
  late int _highlightedIndex;

  @override
  void initState() {
    super.initState();
    _highlightedIndex = widget.initialIndex >= 0 ? widget.initialIndex : 0;

    final initialScrollOffset =
        (_highlightedIndex > 2) ? (_highlightedIndex - 2) * _itemHeight : 0.0;
    _scrollController = ScrollController(
      initialScrollOffset: initialScrollOffset,
    );

    _menuFocusNode = FocusNode(
      onKeyEvent: (node, event) => _handleMenuKeyEvent(event),
    );
  }

  @override
  void dispose() {
    _menuFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final target = index * _itemHeight;
    final current = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;

    if (target < current) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    } else if (target + _itemHeight > current + viewport) {
      _scrollController.animateTo(
        target + _itemHeight - viewport,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleMenuKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final items = widget.items;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_highlightedIndex >= 0 && _highlightedIndex < items.length) {
        widget.onSelect(items[_highlightedIndex].value);
      }
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final next = (_highlightedIndex + 1).clamp(0, items.length - 1);
      setState(() => _highlightedIndex = next);
      _scrollToIndex(next);
      if (!widget.isPlaceholder(items[next])) {
        widget.onSelect(items[next].value);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final prev = (_highlightedIndex - 1).clamp(0, items.length - 1);
      setState(() => _highlightedIndex = prev);
      _scrollToIndex(prev);
      if (!widget.isPlaceholder(items[prev])) {
        widget.onSelect(items[prev].value);
      }
      return KeyEventResult.handled;
    }

    final char = _extractPrintableChar(event);
    if (char != null) {
      final normLabels = items
          .map((it) => _normalizeForKeyMatch(widget.extractLabel(it)))
          .toList();
      final normCodes = items
          .map((it) =>
              it.value is String ? _normalizeForKeyMatch(it.value as String) : '')
          .toList();
      final selectable = items
          .map((it) => it.enabled && !widget.isPlaceholder(it))
          .toList();

      final matchIdx = _matcher.findMatch(
        normalizedLabels: normLabels,
        normalizedValueCodes: normCodes,
        isSelectable: selectable,
        currentIndex: _highlightedIndex,
        char: char,
      );

      if (matchIdx != null) {
        setState(() => _highlightedIndex = matchIdx);
        _scrollToIndex(matchIdx);
        widget.onSelect(items[matchIdx].value);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final maxMenuHeight = 280.0;
    final contentHeight = (widget.items.length * _itemHeight + 8.0)
        .clamp(48.0, maxMenuHeight);

    final spaceBelow =
        screenSize.height - (widget.targetOffset.dy + widget.targetSize.height) - 12.0;
    final showAbove = spaceBelow < contentHeight &&
        widget.targetOffset.dy > contentHeight + 12.0;

    final top = showAbove
        ? (widget.targetOffset.dy - contentHeight - 4.0)
            .clamp(8.0, screenSize.height - contentHeight - 8.0)
        : (widget.targetOffset.dy + widget.targetSize.height + 2.0)
            .clamp(8.0, screenSize.height - contentHeight - 8.0);

    final left = widget.targetOffset.dx
        .clamp(8.0, (screenSize.width - widget.targetSize.width - 8.0).clamp(8.0, screenSize.width));

    return Focus(
      focusNode: _menuFocusNode,
      autofocus: true,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: widget.targetSize.width,
            height: contentHeight,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: widget.animation,
                curve: Curves.easeOut,
              ),
              child: Material(
                elevation: 8,
                color: isDark ? AppTheme.cardDark : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF4E213C)
                        : AppTheme.casart200,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: widget.items.length > 6,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemExtent: _itemHeight,
                    itemCount: widget.items.length,
                    itemBuilder: (ctx, idx) {
                      final item = widget.items[idx];
                      final isHighlighted = idx == _highlightedIndex;

                      return InkWell(
                        onTap: () {
                          widget.onSelect(item.value);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          color: isHighlighted
                              ? (isDark
                                  ? AppTheme.casart900.withValues(alpha: 0.5)
                                  : AppTheme.casart50)
                              : Colors.transparent,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: DefaultTextStyle(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isHighlighted
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isHighlighted
                                        ? (isDark
                                            ? AppTheme.casart200
                                            : AppTheme.casart800)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: item.child,
                                ),
                              ),
                              if (isHighlighted)
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: isDark
                                      ? AppTheme.casart200
                                      : AppTheme.casart800,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
