import 'package:flutter/material.dart';
import '../../core/constants/security_constants.dart';
import '../../core/theme/app_theme.dart';

/// Diálogo modal que solicita la clave de autorización antes de finalizar o reabrir un concurso.
class DialogoAutorizacionConcurso extends StatefulWidget {
  final String concursoNombre;
  final bool willFinalize;

  const DialogoAutorizacionConcurso({
    super.key,
    required this.concursoNombre,
    required this.willFinalize,
  });

  /// Abre el diálogo y retorna `true` si la clave ingresada fue correcta y el usuario confirmó la acción.
  static Future<bool> mostrar(
    BuildContext context, {
    required String concursoNombre,
    required bool willFinalize,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogoAutorizacionConcurso(
        concursoNombre: concursoNombre,
        willFinalize: willFinalize,
      ),
    );
    return resultado ?? false;
  }

  @override
  State<DialogoAutorizacionConcurso> createState() =>
      _DialogoAutorizacionConcursoState();
}

class _DialogoAutorizacionConcursoState
    extends State<DialogoAutorizacionConcurso> {
  final TextEditingController _claveCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _obscureText = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _claveCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validarYConfirmar() {
    final input = _claveCtrl.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa la clave de autorización.';
      });
      _focusNode.requestFocus();
      return;
    }

    if (input != SecurityConstants.claveConcursoStatus) {
      setState(() {
        _errorMessage = 'Clave incorrecta. Verifica la contraseña e intenta nuevamente.';
      });
      _focusNode.requestFocus();
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        widget.willFinalize ? AppTheme.casart800 : Colors.orange.shade800;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ENCABEZADO
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.willFinalize
                          ? Icons.task_alt_rounded
                          : Icons.replay_rounded,
                      color: primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.willFinalize
                              ? 'Finalizar Concurso'
                              : 'Reabrir Concurso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : primaryColor,
                          ),
                        ),
                        Text(
                          widget.willFinalize
                              ? 'Confirmación y autorización de cierre'
                              : 'Confirmación y reapertura del concurso',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // TARJETA IDENTIFICADORA DEL CONCURSO
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A282D)
                      : AppTheme.casart50.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.grey.shade800
                        : AppTheme.casart200.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 20,
                      color: AppTheme.casart800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.concursoNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // TEXTO EXPLICATIVO
              Text(
                widget.willFinalize
                    ? '¿Deseas marcar este concurso como FINALIZADO?\n\nEsto indicará que el periodo de inscripciones y evaluación ha concluido formalmente. Podrás consultar sus datos y reportes en cualquier momento o reabrirlo con clave si se requiere.'
                    : '¿Deseas cambiar el estatus de este concurso a "EN PROCESO"?\n\nEl concurso volverá a estar abierto para el registro de piezas y captura.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // AVISO DE SEGURIDAD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.shade600.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.amber.shade900,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción está protegida. Ingresa la clave de autorización para continuar:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // CAMPO DE CLAVE
              TextField(
                controller: _claveCtrl,
                focusNode: _focusNode,
                autofocus: true,
                obscureText: _obscureText,
                onSubmitted: (_) => _validarYConfirmar(),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Clave de autorización',
                  hintText: 'Ingresa la clave...',
                  prefixIcon: const Icon(Icons.password_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscureText ? 'Mostrar clave' : 'Ocultar clave',
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                  ),
                  errorText: _errorMessage,
                ),
              ),
              const SizedBox(height: 24),

              // ACCIONES
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: AppTheme.cancelButtonStyle,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: widget.willFinalize
                        ? AppTheme.acceptButtonStyle
                        : ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                    onPressed: _validarYConfirmar,
                    child: Text(
                      widget.willFinalize
                          ? 'Marcar Finalizado'
                          : 'Reabrir Concurso',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
